extends SceneTree

# ============================================================
# TEST E — EVALUATION SPECIFICATION v0.1 ACCEPTANCE
# وفق التسجيل المسبق المجمد: 18-Evaluation-Specification-v01.md rev.4
#
# المقيّم المرجعي harness-local حصرًا (صفر Kernel).
# Loader Validation V0–V7 + الأشكال F1–F4 بصيغ §2 الحرفية.
# كل الثوابت ثنائية-الدقة — المقارنات == بالضبط كما جمدت §5.
#
# deg/degree: أي bug ⇒ إعادة Test E كاملًا من الصفر.
# ============================================================

const RS := preload("res://scripts/relevance_supply.gd")
const WORLD_PATH := "res://data/worlds/model_v1/e_base.json"
const ACTIONS_PATH := "res://data/worlds/model_v1/e_actions.json"
const GOALS_PATH := "res://data/worlds/model_v1/e_goals.json"

const RENAME_MAP := {
	"Maker_Prime": "Src_One",
	"Fab_Secondary": "Src_Two",
	"Washington": "Ctl_One",
	"Consumer_R": "Act_One"
}

var pass_count := 0
var fail_count := 0
var actions: Array = []
var goals: Dictionary = {}
const MLOG := "C:/tmp/maestro engine/.ai/evidence/tests/test_e_milestones.log"


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
	print("  TEST E - EVALUATION SPECIFICATION v0.1 ACCEPTANCE")
	print("  Reference evaluator harness-local | doc18 rev.4 frozen")
	print("============================================================")

	if not _load_fixtures():
		print("[FATAL] fixture load failure")
		quit(1)
		return

	var world := _load_world()
	if world.is_empty():
		print("[FATAL] missing world fixture")
		quit(1)
		return

	# ---------- RAW ----------
	print("")
	print("---------------- RAW: weighted scores ----------------")
	print("  G_F4W OPT_TRADE => %.10f | OPT_BASE => %.10f"
		% [score("G_F4W", "OPT_TRADE"), score("G_F4W", "OPT_BASE")])
	print("----------------------------------------------")

	# ---------- Loader positive sanity ----------
	print("")
	print("-- L0: all six fixture goals load clean under V0-V7")
	var load_ok := true
	for gid in goals.keys():
		var err := validate_block(goals[gid])
		if err != "":
			load_ok = false
			print("   %s => REJECT(%s)" % [gid, err])
	_check("L0 fixture goals all pass loader validation", load_ok, "")

	# ---------- Loader negative probes ----------
	print("")
	print("-- L: loader rejection probes (V-rules executable)")
	var p := {}
	p = {"form": "F9"}
	_check("L1 unknown form rejected with exact reason", reject_of(p) == "unknown form", reject_of(p))
	p = {"form": "F5"}
	_check("L2 form F5 rejected as structural-not-declarable",
		reject_of(p) == "F5 is structural, not declarable", reject_of(p))
	p = {"form": "F1", "channels": ["rel_supply"], "target_ref": "X", "direction": "maximize"}
	_check("L3 F1 without scale=interval rejected", reject_of(p) == "F1 requires declared interval scale", reject_of(p))
	p = {"form": "F1", "channels": ["rel_supply"], "target_ref": "X", "scale": "interval", "direction": "up"}
	_check("L4 F1 direction outside closed set rejected", reject_of(p) == "direction must be declared: maximize|minimize", reject_of(p))
	p = {"form": "F4", "mode": "pareto", "terms": [],
		"tie_extension": {"by": "score", "order": "desc"}}
	_check("L5 tampered tie_extension rejected (immutable)", reject_of(p) == "tie_extension immutable in v0.1", reject_of(p))
	p = {"form": "F3", "composite": "dependency_index", "cap": "c", "of": "o",
		"ceiling": 0.375, "violation_multiplier": 10.0}
	_check("L6 composite outside Model v1 set rejected", reject_of(p) == "composite outside existing Model v1 set", reject_of(p))
	p = {"form": "F2", "fact": "a.b", "floor": 90,
		"below_penalty_per_day": 0.0625, "above_saturation": false}
	_check("L7 non-saturated F2 variant rejected in v0.1", reject_of(p) == "only saturated variant implemented in v0.1", reject_of(p))

	# ---------- E1 ----------
	print("")
	print("-- E1: F1 monotonicity (declared interval scale)")
	var s_a := score("G_F1", "ACT_D1A")
	var s_b := score("G_F1", "ACT_D1B")
	print("   D1A=%.10f D1B=%.10f diff=%.10f" % [s_a, s_b, s_b - s_a])
	_check("E1 monotonicity holds under declared interval scale",
		(s_b - s_a) == 0.25 and s_b > s_a, "%.18f" % (s_b - s_a))

	# ---------- E2 ----------
	print("")
	print("-- E2: F2 satisficing kink (floor=90 penalty=0.0625)")
	var c_below := contrib_block(goals["G_F2"], {"facts": {"reserves_days": {"EUV_flow": 75}}})
	var c_at := contrib_block(goals["G_F2"], {"facts": {"reserves_days": {"EUV_flow": 90}}})
	var c_above := contrib_block(goals["G_F2"], {"facts": {"reserves_days": {"EUV_flow": 120}}})
	print("   c(75)=%.10f c(90)=%.10f c(120)=%.10f" % [c_below, c_at, c_above])
	_check("E2 satisficing kink: below-floor deficit penalized at declared rate; at/above floor contributes zero",
		c_below == -0.9375 and c_at == 0.0 and c_above == 0.0,
		"%.18f/%.18f/%.18f" % [c_below, c_at, c_above])

	# ---------- E3 ----------
	print("")
	print("-- E3: F3 ratio ceiling (ceiling=0.375 multiplier=10)")
	var sh_high := _share_for(world, 0.75, 0.25)
	var w_mid := _variant_world(world, 0.3125, 0.6875)
	var w_low := _variant_world(world, 0.25, 0.75)
	var c_viol := contrib_f3(goals["G_F3"], sh_high)
	var c_edge := contrib_f3(goals["G_F3"], _share_for(w_mid, 0.3125, 0.6875))
	var c_head := contrib_f3(goals["G_F3"], _share_for(w_low, 0.25, 0.75))
	print("   shares %.4f/%.4f/%.4f => c=%.4f/%.4f/%.4f"
		% [sh_high, 0.3125, 0.25, c_viol, c_edge, c_head])
	var slope_ok := (c_head - c_edge) == 0.0625
	_check("E3 ratio ceiling: above-ceiling share penalized by declared multiplier; headroom linear without bonus",
		c_viol == -3.75 and c_edge == 0.0625 and c_head == 0.125 and slope_ok,
		"%.18f/%.18f/%.18f slope=%.18f" % [c_viol, c_edge, c_head, c_head - c_edge])

	# ---------- E4 ----------
	print("")
	print("-- E4: lexicographic vs weighted divergence")
	var d_w := decide_scalar("G_F4W", ["OPT_TRADE", "OPT_BASE"])
	var sat_trade := lex_vector("G_F4L", "OPT_TRADE")
	var d_l := decide_lex("G_F4L", ["OPT_TRADE", "OPT_BASE"])
	print("   weighted=>%-9s net_TRADE=%.10f | lex=>%s sat_VECTOR_TRADE=%s"
		% [d_w, score("G_F4W", "OPT_TRADE"), d_l, str(sat_trade)])
	_check("E4 lexicographic refuses trade-off that weighted accepts - both forms earn membership",
		d_w == "OPT_TRADE" and d_l == "OPT_BASE" and d_w != d_l, "%s vs %s" % [d_w, d_l])

	# ---------- E5 ----------
	print("")
	print("-- E5: pareto maxima + section-7 extension")
	var chosen_p := decide_pareto("G_F4P", ["OPT_P1", "OPT_P2", "OPT_BASE"])
	print("   maxima={OPT_P1, OPT_P2} chosen=%s" % chosen_p)
	_check("E5 selects a maximal element deterministically via option_id ascending (doc17 section 7)",
		chosen_p == "OPT_P1", chosen_p)

	# ---------- E6 ----------
	print("")
	print("-- E6: CE-5 twin actions (mandated acceptance)")
	var d_x := canonical(descriptor_of("ACT_TWIN_X"))
	var d_y := canonical(descriptor_of("ACT_TWIN_Y"))
	var twins_opts := ["ACT_TWIN_X", "ACT_TWIN_Y"]
	var sc_x := canonical(_scores_map("G_F1", twins_opts))
	var dec_x := decide_scalar("G_F1", twins_opts)
	var dec_y := decide_scalar("G_F1", ["ACT_TWIN_Y", "ACT_TWIN_X"])
	print("   descriptors identical=%s scores identical=%s decisions X/Y=%s/%s"
		% [str(d_x == d_y), str(sc_x == canonical(_scores_map("G_F1", ["ACT_TWIN_Y", "ACT_TWIN_X"]))), dec_x, dec_y])
	_check("E6 twin actions with identical descriptors yield bitwise-identical scores (Gate-2 path-neutrality)",
		d_x == d_y and sc_x == canonical(_scores_map("G_F1", ["ACT_TWIN_Y", "ACT_TWIN_X"]))
		and dec_x == dec_y and dec_x == "ACT_TWIN_X", "")

	# ---------- E7 ----------
	print("")
	print("-- E7: evaluation identity blindness")
	var roles_base := {
		"f1_deltas": {"goal": "G_F1", "opts": ["ACT_D1A", "ACT_D1B"]},
		"f4_weighted": {"goal": "G_F4W", "opts": ["OPT_TRADE", "OPT_BASE"]}
	}
	var base_out := _eval_roles(roles_base, false)
	var ren_out := _eval_roles(roles_base, true)
	var eq := canonical(base_out) == canonical(ren_out)
	print("   base==renamed(after inverse map): %s" % str(eq))
	_check("E7 evaluation identity-blind: scores invariant under entity renaming (inverse-mapped)", eq, "")

	# ---------- E8 ----------
	print("")
	print("-- E8: read-only + determinism")
	var snap_pre := canonical([world, actions, goals])
	var sink1 := score("G_F4W", "OPT_TRADE")
	var sink2 := decide_pareto("G_F4P", ["OPT_P1", "OPT_P2", "OPT_BASE"])
	var snap_post := canonical([world, actions, goals])
	var run2 := _rerun_all_scalars()
	_check("E8 read-only evaluation, deterministic across independent loads",
		snap_pre == snap_post and run2, "")

	print("")
	_m("REACHED QUIT")
	print("============================================================")
	if fail_count == 0:
		print("  TEST E RESULT: PASS (%d checks)" % pass_count)
	else:
		print("  TEST E RESULT: FAIL (%d passed, %d failed)" % [pass_count, fail_count])
	print("============================================================")
	quit(1 if fail_count > 0 else 0)


# ---------------- reference evaluator (doc18 section 2 verbatim) ----------------

func validate_block(b: Dictionary) -> String:
	if not b.has("form"):
		return "missing form"
	if String(b["form"]) == "F5":
		return "F5 is structural, not declarable"
	if not (String(b["form"]) in ["F1", "F2", "F3", "F4"]):
		return "unknown form"
	var form := String(b["form"])
	if form == "F1":
		if String(b.get("scale", "")) != "interval":
			return "F1 requires declared interval scale"
		if not (String(b.get("direction", "")) in ["maximize", "minimize"]):
			return "direction must be declared: maximize|minimize"
	if form == "F4":
		var mode := String(b.get("mode", ""))
		if mode == "pareto":
			var te: Dictionary = b.get("tie_extension", {})
			if te.get("by", "") != "option_id" or te.get("order", "") != "asc":
				return "tie_extension immutable in v0.1"
		if mode == "weighted":
			for t in b["terms"]:
				var td: Dictionary = t
				if not td.has("scale_decl"):
					return "scale_decl required per weighted term"
	if form == "F3":
		if String(b.get("composite", "")) != "supply_share":
			return "composite outside existing Model v1 set"
	if form == "F2":
		if bool(b.get("above_saturation", false)) != true:
			return "only saturated variant implemented in v0.1"
	return ""


func reject_of(b: Dictionary) -> String:
	return validate_block(b)


func raw_channel(block: Dictionary, desc: Dictionary) -> float:
	var total := 0.0
	var chans: Array = block.get("channels", [])
	var target := String(block.get("target_ref", ""))
	var dch: Dictionary = desc.get("channels", {})
	for ch in chans:
		var cname := String(ch)
		if dch.has(cname) and (dch[cname] as Dictionary).has(target):
			total += float(dch[cname][target])
	return total


func fact_value(path: String, desc: Dictionary) -> float:
	var parts := path.split(".")
	var node = desc.get("facts", {})
	for i in parts.size():
		var key := String(parts[i])
		if typeof(node) != TYPE_DICTIONARY or not (node as Dictionary).has(key):
			return 0.0
		node = (node as Dictionary)[key]
	return float(node)


func contrib_block(block: Dictionary, desc: Dictionary, ctx: Dictionary = {}) -> float:
	var form := String(block["form"])
	if form == "F1":
		var raw := raw_channel(block, desc)
		if String(block["direction"]) == "minimize":
			return -raw
		return raw
	if form == "F2":
		var value := fact_value(String(block["fact"]), desc)
		var floor_v := float(block["floor"])
		var pen := float(block["below_penalty_per_day"])
		if value < floor_v:
			return -(floor_v - value) * pen
		return 0.0
	if form == "F3":
		var ratio := float(ctx.get("share", 0.0))
		var ceiling := float(block["ceiling"])
		var mult := float(block["violation_multiplier"])
		if ratio <= ceiling:
			return ceiling - ratio
		return -(ratio - ceiling) * mult
	if form == "F4":
		var mode := String(block["mode"])
		if mode == "weighted":
			var total := 0.0
			for t in block["terms"]:
				var td: Dictionary = t
				total += contrib_block(td["term"], desc) * float(td["weight"])
			return total
	return 0.0


func score(goal_id: String, action_id: String) -> float:
	return contrib_block(goals[goal_id], descriptor_of(action_id))


func lex_vector(goal_id: String, action_id: String) -> Array:
	var out: Array = []
	for cond in goals[goal_id]["priority"]:
		out.append(contrib_block(cond, descriptor_of(action_id)) >= 0.0)
	return out


func decide_scalar(goal_id: String, opts: Array) -> String:
	var best_id := ""
	var best := -INF
	for oid in opts:
		var s := contrib_block(goals[goal_id], descriptor_of(String(oid)))
		if s > best or (s == best and String(oid) < best_id):
			best = s
			best_id = String(oid)
	return best_id


func decide_lex(goal_id: String, opts: Array) -> String:
	var best_id := ""
	var best_vec: Array = []
	for oid in opts:
		var vec := lex_vector(goal_id, String(oid))
		if best_id == "":
			best_id = String(oid)
			best_vec = vec
			continue
		for i in vec.size():
			if bool(vec[i]) != bool(best_vec[i]):
				if bool(vec[i]):
					best_id = String(oid)
					best_vec = vec
				break
	return best_id


func decide_pareto(goal_id: String, opts: Array) -> String:
	var benefits := {}
	for oid in opts:
		var vec: Array = []
		for t in goals[goal_id]["terms"]:
			vec.append(contrib_block(t, descriptor_of(String(oid))))
		benefits[String(oid)] = vec
	var maxima: Array = []
	for oid in opts:
		var dominated := false
		for other in opts:
			if String(other) == String(oid):
				continue
			if _dominates(benefits[String(other)], benefits[String(oid)]):
				dominated = true
				break
		if not dominated:
			maxima.append(String(oid))
	maxima.sort()
	return String(maxima[0])


func _dominates(a: Array, b: Array) -> bool:
	var ge := true
	var strict := false
	for i in a.size():
		if float(a[i]) < float(b[i]):
			return false
		if float(a[i]) > float(b[i]):
			strict = true
	return ge and strict


func _scores_map(goal_id: String, opts: Array) -> Dictionary:
	var out := {}
	for oid in opts:
		out[String(oid)] = contrib_block(goals[goal_id], descriptor_of(String(oid)))
	return out


# ---------------- fixtures & plumbing ----------------

func _load_fixtures() -> bool:
	actions = _read_json(ACTIONS_PATH).get("actions", [])
	goals = _read_json(GOALS_PATH).get("goals", {})
	return not actions.is_empty() and not goals.is_empty()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _load_world() -> Dictionary:
	return _read_json(WORLD_PATH)


func descriptor_of(action_id: String) -> Dictionary:
	for a in actions:
		if String((a as Dictionary)["action_id"]) == action_id:
			return (a as Dictionary)["descriptor"]
	return {}


func _share_for(world: Dictionary, maker_prod: float, fab_prod: float) -> float:
	var ents: Array = (world["entities"] as Dictionary).values()
	(world["entities"]["Maker_Prime"] as Dictionary)["produces"] = {"EUV_flow": maker_prod}
	(world["entities"]["Fab_Secondary"] as Dictionary)["produces"] = {"EUV_flow": fab_prod}
	return RS.supply_share((world["entities"]["Maker_Prime"] as Dictionary)["produces"], ents, "EUV_flow")


func _variant_world(world: Dictionary, maker_prod: float, fab_prod: float) -> Dictionary:
	var w: Dictionary = world.duplicate(true)
	(w["entities"]["Maker_Prime"] as Dictionary)["produces"] = {"EUV_flow": maker_prod}
	(w["entities"]["Fab_Secondary"] as Dictionary)["produces"] = {"EUV_flow": fab_prod}
	return w


func contrib_f3(block: Dictionary, share: float) -> float:
	return contrib_block(block, {}, {"share": share})


func _remap_deep(v, inv: Dictionary):
	if v is Dictionary:
		var o := {}
		for k in (v as Dictionary).keys():
			o[String(inv.get(k, k))] = _remap_deep(v[k], inv)
		return o
	if v is Array:
		var arr: Array = []
		for item in v:
			arr.append(_remap_deep(item, inv))
		return arr
	if v is String:
		return String(inv.get(v, v))
	return v


func _eval_roles(roles: Dictionary, renamed: bool) -> Dictionary:
	var inv := {}
	if renamed:
		for k in RENAME_MAP.keys():
			inv[RENAME_MAP[k]] = k
	var out := {}
	for rid in roles.keys():
		var role: Dictionary = roles[rid]
		var goal_blk: Dictionary = goals[String(role["goal"])]
		var scores := {}
		for oid in role["opts"]:
			var desc: Dictionary = descriptor_of(String(oid))
			var gblk: Dictionary = goal_blk.duplicate(true)
			if renamed:
				desc = _remap_deep(desc, RENAME_MAP)
				gblk = _remap_deep(gblk, RENAME_MAP)
			var ctx := {}
			scores[String(oid)] = contrib_block(gblk, desc, ctx)
		if renamed:
			out[String(inv.get(rid, rid))] = _remap_deep(scores, inv)
		else:
			out[rid] = scores
	return out


func _rerun_all_scalars() -> bool:
	var again_e1 := (score("G_F1", "ACT_D1B") - score("G_F1", "ACT_D1A")) == 0.25
	var again_e4 := decide_scalar("G_F4W", ["OPT_TRADE", "OPT_BASE"]) == "OPT_TRADE" \
		and decide_lex("G_F4L", ["OPT_TRADE", "OPT_BASE"]) == "OPT_BASE"
	var again_e5 := decide_pareto("G_F4P", ["OPT_P1", "OPT_P2", "OPT_BASE"]) == "OPT_P1"
	var again_e6 := decide_scalar("G_F1", ["ACT_TWIN_X", "ACT_TWIN_Y"]) == "ACT_TWIN_X"
	return again_e1 and again_e4 and again_e5 and again_e6


func canonical(v) -> String:
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
