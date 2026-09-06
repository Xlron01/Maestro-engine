extends RefCounted
class_name InstitutionalRules

# ============================================================
# BATCH-A — INSTITUTIONAL RULES (minimum data-driven abstraction)
# ------------------------------------------------------------
# يجيب أسئلة من نوع: Can this actor perform this action? / Is
# parliamentary approval required? / Does this action require
# confidence? / Can this office be dismissed by this actor? / Does
# this election change the holder? — من بيانات
# data/rules/institutional_rules.json حصرًا (لا constitutional engine
# ولا magic numbers).
#
# v0 NON-FINAL: تمثيل minimum كافٍ لاختلاف المؤسسات؛ التوسع الدستوري
# لاحق بلا إعادة تصميم (قواعد بيانات تُقرأ لا كود متشعب بالأسماء).
# ============================================================

const RULES_PATH := "res://data/rules/institutional_rules.json"

var raw: Dictionary = {}


static func load() -> InstitutionalRules:
	var r := InstitutionalRules.new()
	if not FileAccess.file_exists(RULES_PATH):
		push_error("institutional_rules.json missing: %s" % RULES_PATH)
		return r
	var f := FileAccess.open(RULES_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		r.raw = parsed
	return r


func institutions() -> Dictionary:
	return raw.get("institutions", {})


func office_rules(office_id: String) -> Dictionary:
	var inst: Dictionary = institutions().get("office_" + office_id, {})
	return inst.get("rules", {})


func office_record(office_id: String) -> Dictionary:
	return institutions().get("office_" + office_id, {})


func legislature_rules(legislature_id: String) -> Dictionary:
	var inst: Dictionary = institutions().get("legislature_" + legislature_id, {})
	return inst.get("rules", {})


func election_rules(election_type: String) -> Dictionary:
	var el: Dictionary = raw.get("elections", {}).get(election_type, {})
	return el.get("rules", {})


# Can this actor appoint to this office؟ — سلطة التعيين من البيانات:
# appointing_authority = office_id يشترط أن يكون الـactor حاملَه
func can_appoint(office_id: String, actor_id: String, state) -> Dictionary:
	var rules := office_rules(office_id)
	if rules.is_empty():
		return {"ok": false, "reason": "unknown_office"}
	var auth := String(rules.get("appointing_authority", ""))
	if auth.is_empty():
		return {"ok": true, "reason": "open_appointment"}
	var holder := state.holder_of(auth)
	if holder == actor_id:
		return {"ok": true, "reason": "appointing_authority_holder"}
	return {"ok": false, "reason": "not_appointing_authority"}


# Can this actor dismiss this office؟
func can_dismiss(office_id: String, actor_id: String, state) -> Dictionary:
	var rules := office_rules(office_id)
	if rules.is_empty():
		return {"ok": false, "reason": "unknown_office"}
	var dismissible: Array = rules.get("dismissible_by", [])
	for d in dismissible:
		if state.holder_of(String(d)) == actor_id:
			return {"ok": true, "reason": "dismissible_by_holder"}
	return {"ok": false, "reason": "not_dismissible_by_actor"}


# هل تتطلب هذه المؤسسة ثقة برلمانية لتكوين الحكومة؟
func confidence_required(legislature_id: String) -> bool:
	return bool(legislature_rules(legislature_id).get("confidence_required_to_form", false))


# Does this election change composition/head؟
func election_changes_composition(election_type: String) -> bool:
	return bool(election_rules(election_type).get("changes_composition", false))


func election_changes_head(election_type: String) -> bool:
	return bool(election_rules(election_type).get("changes_head", false))
