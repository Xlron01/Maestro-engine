extends SceneTree

# ============================================================
# TASK-040-pre — MINIMAL DEADLINE ACTIVATION PROOF — ACCEPTANCE (A1–A7)
# ------------------------------------------------------------
# tests-first: التوقعات مجمّدة قبل التشغيل. Workload حتمي صفر-RNG
# (seed: N/A — لا عشوائية إطلاقًا في توليد الحمل).
# القيم الزمنية من data/worlds/politics/deadline_proof.json —
# TEST FIXTURE VALUE لا قيمة إنتاجية توازنية:
#   term_duration_days=30 · deadline_due_at=30 · election_call_days=0
#   test_horizon_days=45
# مصدر الزمن: SimClock الإنتاجي عبر Simulation.run_step (1 step = 1 day)
# — pump بعد كل tick (نقطة الدمج الموثقة في الـorchestrator).
# الأوراكل: canonical snapshot (ترتيب مستقر، بلا عناوين ذاكرة/عدادات
# benchmark) → SHA-256. تشغيلان متطابقان ⇒ hash واحد.
# ============================================================

const PS := preload("res://scripts/politics/political_state.gd")
const IR := preload("res://scripts/politics/institutional_rules.gd")
const PA := preload("res://scripts/politics/political_actions.gd")
const PD := preload("res://scripts/politics/political_deadlines.gd")
const CT := preload("res://scripts/compliance/compliance_types.gd")
const SQ := preload("res://scripts/ScheduledQueue.gd")
const SimScript := preload("res://scripts/Simulation.gd")

const FIXTURE := "res://data/worlds/politics/deadline_proof.json"
const BASE := "res://data/worlds/politics/batch_a_base.json"
const MODULES := [
	"res://scripts/politics/political_state.gd",
	"res://scripts/politics/institutional_rules.gd",
	"res://scripts/politics/political_actions.gd",
	"res://scripts/politics/political_deadlines.gd"
]

var pass_count := 0
var fail_count := 0
var base_raw: Dictionary = {}
var fix: Dictionary = {}
var horizon := 45


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
	print("  TASK-040-pre — MINIMAL DEADLINE ACTIVATION PROOF (A1-A7)")
	print("============================================================")
	var f := FileAccess.open(FIXTURE, FileAccess.READ)
	fix = JSON.parse_string(f.get_as_text())
	f.close()
	var b := FileAccess.open(BASE, FileAccess.READ)
	base_raw = JSON.parse_string(b.get_as_text())
	b.close()
	horizon = int(fix["fixture_terms"]["test_horizon_days"])
	print("  fixture: term=%d due_at=%d call_days=%d horizon=%d seed=%s"
		% [int(fix["fixture_terms"]["term_duration_days"]),
			int(fix["fixture_terms"]["deadline_due_at"]),
			int(fix["fixture_terms"]["election_call_days"]), horizon,
			str(fix["fixture_terms"]["seed"])])

	_t1_causal_chain()
	_t2_no_fabrication()
	_t3_independent_deadline()
	_t4_no_miss_and_no_duplicates()
	_t5_ownership_and_reuse()
	_t6_determinism_oracle()

	print("")
	print("RESULT: PASS %d / FAIL %d" % [pass_count, fail_count])
	quit(0 if fail_count == 0 else 1)


# ---------------- helpers ----------------

func _fresh():
	return PS.load_from(base_raw)


func _cfg() -> Dictionary:
	var cf := FileAccess.open("res://data/rules/compliance_config.json", FileAccess.READ)
	var c = JSON.parse_string(cf.get_as_text())
	cf.close()
	return c


func _rules_variant(term_causes: bool):
	var r = IR.load()
	var ft: Dictionary = fix["fixture_terms"]
	var lrules: Dictionary = (r.raw["institutions"]["legislature_parliament_H"] as Dictionary)["rules"]
	lrules["government_term_days"] = int(ft["term_duration_days"])
	lrules["term_expiration_causes_election"] = term_causes
	lrules["election_call_days"] = int(ft["election_call_days"])
	((r.raw["elections"]["general"] as Dictionary)["rules"] as Dictionary)["schedulable_independently"] = true
	return r


func _compliance_entities() -> Dictionary:
	return {"c_la": {"social_relations": {"c_king": {"loyalty": 0.8, "trust": 0.5}}}}


# السيناريو الكامل: تكوين حكومة يوم 0 عبر الـpipeline، ثم تشغيل إنتاجي
# 45 tick مع pump بعد كل tick (زمن SimClock الحقيقي)
func _run_scenario(term_causes: bool):
	var rules = _rules_variant(term_causes)
	var st = _fresh()
	var ents := _compliance_entities()
	var base_ctx := {"rules": rules, "compliance_config": _cfg(), "compliance_entities": ents}
	var form_ctx: Dictionary = base_ctx.duplicate()
	form_ctx["current_day"] = 0
	PA.execute("FormGovernment", "P_A", {"government_id": "gov_1", "head": "c_la",
		"legislature_id": "parliament_H", "supporting_parties": ["P_A", "P_C"],
		"offices": {"office_pm": "c_la"}}, st, form_ctx)
	var sim = SimScript.new()
	sim.init_world(12345)
	var diag_log: Array = []
	var pa_before: int = PA.eval_count
	for t in range(1, horizon + 1):
		sim.run_step()
		var day: int = sim.clock.total_days()
		var d: Dictionary = PD.pump(st, day, rules, PA, base_ctx)
		diag_log.append(d)
	return {"state": st, "diag": diag_log, "rules": rules,
		"pa_delta": PA.eval_count - pa_before}


func _dl(st, id: String) -> Dictionary:
	return st.deadlines.get(id, {})


func _sum_activated(diag: Array, up_to_day: int) -> int:
	var total := 0
	for d in diag:
		if int(d["day"]) <= up_to_day:
			total += int(d["activated"])
	return total


# ---------------- T1: A1 + A2 + السلسلة السببية المطلوبة ----------------

func _t1_causal_chain() -> void:
	print("\n-- T1: term expiration -> rule eval -> election deadline -> activation -> resolution")
	var out = _run_scenario(true)
	var st = out["state"]
	var diag: Array = out["diag"]

	_check("T1a term deadline scheduled at formation (due_at=30, owner=gov_1)",
		st.deadlines.has("dl_term_gov_1")
		and String(_dl(st, "dl_term_gov_1")["status"]) == "resolved"
		and int(_dl(st, "dl_term_gov_1")["due_at"]) == 30
		and int(_dl(st, "dl_term_gov_1")["scheduled_at"]) == 0
		and String(_dl(st, "dl_term_gov_1")["owner"]) == "gov_1")
	_check("T1b A1: no activation before due day (ticks 1-29 => 0 activations)",
		_sum_activated(diag, 29) == 0)
	var term: Dictionary = _dl(st, "dl_term_gov_1")
	_check("T1c A1: term deadline activated exactly at due day 30 (lateness 0)",
		int(term["actual_activation_at"]) == 30
		and int(term["lateness_days"]) == 0
		and String(term["resolution"]["outcome"]) == "election_deadline_scheduled")
	_check("T1d A4 causal wiring: election deadline created BY the rule evaluation",
		st.deadlines.has("dl_election_dl_term_gov_1")
		and String(_dl(st, "dl_election_dl_term_gov_1")["deadline_type"]) == "election_due"
		and int(_dl(st, "dl_election_dl_term_gov_1")["due_at"]) == 30)
	_check("T1e election executed once via pipeline (HoldElection reached the domain)",
		st.election_history.size() == 1
		and String(st.election_results[0]["winner_party"]) == "P_A")
	_check("T1f A2: required deadlines all resolved at horizon (none silently missed)",
		st.deadline_stats["scheduled"] == st.deadline_stats["resolved"]
		and st.deadlines.size() == 2)
	var all_resolved := true
	for id in st.deadlines:
		if String((st.deadlines[id] as Dictionary)["status"]) != "resolved":
			all_resolved = false
	_check("T1g deadline queue drained (size 0) and every record resolved",
		all_resolved and int(diag[diag.size() - 1]["queue_size"]) == 0)
	_check("T1h A3: zero duplicate activations",
		int(st.deadline_stats["duplicates"]) == 0
		and int(_dl(st, "dl_term_gov_1")["activation_count"]) == 1
		and int(_dl(st, "dl_election_dl_term_gov_1")["activation_count"]) == 1)


# ---------------- T2: A4 negative — لا اختلاق سببية غير مطلوبة ----------------

func _t2_no_fabrication() -> void:
	print("\n-- T2: rules WITHOUT term->election => term resolves, no election fabricated")
	var out = _run_scenario(false)
	var st = out["state"]
	var term: Dictionary = _dl(st, "dl_term_gov_1")
	var has_election_dl := false
	for id in st.deadlines:
		if String((st.deadlines[id] as Dictionary)["deadline_type"]) == "election_due":
			has_election_dl = true
	_check("T2 term resolved as no_election_required_per_rules; no election deadline; no election",
		String(term["status"]) == "resolved"
		and String(term["resolution"]["outcome"]) == "no_election_required_per_rules"
		and not has_election_dl and st.election_history.is_empty())


# ---------------- T3: election deadline مستقل (ليس hardwired) ----------------

func _t3_independent_deadline() -> void:
	print("\n-- T3: independent election_due deadline (no government term involved)")
	var rules = _rules_variant(true)
	var st = _fresh()
	var ents := _compliance_entities()
	var ctx := {"rules": rules, "compliance_config": _cfg(), "compliance_entities": ents}
	PD.schedule(st, "dl_election_indep", "election_due", "c_king", 10, 0,
		{"legislature_id": "parliament_H", "election_id": "el_indep", "type": "general"})
	var activated_at := -1
	var sim = SimScript.new()
	sim.init_world(12345)
	for t in range(1, 13):
		sim.run_step()
		var day: int = sim.clock.total_days()
		var d: Dictionary = PD.pump(st, day, rules, PA, ctx)
		if int(d["activated"]) > 0 and activated_at == -1:
			activated_at = day
	_check("T3 independent election deadline activates at day 10 and executes HoldElection",
		activated_at == 10
		and String(_dl(st, "dl_election_indep")["status"]) == "resolved"
		and st.election_history.size() == 1
		and String(st.election_history[0]["election_id"]) == "el_indep")


# ---------------- T4/T5: A2+A3 على الحالة النهائية ----------------

func _t4_no_miss_and_no_duplicates() -> void:
	print("\n-- T4/T5: horizon sweep — no missed deadline, no duplicate activation")
	var out = _run_scenario(true)
	var st = out["state"]
	var due_total := 0
	var act_total := 0
	var res_total := 0
	for id in st.deadlines:
		var rec: Dictionary = st.deadlines[id]
		if String(rec["status"]) != "resolved":
			due_total += 1
		if int(rec["activation_count"]) != 1:
			act_total += 1
	_check("T4 A2: zero deadlines stuck un-resolved at horizon", due_total == 0)
	_check("T5 A3: every deadline activated exactly once",
		act_total == 0 and int(st.deadline_stats["duplicates"]) == 0
		and int(st.deadline_stats["activated"]) == int(st.deadline_stats["resolved"]))


# ---------------- T7/T8: A6 ownership + A7 no scheduler duplication ----------------

func _t5_ownership_and_reuse() -> void:
	print("\n-- T7/T8: ownership path preserved + scheduler reuse (no second scheduler)")
	var out = _run_scenario(true)
	var st = out["state"]
	# A6: التنشيط المشتق مر عبر PoliticalActions (HoldElection) لا كتابة مباشرة
	# 2 deadlines activated؛ election_due الوحيد الذي ينفذ action ⇒ تقييم واحد
	_check("T7 A6: deadline activation flowed through the Action pipeline",
		int(out["pa_delta"]) == 1
		and st.event_log.size() > 0
		and _ev_has(st, "DeadlineActivated") and _ev_has(st, "DeadlineResolved")
		and _ev_has(st, "ElectionHeld"))
	_check("T8 A7: deadline queue REUSES kernel ScheduledQueue CLASS (mechanism reuse per Decision 004)",
		st.deadline_queue is SQ)
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
		for token in ["_process(", "run_step(", "EventQueue", "dispatch.json",
				"RandomNumberGenerator", "randf(", "randi(", "Time.get"]:
			if src.contains(token):
				audit_ok = false
				audit_detail = "%s contains %s" % [p, token]
	_check("T8b source audit: no polling/engine-coupling/rng in politics modules",
		audit_ok, audit_detail)


func _ev_has(st, name: String) -> bool:
	for e in st.event_log:
		if String(e["event"]) == name:
			return true
	return false


# ---------------- T6: A5 determinism oracle ----------------

func _t6_determinism_oracle() -> void:
	print("\n-- T6: A5 determinism — canonical snapshot + SHA-256 across repeated runs")
	var o1 = _run_scenario(true)
	var o2 = _run_scenario(true)
	var s1 = o1["state"]
	var s2 = o2["state"]
	var h1: String = s1.canonical().sha256_text()
	var h2: String = s2.canonical().sha256_text()
	print("  CANONICAL_SHA256 run1 = %s" % h1)
	print("  CANONICAL_SHA256 run2 = %s" % h2)
	_check("T6 A5: identical canonical simulation state => identical SHA-256",
		h1 == h2 and h1.length() == 64)
	_check("T6b canonical excludes runtime metadata: snapshot deterministic across runs",
		CT.canonical(s1.event_log) == CT.canonical(s2.event_log)
		and CT.canonical(s1.deadlines) == CT.canonical(s2.deadlines))


# ---------------- lateness diagnostic (§9) ----------------

func _late_diagnostic() -> int:
	# تشخيصي: caller متأخر — pump يقفز من يوم 29 إلى 35
	var rules = _rules_variant(true)
	var st = _fresh()
	var ents := _compliance_entities()
	var ctx := {"rules": rules, "compliance_config": _cfg(), "compliance_entities": ents}
	var form_ctx: Dictionary = ctx.duplicate()
	form_ctx["current_day"] = 0
	PA.execute("FormGovernment", "P_A", {"government_id": "gov_1", "head": "c_la",
		"legislature_id": "parliament_H", "supporting_parties": ["P_A", "P_C"],
		"offices": {}}, st, form_ctx)
	for day in range(1, 30):
		PD.pump(st, day, rules, PA, ctx)
	PD.pump(st, 35, rules, PA, ctx)
	return int(_dl(st, "dl_term_gov_1")["lateness_days"])
