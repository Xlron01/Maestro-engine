extends SceneTree

const SimClass = preload("res://scripts/Simulation.gd")

func _init() -> void:
	print("")
	print("============================================================")
	print("  PHASE 6 STEP 1 — Agent & Agency Entity Hosting Test")
	print("============================================================")
	print("")

	var sim = SimClass.new()
	sim.init_world(12345)

	# 1. التحقق من تحميل Agency
	if not sim.world.agencies.has("cia"):
		print("[FAIL] Agency 'cia' not loaded into WorldState.agencies!")
		quit()
		return
	print("[PASS] 1. Agency 'cia' loaded: %s" % sim.world.agencies["cia"]["name"])

	# 2. التحقق من تحميل Agent وربطه بالـ Agency وقراءة خاصية xp
	if not sim.world.agents.has("agent_007"):
		print("[FAIL] Agent 'agent_007' not loaded into WorldState.agents!")
		quit()
		return

	var agent = sim.world.agents["agent_007"]
	var agency_id = agent.get("agency_id", "")
	var xp = agent.get("xp", 0)

	if agency_id == "cia" and xp == 100:
		print("[PASS] 2. Agent 'agent_007' linked to '%s' with xp=%d" % [agency_id, xp])
	else:
		print("[FAIL] Agent properties mismatch: agency_id='%s', xp=%d" % [agency_id, xp])
		quit()
		return

	# 3. التحقق من الحفظ والاستعادة الحقيقية من الديسك (Save/Load)
	var save_path := "user://phase6_step1_test.json"
	var save_res := sim.save_to_file(save_path)
	if not save_res["ok"]:
		print("[FAIL] save_to_file failed: " + save_res["error"])
		quit()
		return

	var sim_loaded = SimClass.new()
	var load_res := sim_loaded.load_from_file(save_path)
	if not load_res["ok"]:
		print("[FAIL] load_from_file failed: " + load_res["error"])
		quit()
		return

	if sim_loaded.world.agencies.has("cia") and sim_loaded.world.agents.has("agent_007"):
		var loaded_xp = sim_loaded.world.agents["agent_007"].get("xp", 0)
		if loaded_xp == 100:
			print("[PASS] 3. Save/Load Integration verified: Agent & Agency state preserved perfectly across disk Save/Load (xp=%d)" % loaded_xp)
		else:
			print("[FAIL] Loaded agent xp mismatch: expected 100, got %d" % loaded_xp)
	else:
		print("[FAIL] Agencies/Agents missing after load_from_file!")

	print("")
	print("============================================================")
	print("  PHASE 6 STEP 1 VERIFICATION PASSED")
	print("============================================================")
	print("")
	quit()
