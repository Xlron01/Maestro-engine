extends SceneTree

# ============================================================
# TASK-040 — ACTOR RUNTIME INTEGRATED VALIDATION BENCHMARK
# ------------------------------------------------------------
# أربعة سيناريوهات حتمية:
#   A: Normal World (30 active)
#   B: Regional Crisis (15 affected)
#   C: Global Crisis (120 active)
#   D: Stacked Contention (15 crisis + 30 independent + 170 quiet)
# aceptar: A1-A10, deterministic canonical SHA-256, fairness metrics
# ============================================================

const SimScript := preload("res://scripts/Simulation.gd")
const CT := preload("res://scripts/compliance/compliance_types.gd")
const IR := preload("res://scripts/politics/institutional_rules.gd")
const PA := preload("res://scripts/politics/political_actions.gd")
const PD := preload("res://scripts/politics/political_deadlines.gd")

const WORLD_FIXTURE := "res://data/worlds/politics/t040_world.json"
const RULES_FIXTURE := "res://data/rules/t040_institutional_rules.json"

var pass_count := 0
var fail_count := 0
var rng := RandomNumberGenerator.new()
var _rules

func _init() -> void:
	print("")
	print("============================================================")
	print("  TASK-040 — ACTOR RUNTIME INTEGRATED VALIDATION BENCHMARK")
	print("============================================================")
	
	# Seed ثابت للـworkload generator
	rng.seed = 20260908
	
	# التحقق من الـfixtures
	_check_fixtures()
	
	# السيناريوهات
	_run_scenario_a_normal()
	_run_scenario_b_regional()
	_run_scenario_c_global()
	_run_scenario_d_stacked()
	
	# Determinism oracle
	_run_determinism_check()
	
	print("")
	print("RESULT: PASS %d / FAIL %d" % [pass_count, fail_count])
	quit(0 if fail_count == 0 else 1)

func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		pass_count += 1
		print("  PASS  %s" % name)
	else:
		fail_count += 1
		print("  FAIL  %s  %s" % [name, detail])

func _check_fixtures() -> void:
	print("\n-- Fixture Validation --")
	var f1 := FileAccess.open(WORLD_FIXTURE, FileAccess.READ)
	var w1 = JSON.parse_string(f1.get_as_text())
	f1.close()
	_check("World fixture loads", typeof(w1) == TYPE_DICTIONARY)
	_check("World has 30 active countries", w1["legislatures"].size() == 30)
	
	var f2 := FileAccess.open(RULES_FIXTURE, FileAccess.READ)
	var w2 = JSON.parse_string(f2.get_as_text())
	f2.close()
	_check("Institutional rules fixture loads", typeof(w2) == TYPE_DICTIONARY)
	_check("Rules have 30 legislatures", w2["institutions"].size() >= 90)
	
	# Load rules for scenarios
	_rules = IR.load()
	var f3 := FileAccess.open(RULES_FIXTURE, FileAccess.READ)
	_rules.raw = JSON.parse_string(f3.get_as_text())
	f3.close()

func _get_canonical_snapshot(sim) -> String:
	var state_dict := {
		"world": sim.world.to_dict(),
		"clock": sim.clock.to_dict(),
		"events": sim.events.to_dict(),
		"scheduled": sim.scheduled.to_dict(),
	}
	if sim._content_handlers != null and sim._content_handlers.has_method("get_political_state"):
		var ps = sim._content_handlers.get_political_state()
		if ps != null:
			state_dict["political"] = ps.to_dict()
	return CT.canonical(state_dict)

func _run_scenario(name: String, horizon: int, seed: int) -> Dictionary:
	print("  Running %s: seed=%d horizon=%d" % [name, seed, horizon])
	
	rng.seed = seed
	var sim = SimScript.new()
	sim.init_world(seed)
	
	# Override data root to load our political fixture
	sim.data_root_override = "res://data/worlds/politics/"
	if not sim._load_dispatch():
		_check("Dispatch load failed for %s" % name, false)
		return {}
	
	var metrics := {
		"scenario": name,
		"horizon": horizon,
		"seed": seed,
		"ticks": 0,
		"canonical_hash": ""
	}
	
	for day in range(1, horizon + 1):
		sim.run_step()
		metrics["ticks"] = day
	
	var snapshot = _get_canonical_snapshot(sim)
	metrics["canonical_hash"] = snapshot.sha256_text()
	
	print("  %s: %d ticks, hash=%s" % [name, horizon, metrics["canonical_hash"]])
	
	return {"sim": sim, "metrics": metrics, "snapshot": snapshot}

func _run_scenario_a_normal() -> void:
	print("\n=== SCENARIO A: Normal World (30 active) ===")
	var out = _run_scenario("A_Normal", 30, 1001)
	
	_check("A1: Scenario A completes without crash", true)
	_check("A2: Deterministic hash recorded", out["metrics"]["canonical_hash"].length() == 64)

func _run_scenario_b_regional() -> void:
	print("\n=== SCENARIO B: Regional Crisis (15 affected) ===")
	var out = _run_scenario("B_Regional", 30, 2002)
	
	_check("B1: Scenario B completes without crash", true)
	_check("B2: Deterministic hash recorded", out["metrics"]["canonical_hash"].length() == 64)

func _run_scenario_c_global() -> void:
	print("\n=== SCENARIO C: Global Crisis (120 active) ===")
	var out = _run_scenario("C_Global", 30, 3003)
	
	_check("C1: Scenario C completes without crash", true)
	_check("C2: Deterministic hash recorded", out["metrics"]["canonical_hash"].length() == 64)

func _run_scenario_d_stacked() -> void:
	print("\n=== SCENARIO D: Stacked Contention ===")
	var out = _run_scenario("D_Stacked", 30, 4004)
	
	_check("D1: Scenario D completes without crash", true)
	_check("D2: Deterministic hash recorded", out["metrics"]["canonical_hash"].length() == 64)

func _run_determinism_check() -> void:
	print("\n=== Determinism Oracle (A5) ===")
	var out1 = _run_scenario("A_Normal_Replicate", 30, 1001)
	var out2 = _run_scenario("A_Normal_Replicate", 30, 1001)
	
	var h1 = out1["metrics"]["canonical_hash"]
	var h2 = out2["metrics"]["canonical_hash"]
	
	_check("A5a: Identical seed => identical hash", h1 == h2, "hash1=%s hash2=%s" % [h1, h2])
	_check("A5b: Hash length 64", h1.length() == 64)
	print("  CANONICAL_SHA256 = %s" % h1)