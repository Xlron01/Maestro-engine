extends SceneTree

# ============================================================
# Phase 2 Scenario Test — Maestro Engine
# ------------------------------------------------------------
# شغّله بـ:
#   godot --headless --script scripts/ScenarioTest.gd
# ============================================================

const SCENARIO_SEED:  int    = 12345
const SCENARIO_STEPS: int    = 90     # 3 شهور (3 × 30 يوم)
const SAVE_PATH:      String = "user://phase2_scenario_test.json"
const BAD_VER_PATH:   String = "user://phase2_bad_version.json"

const SimClass = preload("res://scripts/Simulation.gd")

# ============================================================
# TEST 4 — Regression Anchor
# ------------------------------------------------------------
# الخطوات:
#   1. اشغّل أول مرة بـ CALIBRATE_MODE = true
#   2. انسخ الـ checksum اللي بيظهر في EXPECTED_CHECKSUM
#   3. حط CALIBRATE_MODE = false
#
# من بعد كده: أي تعديل في المحرك يغيّر السلوك هيطلع [FAIL]
# لو التغيير متعمد → حدّث EXPECTED_CHECKSUM بوعي كامل.
# ============================================================
const CALIBRATE_MODE:    bool   = false
const EXPECTED_CHECKSUM: String = "a7cff9f1587a6f98487990e0c90a72955d8955ed0447f2863a07e55a02bd6896"

var _pass_count: int = 0
var _fail_count: int = 0

func _init() -> void:
	print("")
	print("============================================================")
	print("  PHASE 2 SCENARIO TEST — Maestro Engine")
	print("  seed=%d | steps=%d" % [SCENARIO_SEED, SCENARIO_STEPS])
	print("============================================================")
	print("")

	_test1_baseline_determinism()
	_test2_save_load_continuity()
	_test3_schema_version_guard()
	_test4_state_checksum()
	_test5_coup_risk_evaluation()

	var total := _pass_count + _fail_count
	print("")
	print("============================================================")
	if _fail_count == 0:
		print("  ALL TESTS PASSED (%d/%d)" % [_pass_count, total])
	else:
		print("  RESULT: %d PASSED, %d FAILED (out of %d)" % [_pass_count, _fail_count, total])
	print("============================================================")
	print("")
	quit()

# ---- Helpers ----

func _pass(name: String) -> void:
	_pass_count += 1
	print("[PASS] %s" % name)

func _fail(name: String, reason: String) -> void:
	_fail_count += 1
	print("[FAIL] %s" % name)
	print("       Reason: %s" % reason)

# Node.new() بدون إضافة للـ scene tree → _ready() مش بتتنادى
func _make_sim() -> SimClass:
	var sim = SimClass.new()
	sim.init_world(SCENARIO_SEED)
	return sim

# الـ checksum دايمًا من الـ in-memory snapshot — مش من نص الملف
# ده بيتجنب أي اختلاف ترتيب مفاتيح Dictionary بعد JSON round-trip (Fix 3)
func _snapshot_str(sim: SimClass) -> String:
	return JSON.stringify(sim.world.snapshot())

func _sha256(text: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	return ctx.finish().hex_encode()

# ============================================================
# TEST 1 — Baseline Determinism
# ============================================================
func _test1_baseline_determinism() -> void:
	var name := "TEST 1 — Baseline Determinism"

	var sim_a := _make_sim()
	sim_a.run_steps(SCENARIO_STEPS)
	var snap_a := _snapshot_str(sim_a)

	var sim_b := _make_sim()
	sim_b.run_steps(SCENARIO_STEPS)
	var snap_b := _snapshot_str(sim_b)

	if snap_a == snap_b:
		_pass(name)
	else:
		_fail(name, "Two identical runs (seed=%d, steps=%d) produced different snapshots" % [SCENARIO_SEED, SCENARIO_STEPS])

# ============================================================
# TEST 2 — Save/Load Continuity
# ============================================================
func _test2_save_load_continuity() -> void:
	var name := "TEST 2 — Save/Load Continuity"
	const EXTRA_STEPS := 30

	# Run A: continuous — الأصل اللي بنقارن بيه
	var sim_continuous := _make_sim()
	sim_continuous.run_steps(SCENARIO_STEPS + EXTRA_STEPS)
	var snap_continuous := _snapshot_str(sim_continuous)

	# Run B: SCENARIO_STEPS → save → load جديد → EXTRA_STEPS
	var sim_b := _make_sim()
	sim_b.run_steps(SCENARIO_STEPS)

	var save_result := sim_b.save_to_file(SAVE_PATH)
	if not save_result["ok"]:
		_fail(name, "save_to_file failed: " + save_result["error"])
		return

	# sim_loaded من الصفر — بدون init_world() — load_from_file يستعيد كل الحالة
	var sim_loaded = SimClass.new()
	var load_result := sim_loaded.load_from_file(SAVE_PATH)
	if not load_result["ok"]:
		_fail(name, "load_from_file failed: " + load_result["error"])
		return

	sim_loaded.run_steps(EXTRA_STEPS)
	var snap_loaded := _snapshot_str(sim_loaded)

	if snap_continuous == snap_loaded:
		_pass(name)
	else:
		_fail(name,
			("State after save/load/continue differs from continuous run\n" +
			"       (step %d -> save -> load -> step %d more)") % [SCENARIO_STEPS, EXTRA_STEPS])

# ============================================================
# TEST 3 — Schema Version Guard
# ============================================================
func _test3_schema_version_guard() -> void:
	var name := "TEST 3 — Schema Version Guard"

	var bad_data := JSON.stringify({"save_version": 999, "seed": 0})
	var file := FileAccess.open(BAD_VER_PATH, FileAccess.WRITE)
	if file == null:
		_fail(name, "Cannot write test fixture to user://")
		return
	file.store_string(bad_data)
	file.close()

	var sim = SimClass.new()
	var result := sim.load_from_file(BAD_VER_PATH)

	if not result["ok"] and result["error"].to_lower().contains("version"):
		_pass(name)
	else:
		_fail(name, "Expected version error. Got ok=%s, error='%s'" % [str(result["ok"]), result.get("error", "")])

# ============================================================
# TEST 4 — State Checksum (Regression Anchor)
# ============================================================
func _test4_state_checksum() -> void:
	var name := "TEST 4 — State Checksum (Regression Anchor)"

	var sim := _make_sim()
	sim.run_steps(SCENARIO_STEPS)

	# Fix 3: checksum من الـ in-memory snapshot (مش من نص الملف)
	# بيتجنب أي اختلاف ترتيب مفاتيح بعد round-trip
	var snap_str := _snapshot_str(sim)
	var checksum := _sha256(snap_str)

	if CALIBRATE_MODE:
		print("")
		print("  +-- [CALIBRATE MODE] ----------------------------------------+")
		print("  |  seed=%d, steps=%d" % [SCENARIO_SEED, SCENARIO_STEPS])
		print("  |  SHA256 = %s" % checksum)
		print("  |")
		print("  |  الخطوات:")
		print("  |  1. انسخ الـ SHA256 فوق")
		print("  |  2. حطّه في EXPECTED_CHECKSUM في ScenarioTest.gd")
		print("  |  3. غيّر CALIBRATE_MODE = false")
		print("  |  4. اشغّل تاني للتأكد إن TEST 4 يطلع [PASS]")
		print("  +------------------------------------------------------------+")
		print("")
		_pass(name + " (calibration — not a real assertion yet)")
	elif EXPECTED_CHECKSUM == "REPLACE_ME_ON_FIRST_RUN":
		_fail(name,
			"CALIBRATE_MODE=false لكن EXPECTED_CHECKSUM لم يُضبط.\n" +
			"       شغّل مرة بـ CALIBRATE_MODE=true واحفظ الـ checksum.")
	elif checksum == EXPECTED_CHECKSUM:
		_pass(name)
	else:
		_fail(name,
			"Checksum mismatch — تغيير في سلوك المحاكاة اكتُشف!\n" +
			"       Expected: %s\n" % EXPECTED_CHECKSUM +
			"       Got:      %s\n" % checksum +
			"       لو التغيير متعمد: حدّث EXPECTED_CHECKSUM في ScenarioTest.gd.")

# ============================================================
# TEST 5 — Coup Risk & Reusable Weighting Evaluation
# ============================================================
func _test5_coup_risk_evaluation() -> void:
	var name := "TEST 5 — Coup Risk & Reusable Weighting Evaluation"

	var sim = SimClass.new()
	sim.init_world(SCENARIO_SEED)

	# مصر (egypt) استقرارها 0.8 (أعلى من العتبة 0.6)
	# دولة ب (country_b) نقلل استقرارها لـ 0.3 (< 0.6) ونرفع war_exhaustion لـ 0.8
	if sim.world.countries.has("country_b"):
		sim.world.countries["country_b"]["stability"] = 0.3
		sim.world.countries["country_b"]["war_exhaustion"] = 0.8
		sim.world.countries["country_b"]["coup_ideology_support"] = 0.9

	# شغل 35 يوم لتجاوز أول فحص شهري (t=30)
	sim.run_steps(35)

	# 1. فحص التفعيل المحدود (Selective Activation)
	# country_b استقرارها 0.3 < 0.6 -> تم تقييمها (coup_evaluations_count > 0)
	if sim.coup_evaluations_count == 0:
		_fail(name, "Unstable country (country_b) was NOT evaluated for coup risk!")
		return

	# egypt استقرارها 0.8 >= 0.6 -> لم تدخل في التقييم
	if sim.world.countries.has("egypt") and sim.world.countries["egypt"].has("coup_risk_score"):
		_fail(name, "Stable country (egypt) WAS evaluated for coup risk (Selective Activation violated)!")
		return

	# 2. فحص تأثير البيانات بدون لمس الكود
	var score_before: float = sim.world.countries["country_b"].get("coup_risk_score", 0.0)

	# قم بتغيير وزن في rules واعد التقييم لنفس الدولة بـ DecisionSystem.evaluate_coup_risk
	var custom_rules = sim.rules.duplicate()
	custom_rules["coup_weight_war_exhaustion"] = 2.0 # نضاعف الوزن
	var score_after: float = DecisionSystem.evaluate_coup_risk(sim.world.countries["country_b"], custom_rules)

	if score_before == score_after:
		_fail(name, "Changing rules in politics.json did not change coup_risk_score (data-driven principle violated)!")
		return

	_pass(name)
