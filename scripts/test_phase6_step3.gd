extends SceneTree

const SimClass     = preload("res://scripts/Simulation.gd")
const DecisionClass = preload("res://scripts/DecisionSystem.gd")

func _init() -> void:
	print("")
	print("============================================================")
	print("  PHASE 6 STEP 3 — Scheduled Agent Operation (Sleep/Wake)")
	print("============================================================")
	print("")

	var sim = SimClass.new()
	sim.init_world(12345)

	# 0) تأكيد تحميل البيانات الأساسية
	if not sim.world.agents.has("agent_007") or not sim.world.agencies.has("cia"):
		print("[FAIL] agent_007 or cia not loaded!")
		quit()
		return

	var agent = sim.world.agents["agent_007"]
	print("Initial state: agent_007 XP = %d | operation_evaluations_count = %d" % [
		agent.get("xp", 0), sim.operation_evaluations_count
	])
	print("")

	# 1) اليوم 0: تسجيل العملية المجدولة عند t=30
	sim.scheduled.register("agent_007", "agent_operation_check", 99999, 30)
	print("[t=0] Scheduled agent_007 operation_check at t=30")
	print("  operation_evaluations_count = %d (Expected: 0)" % sim.operation_evaluations_count)
	if sim.operation_evaluations_count != 0:
		print("[FAIL] Counter should be 0 immediately after registration!")
		quit()
		return
	print("")

	# 2) الأيام 1 إلى 29: إثبات النوم المباشر
	var sleep_violated: bool = false
	for day in range(1, 30):
		sim.run_step()
		var count = sim.operation_evaluations_count
		if count != 0:
			print("[FAIL] operation_evaluations_count = %d at t=%d (Expected: 0 — sleep violated!)" % [count, day])
			sleep_violated = true
			break

	if sleep_violated:
		quit()
		return

	var count_at_29 = sim.operation_evaluations_count
	print("[t=1..29] Sleep proof: operation_evaluations_count = %d at end of day 29 (Expected: 0)" % count_at_29)
	if count_at_29 != 0:
		print("[FAIL] Sleep violated somewhere in t=1..29!")
		quit()
		return
	print("[PASS] 1. Sleep proof: operation_evaluations_count == 0 throughout t=1..29")
	print("")

	# 3) اليوم 30: إثبات الاستيقاظ المباشر
	var xp_before = agent.get("xp", 0)
	print("[t=30] Running step — expecting wake-up...")
	sim.run_step()

	var count_at_30 = sim.operation_evaluations_count
	var xp_after = agent.get("xp", 0)

	print("  operation_evaluations_count at t=30 = %d (Expected: 1)" % count_at_30)
	print("  agent_007 XP: %d -> %d (Expected: 125)" % [xp_before, xp_after])

	if count_at_30 != 1:
		print("[FAIL] operation_evaluations_count should be 1 at t=30!")
		quit()
		return
	print("[PASS] 2. Wake-up proof: operation_evaluations_count == 1 at t=30")

	if xp_after != 125:
		print("[FAIL] agent_007 XP should be 125 after operation (got %d)!" % xp_after)
		quit()
		return
	print("[PASS] 3. XP gain confirmed: agent_007 XP = %d (success path)" % xp_after)
	print("")

	# 4) إثبات One-Shot: لا تكرار بعد t=30
	print("[t=31..60] Verifying One-Shot (no re-execution)...")
	for _extra in range(30):
		sim.run_step()

	var count_after_60 = sim.operation_evaluations_count
	print("  operation_evaluations_count after t=60 = %d (Expected: 1)" % count_after_60)
	if count_after_60 != 1:
		print("[FAIL] NOT a one-shot job! count=%d" % count_after_60)
		quit()
		return
	print("[PASS] 4. One-Shot confirmed: no re-execution after t=30")
	print("")

	# 5) Save / Load: التحقق من استمرارية العداد
	print("[Save/Load] Saving state to disk...")
	var save_path := "user://phase6_step3_test.json"
	var save_res := sim.save_to_file(save_path)
	if not save_res["ok"]:
		print("[FAIL] save_to_file failed: " + save_res["error"])
		quit()
		return

	var sim2 = SimClass.new()
	var load_res := sim2.load_from_file(save_path)
	if not load_res["ok"]:
		print("[FAIL] load_from_file failed: " + load_res["error"])
		quit()
		return

	var loaded_count  = sim2.operation_evaluations_count
	var loaded_xp     = sim2.world.agents["agent_007"].get("xp", 0)
	print("  Loaded operation_evaluations_count = %d (Expected: 1)" % loaded_count)
	print("  Loaded agent_007 XP = %d (Expected: 125)" % loaded_xp)

	if loaded_count != 1 or loaded_xp != 125:
		print("[FAIL] Save/Load did not preserve counter or XP!")
		quit()
		return
	print("[PASS] 5. Save/Load: operation_evaluations_count and XP preserved across disk round-trip")
	print("")

	print("============================================================")
	print("  PHASE 6 STEP 3 VERIFICATION PASSED — 5/5")
	print("============================================================")
	print("")
	quit()
