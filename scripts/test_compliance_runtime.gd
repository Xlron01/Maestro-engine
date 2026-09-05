extends SceneTree

# ============================================================
# TASK-038 — COMPLIANCE RUNTIME LAYER — ACCEPTANCE SUITE (A–L)
# ------------------------------------------------------------
# tests-first: التوقعات أدناه مجمّدة قبل كتابة compliance_query.gd،
# وفق عقود المالك المقفولة (رسالة 2026-09-06) وخطة rev.2 المعتمدة.
# القيم الرقمية المتوقعة تأتي من data/rules/compliance_config.json
# (NON-FINAL v0) — القبول سلوكي: الحالات تُبنى بالتركيب لا بالثوابت.
#
# A Determinism · B Capability Short-Circuit · C Capability Unknown
# D Authority Independence · E Loyalty Independence · F Influence Independence
# G Legitimacy PARTIAL · H Action Legitimacy PARTIAL · I Resistance Separation
# J No World Mutation · K No Per-Tick Polling
# L Regression = تشغيلات منفصلة (ScenarioTest/d1/integration/economy) — logs
# ============================================================

const CT := preload("res://scripts/compliance/compliance_types.gd")
const CQ := preload("res://scripts/compliance/compliance_query.gd")
const CAP := preload("res://scripts/compliance/capability_query.gd")
const IQ := preload("res://scripts/compliance/influence_query.gd")
const LQ := preload("res://scripts/compliance/legitimacy_query.gd")
const RC := preload("res://scripts/relevance_control.gd")
const SimScript := preload("res://scripts/Simulation.gd")

const BASE_PATH := "res://data/worlds/compliance/base.json"
const MODULES := [
	"res://scripts/compliance/compliance_types.gd",
	"res://scripts/compliance/capability_query.gd",
	"res://scripts/compliance/influence_query.gd",
	"res://scripts/compliance/legitimacy_query.gd",
	"res://scripts/compliance/compliance_query.gd"
]

var pass_count := 0
var fail_count := 0
var cfg: Dictionary = {}
var base_ents: Dictionary = {}


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
	print("  TASK-038 COMPLIANCE RUNTIME LAYER — ACCEPTANCE (A-L)")
	print("============================================================")

	cfg = CT.load_config()
	if cfg.is_empty():
		print("[FATAL] compliance_config.json missing/invalid")
		quit(1)
		return
	var f := FileAccess.open(BASE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		print("[FATAL] base fixture invalid")
		quit(1)
		return
	base_ents = parsed["entities"]

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
	_run_k()

	print("")
	print("RESULT: PASS %d / FAIL %d" % [pass_count, fail_count])
	quit(0 if fail_count == 0 else 1)


# ---------------- context builders (حتمية) ----------------

func _base() -> Dictionary:
	return (base_ents as Dictionary).duplicate(true)


func _set_authority(ents: Dictionary, degree) -> void:
	if degree == null:
		(ents["Commander_A"] as Dictionary).erase("authority")
	else:
		ents["Commander_A"]["authority"] = [{"to": "Unit_B", "degree": degree}]


func _set_social(ents: Dictionary, loyalty, trust: float) -> void:
	if loyalty == null:
		(ents["Unit_B"] as Dictionary).erase("social_relations")
	else:
		ents["Unit_B"]["social_relations"] = {"Commander_A": {"loyalty": loyalty, "trust": trust}}


func _ctx(ents: Dictionary, facts: Dictionary, action: Dictionary) -> Dictionary:
	return {
		"entities": ents,
		"chains": RC.control_chains({"entities": ents}),
		"facts": facts,
		"config": cfg,
		"action": action,
		"actor_id": "Commander_A",
		"target_id": "Unit_B"
	}


func _act(requires: Array, harms: Array = []) -> Dictionary:
	return {"id": "March_Order", "requires": requires, "harms_interests": harms}


func _supplies_req(min_v: float) -> Array:
	return [{"path": "Unit_B.supplies", "op": "gte", "value": min_v}]


func _supplies_facts() -> Dictionary:
	return {"Unit_B": {"supplies": 10.0}}


# ---------------- A — Determinism ----------------

func _run_a() -> void:
	print("\n-- A: Determinism (same inputs => identical assessment)")
	var ctx := _ctx(_base(), _supplies_facts(), _act(_supplies_req(5.0)))
	var r1 = CQ.assess("Unit_B", _act(_supplies_req(5.0)), "Commander_A", ctx)
	var r2 = CQ.assess("Unit_B", _act(_supplies_req(5.0)), "Commander_A", ctx)
	_check("A1 two identical compliance calls => canonical bitwise equal",
		CT.canonical(r1) == CT.canonical(r2))
	var l1 = LQ.assess("Regime_H", "State", "Unit_B", ctx)
	var l2 = LQ.assess("Regime_H", "State", "Unit_B", ctx)
	_check("A2 two identical legitimacy calls => canonical bitwise equal",
		CT.canonical(l1) == CT.canonical(l2))


# ---------------- B — Capability Short-Circuit ----------------

func _run_b() -> void:
	print("\n-- B: Capability INFEASIBLE+COMPLETE => no fabricated compliance")
	var ents := _base()
	var act := _act(_supplies_req(20.0))  # supplies=10 => INFEASIBLE
	var r = CQ.assess("Unit_B", act, "Commander_A", _ctx(ents, _supplies_facts(), act))
	_check("B1 short-circuited with null degree/mode/strength",
		bool(r["short_circuited"]) and r["compliance_degree"] == null
		and r["resistance_mode"] == null and r["resistance_strength"] == null)
	# loyalty معادية + conflict — لا يصنع refusal لأن البوابة قصت قبلها
	var ents2 := _base()
	_set_social(ents2, 0.1, 0.1)
	var act2 := _act(_supplies_req(20.0), ["autonomy"])
	var r2 = CQ.assess("Unit_B", act2, "Commander_A", _ctx(ents2, _supplies_facts(), act2))
	_check("B2 short-circuit unaffected by loyalty/conflict (canonical equal to B1)",
		CT.canonical(r) == CT.canonical(r2))


# ---------------- C — Capability Unknown ----------------

func _run_c() -> void:
	print("\n-- C: Capability UNKNOWN+PARTIAL (missing Geography) continues")
	var reqs := _supplies_req(5.0)
	reqs.append({"path": "Geography.distance_to_target", "op": "lte", "value": 100.0})
	var act := _act(reqs)
	var cap = CAP.assess("Commander_A", act, "Unit_B", _ctx(_base(), _supplies_facts(), act))
	_check("C1 capability UNKNOWN+PARTIAL, not INFEASIBLE, missing Geography path",
		String(cap["feasibility"]) == "UNKNOWN" and String(cap["status"]) == "PARTIAL"
		and (cap["missing_inputs"] as Array).has("Geography.distance_to_target"))
	var r = CQ.assess("Unit_B", act, "Commander_A", _ctx(_base(), _supplies_facts(), act))
	_check("C2 resolution continues: degree/mode present, PARTIAL propagated",
		r["compliance_degree"] != null and r["resistance_mode"] != null
		and String(r["status"]) == "PARTIAL"
		and (r["missing_inputs"] as Array).has("Geography.distance_to_target"))


# ---------------- D — Authority Independence ----------------

func _run_d() -> void:
	print("\n-- D: Authority high vs absent (loyalty absent => NEUTRAL path)")
	var ents_hi := _base()
	_set_social(ents_hi, null, 0.0)
	var act := _act(_supplies_req(5.0))
	var r_hi = CQ.assess("Unit_B", act, "Commander_A", _ctx(ents_hi, _supplies_facts(), act))
	var ents_lo := _base()
	_set_social(ents_lo, null, 0.0)
	_set_authority(ents_lo, null)
	var r_lo = CQ.assess("Unit_B", act, "Commander_A", _ctx(ents_lo, _supplies_facts(), act))
	_check("D1 compliance differs: pressure => (%s, %s) vs no-authority => (%s, %s)"
		% [r_hi["compliance_degree"], r_hi["resistance_mode"],
			r_lo["compliance_degree"], r_lo["resistance_mode"]],
		float(r_hi["compliance_degree"]) != float(r_lo["compliance_degree"])
		and String(r_hi["resistance_mode"]) != String(r_lo["resistance_mode"]))
	var cap_hi = CAP.assess("Commander_A", act, "Unit_B", _ctx(ents_hi, _supplies_facts(), act))
	var cap_lo = CAP.assess("Commander_A", act, "Unit_B", _ctx(ents_lo, _supplies_facts(), act))
	_check("D2 capability assessment bitwise identical (Authority != Capability)",
		CT.canonical(cap_hi) == CT.canonical(cap_lo))


# ---------------- E — Loyalty Independence ----------------

func _run_e() -> void:
	print("\n-- E: loyalty changes, influence pinned (channel separation)")
	var ents_hi := _base()  # loyalty 0.9 / trust 0.1
	var ents_lo := _base()
	_set_social(ents_lo, 0.1, 0.1)  # trust SAME, loyalty changed only
	var act := _act(_supplies_req(5.0))
	var inf_hi = IQ.assess("Commander_A", "Unit_B", _ctx(ents_hi, _supplies_facts(), act))
	var inf_lo = IQ.assess("Commander_A", "Unit_B", _ctx(ents_lo, _supplies_facts(), act))
	_check("E1 influence assessment bitwise identical across loyalty change",
		CT.canonical(inf_hi) == CT.canonical(inf_lo))
	var r_hi = CQ.assess("Unit_B", act, "Commander_A", _ctx(ents_hi, _supplies_facts(), act))
	var r_lo = CQ.assess("Unit_B", act, "Commander_A", _ctx(ents_lo, _supplies_facts(), act))
	_check("E2 compliance changed via loyalty: (%s,%s) -> (%s,%s)"
		% [r_hi["compliance_degree"], r_hi["resistance_mode"],
			r_lo["compliance_degree"], r_lo["resistance_mode"]],
		float(r_hi["compliance_degree"]) != float(r_lo["compliance_degree"]))


# ---------------- F — Influence Independence ----------------

func _run_f() -> void:
	print("\n-- F: informal-high/no-authority vs authority-high/informal-low")
	var ents_a := _base()
	_set_authority(ents_a, null)
	_set_social(ents_a, 0.9, 0.9)
	var ents_b := _base()
	_set_social(ents_b, 0.1, 0.0)
	var act := _act(_supplies_req(5.0))
	var i_a = IQ.assess("Commander_A", "Unit_B", _ctx(ents_a, _supplies_facts(), act))
	var i_b = IQ.assess("Commander_A", "Unit_B", _ctx(ents_b, _supplies_facts(), act))
	_check("F1 channels not aliases: a(struct=%s,informal=%s) b(struct=%s,informal=%s)"
		% [i_a["structural"], i_a["informal"], i_b["structural"], i_b["informal"]],
		float(i_a["structural"]) == 0.0 and float(i_a["informal"]) == 0.9
		and float(i_b["structural"]) == 0.9 and float(i_b["informal"]) == 0.0)
	_check("F2 canonical assessments differ",
		CT.canonical(i_a) != CT.canonical(i_b))


# ---------------- G — Legitimacy PARTIAL ----------------

func _run_g() -> void:
	print("\n-- G: State legitimacy with missing PopularSupport")
	var ctx := _ctx(_base(), _supplies_facts(), _act(_supplies_req(5.0)))
	var r = LQ.assess("Regime_H", "State", "Unit_B", ctx)
	_check("G1 status PARTIAL + missing contains PopularSupport",
		String(r["status"]) == "PARTIAL"
		and (r["missing_inputs"] as Array).has("PopularSupport"))
	_check("G2 value computed from available evidence only (mean of primitives), no default",
		r["value"] != null and is_equal_approx(float(r["value"]), 0.6))


# ---------------- H — Action Legitimacy PARTIAL ----------------

func _run_h() -> void:
	print("\n-- H: Action legitimacy with missing ConstitutionalValidity")
	var ctx := _ctx(_base(), _supplies_facts(), _act(_supplies_req(5.0)))
	var r = LQ.assess("Commander_A", "Action", "Unit_B", ctx)
	_check("H1 status PARTIAL + missing contains ConstitutionalValidity",
		String(r["status"]) == "PARTIAL"
		and (r["missing_inputs"] as Array).has("ConstitutionalValidity"))
	_check("H2 computation continues from available inputs (value non-null from Authority)",
		r["value"] != null)


# ---------------- I — Resistance Separation ----------------

func _run_i() -> void:
	print("\n-- I: five resistance states without ambiguity")

	# I1 full compliance: loyal + no conflict
	var r1 = CQ.assess("Unit_B", _act(_supplies_req(5.0)), "Commander_A",
		_ctx(_base(), _supplies_facts(), _act(_supplies_req(5.0))))
	_check("I1 full: (1.0, NONE)", float(r1["compliance_degree"]) == 1.0
		and String(r1["resistance_mode"]) == "NONE")

	# I2 partial execution: no loyalty (NEUTRAL) + authority pressure
	var e2 := _base()
	_set_social(e2, null, 0.0)
	var r2 = CQ.assess("Unit_B", _act(_supplies_req(5.0)), "Commander_A",
		_ctx(e2, _supplies_facts(), _act(_supplies_req(5.0))))
	_check("I2 partial: (%s, NONE)" % r2["compliance_degree"],
		is_equal_approx(float(r2["compliance_degree"]), float(cfg["partial_degree"]))
		and String(r2["resistance_mode"]) == "NONE")

	# I3 passive refusal: NEUTRAL + no authority
	var e3 := _base()
	_set_social(e3, null, 0.0)
	_set_authority(e3, null)
	var r3 = CQ.assess("Unit_B", _act(_supplies_req(5.0)), "Commander_A",
		_ctx(e3, _supplies_facts(), _act(_supplies_req(5.0))))
	_check("I3 passive: (0.0, PASSIVE, %s)" % r3["resistance_strength"],
		float(r3["compliance_degree"]) == 0.0
		and String(r3["resistance_mode"]) == "PASSIVE"
		and is_equal_approx(float(r3["resistance_strength"]), float(cfg["passive_strength"])))

	# I4 active resistance: conflict + disloyal + no authority
	var e4 := _base()
	_set_authority(e4, null)
	_set_social(e4, 0.1, 0.1)
	var r4 = CQ.assess("Unit_B", _act(_supplies_req(5.0), ["autonomy"]), "Commander_A",
		_ctx(e4, _supplies_facts(), _act(_supplies_req(5.0), ["autonomy"])))
	_check("I4 active: (0.0, ACTIVE, %s)" % r4["resistance_strength"],
		float(r4["compliance_degree"]) == 0.0
		and String(r4["resistance_mode"]) == "ACTIVE"
		and is_equal_approx(float(r4["resistance_strength"]), float(cfg["active_strength"])))

	# I5 partial execution + active resistance: conflict + disloyal + pressure
	var e5 := _base()
	_set_social(e5, 0.1, 0.1)
	var r5 = CQ.assess("Unit_B", _act(_supplies_req(5.0), ["autonomy"]), "Commander_A",
		_ctx(e5, _supplies_facts(), _act(_supplies_req(5.0), ["autonomy"])))
	_check("I5 partial+active: (%s, ACTIVE)" % r5["compliance_degree"],
		is_equal_approx(float(r5["compliance_degree"]), float(cfg["partial_active_degree"]))
		and String(r5["resistance_mode"]) == "ACTIVE")


# ---------------- J — No World Mutation ----------------

func _run_j() -> void:
	print("\n-- J: compliance query leaves world untouched")
	var ents := _base()
	var facts := _supplies_facts()
	var before := CT.canonical({"e": ents, "f": facts})
	var r = CQ.assess("Unit_B", _act(_supplies_req(5.0)), "Commander_A",
		_ctx(ents, facts, _act(_supplies_req(5.0))))
	var after := CT.canonical({"e": ents, "f": facts})
	_check("J1 before_state == after_state (bitwise canonical)", before == after)


# ---------------- K — No Per-Tick Polling ----------------

func _run_k() -> void:
	print("\n-- K: no per-tick polling (audit + runtime counter)")
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
		for token in ["_process(", "run_step(", "ScheduledQueue", "EventQueue", "dispatch.json"]:
			if src.contains(token):
				audit_ok = false
				audit_detail = "%s contains %s" % [p, token]
	_check("K1 source audit: no tick-loop/process/polling bindings in layer modules",
		audit_ok, audit_detail)

	var dtext := ""
	var df := FileAccess.open("res://data/rules/dispatch.json", FileAccess.READ)
	if df != null:
		dtext = df.get_as_text()
		df.close()
	_check("K2 dispatch.json untouched: no compliance wiring",
		not dtext.contains("compliance") and not dtext.contains("Compliance"))

	# runtime: N ticks production => 0 compliance evaluations; explicit call => 1
	var before_count: int = CQ.eval_count
	var sim = SimScript.new()
	sim.init_world(12345)
	for i in range(30):
		sim.run_step()
	var after_ticks: int = CQ.eval_count
	var r = CQ.assess("Unit_B", _act(_supplies_req(5.0)), "Commander_A",
		_ctx(_base(), _supplies_facts(), _act(_supplies_req(5.0))))
	_check("K3 runtime: 30 ticks => +%d evaluations, explicit call => +%d"
		% [after_ticks - before_count, CQ.eval_count - after_ticks],
		after_ticks == before_count and CQ.eval_count == after_ticks + 1)
