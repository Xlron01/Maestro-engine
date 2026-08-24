extends SceneTree

const SimClass = preload("res://scripts/Simulation.gd")
const DecisionClass = preload("res://scripts/DecisionSystem.gd")

func _init() -> void:
	print("")
	print("============================================================")
	print("  PHASE 6 STEP 2 — Mutable State (Agent XP Operation Test)")
	print("============================================================")
	print("")

	var sim = SimClass.new()
	sim.init_world(12345)

	# 1. فحص وجود العميلين والـ Agency والقواعد
	if not sim.world.agencies.has("cia"):
		print("[FAIL] Agency 'cia' not loaded!")
		quit()
		return

	if not sim.world.agents.has("agent_007") or not sim.world.agents.has("agent_rookie"):
		print("[FAIL] Agents 'agent_007' or 'agent_rookie' missing!")
		quit()
		return

	var agency = sim.world.agencies["cia"]
	var agent_vet = sim.world.agents["agent_007"]
	var agent_rook = sim.world.agents["agent_rookie"]

	print("--- Before Operation Execution ---")
	print("Veteran  agent_007:   XP = %d" % agent_vet.get("xp", 0))
	print("Rookie   agent_rookie: XP = %d" % agent_rook.get("xp", 0))
	print("")

	# 2. تنفيذ العملية للعميل الخبير (agent_007) — توقع النجاح
	var res_vet = DecisionClass.evaluate_operation(agent_vet, agency, sim.rules)
	print("--- Operation 1: Veteran agent_007 ---")
	print("Score: %.2f | Threshold: %.2f | Success: %s | XP: %d -> %d (+%d)" % [
		res_vet["score"], res_vet["threshold"], res_vet["success"],
		res_vet["old_xp"], res_vet["new_xp"], res_vet["xp_gain"]
	])

	if not res_vet["success"] or res_vet["new_xp"] != 125:
		print("[FAIL] Veteran operation expected SUCCESS with XP 125!")
		quit()
		return
	print("[PASS] 1. Veteran agent_007 operation SUCCESS verified (XP = 125)")

	# 3. تنفيذ العملية للعميل المبتدئ (agent_rookie) — توقع الفشل
	var res_rook = DecisionClass.evaluate_operation(agent_rook, agency, sim.rules)
	print("")
	print("--- Operation 2: Rookie agent_rookie ---")
	print("Score: %.2f | Threshold: %.2f | Success: %s | XP: %d -> %d (+%d)" % [
		res_rook["score"], res_rook["threshold"], res_rook["success"],
		res_rook["old_xp"], res_rook["new_xp"], res_rook["xp_gain"]
	])

	if res_rook["success"] or res_rook["new_xp"] != 25:
		print("[FAIL] Rookie operation expected FAILURE with XP 25!")
		quit()
		return
	print("[PASS] 2. Rookie agent_rookie operation FAILURE verified (XP = 25)")

	# 4. الحفظ والاستعادة الحقيقية من الديسك (Save/Load)
	print("")
	var save_path := "user://phase6_step2_test.json"
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

	var loaded_vet_xp = sim_loaded.world.agents["agent_007"].get("xp", 0)
	var loaded_rook_xp = sim_loaded.world.agents["agent_rookie"].get("xp", 0)

	print("--- After Save/Load Verification ---")
	print("Loaded agent_007   XP = %d (Expected: 125)" % loaded_vet_xp)
	print("Loaded agent_rookie XP = %d (Expected: 25)" % loaded_rook_xp)

	if loaded_vet_xp == 125 and loaded_rook_xp == 25:
		print("[PASS] 3. Save/Load Integration verified: Both updated XP values preserved across disk Save/Load")
	else:
		print("[FAIL] Loaded XP mismatch after Save/Load!")
		quit()
		return

	print("")
	print("============================================================")
	print("  PHASE 6 STEP 2 VERIFICATION PASSED")
	print("============================================================")
	print("")
	quit()
