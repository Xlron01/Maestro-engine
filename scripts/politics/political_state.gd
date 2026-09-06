extends RefCounted
class_name PoliticalState

# ============================================================
# BATCH-A — POLITICAL INSTITUTIONAL CORE — Owning Domain State (TASK-039)
# ------------------------------------------------------------
# المالك الوحيد لحالة politics: Offices / Parties / Legislatures /
# Bills / Governments + عقود التاريخ:
#   ElectionHistory[] · ElectionResult[] · ElectionDisputeHistory[]
#   SuccessionHistory[] · RegimeHistory[]
#
# ملاحظة تنفيذية موثقة (تعارض موثق لا تغيير صامت): المواصفة قالت
# "استخدم الـcontracts الموجودة" — هذه العقود لم تكن موجودة في أي كود
# سابق (تدقيق grep موثق في تقرير المهمة)؛ هذا أول implementation لها
# بالأسماء والأشكال المحددة في المواصفة حرفيًا.
#
# قواعد مجمدة:
#   - التاريخ لا يتحول إلى current-state duplication: Office لا يحمل
#     سجل تعيينات، Government لا يحمل previous_government.
#   - persistent entity ≠ active update: صفر polling هنا — الاستخدام
#     on-demand عبر PoliticalActions فقط (قبول J يراقب).
#   - صفر stochastic: لا Time.* ولا RNG داخل هذه الوحدة — deterministic.
#   - الـmutation حصرًا عبر apply_* / emit_event (الـActions لا تكتب
#     الحقول مباشرة — pipeline: Resolution → Owning Domain → State).
# ============================================================

const CT := preload("res://scripts/compliance/compliance_types.gd")

var characters := {}          # character_id -> {character_id, name?} (هوية فقط)
var offices := {}             # office_id -> Office
var parties := {}             # party_id -> Party
var legislatures := {}        # legislature_id -> Legislature
var bills := {}               # bill_id -> Bill
var governments := {}         # government_id -> Government
var government_support := {}  # party_id -> government_id (sparse — علاقة الدعم الوحيدة)
var election_history := []    # ElectionHistory[]
var election_results := []    # ElectionResult[]
var election_disputes := []   # ElectionDisputeHistory[]
var succession_history := []  # SuccessionHistory[]
var regime_history := []      # RegimeHistory[]
var event_log := []           # تسلسل أحداث حتمي مرقم
var _seq := 0


static func load_from(data: Dictionary):
	var s = new()
	for c in (data.get("characters", {}) as Dictionary).keys():
		s.characters[String(c)] = {"character_id": String(c)}
	s.parties = _deep(data.get("parties", {}))
	s.legislatures = _deep(data.get("legislatures", {}))
	s.offices = _deep(data.get("offices", {}))
	s.governments = _deep(data.get("governments", {}))
	s.government_support = _deep(data.get("government_support", {}))
	return s


static func _deep(v):
	return (v as Dictionary).duplicate(true)


# ---------------- Queries (لا duplication) ----------------

func supporting_parties(gov_id: String) -> Array:
	# الدعم الحي مشتق من علاقة sparse government_support — ليس حقلًا مخزنًا ثانيًا
	var out: Array = []
	for p in government_support.keys():
		if String(government_support[p]) == gov_id:
			out.append(String(p))
	out.sort()
	return out

func seats_total(leg_id: String) -> int:
	var leg: Dictionary = legislatures.get(leg_id, {})
	var total := 0
	for p in (leg.get("seats", {}) as Dictionary):
		total += int(leg["seats"][p])
	return total

func seat_share(leg_id: String, party_ids: Array) -> float:
	var total := seats_total(leg_id)
	if total <= 0:
		return 0.0
	var s := 0
	var seats: Dictionary = (legislatures.get(leg_id, {}) as Dictionary).get("seats", {})
	for p in party_ids:
		s += int(seats.get(String(p), 0))
	return float(s) / float(total)

func holder_of(office_id: String) -> String:
	var o: Dictionary = offices.get(office_id, {})
	return String(o.get("holder", "")) if o.get("holder") != null else ""

func party_of_leader(character_id: String) -> String:
	for p in parties.keys():
		if String((parties[p] as Dictionary).get("leader", "")) == character_id:
			return String(p)
	return ""

func head_government(head_character: String) -> String:
	for g in governments.keys():
		var gd: Dictionary = governments[g]
		if String(gd.get("head", "")) == head_character and String(gd.get("status", "")) in ["active", "forming"]:
			return String(g)
	return ""


# ---------------- Owning-domain mutators (الوحيدة المسموحة) ----------------

func emit_event(event_name: String, payload: Dictionary) -> Dictionary:
	_seq += 1
	var e := {"event": String(event_name), "seq": _seq, "payload": payload}
	event_log.append(e)
	return e


func apply_office_fill(office_id: String, holder: String) -> void:
	offices[office_id]["holder"] = holder
	offices[office_id]["status"] = "appointed"

func apply_office_vacate(office_id: String) -> void:
	offices[office_id]["holder"] = null
	offices[office_id]["status"] = "vacant"

func apply_government(gov: Dictionary) -> void:
	governments[String(gov["government_id"])] = gov

func apply_government_status(gov_id: String, status: String) -> void:
	governments[gov_id]["status"] = status

func apply_bill(bill: Dictionary) -> void:
	bills[String(bill["bill_id"])] = bill
	var leg_id := String(bill["legislature_id"])
	var active: Array = legislatures[leg_id].get("active_bills", [])
	if not active.has(String(bill["bill_id"])):
		active.append(String(bill["bill_id"]))
	legislatures[leg_id]["active_bills"] = active

func apply_bill_status(bill_id: String, status: String) -> void:
	bills[bill_id]["status"] = status

func apply_support(party_id: String, gov_id: String) -> void:
	government_support[party_id] = gov_id

func apply_withdraw_support(party_id: String) -> void:
	government_support.erase(party_id)

func apply_seats(leg_id: String, seats: Dictionary) -> void:
	legislatures[leg_id]["seats"] = seats

func apply_election(election_rec: Dictionary, result_rec: Dictionary) -> void:
	election_history.append(election_rec)
	election_results.append(result_rec)

func apply_dispute(rec: Dictionary) -> void:
	election_disputes.append(rec)

func apply_succession(rec: Dictionary) -> void:
	succession_history.append(rec)

func apply_regime(rec: Dictionary) -> void:
	regime_history.append(rec)


# ---------------- Serialization / Determinism ----------------

func to_dict() -> Dictionary:
	return {
		"characters": characters.duplicate(true),
		"offices": offices.duplicate(true),
		"parties": parties.duplicate(true),
		"legislatures": legislatures.duplicate(true),
		"bills": bills.duplicate(true),
		"governments": governments.duplicate(true),
		"government_support": government_support.duplicate(true),
		"election_history": election_history.duplicate(true),
		"election_results": election_results.duplicate(true),
		"election_disputes": election_disputes.duplicate(true),
		"succession_history": succession_history.duplicate(true),
		"regime_history": regime_history.duplicate(true),
		"event_log": event_log.duplicate(true)
	}

func canonical() -> String:
	return CT.canonical(to_dict())
