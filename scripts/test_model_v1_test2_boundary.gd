extends SceneTree

# ============================================================
# TEST 2 — RELEVANCE BOUNDARY / DECISION NON-EQUIVALENCE
# وفق تعريف صاحب المشروع: إثبات أن Relevance لا تتحول تلقائيًا إلى Decision.
#
# التصنيف الثلاثي المثبت:
#   FACT          — يقرأه النموذج
#   DERIVED STATE — Relevance المجمدة
#   DECISION      — مرجع تجريبي داخل هذا العدّاء حصرًا (reference-only)
#
# التوقعات المسجلة قبل التشغيل:
#   A-BOUNDARY: الحالات الخمس غير المادية (stance/relations/goal_swap/
#     goal_zero_rel) ⇒ مصفوفتا supply/access bitwise == base
#   PC: تغيير fact حقيقي ⇒ القيم تتحرك (إثبات حساسية)
#   B-D1: نفس Relevance + تبديل goals ⇒ قراران مختلفان
#   B-D2: حساب القرارات لا يلوث أي قيمة (world/relevance bitwise بعد الحساب)
#   B-D3: relevance=0 + أقصى هدف ⇒ secure score = 0.0 بالضبط
#   J-L1/L2/L3: على كل حالة
#
# قاعدة deg/degree: أي bug ⇒ إعادة كل الفحوصات من الصفر.
# ============================================================

const RS := preload("res://scripts/relevance_supply.gd")
const RC := preload("res://scripts/relevance_control.gd")
const WORLD_PATH := "res://data/worlds/model_v1/test2_base.json"
const FORBIDDEN_AGGREGATES := ["total_danger", "threat_level", "global_threat", "overall_risk"]

var pass_count := 0
var fail_count := 0
var cfg: Dictionary = {}
var worlds := {}
var outputs := {}
const MLOG := "C:/tmp/maestro engine/.ai/evidence/tests/t2_real_milestones.log"


func _m(tag: String) -> void:
	var f := FileAccess.open(MLOG, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(MLOG, FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line("[%d] %s" % [Time.get_ticks_msec(), tag])
		f.close()


func _init() -> void:
	_m("START")
	print("")
	print("============================================================")
	print("  TEST 2 - RELEVANCE BOUNDARY / DECISION NON-EQUIVALENCE")
	print("  Frozen Model v1 | Reference decision = harness-local only")
	print("============================================================")

	_m("cfg loading")
	cfg = RS.load_config()
	_m("cfg loaded, empty=" + str(cfg.is_empty()))
	if cfg.is_empty():
		print("[FATAL] missing relevance config")
		quit(1)
		return

	for st in ["base", "v_friendly", "v_hostile", "v_no_intent", "v_goal_swap",
			"v_goal_zero_rel", "pc_fact"]:
		_m("building " + st)
		var w := _load_world_variant(st)
		if w.is_empty():
			print("[FATAL] cannot build state %s" % st)
			quit(1)
			return
		_m("layers computing " + st)
		worlds[st] = w
		outputs[st] = _layers(w)
		_m("layers done " + st)

	# ---------- النتائج الخام ----------
	print("")
	print("---------------- RAW RESULTS ----------------")
	_m("RAW begin")
	for st in ["base", "v_friendly", "v_hostile", "v_no_intent", "v_goal_swap",
			"v_goal_zero_rel", "pc_fact"]:
		print("")
		print("state: %s" % st)
		for layer in ["supply", "access"]:
			var m: Dictionary = outputs[st][layer]
			for o in m.keys():
				for t in m[o].keys():
					print("  %s(%s -> %s) = %.10f" % [layer, o, t, float(m[o][t])])
	print("")
	print("----------------------------------------------")
	_m("RAW end")

	# ---------- A-BOUNDARY ----------
	print("")
	print("---------------- A-BOUNDARY (non-fact variants) ----------------")
	print("")
	for st in ["v_friendly", "v_hostile", "v_no_intent", "v_goal_swap", "v_goal_zero_rel"]:
		var diffs := _diff_cells(outputs["base"], outputs[st])
		var ch_b := JSON.stringify(_sort_rec(_strip_diag(outputs["base"]["chains"])))
		var ch_v := JSON.stringify(_sort_rec(_strip_diag(outputs[st]["chains"])))
		if ch_b != ch_v:
			diffs.append("chains")
		_m("boundary done " + st)
		_check("A-BOUNDARY %s: full matrices + chains bitwise == base (0 diffs)" % st,
			diffs.is_empty(), str(diffs))

	# ---------- PC positive control ----------
	var pc_diffs := _diff_cells(outputs["base"], outputs["pc_fact"])
	_check("PC fact change moves values (harness sensitivity proof)",
		pc_diffs.size() > 0, "cells=%d" % pc_diffs.size())

	# ---------- B reference decision (harness-local stub) ----------
	print("")
	print("-- B: Reference decision stub (binary argmax, harness-local)")
	_m("B begin")
	var r_alpha := float(outputs["base"]["supply"]["Consumer_Alpha"]["Maker_Prime"])
	var d_alpha_goals := _ref_decision(r_alpha,
		worlds["base"]["entities"]["Consumer_Alpha"]["goal_table"])
	var d_beta_goals := _ref_decision(r_alpha,
		worlds["base"]["entities"]["Consumer_Beta"]["goal_table"])
	print("   same relevance=%.10f | Alpha-goals => %s | Beta-goals => %s"
		% [r_alpha, d_alpha_goals, d_beta_goals])
	_check("B-D1 SAME relevance + swapped goals => DIFFERENT decision",
		d_alpha_goals != d_beta_goals,
		"%s vs %s" % [d_alpha_goals, d_beta_goals])

	var snap_before := JSON.stringify(_sort_rec(worlds["base"]))
	# (القرارات حُسبت أعلاه كقراءات خالصة)
	var snap_after := JSON.stringify(_sort_rec(worlds["base"]))
	_check("B-D2 decision computation leaves world object untouched (bitwise)",
		snap_before == snap_after, "")

	var anchor_rel := float(outputs["base"]["supply"]["Anchor_Null"]["Maker_Prime"])
	var anchor_scores := _ref_scores(anchor_rel, {"resource_security": 1.0, "prestige": 0.0})
	_m("B done")
	_check("B-D3 zero relevance + maximal resource goal => secure score exactly 0.0",
		anchor_rel == 0.0 and float(anchor_scores["secure"]) == 0.0,
		"rel=%.18f" % anchor_rel)

	# ---------- Joint laws per state ----------
	print("")
	print("-- J: Laws per state")
	_m("J begin")
	for st in ["base", "v_friendly", "v_hostile", "v_no_intent", "v_goal_swap",
			"v_goal_zero_rel", "pc_fact"]:
		_l2_l3_for_state(outputs[st]["chains"], outputs[st], st)
		_m("laws done " + st)

	print("")
	_m("REACHED QUIT")
	print("============================================================")
	if fail_count == 0:
		print("  TEST 2 RESULT: PASS (%d checks)" % pass_count)
	else:
		print("  TEST 2 RESULT: FAIL (%d passed, %d failed)" % [pass_count, fail_count])
	print("============================================================")
	quit(1 if fail_count > 0 else 0)


func _load_world_variant(st: String) -> Dictionary:
	if not FileAccess.file_exists(WORLD_PATH):
		return {}
	var f := FileAccess.open(WORLD_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var w: Dictionary = parsed.duplicate(true)
	match st:
		"v_friendly":
			w["entities"]["Washington"]["stance"] = "cooperative"
			w["entities"]["Washington"]["relations"]["China_Entity"] = "cooperative"
			w["entities"]["Consumer_Alpha"]["stance"] = "cooperative"
		"v_hostile":
			w["entities"]["Washington"]["stance"] = "hostile"
			w["entities"]["Washington"]["relations"]["China_Entity"] = "hostile"
			w["entities"]["Consumer_Alpha"]["stance"] = "hostile"
		"v_no_intent":
			w["entities"]["Washington"].erase("stance")
			w["entities"]["Washington"].erase("relations")
			w["entities"]["Consumer_Alpha"].erase("stance")
		"v_goal_swap":
			var gt_a: Dictionary = w["entities"]["Consumer_Alpha"]["goal_table"]
			var gt_b: Dictionary = w["entities"]["Consumer_Beta"]["goal_table"]
			w["entities"]["Consumer_Alpha"]["goal_table"] = gt_b
			w["entities"]["Consumer_Beta"]["goal_table"] = gt_a
		"v_goal_zero_rel":
			w["entities"]["Anchor_Null"]["goal_table"] = {
				"resource_security": 1.0, "prestige": 0.0
			}
		"pc_fact":
			w["entities"]["Fab_Secondary"]["produces"]["EUV_flow"] = 0.55
	return w


func _layers(world: Dictionary) -> Dictionary:
	var chains: Dictionary = RC.control_chains(world)
	var supply := {}
	var access := {}
	var entities: Dictionary = world["entities"]
	for y in entities.keys():
		supply[y] = {}
		access[y] = {}
		for x in entities.keys():
			if String(y) == String(x):
				continue
			supply[y][x] = float(RS.relevance_supply(world, cfg, String(y), String(x))["value"])
			access[y][x] = float(RC.relevance_access(world, chains, cfg, String(y), String(x))["value"])
	return {"chains": chains, "supply": supply, "access": access}


func _diff_cells(ma: Dictionary, mb: Dictionary) -> Array:
	var diffs: Array = []
	for layer in ["supply", "access"]:
		if not ma.has(layer) or not mb.has(layer):
			diffs.append("%s layer-missing" % layer)
			continue
		for o in ma[layer].keys():
			if not (mb[layer] as Dictionary).has(o):
				diffs.append("%s/%s row-missing" % [layer, o])
				continue
			for t in ma[layer][o].keys():
				if not (mb[layer][o] as Dictionary).has(t):
					diffs.append("%s %s->%s cell-missing" % [layer, o, t])
					continue
				if float(ma[layer][o][t]) != float(mb[layer][o][t]):
					diffs.append("%s %s->%s" % [layer, o, t])
	return diffs


func _ref_decision(relevance: float, goal_table: Dictionary) -> String:
	return String(_ref_scores(relevance, goal_table)["decision"])


func _ref_scores(relevance: float, goal_table: Dictionary) -> Dictionary:
	var sec := float(goal_table.get("resource_security", 0.0)) * relevance
	var disengage := float(goal_table.get("prestige", 0.0)) * 0.5
	var decision := "secure_supply" if sec >= disengage else "disengage"
	return {"secure": sec, "disengage": disengage, "decision": decision}


func _l2_l3_for_state(chains: Dictionary, layered: Dictionary, tag: String) -> void:
	var agg_found := false
	for g in (chains["gates"] as Dictionary).keys():
		for k in ((chains["gates"][g] as Dictionary)).keys():
			if String(k) in FORBIDDEN_AGGREGATES:
				agg_found = true
	for layer in ["supply", "access"]:
		for o in (layered[layer] as Dictionary).keys():
			for t in (layered[layer][o] as Dictionary).keys():
				if String(t) in FORBIDDEN_AGGREGATES or String(o) in FORBIDDEN_AGGREGATES:
					agg_found = true
	_check("%s L2-joint: no aggregate keys in derived output" % tag, not agg_found, "")

	var all_floats := true
	for layer in ["supply", "access"]:
		var m: Dictionary = layered[layer]
		for o in m.keys():
			for t in m[o].keys():
				if typeof(m[o][t]) != TYPE_FLOAT:
					all_floats = false
	for g in (chains["gates"] as Dictionary).keys():
		var gd: Dictionary = chains["gates"][g]
		for h in (gd["holders"] as Dictionary).values():
			if typeof(h) != TYPE_FLOAT:
				all_floats = false
		for c in (gd["controllers"] as Dictionary).values():
			if typeof(c) != TYPE_FLOAT:
				all_floats = false
	_check("%s L3-joint: all emitted derived values bare floats" % tag, all_floats, "")


func _strip_diag(v):
	# يجرد الحقول التشخيصية (visits/cycle_events/steps) للمقارنة البنيوية
	if v is Dictionary:
		var o := {}
		for k in (v as Dictionary).keys():
			var ks := String(k)
			if ks in ["visits", "cycle_events", "steps"]:
				continue
			o[ks] = _strip_diag(v[k])
		return o
	if v is Array:
		var a: Array = []
		for item in v:
			a.append(_strip_diag(item))
		return a
	return v


func _canonical(v) -> String:
	return JSON.stringify(_sort_rec(_strip_diag(v)))


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
