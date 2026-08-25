extends SceneTree

# ============================================================
# TEST D1 — DECISION BOUNDARY TEST
# وفق التسجيل المسبق المجمد: 16-Decision-Boundary-Test.md
#
# المبدأ الحاكم (توجيه المالك):
#   D1 لا يختبر صحة Evaluation Formula — يختبر أن Decision Layer
#   يحترم حدود ومدخلات ومخرجات الـDecision Semantics.
#
# الخصائص السبع: P1 Goal / P2 Relevance / P3 Capability /
#   P4 Option Sensitivity / P5 Identity Blindness /
#   P6 Read-only / P7 Determinism
#
# طبقة القرار المرجعية decide() داخل هذا العدّاء حصرًا (reference-only)
# — صفر Kernel code. أسماء القنوات حرفية من doc 10:
#   rel_supply / access
#
# قاعدة deg/degree: أي bug ⇒ إعادة كل الفحوصات من الصفر.
# ============================================================

const RS := preload("res://scripts/relevance_supply.gd")
const RC := preload("res://scripts/relevance_control.gd")
const WORLD_PATH := "res://data/worlds/model_v1/d1_base.json"
const OPTIONS_PATH := "res://data/worlds/model_v1/d1_options.json"
const FORBIDDEN_AGGREGATES := ["total_danger", "threat_level", "global_threat", "overall_risk"]

const RENAME_MAP := {
	"Maker_Prime": "Src_One",
	"Fab_Secondary": "Src_Two",
	"Gate_Holder": "Gk_One",
	"Washington": "Ctl_One",
	"Decision_Actor": "Act_One",
	"Second_Actor": "Act_Two",
	"Anchor_Null": "Anch_One"
}

var pass_count := 0
var fail_count := 0
var cfg: Dictionary = {}
var base_options: Array = []
const MLOG := "C:/tmp/maestro engine/.ai/evidence/tests/d1_milestones.log"


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
	print("  TEST D1 - DECISION BOUNDARY (architecture, not formula)")
	print("  Frozen Model v1 | decide() harness-local reference-only")
	print("============================================================")

	cfg = RS.load_config()
	if cfg.is_empty():
		print("[FATAL] missing relevance config")
		quit(1)
		return

	base_options = _load_options()
	if base_options.is_empty():
		print("[FATAL] missing options fixture")
		quit(1)
		return

	var worlds := {}
	var layers := {}
	for st in ["base", "v_goal_swap", "v_fact_change", "v_capped_actor",
			"v_capped_full", "v_option_add", "v_renamed"]:
		_m("building " + st)
		var w := _load_world_variant(st)
		if w.is_empty():
			print("[FATAL] cannot build state %s" % st)
			quit(1)
			return
		worlds[st] = w
		layers[st] = _layers(w)
		_m("layers done " + st)

	# ---------- RAW ----------
	print("")
	print("---------------- RAW RELEVANCE (base) ----------------")
	for layer in ["supply", "access"]:
		var m: Dictionary = layers["base"][layer]
		for o in m.keys():
			for t in m[o].keys():
				print("  %s(%s -> %s) = %.10f" % [layer, o, t, float(m[o][t])])
	print("----------------------------------------------")

	# ---------- A-BOUNDARY: goal_table swap is non-fact ----------
	var ab_diffs := _diff_layers(layers["base"], layers["v_goal_swap"])
	_check("A-BOUNDARY goal_swap: matrices bitwise == base (relevance untouched by goals)",
		ab_diffs.is_empty(), str(ab_diffs))

	# ---------- P1 Goal Dependence ----------
	print("")
	print("-- P1: Goal Dependence (same world/relevance/options)")
	var ent_b: Dictionary = worlds["base"]["entities"]
	var row_a := _rel_row(layers["base"], "Decision_Actor")
	var d_own := decide(ent_b["Decision_Actor"], ent_b["Decision_Actor"]["goal_table"],
		_default_opts(), row_a)
	var d_swapped := decide(ent_b["Decision_Actor"], ent_b["Second_Actor"]["goal_table"],
		_default_opts(), row_a)
	print("   own-goals => %s | swapped-goals => %s" % [d_own["decision"], d_swapped["decision"]])
	_check("P1 same inputs + swapped goals => different decision",
		String(d_own["decision"]) != String(d_swapped["decision"]), "")

	# ---------- P2 Relevance Dependence ----------
	print("")
	print("-- P2: Relevance Dependence (fact change crosses preference boundary)")
	var s_base := float(layers["base"]["supply"]["Decision_Actor"]["Maker_Prime"])
	var s_fact := float(layers["v_fact_change"]["supply"]["Decision_Actor"]["Maker_Prime"])
	print("   rel_supply(A->Maker) base=%.10f fact=%.10f" % [s_base, s_fact])
	_check("P2a fact change drops rel_supply STRICTLY", s_fact < s_base, "")
	var d_pb := decide(ent_b["Decision_Actor"], ent_b["Decision_Actor"]["goal_table"],
		_default_opts(), row_a)
	var row_pf := _rel_row(layers["v_fact_change"], "Decision_Actor")
	var ent_f: Dictionary = worlds["v_fact_change"]["entities"]
	var d_pf := decide(ent_f["Decision_Actor"], ent_f["Decision_Actor"]["goal_table"],
		_default_opts(), row_pf)
	var m_base := absf(float(d_pb["scores"]["opt_secure"]["final"]) - float(d_pb["scores"]["opt_disengage"]["final"]))
	var m_fact := absf(float(d_pf["scores"]["opt_secure"]["final"]) - float(d_pf["scores"]["opt_disengage"]["final"]))
	print("   base => %s (margin %.6f) | fact => %s (margin %.6f)"
		% [d_pb["decision"], m_base, d_pf["decision"], m_fact])
	_check("P2b decision flips secure->disengage on fact change",
		String(d_pb["decision"]) == "opt_secure" and String(d_pf["decision"]) == "opt_disengage", "")
	_check("P2c preference margin > 0.01 in BOTH states", m_base > 0.01 and m_fact > 0.01,
		"%.6f / %.6f" % [m_base, m_fact])

	# ---------- P3 Capability Constraint ----------
	print("")
	print("-- P3: Capability Constraint (goal cannot conjure capability)")
	var gate_goals := {"gate_leverage": {"channels": ["access"], "weight": 1.0}}
	var d_capped := decide(ent_b["Decision_Actor"], gate_goals, _default_opts(), row_a)
	var elig_capped: bool = bool(d_capped["scores"]["opt_gate_play"]["eligible"])
	print("   limited-actor + max gate goal => %s (gate_play eligible=%s)"
		% [d_capped["decision"], elig_capped])
	_check("P3a gated option ineligible + never chosen despite maximal pull",
		not elig_capped and String(d_capped["decision"]) != "opt_gate_play", "")
	var ent_cf: Dictionary = worlds["v_capped_full"]["entities"]
	var row_cf := _rel_row(layers["v_capped_full"], "Decision_Actor")
	var d_full := decide(ent_cf["Decision_Actor"], gate_goals, _default_opts(), row_cf)
	print("   full-actor + same goals => %s (eligible=%s)"
		% [d_full["decision"], d_full["scores"]["opt_gate_play"]["eligible"]])
	_check("P3b negative-control: capability is the ONLY blocker (full class may choose it)",
		bool(d_full["scores"]["opt_gate_play"]["eligible"]) and String(d_full["decision"]) == "opt_gate_play", "")

	# ---------- P4 Option Sensitivity ----------
	print("")
	print("-- P4: Option Sensitivity (new better option captures decision)")
	var opts_plus := _default_opts()
	opts_plus.append(_find_option("opt_dominant"))
	var d_add := decide(ent_b["Decision_Actor"], ent_b["Decision_Actor"]["goal_table"],
		opts_plus, row_a)
	var f_dom := float(d_add["scores"]["opt_dominant"]["final"])
	var f_sec := float(d_add["scores"]["opt_secure"]["final"])
	print("   with opt_dominant => %s (dominant=%.10f secure=%.10f)" % [d_add["decision"], f_dom, f_sec])
	_check("P4a decision moves to newly added superior option",
		String(d_add["decision"]) == "opt_dominant", "")
	_check("P4b added option never worse than incumbent", f_dom >= f_sec, "")

	# ---------- P5 Identity Blindness ----------
	print("")
	print("-- P5: Identity Blindness (rename everything semantic-preserving)")
	var inv := _inverse_map(RENAME_MAP)
	var ren_dec_a := _decide_renamed(layers["v_renamed"], worlds["v_renamed"], "Act_One",
		worlds["base"]["entities"]["Decision_Actor"]["goal_table"])
	var ren_dec_s := _decide_renamed(layers["v_renamed"], worlds["v_renamed"], "Act_Two",
		worlds["base"]["entities"]["Second_Actor"]["goal_table"])
	print("   renamed roles => Act_One:%s Act_Two:%s (base: %s / %s)"
		% [ren_dec_a["decision"], ren_dec_s["decision"], d_own["decision"],
		decide(ent_b["Second_Actor"], ent_b["Second_Actor"]["goal_table"],
			_default_opts(), _rel_row(layers["base"], "Second_Actor"))["decision"]])
	_check("P5a renamed entities yield identical role decisions",
		String(ren_dec_a["decision"]) == String(d_own["decision"])
		and String(ren_dec_s["decision"]) == _decide_role_second(ent_b, layers["base"]), "")
	var mat_diffs := _diff_layers_mapped(layers["base"], layers["v_renamed"], inv)
	_check("P5b renamed relevance matrices == base after inverse key mapping",
		mat_diffs.is_empty(), str(mat_diffs))

	# ---------- P6 Read-only ----------
	print("")
	print("-- P6: Read-only Inputs (world + relevance untouched bitwise)")
	var snap_world_pre := _canonical(worlds["base"])
	var snap_layers_pre := _canonical(_strip_diag(layers["base"]))
	var _sink1 := decide(ent_b["Decision_Actor"], ent_b["Decision_Actor"]["goal_table"],
		_default_opts(), row_a)
	var _sink2 := decide(ent_b["Decision_Actor"], ent_b["Second_Actor"]["goal_table"],
		_default_opts(), row_a)
	var snap_world_post := _canonical(worlds["base"])
	var snap_layers_post := _canonical(_strip_diag(layers["base"]))
	_check("P6a world object bitwise unchanged by decision computation",
		snap_world_pre == snap_world_post, "")
	var layers_recomputed := _layers(worlds["base"])
	_check("P6b freshly recomputed relevance bitwise identical after decisions",
		_canonical(_strip_diag(layers_recomputed)) == snap_layers_post
		and _canonical(_strip_diag(layers_recomputed)) == snap_layers_pre, "")

	# ---------- P7 Determinism ----------
	print("")
	print("-- P7: Determinism (independent reload, same inputs)")
	var w2 := _load_world_variant("base")
	var l2 := _layers(w2)
	var e2: Dictionary = w2["entities"]
	var d2a := decide(e2["Decision_Actor"], e2["Decision_Actor"]["goal_table"],
		_default_opts(), _rel_row(l2, "Decision_Actor"))
	var d2s := decide(e2["Second_Actor"], e2["Second_Actor"]["goal_table"],
		_default_opts(), _rel_row(l2, "Second_Actor"))
	var det := _canonical(_strip_diag(l2)) == _canonical(_strip_diag(layers["base"])) \
		and String(d2a["decision"]) == String(d_own["decision"]) \
		and String(d2s["decision"]) == _decide_role_second(ent_b, layers["base"])
	_check("P7 independent reload => bitwise matrices + identical decisions", det, "")

	# ---------- Joint laws per state ----------
	print("")
	print("-- J: Laws per state")
	for st in ["base", "v_goal_swap", "v_fact_change", "v_capped_actor",
			"v_capped_full", "v_option_add", "v_renamed"]:
		_l2_l3_for_state(layers[st], st)

	print("")
	_m("REACHED QUIT")
	print("============================================================")
	if fail_count == 0:
		print("  D1 RESULT: PASS (%d checks)" % pass_count)
	else:
		print("  D1 RESULT: FAIL (%d passed, %d failed)" % [pass_count, fail_count])
	print("============================================================")
	quit(1 if fail_count > 0 else 0)


# ---------------- decide(): reference-only decision layer ----------------

func decide(actor_facts: Dictionary, goal_table: Dictionary, options: Array,
		rel_row: Dictionary) -> Dictionary:
	var scores := {}
	var best_id := ""
	var best_final := -INF
	for opt in options:
		var oid := String(opt["option_id"])
		var eligible := _is_eligible(opt, actor_facts)
		var raw := 0.0
		if eligible:
			raw = _raw_score(opt, rel_row)
		var parts := _goal_boosts(goal_table, opt)
		var fin := raw * float(parts["channeled"]) + float(parts["empty"])
		scores[oid] = {"raw": raw, "boost_channeled": parts["channeled"],
			"boost_empty": parts["empty"], "final": fin, "eligible": eligible}
		if eligible and (fin > best_final or (fin == best_final and oid < best_id)):
			best_final = fin
			best_id = oid
	return {"decision": best_id, "scores": scores}


func _is_eligible(opt: Dictionary, actor_facts: Dictionary) -> bool:
	if not opt.has("requires"):
		return true
	for k in (opt["requires"] as Dictionary).keys():
		if String(actor_facts.get(k, "")) != String((opt["requires"] as Dictionary)[k]):
			return false
	return true


func _raw_score(opt: Dictionary, rel_row: Dictionary) -> float:
	var total := 0.0
	var target := ""
	if opt.has("target_ref"):
		target = String(opt["target_ref"])
	for ch in (opt["channels"] as Array):
		var chname := String(ch)
		if rel_row.has(chname) and (rel_row[chname] as Dictionary).has(target):
			total += float(rel_row[chname][target])
	return total


func _goal_boosts(goal_table: Dictionary, opt: Dictionary) -> Dictionary:
	var och: Array = opt.get("channels", [])
	var channeled := 0.0
	var empty := 0.0
	for gname in goal_table.keys():
		var g: Dictionary = goal_table[gname]
		var gch: Array = g.get("channels", [])
		var w := float(g.get("weight", 0.0))
		if gch.is_empty():
			if och.is_empty():
				empty += w
		else:
			for c in gch:
				if c in och:
					channeled += w
					break
	return {"channeled": channeled, "empty": empty}


# ---------------- harness plumbing ----------------

func _load_options() -> Array:
	if not FileAccess.file_exists(OPTIONS_PATH):
		return []
	var f := FileAccess.open(OPTIONS_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has("options"):
		return []
	var out: Array = []
	for o in (parsed as Dictionary)["options"]:
		if bool(o.get("available_by_default", true)):
			out.append(o)
	return out


func _default_opts() -> Array:
	var out: Array = []
	for o in base_options:
		out.append(o)
	return out


func _find_option(oid: String) -> Dictionary:
	var f := FileAccess.open(OPTIONS_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	for o in (parsed as Dictionary)["options"]:
		if String(o["option_id"]) == oid:
			return o
	return {}


func _load_world_variant(st: String) -> Dictionary:
	if not FileAccess.file_exists(WORLD_PATH):
		return {}
	var f := FileAccess.open(WORLD_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var w: Dictionary = parsed.duplicate(true)
	match st:
		"v_goal_swap":
			var ga: Dictionary = w["entities"]["Decision_Actor"]["goal_table"]
			var gb: Dictionary = w["entities"]["Second_Actor"]["goal_table"]
			w["entities"]["Decision_Actor"]["goal_table"] = gb
			w["entities"]["Second_Actor"]["goal_table"] = ga
		"v_fact_change":
			w["entities"]["Maker_Prime"]["produces"]["EUV_flow"] = 0.02
		"v_capped_actor":
			w["entities"]["Decision_Actor"]["goal_table"] = {
				"gate_leverage": {"channels": ["access"], "weight": 1.0}
			}
		"v_capped_full":
			w["entities"]["Decision_Actor"]["projection_class"] = "full"
			w["entities"]["Decision_Actor"]["goal_table"] = {
				"gate_leverage": {"channels": ["access"], "weight": 1.0}
			}
		"v_option_add":
			pass
		"v_renamed":
			w = _rename_world(w)
	return w


func _rename_world(w: Dictionary) -> Dictionary:
	var out := {"world_id": w["world_id"], "description": w["description"],
		"capabilities_declared": w["capabilities_declared"], "enables": {}, "entities": {}}
	for ename in (w["entities"] as Dictionary).keys():
		var e: Dictionary = (w["entities"] as Dictionary)[ename].duplicate(true)
		if e.has("relations"):
			var rel := {}
			for rk in (e["relations"] as Dictionary).keys():
				rel[String(RENAME_MAP.get(rk, rk))] = e["relations"][rk]
			e["relations"] = rel
		if e.has("authority"):
			var auth: Array = []
			for a in e["authority"]:
				var ad: Dictionary = a.duplicate(true)
				ad["to"] = String(RENAME_MAP.get(ad["to"], ad["to"]))
				auth.append(ad)
			e["authority"] = auth
		out["entities"][String(RENAME_MAP.get(ename, ename))] = e
	return out


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


func _rel_row(layered: Dictionary, actor: String) -> Dictionary:
	return {"rel_supply": layered["supply"][actor], "access": layered["access"][actor]}


func _decide_role_second(ent: Dictionary, layered: Dictionary) -> String:
	var d := decide(ent["Second_Actor"], ent["Second_Actor"]["goal_table"],
		_default_opts(), _rel_row(layered, "Second_Actor"))
	return String(d["decision"])


func _renamed_opts_for(role_new: String) -> Array:
	var src := "Decision_Actor" if role_new == "Act_One" else "Second_Actor"
	var out: Array = []
	for o in base_options:
		var c: Dictionary = o.duplicate(true)
		if c.has("target_ref"):
			c["target_ref"] = String(RENAME_MAP.get(c["target_ref"], c["target_ref"]))
		out.append(c)
	return out


func _decide_renamed(layered: Dictionary, world: Dictionary, actor_new: String,
	orig_goals: Dictionary) -> Dictionary:
	var goals := orig_goals.duplicate(true)
	return decide(world["entities"][actor_new], goals, _renamed_opts_for(actor_new),
		_rel_row(layered, actor_new))


func _diff_layers(la: Dictionary, lb: Dictionary) -> Array:
	return _diff_cells(la, lb, "")


func _diff_cells(la: Dictionary, lb: Dictionary, prefix_map: String) -> Array:
	var diffs: Array = []
	for layer in ["supply", "access"]:
		var ma: Dictionary = la[layer]
		var mb: Dictionary = lb[layer]
		for o in ma.keys():
			var ob := String(o)
			if prefix_map != "":
				ob = prefix_map + String(o)
			if not mb.has(ob):
				diffs.append("%s/%s row-missing" % [layer, o])
				continue
			for t in ma[o].keys():
				var tb := String(t)
				if prefix_map != "":
					tb = prefix_map + String(t)
				if not (mb[ob] as Dictionary).has(tb):
					diffs.append("%s %s->%s cell-missing" % [layer, o, t])
					continue
				if float(ma[o][t]) != float(mb[ob][tb]):
					diffs.append("%s %s->%s" % [layer, o, t])
	var ca := JSON.stringify(_sort_rec(_strip_diag(la["chains"])))
	var cb := JSON.stringify(_sort_rec(_strip_diag(lb["chains"])))
	if ca != cb and prefix_map == "":
		diffs.append("chains")
	return diffs


func _diff_layers_mapped(base_l: Dictionary, renamed_l: Dictionary, inv: Dictionary) -> Array:
	var mapped := {
		"supply": _remap_matrix_keys(renamed_l["supply"], inv),
		"access": _remap_matrix_keys(renamed_l["access"], inv),
		"chains": _remap_deep(renamed_l["chains"], inv)
	}
	return _diff_cells(base_l, mapped, "")


func _remap_matrix_keys(m: Dictionary, inv: Dictionary) -> Dictionary:
	var out := {}
	for o in m.keys():
		var row := {}
		for t in m[o].keys():
			row[String(inv.get(t, t))] = m[o][t]
		out[String(inv.get(o, o))] = row
	return out


func _remap_deep(v, inv: Dictionary):
	if v is Dictionary:
		var o := {}
		for k in (v as Dictionary).keys():
			o[String(inv.get(k, k))] = _remap_deep(v[k], inv)
		return o
	if v is Array:
		var a: Array = []
		for item in v:
			a.append(_remap_deep(item, inv))
		return a
	if v is String:
		return String(inv.get(v, v))
	return v


func _inverse_map(m: Dictionary) -> Dictionary:
	var out := {}
	for k in m.keys():
		out[m[k]] = k
	return out


func _l2_l3_for_state(layered: Dictionary, tag: String) -> void:
	var agg_found := false
	for g in (layered["chains"]["gates"] as Dictionary).keys():
		for k in ((layered["chains"]["gates"][g] as Dictionary)).keys():
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
	for g in (layered["chains"]["gates"] as Dictionary).keys():
		var gd: Dictionary = layered["chains"]["gates"][g]
		for h in (gd["holders"] as Dictionary).values():
			if typeof(h) != TYPE_FLOAT:
				all_floats = false
		for c in (gd["controllers"] as Dictionary).values():
			if typeof(c) != TYPE_FLOAT:
				all_floats = false
	_check("%s L3-joint: all emitted derived values bare floats" % tag, all_floats, "")


func _strip_diag(v):
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
