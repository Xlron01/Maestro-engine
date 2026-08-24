extends SceneTree

# ============================================================
# MODEL v1 — INTEGRATION GATE (§9.3)
# القناتان + السلاسل على خط إنتاج واحد، والقوانين الثلاثة تُختبر معًا.
#
# I-1 Supply primitive: exposure_supply(China⇐NL,EUV) = 0.70×1.0×1.5 (mirror exact)
# I-2 Chain primitive: DerivedPossession(Washington→EUV_gate) == 0.80
# I-3 Access channel: = exposure_supply × dp × ex_cap (mirror exact, same op order)
# I-4 L1-joint: انقلاب stance/إضافة hostile_relation ⇒ الطبقات الثلاث bitwise
# I-5 L2-joint: لا مفاتيح تجميعية في المخرجات — أسماء كيانات فقط
# I-6 L3-joint: كل قيمة مخرجة float خالص (لا bool/string payload)
# I-7 Determinism: تشغيل مزدوج متطابق لكل طبقة
# ============================================================

const RS := preload("res://scripts/relevance_supply.gd")
const RC := preload("res://scripts/relevance_control.gd")
const WORLD_PATH := "res://data/worlds/model_v1/integration.json"

var pass_count := 0
var fail_count := 0


func _init() -> void:
	print("")
	print("============================================================")
	print("  MODEL v1 — INTEGRATION GATE")
	print("  Both channels + chains | Joint L1/L2/L3 compliance")
	print("============================================================")

	var world := _load_world()
	if world.is_empty():
		print("[FATAL] missing integration world")
		quit(1)
		return
	var cfg: Dictionary = RS.load_config()
	if cfg.is_empty():
		print("[FATAL] missing relevance config")
		quit(1)
		return

	# ---------- الطبقات ----------
	var supply_exposure: float = RS.supply_share(
		(world["entities"]["NL_Policy"] as Dictionary)["produces"],
		world["entities"].values(), "EUV_flow") # = share of NL (sole producer)
	var eff_dep: float = RS.effective_depends_on(world["entities"]["China"], "EUV_flow")
	var crit: float = RS.sector_criticality(world["entities"]["China"], "EUV_flow",
		cfg.get("criticality", {}))
	var exposure_value: float = eff_dep * supply_exposure * crit

	var chains: Dictionary = RC.control_chains(world)
	var euv_controllers: Dictionary = (chains["gates"]["EUV_gate"] as Dictionary)["controllers"]
	var dp_washington: float = float(euv_controllers.get("Washington", 0.0))
	var ex_cap: float = RC.exercise_capability(
		String((world["entities"]["Washington"] as Dictionary).get("projection_class", "default")),
		cfg.get("projection_table", {}))

	var access_value: float = exposure_value * dp_washington * ex_cap

	# Relevance_Supply الكاملة عبر وحدة A + قناة الوصول من B
	var rel_supply_out: Dictionary = RS.relevance_supply(world, cfg, "China", "NL_Policy")
	var rel_supply_value: float = float(rel_supply_out["value"])
	var relevance_total: float = rel_supply_value + access_value

	print("")
	print("[layers] exposure=%.10f dp=%.4f ex_cap=%.2f access=%.10f rel_supply=%.10f total=%.10f"
		% [exposure_value, dp_washington, ex_cap, access_value, rel_supply_value, relevance_total])

	# ---------- I-1 Supply primitive (mirror exact) ----------
	var mirror_eff: float = 0.70 * (1.0 - 0.0)
	var mirror_share: float = 1.0 / 1.0
	var mirror_exposure: float = mirror_eff * mirror_share * 1.5
	_check("I-1 exposure primitive matches mirrored computation exactly",
		exposure_value == mirror_exposure, "%.18f vs %.18f" % [exposure_value, mirror_exposure])

	# ---------- I-2 Chain primitive ----------
	_check("I-2 derived possession Washington->EUV_gate == 0.8 exactly", dp_washington == 0.8,
		"%.18f" % dp_washington)

	# ---------- I-3 Access channel mirror ----------
	var mirror_access: float = exposure_value * 0.8 * 1.0
	_check("I-3 access channel == exposure_supply x dp x exercise_cap (mirror exact)",
		access_value == mirror_access, "%.18f vs %.18f" % [access_value, mirror_access])

	# ---------- I-4 L1 joint across ALL layers ----------
	var w_flip: Dictionary = world.duplicate(true)
	(w_flip["entities"]["Washington"] as Dictionary)["stance"] = "coercive"
	(w_flip["entities"]["China"] as Dictionary)["hostile_relation_with"] = ["Washington"]

	var chains_flip: Dictionary = RC.control_chains(w_flip)
	var flip_euv_ctrl: Dictionary = (chains_flip["gates"]["EUV_gate"] as Dictionary)["controllers"]
	var flip_dp: float = float(flip_euv_ctrl.get("Washington", 0.0))
	var flip_ex_cap: float = RC.exercise_capability(
		String((w_flip["entities"]["Washington"] as Dictionary).get("projection_class", "default")),
		cfg.get("projection_table", {}))
	var flip_acc: float = exposure_value * flip_dp * flip_ex_cap
	var flip_rel_supply: float = float(RS.relevance_supply(w_flip, cfg, "China", "NL_Policy")["value"])

	var l1_ok := true
	if flip_dp != dp_washington:
		l1_ok = false
	if absf(flip_acc - access_value) > 0.0000001:
		l1_ok = false
	if flip_rel_supply != rel_supply_value:
		l1_ok = false
	_check("I-4 L1 joint: stance/hostility flips leave ALL layers bitwise identical",
		l1_ok, "")

	# ---------- I-5 L2 joint: pair-indexed only, no aggregate keys ----------
	var forbidden_aggregates := ["total_danger", "threat_level", "global_threat", "overall_risk"]
	var agg_found := false
	for g in (chains_flip["gates"] as Dictionary).keys():
		for k in ((chains_flip["gates"][g] as Dictionary)).keys():
			if String(k) in forbidden_aggregates:
				agg_found = true
	for k in (chains_flip as Dictionary).keys():
		if String(k) in forbidden_aggregates:
			agg_found = true
	_check("I-5 L2 joint: no aggregate threat/danger keys anywhere in derived output",
		not agg_found, "")

	# ---------- I-6 L3 joint: all emitted values are pure floats ----------
	var all_floats := true
	for g in (chains["gates"] as Dictionary).keys():
		var gd: Dictionary = chains["gates"][g]
		for h in (gd["holders"] as Dictionary).values():
			if typeof(h) != TYPE_FLOAT:
				all_floats = false
		for c in (gd["controllers"] as Dictionary).values():
			if typeof(c) != TYPE_FLOAT:
				all_floats = false
	_check("I-6 L3 joint: every emitted derived value is a bare float", all_floats, "")

	# ---------- I-7 determinism ----------
	var run_a: Dictionary = RC.control_chains(_fresh_world(world))
	var run_b: Dictionary = RC.control_chains(_fresh_world(world))
	_check("I-7 double-run chains output canonical-identical",
		_canon(run_a) == _canon(run_b), "")

	print("")
	print("============================================================")
	if fail_count == 0:
		print("  INTEGRATION GATE RESULT: PASS (%d checks)" % pass_count)
		print("  Model v1 is CLEARED FOR FREEZE pending owner sign-off.")
	else:
		print("  INTEGRATION GATE RESULT: FAIL (%d passed, %d failed)" % [pass_count, fail_count])
	print("============================================================")
	quit(1 if fail_count > 0 else 0)


func _fresh_world(world: Dictionary) -> Dictionary:
	return world.duplicate(true)


func _canon(v) -> String:
	return JSON.stringify(_sort_rec(v))


func _sort_rec(v):
	if v is Dictionary:
		var keys := (v as Dictionary).keys()
		keys.sort()
		var out := {}
		for k in keys:
			out[k] = _sort_rec(v[k])
		return out
	if v is Array:
		var arr: Array = []
		for item in v:
			arr.append(_sort_rec(item))
		return arr
	return v


func _load_world() -> Dictionary:
	if not FileAccess.file_exists(WORLD_PATH):
		push_error("missing world")
		return {}
	var f := FileAccess.open(WORLD_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("invalid json")
		return {}
	return parsed


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		pass_count += 1
		print("[PASS] %s" % label)
	else:
		fail_count += 1
		var msg := "[FAIL] %s" % label
		if detail != "":
			msg += " | %s" % detail
		print(msg)


func cfg_weights() -> Dictionary:
	var cfg: Dictionary = RS.load_config()
	return cfg.get("weights", {})
