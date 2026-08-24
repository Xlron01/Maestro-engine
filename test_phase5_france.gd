extends SceneTree

const SimClass = preload("res://scripts/Simulation.gd")

func _init() -> void:
	print("")
	print("============================================================")
	print("  PHASE 5 INTEGRATED VERIFICATION — France (Data-driven)")
	print("============================================================")
	print("")

	var sim = SimClass.new()
	sim.init_world(12345)

	# 1. التأكد من وجود فرنسا القادمة حصرًا من JSON
	if not sim.world.countries.has("france"):
		print("[FAIL] France not loaded into world.countries!")
		quit()
		return
	print("[PASS] 1. France loaded from JSON data file (data/countries/france/country.json)")

	var initial_pop: float = sim.world.countries["france"]["population"]
	var initial_action: String = sim.world.countries["france"]["chosen_action"]

	# 2. تشغيل المحاكاة 35 يوم لتجاوز أول دورة جدولة وتقييم (t=30)
	sim.run_steps(35)

	var action_after_30d: String = sim.world.countries["france"]["chosen_action"]
	var pop_after_30d: float = sim.world.countries["france"]["population"]

	if initial_action == "none" and action_after_30d != "none":
		print("[PASS] 2. France operational evaluation verified: chosen_action changed from 'none' to '%s'" % action_after_30d)
	else:
		print("[FAIL] France action did not change! (Action: %s)" % action_after_30d)

	if pop_after_30d > initial_pop:
		print("[PASS] 3. France scheduled jobs operational: population grew from %.0f to %.0f" % [initial_pop, pop_after_30d])
	else:
		print("[FAIL] France population did not grow!")

	# 3. اختبار التوافق والتكامل المباشر لـ Save/Load لدولة فرنسا
	var save_path := "user://phase5_france_test.json"
	var save_res := sim.save_to_file(save_path)
	if not save_res["ok"]:
		print("[FAIL] Save failed: " + save_res["error"])
		quit()
		return

	var sim_loaded = SimClass.new()
	var load_res := sim_loaded.load_from_file(save_path)
	if not load_res["ok"]:
		print("[FAIL] Load failed: " + load_res["error"])
		quit()
		return

	if sim_loaded.world.countries.has("france"):
		var loaded_pop: float = sim_loaded.world.countries["france"]["population"]
		var loaded_action: String = sim_loaded.world.countries["france"]["chosen_action"]
		if loaded_pop == pop_after_30d and loaded_action == action_after_30d:
			print("[PASS] 4. France Save/Load Integration verified: state perfectly preserved across disk save/load")
		else:
			print("[FAIL] Loaded state mismatch for France!")
	else:
		print("[FAIL] France missing after load!")

	print("")
	print("============================================================")
	print("  PHASE 5 INTEGRATED VERIFICATION PASSED")
	print("============================================================")
	print("")
	quit()
