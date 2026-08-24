extends SceneTree

const SimClass = preload("res://scripts/Simulation.gd")

func _init() -> void:
	print("")
	print("============================================================")
	print("  PHASE 6 STEP 4 — Cross-Entity Propagation (Agent_Exposed)")
	print("============================================================")
	print("")

	var sim = SimClass.new()
	sim.init_world(12345)

	if not sim.world.countries.has("egypt"):
		print("[FAIL] 'egypt' missing in world!")
		quit()
		return

	var egypt_initial_stability: float = sim.world.countries["egypt"]["stability"]
	print("Initial egypt stability: %.4f" % egypt_initial_stability)

	# 1. دفع حدث Agent_Exposed في لحظة t=1
	var payload = {
		"agent_id": "agent_007",
		"agency_id": "cia",
		"target_country": "egypt"
	}
	sim.events.push_event(1, "Agent_Exposed", "agent_007", payload)

	# 2. تشغيل الخطوة t=1
	sim.run_step()
	var debug_t1 = sim.get_debug_info()
	var active_ids_t1 = debug_t1["active_ids"]
	print("Day 1 Active IDs (%d total): %s" % [active_ids_t1.size(), str(active_ids_t1)])

	# فحص الاستيقاظ الانتقائي عند t=1
	if not active_ids_t1.has("agent_007"):
		print("[FAIL] Source agent 'agent_007' was NOT activated at t=1!")
		quit()
		return
	if not active_ids_t1.has("cia"):
		print("[FAIL] Owner agency 'cia' was NOT activated at t=1!")
		quit()
		return
	if not active_ids_t1.has("egypt"):
		print("[FAIL] Target country 'egypt' was NOT activated at t=1!")
		quit()
		return

	print("[PASS] 1. Direct activation of related entities verified (agent_007, cia, egypt)")

	# 3. فحص النوم الصريح المباشر عند t=1 (Unrelated entities)
	var unrelated = ["country_b", "country_c", "france"]
	for u in unrelated:
		if active_ids_t1.has(u):
			print("[FAIL] Unrelated entity '%s' WAS activated at t=1!" % u)
			quit()
			return

	print("[PASS] 2. Immediate negative proof verified at t=1 (unrelated entities sleeping)")

	# 4. الدليل السلبي الممتد (Extended Negative Proof across t=2 -> t=10)
	print("Running extended simulation days t=2 -> t=10 to verify long-term sleep...")
	sim.run_steps(9) # يصل إلى t=10

	for log_entry in sim.activation_log:
		var day = log_entry["day"]
		var active = log_entry["active_ids"]
		for u in unrelated:
			if active.has(u):
				print("[FAIL] Unrelated entity '%s' woke up on day %d!" % [u, day])
				quit()
				return

	print("[PASS] 3. Extended negative proof verified (unrelated entities remained 100%% asleep t=1 -> t=10)")

	# 5. فحص عقوبة الاستقرار لـ egypt
	var egypt_new_stability: float = sim.world.countries["egypt"]["stability"]
	var expected_penalty: float = sim.rules.get("agent_exposure_stability_penalty", 0.03)
	var expected_stability: float = egypt_initial_stability - expected_penalty
	print("Egypt stability after exposure: %.4f (Expected: %.4f)" % [egypt_new_stability, expected_stability])

	if abs(egypt_new_stability - expected_stability) > 0.0001:
		print("[FAIL] Egypt stability penalty incorrect! Got %.4f, expected %.4f" % [egypt_new_stability, expected_stability])
		quit()
		return

	print("[PASS] 4. Target country stability penalty applied correctly (-0.03)")

	# 6. فحص العداد الصريح
	print("Exposure propagation count: %d (Expected: 2)" % sim.exposure_propagation_count)
	if sim.exposure_propagation_count != 2:
		print("[FAIL] exposure_propagation_count expected to be 2, got %d" % sim.exposure_propagation_count)
		quit()
		return

	print("[PASS] 5. Explicit propagation counter verified (= 2)")

	# 7. فحص الحفظ والاستعادة الحقيقية (Save/Load Integration)
	var save_path := "user://phase6_step4_test.json"
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

	if sim_loaded.exposure_propagation_count != 2:
		print("[FAIL] Loaded exposure_propagation_count mismatch: %d" % sim_loaded.exposure_propagation_count)
		quit()
		return

	var loaded_egypt_stab = sim_loaded.world.countries["egypt"]["stability"]
	if abs(loaded_egypt_stab - egypt_new_stability) > 0.0001:
		print("[FAIL] Loaded egypt stability mismatch: %.4f" % loaded_egypt_stab)
		quit()
		return

	print("[PASS] 6. Save/Load persistence of propagation state and stability verified")

	print("")
	print("============================================================")
	print("  PHASE 6 STEP 4 VERIFICATION PASSED (6/6 Checks)")
	print("============================================================")
	print("")
	quit()
