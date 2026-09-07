extends SceneTree

# ============================================================
# TASK-039 — BATCH-A POLITICAL INSTITUTIONAL CORE — ACCEPTANCE (A–K)
# ------------------------------------------------------------
# tests-first: التوقعات أدناه مجمّدة قبل كتابة political_actions.gd.
# القيم المتوقعة مشتقة من data/rules/institutional_rules.json
# (عتبات 0.5) وdata/worlds/politics/batch_a_base.json (قوى انتخابية
# 0.45/0.40/0.15 × 200 مقعد = 90/80/30) — كل شيء deterministic بلا RNG.
#
# الأحداث المتوقعة تسلسلها حتمي؛ الأكشن يمر دائمًا:
#   Actor → Action → Queries/Assessments → Resolution → Events
#   → Owning Domain mutates State
# ============================================================

const PS := preload("res://scripts/politics/political_state.gd")
const IR := preload("res://scripts/politics/institutional_rules.gd")
const PA := preload("res://scripts/politics/political_actions.gd")
const CQ := preload("res://scripts/compliance/compliance_query.gd")
const CT := preload("res://scripts/compliance/compliance_types.gd")
const SimScript := preload("res://scripts/Simulation.gd")

const FIXTURE := "res://data/worlds/politics/batch_a_base.json"
const MODULES := [
	"res://scripts/politics/political_state.gd",
	"res://scripts/politics/institutional_rules.gd",
	"res://scripts/politics/political_actions.gd"
]

var pass_count := 0
var fail_count := 0
var rules
var base_raw: Dictionary = {}
var executed_count := 0   # عدّاد نداءات execute في هذا الجناح (لمطابقة eval_count — J3)


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		pass_count += 1
		print("  PASS  %s" % name)
	else:
		fail_count += 1
		print("  FAIL  %s  %s" % [name, detail])


func _init() -> void:
	print("")
	print("============================================================")
	print("  TASK-039 BATCH-A POLITICAL INSTITUTIONAL CORE — ACCEPTANCE")
	print("============================================================")
	rules = IR.load()
	if rules.raw.is_empty():
		print("[FATAL] institutional_rules.json missing/invalid")
		quit(1)
		return
	var f := FileAccess.open(FIXTURE, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		print("[FATAL] fixture invalid")
		quit(1)
		return
	base_raw = parsed

	_run_a()
	_run_b()
	_run_c()
	_run_d()
	_run_e()
	_run_f()
	_run_g()
	_run_h()
	_run_i()
	_run_j()

	print("")
	print("RESULT: PASS %d / FAIL %d  (execute calls=%d)" % [pass_count, fail_count, executed_count])
	quit(0 if fail_count == 0 else 1)


# ---------------- helpers ----------------

func _fresh():
	return PS.load_from(base_raw)

func _exec(state, action: String, actor: String, payload: Dictionary, entities: Dictionary = {}) -> Dictionary:
	executed_count += 1
	var ctx := {
		"rules": rules,
		"compliance_config": CT_configs(),
		"compliance_entities": entities
	}
	return PA.execute(action, actor, payload, state, ctx)


func CT_configs() -> Dictionary:
	var cf := FileAccess.open("res://data/rules/compliance_config.json", FileAccess.READ)
	var c = JSON.parse_string(cf.get_as_text())
	cf.close()
	return c

func _compliance_entities() -> Dictionary:
	# ولاء المرشح تجاه المعيّن (عقد الاستخدام: chains اختيارية ⇒ PARTIAL)
	return {
		"c_mp1": {"social_relations": {"c_king": {"loyalty": 0.9, "trust": 0.5}}},
		"c_la": {"social_relations": {"c_king": {"loyalty": 0.8, "trust": 0.5}}}
	}

const SUPPLIES := {}  # لا capability facts مطلوبة في politics actions v0


func _run_political_loop():
	var st = _fresh()
	var ents = _compliance_entities()
	var snap := []
	# 1) Election
	_exec(st, "HoldElection", "c_king", {"election_id": "el_1", "type": "general", "legislature_id": "parliament_H"}, ents)
	snap.append({"gov": "", "sup": "", "ev": _event_names(st)})
	# 2) Formation attempt below threshold
	_exec(st, "FormGovernment", "P_A", {"government_id": "gov_1", "head": "c_la",
		"legislature_id": "parliament_H", "supporting_parties": ["P_A"],
		"offices": {"office_pm": "c_la"}}, ents)
	snap.append({"gov": _gov_status(st, "gov_1"), "sup": _sup(st, "P_C"), "ev": _event_names(st)})
	# 3) Party support (forming government)
	_exec(st, "SupportGovernment", "P_C", {"government_id": "gov_1"}, ents)
	snap.append({"gov": _gov_status(st, "gov_1"), "sup": _sup(st, "P_C"), "ev": _event_names(st)})
	# 4) Formation retry (succeeds)
	_exec(st, "FormGovernment", "P_A", {"government_id": "gov_1", "head": "c_la",
		"legislature_id": "parliament_H", "supporting_parties": ["P_A", "P_C"],
		"offices": {"office_pm": "c_la"}}, ents)
	snap.append({"gov": _gov_status(st, "gov_1"), "sup": _sup(st, "P_C"), "ev": _event_names(st)})
	# 5) Confidence passes
	_exec(st, "VoteConfidence", "parliament_H", {"government_id": "gov_1",
		"legislature_id": "parliament_H", "votes": {"P_A": "aye", "P_C": "aye", "P_B": "nay"}}, ents)
	snap.append({"gov": _gov_status(st, "gov_1"), "sup": _sup(st, "P_C"), "ev": _event_names(st)})
	# 6) No-confidence fails (survives)
	_exec(st, "VoteNoConfidence", "parliament_H", {"government_id": "gov_1",
		"legislature_id": "parliament_H", "votes": {"P_B": "aye"}}, ents)
	snap.append({"gov": _gov_status(st, "gov_1"), "sup": _sup(st, "P_C"), "ev": _event_names(st)})
	# 7) Withdraw support (no direct fall)
	_exec(st, "WithdrawSupport", "P_C", {"government_id": "gov_1"}, ents)
	snap.append({"gov": _gov_status(st, "gov_1"), "sup": _sup(st, "P_C"), "ev": _event_names(st)})
	# 8) No-confidence passes (falls)
	_exec(st, "VoteNoConfidence", "parliament_H", {"government_id": "gov_1",
		"legislature_id": "parliament_H", "votes": {"P_B": "aye", "P_C": "aye"}}, ents)
	snap.append({"gov": _gov_status(st, "gov_1"), "sup": _sup(st, "P_C"), "ev": _event_names(st)})
	return {"state": st, "snap": snap}


func _gov_status(st, gov_id: String) -> String:
	if not st.governments.has(gov_id):
		return ""
	return String((st.governments[gov_id] as Dictionary).get("status", ""))


func _sup(st, party_id: String) -> String:
	return String(st.government_support.get(party_id, ""))


func _event_names(st) -> Array:
	var out: Array = []
	for e in st.event_log:
		out.append(String(e["event"]))
	return out


# ---------------- A — Political loop ----------------

func _run_a() -> void:
	print("\n-- A: full political loop with per-transition state assertions")
	var out = _run_political_loop()
	var st = out["state"]
	var snap: Array = out["snap"]

	_check("A1 election held: history=1 result=1 winner=P_A tally=90/80/30",
		st.election_history.size() == 1 and st.election_results.size() == 1
		and String(st.election_results[0]["winner_party"]) == "P_A"
		and int(st.election_results[0]["tally"][0]["seats"]) == 90
		and int(st.election_results[0]["tally"][1]["seats"]) == 80
		and int(st.election_results[0]["tally"][2]["seats"]) == 30)
	_check("A2 formation below threshold => incomplete (forming, no GovernmentFormed)",
		String(snap[1]["gov"]) == "forming"
		and (snap[1]["ev"] as Array).has("FormationIncomplete")
		and not (snap[1]["ev"] as Array).has("GovernmentFormed"))
	_check("A3 support relation exists via sparse map after SupportGovernment",
		String(snap[2]["sup"]) == "gov_1"
		and (snap[2]["ev"] as Array).has("GovernmentSupportChanged"))
	_check("A4 formation retry => formed + office assigned at formation",
		String(snap[3]["gov"]) == "active"
		and (snap[3]["ev"] as Array).has("GovernmentFormed")
		and (snap[3]["ev"] as Array).has("OfficeAssignment")
		and st.offices["office_pm"]["holder"] == "c_la")
	_check("A5 confidence passed; then no-confidence failed (survives)",
		(snap[4]["ev"] as Array).has("ConfidencePassed")
		and (snap[5]["ev"] as Array).has("NoConfidenceFailed")
		and String(snap[5]["gov"]) == "active")
	_check("A6 withdraw: relation removed; government NOT directly fallen",
		String(snap[6]["sup"]) == ""
		and String(snap[6]["gov"]) == "active"
		and (snap[6]["ev"] as Array).has("GovernmentSupportWithdrawn"))
	_check("A7 no-confidence passes => GovernmentRemoved (institutional resolution)",
		(snap[7]["ev"] as Array).has("NoConfidencePassed")
		and (snap[7]["ev"] as Array).has("GovernmentRemoved")
		and String(st.governments["gov_1"]["status"]) == "removed")


# ---------------- B — Election != Succession ----------------

func _run_b() -> void:
	print("\n-- B: Election != Succession (incumbent wins vs opposition wins)")
	# B1: incumbent party wins => no mandatory succession
	var st = _fresh()
	var ents := _compliance_entities()
	_exec(st, "SupportGovernment", "P_C", {"government_id": "gov_1"}, ents)
	_exec(st, "FormGovernment", "P_A", {"government_id": "gov_1", "head": "c_la",
		"legislature_id": "parliament_H", "supporting_parties": ["P_A", "P_C"],
		"offices": {"office_pm": "c_la"}}, ents)
	_exec(st, "HoldElection", "c_king", {"election_id": "el_2", "type": "general", "legislature_id": "parliament_H"}, ents)
	var has_el := false
	for e in st.election_history:
		if String(e["election_id"]) == "el_2":
			has_el = true
	_check("B1 incumbent wins: election+result exist, NO succession record, no succession_id on election",
		has_el and st.succession_history.is_empty()
		and not (st.election_history[0] as Dictionary).has("succession_id"))

	# B2: opposition wins (deterministic variant) => succession per institutional rules
	var raw2 := (base_raw as Dictionary).duplicate(true)
	(raw2["parties"]["P_A"]["political_profile"] as Dictionary)["electoral_strength"] = 0.40
	(raw2["parties"]["P_B"]["political_profile"] as Dictionary)["electoral_strength"] = 0.55
	(raw2["parties"]["P_C"]["political_profile"] as Dictionary)["electoral_strength"] = 0.05
	var st2 = PS.load_from(raw2)
	_exec(st2, "SupportGovernment", "P_C", {"government_id": "gov_1"}, ents)
	_exec(st2, "FormGovernment", "P_A", {"government_id": "gov_1", "head": "c_la",
		"legislature_id": "parliament_H", "supporting_parties": ["P_A", "P_C"],
		"offices": {"office_pm": "c_la"}}, ents)
	_exec(st2, "HoldElection", "c_king", {"election_id": "el_2", "type": "general", "legislature_id": "parliament_H"}, ents)
	var suc_ok: bool = st2.succession_history.size() == 1
	var suc = {}
	if suc_ok:
		var s0 = st2.succession_history[0]
		suc = s0
	_check("B2 opposition wins => succession occurred with election_id link + composition changed",
		suc_ok and String(suc.get("election_id", "")) == "el_2"
		and String(suc.get("cause", "")) == "election"
		and String(st2.offices["office_pm"]["holder"]) == "c_lb"
		and int(st2.legislatures["parliament_H"]["seats"]["P_B"]) == 110)

	# dispute contract (بدل disputed bool)
	_exec(st2, "ContestElectionResult", "P_A", {"election_id": "el_2", "dispute_id": "disp_1"}, ents)
	_check("B3 dispute recorded in ElectionDisputeHistory linked by election_id",
		st2.election_disputes.size() == 1
		and String(st2.election_disputes[0]["election_id"]) == "el_2"
		and String(st2.election_disputes[0]["status"]) == "raised")


# ---------------- C — Party support ----------------

func _run_c() -> void:
	print("\n-- C: party support relation, no direct parliament mutation")
	var st = _fresh()
	var ents := _compliance_entities()
	var seats_before := CT.canonical(st.legislatures["parliament_H"]["seats"])
	_exec(st, "FormGovernment", "P_A", {"government_id": "gov_1", "head": "c_la",
		"legislature_id": "parliament_H", "supporting_parties": ["P_A"],
		"offices": {}}, ents)
	_exec(st, "SupportGovernment", "P_C", {"government_id": "gov_1"}, ents)
	_check("C1 support relation exists (sparse map)",
		String(st.government_support.get("P_C", "")) == "gov_1"
		and _event_names(st).has("GovernmentSupportChanged"))
	_exec(st, "WithdrawSupport", "P_C", {"government_id": "gov_1"}, ents)
	_check("C2 withdraw removes relation; parliament seats bitwise unchanged",
		not st.government_support.has("P_C")
		and CT.canonical(st.legislatures["parliament_H"]["seats"]) == seats_before)


# ---------------- D — Office ----------------

func _run_d() -> void:
	print("\n-- D: office lifecycle without duplicated history")
	var st = _fresh()
	var ents := _compliance_entities()
	var chars_before := CT.canonical(st.characters)
	# رئيس الدولة يعيّن رئيس الحكومة (appointing_authority=office_president)
	var r1 = _exec(st, "AppointOfficeholder", "c_king", {"office_id": "office_pm", "candidate": "c_la"}, ents)
	_check("D1 appoint head-of-government by head-of-state: holder changes + OfficeFilled",
		bool(r1["ok"]) and st.offices["office_pm"]["holder"] == "c_la"
		and String(st.offices["office_pm"]["status"]) == "appointed"
		and _event_names(st).has("OfficeFilled"))
	# رئيس الحكومة يعيّن وزيرًا (appointing_authority=office_pm)
	var r1b = _exec(st, "AppointOfficeholder", "c_la", {"office_id": "office_finance", "candidate": "c_mp1"}, ents)
	_check("D1b PM appoints minister per rules",
		bool(r1b["ok"]) and st.offices["office_finance"]["holder"] == "c_mp1")
	# مخالفة سلطة التعيين
	var r_bad = _exec(st, "AppointOfficeholder", "c_la", {"office_id": "office_pm", "candidate": "c_mp1"}, ents)
	_check("D2 non-appointing-authority fails by rules",
		not bool(r_bad["ok"]) and String(r_bad["reason"]) == "not_appointing_authority")
	# عزل pm: شاغر + لا succession (succession_on_vacancy=none) + الكيان لم يتغير + بلا تاريخ مكرر
	_exec(st, "DismissOfficeholder", "c_king", {"office_id": "office_pm"}, ents)
	_check("D3 dismiss: office vacant; character untouched; exactly 5 minimum fields; no succession",
		st.offices["office_pm"]["holder"] == null
		and String(st.offices["office_pm"]["status"]) == "vacant"
		and st.succession_history.is_empty()
		and CT.canonical(st.characters) == chars_before
		and (st.offices["office_pm"] as Dictionary).keys().size() == 5)


# ---------------- E — Bills ----------------

func _run_e() -> void:
	print("\n-- E: bills — propose, vote, outcome separated from vote action")
	var st = _fresh()
	var ents := _compliance_entities()
	_exec(st, "ProposeBill", "P_A", {"bill_id": "b_1", "legislature_id": "parliament_H", "title": "Budget"}, ents)
	_check("E1 BillProposed: bill exists, status proposed, active in legislature",
		String(st.bills["b_1"]["status"]) == "proposed"
		and (st.legislatures["parliament_H"]["active_bills"] as Array).has("b_1")
		and _event_names(st).has("BillProposed"))
	_exec(st, "VoteBill", "parliament_H", {"bill_id": "b_1",
		"legislature_id": "parliament_H", "votes": {"P_A": "aye", "P_C": "aye", "P_B": "nay"}}, ents)
	_check("E2 vote recorded and outcome separate: BillVoted then BillPassed",
		_event_names(st).has("BillVoted") and _event_names(st).has("BillPassed")
		and String(st.bills["b_1"]["status"]) == "passed")
	_exec(st, "ProposeBill", "P_B", {"bill_id": "b_2", "legislature_id": "parliament_H", "title": "Reform"}, ents)
	_exec(st, "VoteBill", "parliament_H", {"bill_id": "b_2", "legislature_id": "parliament_H", "votes": {"P_A": "nay", "P_B": "aye", "P_C": "nay"}}, ents)
	_check("E3 rejection path deterministic: BillRejected (40% < threshold)",
		_event_names(st).has("BillRejected") and String(st.bills["b_2"]["status"]) == "rejected")


# ---------------- F — Confidence determinism ----------------

func _run_f() -> void:
	print("\n-- F: confidence transitions deterministic (incl. ResignGovernment)")
	var st = _run_political_loop()["state"]
	# بعد سقوط gov_1: حكومة جديدة من المعارضة ثم استقالتها
	var ents := _compliance_entities()
	_exec(st, "FormGovernment", "P_B", {"government_id": "gov_2", "head": "c_lb",
		"legislature_id": "parliament_H", "supporting_parties": ["P_B", "P_C"],
		"offices": {"office_pm": "c_lb"}}, ents)
	_check("F1 opposition forms government after removal (55% >= threshold)",
		String(st.governments["gov_2"]["status"]) == "active")
	var r = _exec(st, "ResignGovernment", "c_lb", {"government_id": "gov_2"}, ents)
	_check("F2 ResignGovernment: GovernmentResigned + status resigned",
		bool(r["ok"]) and _event_names(st).has("GovernmentResigned")
		and String(st.governments["gov_2"]["status"]) == "resigned")
	var seq1 := []
	for e in st.event_log:
		seq1.append(int(e["seq"]))
	var ordered := true
	for i in range(seq1.size()):
		if int(seq1[i]) != i + 1:
			ordered = false
	_check("F3 event sequence strictly deterministic (seq = 1..N)", ordered)


# ---------------- G — Compliance integration ----------------

func _run_g() -> void:
	print("\n-- G: actions consume ComplianceAssessment, never execute it directly")
	var st = _fresh()
	var ents := _compliance_entities()
	var before: int = CQ.eval_count
	var state_before = st.canonical()
	var r = _exec(st, "AppointOfficeholder", "c_king", {"office_id": "office_pm", "candidate": "c_la"}, ents)
	_check("G1 exactly one compliance assessment consumed during the action",
		CQ.eval_count == before + 1
		and (r["assessments"] as Array).size() == 1
		and (r["assessments"][0] as Dictionary).has("compliance_degree"))
	# الاستعلام وحده (بلا resolution) لا يغير الحالة — الفصل Assessment ≠ Mutation
	var st2 = _fresh()
	var before2 = st2.canonical()
	var cctx := {"entities": ents, "chains": null, "config": CT_configs(),
		"action": {"id": "AcceptAppointment", "requires": [], "harms_interests": []},
		"actor_id": "c_mp1", "target_id": "c_king"}
	CQ.assess("c_mp1", cctx["action"], "c_king", cctx)
	_check("G2 bare compliance query leaves state bitwise untouched",
		st2.canonical() == before2)


# ---------------- H — PARTIAL dependencies ----------------

func _run_h() -> void:
	print("\n-- H: missing ConstitutionalValidity/PopularSupport => PARTIAL, no fabrication")
	var st = _fresh()
	var ents := _compliance_entities()
	var r = _exec(st, "AppointOfficeholder", "c_king", {"office_id": "office_pm", "candidate": "c_la"}, ents)
	var a: Dictionary = r["assessments"][0]
	var missing: Array = a["missing_inputs"]
	var has_ps := false
	var has_cv := false
	for m in missing:
		if String(m).contains("PopularSupport"):
			has_ps = true
		if String(m).contains("ConstitutionalValidity"):
			has_cv = true
	_check("H1 assessment PARTIAL with missing_inputs populated (PopularSupport/ConstitutionalValidity)",
		String(a["status"]) == "PARTIAL" and has_ps and has_cv)
	_check("H2 no fabricated values: degree/mode present from v0 evidence rules, missing listed not defaulted",
		a["compliance_degree"] != null and a["resistance_mode"] != null
		and not missing.is_empty())


# ---------------- I — Determinism ----------------

func _run_i() -> void:
	print("\n-- I: same initial state + same action stream => same checksum/events")
	var o1 = _run_political_loop()
	var o2 = _run_political_loop()
	var s1 = o1["state"]
	var s2 = o2["state"]
	_check("I1 state checksum identical (canonical bitwise)",
		s1.canonical() == s2.canonical())
	_check("I2 event sequence identical (canonical bitwise)",
		CT.canonical(s1.event_log) == CT.canonical(s2.event_log))


# ---------------- J — No per-tick activity ----------------

func _run_j() -> void:
	print("\n-- J: no per-tick polling (audit + runtime counter)")
	var audit_ok := true
	var audit_detail := ""
	for p in MODULES:
		var fa := FileAccess.open(p, FileAccess.READ)
		if fa == null:
			audit_ok = false
			audit_detail = "cannot open " + p
			break
		var src := fa.get_as_text()
		fa.close()
		# ScheduledQueue أزيلت من قائمة الحظر بتوجيه TASK-040-pre §2/A7 (أحدث):
		# إعادة استخدام ScheduledQueue كinstance مملوك مطلوبة صراحة — المحظور
		# يبقى اقتران مسار الإنتاج الفعلي (tick loop/EventQueue/dispatch/rng).
		for token in ["_process(", "run_step(", "EventQueue",
				"dispatch.json", "RandomNumberGenerator", "randf(", "randi(", "Time.get"]:
			if src.contains(token):
				audit_ok = false
				audit_detail = "%s contains %s" % [p, token]
	_check("J1 source audit: no tick-loop/engine-coupling/rng/time in politics modules",
		audit_ok, audit_detail)

	var before: int = PA.eval_count
	var sim = SimScript.new()
	sim.init_world(12345)
	for i in range(30):
		sim.run_step()
	var after_ticks: int = PA.eval_count
	_exec(_fresh(), "SupportGovernment", "P_C", {"government_id": "gov_1"}, _compliance_entities())
	_check("J2 runtime: 30 production ticks => 0 political evaluations; explicit action => exactly +1",
		after_ticks == before and PA.eval_count == after_ticks + 1)
	_check("J3 no hidden evaluations: total execute calls == eval_count delta",
		PA.eval_count == executed_count)
