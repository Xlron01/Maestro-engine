extends SceneTree

const SimClass = preload("res://scripts/Simulation.gd")

func _init() -> void:
	print("")
	print("============================================================")
	print("  PHASE 6 STEP 5 — Mid-flight Save/Load Under Complexity")
	print("============================================================")
	print("")

	const TEST_SEED := 12345
	const SAVE_PATH := "user://test_phase6_step5_midflight.json"

	# ============================================================
	# 1. Continuous Run (Simulation A: t=0 -> t=60)
	# ============================================================
	var sim_a = SimClass.new()
	sim_a.init_world(TEST_SEED)

	# جدولة عملية عميل عند t=30
	sim_a.scheduled.register("agent_007", "agent_operation_check", 30, 30)

	# دفع حدث انكشاف عميل عند t=40
	var payload_a = {"agent_id": "agent_007", "agency_id": "cia", "target_country": "egypt"}
	sim_a.events.push_event(40, "Agent_Exposed", "agent_007", payload_a)

	sim_a.run_steps(60)

	var snap_a = JSON.stringify(sim_a.world.snapshot())
	var op_count_a = sim_a.operation_evaluations_count
	var exp_count_a = sim_a.exposure_propagation_count
	var vet_xp_a = sim_a.world.agents["agent_007"].get("xp", 0)
	var egypt_stab_a = sim_a.world.countries["egypt"]["stability"]

	print("--- Continuous Run A (t=0 -> t=60) ---")
	print("Operation evaluations count: %d (Expected: 1)" % op_count_a)
	print("Exposure propagation count:  %d (Expected: 2)" % exp_count_a)
	print("Agent_007 final XP:          %d (Expected: 125)" % vet_xp_a)
	print("Egypt final stability:       %.4f" % egypt_stab_a)

	if op_count_a != 1 or exp_count_a != 2 or vet_xp_a != 125:
		print("[FAIL] Continuous Run A state mismatch!")
		quit()
		return

	print("[PASS] 1. Continuous Baseline Run completed cleanly (op_count=1, exp_count=2, XP=125)")

	# ============================================================
	# 2. Mid-flight Save (Simulation B: t=0 -> t=15 -> Save)
	# ============================================================
	var sim_b = SimClass.new()
	sim_b.init_world(TEST_SEED)

	sim_b.scheduled.register("agent_007", "agent_operation_check", 30, 30)
	var payload_b = {"agent_id": "agent_007", "agency_id": "cia", "target_country": "egypt"}
	sim_b.events.push_event(40, "Agent_Exposed", "agent_007", payload_b)

	sim_b.run_steps(15)

	# التأكد من حالة منتصف الطريق (t=15)
	print("")
	print("--- Mid-flight Run B at t=15 ---")
	print("Day at save: %d" % sim_b.clock.total_days())
	print("Pending jobs count: %d" % sim_b.scheduled.all_jobs().size())
	print("Pending events count: %d" % sim_b.events.pending_count())

	if sim_b.clock.total_days() != 15:
		print("[FAIL] Expected day 15 at mid-flight save!")
		quit()
		return

	if sim_b.operation_evaluations_count != 0 or sim_b.exposure_propagation_count != 0:
		print("[FAIL] Mid-flight state executed events prematurely!")
		quit()
		return

	print("[PASS] 2. Mid-flight state at t=15 verified (pending job @t=30 & pending event @t=40 in queue)")

	# حفظ إلى الديسك
	var save_res = sim_b.save_to_file(SAVE_PATH)
	if not save_res["ok"]:
		print("[FAIL] save_to_file failed: " + save_res["error"])
		quit()
		return

	print("[PASS] 3. Mid-flight simulation state saved successfully to disk")

	# ============================================================
	# 3. Load into Fresh Instance & Resume (t=15 -> t=60)
	# ============================================================
	var sim_loaded = SimClass.new() # كائن جديد خالص بدون init_world
	var load_res = sim_loaded.load_from_file(SAVE_PATH)
	if not load_res["ok"]:
		print("[FAIL] load_from_file failed: " + load_res["error"])
		quit()
		return

	print("")
	print("--- Loaded Instance at t=15 ---")
	print("Loaded day: %d" % sim_loaded.clock.total_days())
	print("Loaded pending jobs count: %d" % sim_loaded.scheduled.all_jobs().size())
	print("Loaded pending events count: %d" % sim_loaded.events.pending_count())

	if sim_loaded.clock.total_days() != 15:
		print("[FAIL] Loaded instance day mismatch! Expected 15, got %d" % sim_loaded.clock.total_days())
		quit()
		return

	print("[PASS] 4. Fresh instance loaded state from disk cleanly (day 15 restored)")

	# استكمال المحاكاة 45 خطوة إضافية (تصل إلى t=60)
	print("Resuming execution from t=15 for 45 steps (reaching t=60)...")
	sim_loaded.run_steps(45)

	var snap_loaded = JSON.stringify(sim_loaded.world.snapshot())
	var op_count_loaded = sim_loaded.operation_evaluations_count
	var exp_count_loaded = sim_loaded.exposure_propagation_count
	var vet_xp_loaded = sim_loaded.world.agents["agent_007"].get("xp", 0)
	var egypt_stab_loaded = sim_loaded.world.countries["egypt"]["stability"]

	print("")
	print("--- Resumed Run (t=15 -> t=60) Results ---")
	print("Operation evaluations count: %d (Expected: %d)" % [op_count_loaded, op_count_a])
	print("Exposure propagation count:  %d (Expected: %d)" % [exp_count_loaded, exp_count_a])
	print("Agent_007 final XP:          %d (Expected: %d)" % [vet_xp_loaded, vet_xp_a])
	print("Egypt final stability:       %.4f (Expected: %.4f)" % [egypt_stab_loaded, egypt_stab_a])

	if op_count_loaded != op_count_a or exp_count_loaded != exp_count_a or vet_xp_loaded != vet_xp_a or abs(egypt_stab_loaded - egypt_stab_a) > 0.0001:
		print("[FAIL] Resumed loaded run state differs from continuous run!")
		quit()
		return

	print("[PASS] 5. Resumed execution executed pending scheduled job (@t=30) and pending event (@t=40) perfectly")

	# ============================================================
	# 4. Strict Determinism Check (Snapshot A == Snapshot B_loaded)
	# ============================================================
	if snap_a == snap_loaded:
		print("[PASS] 6. 100% Determinism & Continuity verified: Continuous Run A and Mid-flight Save/Load Run B snapshots are IDENTICAL")
	else:
		print("[FAIL] Determinism mismatch! Snapshot of continuous run differs from mid-flight save/load run!")
		quit()
		return

	print("")
	print("============================================================")
	print("  PHASE 6 STEP 5 VERIFICATION PASSED (6/6 Checks)")
	print("============================================================")
	print("")
	quit()
