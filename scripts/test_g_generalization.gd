extends SceneTree

# ============================================================
# TEST G — PLANNING GENERALIZATION / BEHAVIORAL VALIDATION
# وفق التسجيل المسبق المجمد: 22-Generalization-Gate.md rev.2
#
# Planner مرجعي harness-local:
#   DFS عمق 1..N(=3) · ترتيب العقد §7 (option_id تصاعديًا)
#   تقليم فوري عند فشل البوابة · سقف تخزين 64 سلسلة/fixture
#   الاختيار: min(total declared cost) ثم نص السلسلة معجميًا (§7)
#
# G-audit منفذ آليًا: منطقة FIXTURES مفصولة بعلامات، ومنطقة
#   PLANNER-CORE تُفحص آليًا خلوّها من أي action_id خاص بfixture.
# أرشفة إلزامية runNN.log لكل محاولة.
# ============================================================

const GEH := preload("res://scripts/game_event_handlers.gd")
const SELF_PATH := "res://scripts/test_g_generalization.gd"
const DISPATCH_PATH := "res://data/rules/dispatch.json"
const RULES_PATH := "res://data/rules/politics.json"
const N_MAX := 3
const CHAIN_CAP := 64

var pass_count := 0
var fail_count := 0
var dispatch_map: Dictionary = {}
var rules: Dictionary = {}

# BEGIN FIXTURES (doc22 section 3 verbatim - no solutions inside)

func fx1() -> Dictionary:
	return {
		"id": "F1", "world": {"countries": {"D": {"stability": 1.0}}, "provinces": {}, "agents": {}},
		"actions": [
			{"action_id": "MIN_D", "event": "Minister_Died", "source": "D",
				"payload": {}, "cost": 2.0}
		],
		"goal": [{"field": "countries.D.stability", "op": "==", "value": 0.95}],
		"forbidden": [],
		"expect": "PLAN"
	}


func fx2() -> Dictionary:
	return {
		"id": "F2", "world": {"countries": {"B": {"stability": 0.5}}, "provinces": {"P1": {"owner": "B", "damage": 0.0, "supply": 1.0}}, "agents": {}},
		"actions": [
			{"action_id": "RAIL1", "event": "Railway_Damaged", "source": "",
				"payload": {"province": "P1"}, "cost": 1.0,
				"preconds": [{"field": "provinces.P1.damage", "op": "<", "value": 0.4}]},
			{"action_id": "RAIL2", "event": "Railway_Damaged", "source": "",
				"payload": {"province": "P1"}, "cost": 1.0,
				"preconds": [{"field": "provinces.P1.damage", "op": "==", "value": 0.4}]}
		],
		"goal": [{"field": "provinces.P1.damage", "op": "==", "value": 0.8}],
		"forbidden": [], "expect": "PLAN"
	}


func fx3() -> Dictionary:
	return {
		"id": "F3", "world": {"countries": {"B": {"stability": 0.5}}, "provinces": {}, "agents": {}},
		"actions": [
			{"action_id": "COUP_B", "event": "Coup_Attempt", "source": "B",
				"payload": {}, "cost": 1.0,
				"preconds": [{"field": "countries.B.stability", "op": ">=", "value": 0.5}]},
			{"action_id": "MIN_B", "event": "Minister_Died", "source": "B",
				"payload": {}, "cost": 1.0,
				"preconds": [{"field": "countries.B.stability", "op": ">=", "value": 0.28}]}
		],
		"goal": [{"field": "countries.B.stability", "op": "==", "value": 0.25}],
		"forbidden": [], "expect": "PLAN", "trap": true
	}


func fx4() -> Dictionary:
	return {
		"id": "F4", "world": {"countries": {"B": {"stability": 0.5}}, "provinces": {"P1": {"owner": "B", "damage": 0.0, "supply": 1.0}}, "agents": {}},
		"actions": [
			{"action_id": "RAIL_F4", "event": "Railway_Damaged", "source": "",
				"payload": {"province": "P1"}, "cost": 1.0,
				"preconds": [{"field": "provinces.P1.damage", "op": "<=", "value": 0.8}]},
			{"action_id": "DECOY_COUP_B", "event": "Coup_Attempt", "source": "B",
				"payload": {}, "cost": 0.0}
		],
		"goal": [{"field": "provinces.P1.damage", "op": "==", "value": 0.8}],
		"forbidden": [{"field": "countries.B.stability", "op": "<", "value": 0.44}],
		"expect": "PLAN", "active_constraint": true
	}


func fx5() -> Dictionary:
	return {
		"id": "F5", "world": {"countries": {"B": {"stability": 0.5}}, "provinces": {"P1": {"owner": "B", "damage": 0.0, "supply": 1.0}, "P2": {"owner": "B", "damage": 0.0, "supply": 1.0}}, "agents": {}},
		"actions": [
			{"action_id": "RAIL_P1", "event": "Railway_Damaged", "source": "",
				"payload": {"province": "P1"}, "cost": 1.0,
				"preconds": [{"field": "provinces.P1.damage", "op": "<=", "value": 0.4}]},
			{"action_id": "RAIL_P2", "event": "Railway_Damaged", "source": "",
				"payload": {"province": "P2"}, "cost": 1.0,
				"preconds": [{"field": "provinces.P1.damage", "op": ">=", "value": 0.4}]}
		],
		"goal": [
			{"field": "provinces.P1.damage", "op": "==", "value": 0.8},
			{"field": "provinces.P2.damage", "op": "==", "value": 0.4}
		],
		"forbidden": [], "expect": "PLAN"
	}


func fx6() -> Dictionary:
	var f := fx2()
	f["id"] = "F6"
	for a in f["actions"]:
		if String(a["action_id"]) == "RAIL2":
			a["action_id"] = "RAIL2X"
			a["cost"] = 7.0
	var dup := (f["actions"][1] as Dictionary).duplicate(true)
	dup["action_id"] = "RAIL2"
	dup["cost"] = 1.0
	f["actions"].append(dup)
	return f


func fx7() -> Dictionary:
	return {
		"id": "F7", "world": {"countries": {"B": {"stability": 0.52}}, "provinces": {"P1": {"owner": "B", "damage": 0.0, "supply": 1.0}}, "agents": {}},
		"actions": [
			{"action_id": "RAIL", "event": "Railway_Damaged", "source": "",
				"payload": {"province": "P1"}, "cost": 1.0,
				"preconds": [{"field": "provinces.P1.damage", "op": "<=", "value": 0.8}]}
		],
		"goal": [{"field": "countries.B.stability", "op": "==", "value": 0.48}],
		"forbidden": [], "expect": "PLAN"
	}


func fx8() -> Dictionary:
	var f := fx2()
	f["id"] = "F8"
	f["goal"] = [{"field": "provinces.P1.damage", "op": "==", "value": 0.4}]
	return f


func fx9() -> Dictionary:
	return {
		"id": "F9", "world": {"countries": {"C": {"stability": 0.9}}, "provinces": {}, "agents": {}},
		"actions": [
			{"action_id": "COUP_C", "event": "Coup_Attempt", "source": "C",
				"payload": {}, "cost": 1.0},
			{"action_id": "MIN_C", "event": "Minister_Died", "source": "C",
				"payload": {}, "cost": 1.0}
		],
		"goal": [{"field": "countries.C.stability", "op": "==", "value": 0.55}],
		"forbidden": [], "expect": "NO-PLAN"
	}

# END FIXTURES


# ---------------- BEGIN PLANNER CORE ----------------

class WorldStub:
	var countries: Dictionary = {}
	var provinces: Dictionary = {}
	var agents: Dictionary = {}
	func related_entities(_id: String) -> Array:
		return []


class ActivationStub:
	var log: Array = []
	func activate(id: String, reason: String) -> void:
		log.append({"id": id, "reason": reason})


class EventQueueStub:
	var items: Array = []
	func push_event(t: int, type: String, source: String, payload: Dictionary) -> void:
		items.append({"t": t, "type": type, "source": source, "payload": payload})


class HypoSim:
	extends Node
	var rules: Dictionary = {}
	var world: WorldStub
	var events: EventQueueStub
	var activation: ActivationStub
	var exposure_propagation_count: int = 0
	var coup_evaluations_count: int = 0
	var operation_evaluations_count: int = 0
	var hypothetical: bool = true


var handlers: GEH
var hypo_sim: HypoSim


func setup_replay(base: WorldStub) -> void:
	hypo_sim = HypoSim.new()
	hypo_sim.rules = rules
	var w := WorldStub.new()
	w.countries = base.countries.duplicate(true)
	w.provinces = base.provinces.duplicate(true)
	w.agents = base.agents.duplicate(true)
	hypo_sim.world = w
	hypo_sim.events = EventQueueStub.new()
	hypo_sim.activation = ActivationStub.new()
	handlers = GEH.new()
	handlers.setup(hypo_sim)


func apply_action(act: Dictionary) -> void:
	var ev := String(act["event"])
	var fn := String(dispatch_map.get(ev, ""))
	var e := {"type": ev, "source": String(act.get("source", "")),
		"payload": act.get("payload", {})}
	handlers.call(fn, e, 0)


func step_predict(base: WorldStub, act: Dictionary) -> WorldStub:
	setup_replay(base)
	apply_action(act)
	return hypo_sim.world


func view_of(w: WorldStub) -> Dictionary:
	var facts := {}
	for section in ["countries", "provinces", "agents"]:
		var sec: Dictionary = w.get(section)
		for ename in sec.keys():
			for key in (sec[ename] as Dictionary).keys():
				facts[section + "." + String(ename) + "." + String(key)] \
					= sec[ename][key]
	return {"facts": facts}


func fact_value(path: String, view: Dictionary) -> float:
	return float(view["facts"].get(path, 0.0))


func cond_ok(c: Dictionary, view: Dictionary) -> bool:
	var v := fact_value(String(c["field"]), view)
	var target := float(c["value"])
	match String(c["op"]):
		"<":
			return v < target
		"<=":
			return v <= target
		">":
			return v > target
		">=":
			return v >= target
		_:
			return v == target


func satisfies(view: Dictionary, goal: Array, forbidden: Array) -> bool:
	for g in goal:
		if not cond_ok(g, view):
			return false
	for f in forbidden:
		if cond_ok(f, view):
			return false
	return true



func sectionalize(world_def: Dictionary) -> Dictionary:
	var out := {"countries": {}, "provinces": {}, "agents": {}}
	for k in world_def.keys():
		var key := String(k)
		if key in ["countries", "provinces", "agents"]:
			out[key] = (world_def[k] as Dictionary).duplicate(true)
		else:
			out["countries"][key] = (world_def[k] as Dictionary).duplicate(true)
	return out

var enum_count := 0
var bait_hits := 0


func plan(fixture: Dictionary, max_depth_override: int = N_MAX) -> Dictionary:
	var world_stub := WorldStub.new()
	var sec := sectionalize(fixture["world"])
	world_stub.countries = sec["countries"]
	world_stub.provinces = sec["provinces"]
	world_stub.agents = sec["agents"]
	var actions: Array = fixture["actions"]
	var goal: Array = fixture["goal"]
	var forbidden: Array = fixture["forbidden"]
	enum_count = 0
	bait_hits = 0
	var satisfiers: Array = []

	for depth in range(1, max_depth_override + 1):
		_dfs(world_stub, actions, goal, forbidden, depth,
			[], [], 0.0, satisfiers)
		# لا إنهاء مبكر: عدّاد الطُعم (bait) يحتاج مسح كل الأعماق المجمدة

	if satisfiers.is_empty():
		return {"status": "NO-PLAN", "enum_count": enum_count,
			"bait_hits": bait_hits}

	var best: Dictionary = satisfiers[0]
	for s in satisfiers:
		var sd: Dictionary = s
		if float(sd["cost"]) < float(best["cost"]) \
				or (float(sd["cost"]) == float(best["cost"])
				and String(sd["key"]) < String(best["key"])):
			best = sd
	return {"status": "PLAN", "chain": best["ids"], "cost": best["cost"],
		"view": best["view"], "enum_count": enum_count,
		"satisfier_costs": _satisfier_costs(satisfiers),
		"bait_hits": bait_hits}


func _satisfier_costs(satisfiers: Array) -> Array:
	var out: Array = []
	for s in satisfiers:
		out.append(float((s as Dictionary)["cost"]))
	out.sort()
	return out


func _dfs(cur: WorldStub, actions: Array, goal: Array, forbidden: Array,
		remaining: int, ids: Array, used_actions: Array, cost: float,
		satisfiers: Array) -> void:
	if remaining == 0:
		return
	var ordered: Array = actions.duplicate()
	ordered.sort_custom(func(a, b): return String(a["action_id"]) < String(b["action_id"]))
	for act in ordered:
		var ad: Dictionary = act
		var view_now := view_of(cur)
		var pre_ok := true
		for pc in ad.get("preconds", []):
			if not cond_ok(pc, view_now):
				pre_ok = false
				break
		if not pre_ok:
			continue
		enum_count += 1
		var nxt := step_predict(cur, ad)
		var nview := view_of(nxt)
		var nids: Array = ids.duplicate()
		nids.append(String(ad["action_id"]))
		var nused: Array = used_actions.duplicate()
		nused.append(ad)
		var ncost := cost + float(ad["cost"])
		var key := ">".join(PackedStringArray(nids))
		var has_decoy := false
		for ua in nused:
			if String((ua as Dictionary)["action_id"]).find("DECOY") != -1:
				has_decoy = true
				break
		if has_decoy and satisfies(nview, goal, []):
			bait_hits += 1
		if satisfies(nview, goal, forbidden):
			satisfiers.append({"ids": nids, "key": key, "cost": ncost,
				"view": nview})
		else:
			_dfs(nxt, actions, goal, forbidden, remaining - 1,
				nids, nused, ncost, satisfiers)

# ---------------- END PLANNER CORE ----------------


func replay_validate(fixture: Dictionary, chain_ids: Array) -> Dictionary:
	var world_stub := WorldStub.new()
	var sec := sectionalize(fixture["world"])
	world_stub.countries = sec["countries"]
	world_stub.provinces = sec["provinces"]
	world_stub.agents = sec["agents"]
	var amap := {}
	for a in fixture["actions"]:
		amap[String(a["action_id"])] = a
	var total := 0.0
	for cid in chain_ids:
		var act: Dictionary = amap[String(cid)]
		for pc in act.get("preconds", []):
			if not cond_ok(pc, view_of(world_stub)):
				return {"ok": false, "why": "gate-fail@" + String(cid)}
		world_stub = step_predict(world_stub, act)
		total += float(act["cost"])
	var view := view_of(world_stub)
	return {"ok": satisfies(view, fixture["goal"], fixture["forbidden"]),
		"view": view, "cost": total}


func canon(v) -> String:
	return JSON.stringify(sort_rec(v))


func sort_rec(v):
	if v is Dictionary:
		var keys := (v as Dictionary).keys()
		keys.sort()
		var o := {}
		for k in keys:
			o[k] = sort_rec(v[k])
		return o
	if v is Array:
		var arr: Array = []
		for x in v:
			arr.append(sort_rec(x))
		return arr
	return v


func world_canon(w: WorldStub) -> String:
	return canon({"c": w.countries, "p": w.provinces, "a": w.agents})


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		pass_count += 1
		print("[PASS] %s" % label)
	else:
		fail_count += 1
		print("[FAIL] %s | %s" % [label, detail])


func _init() -> void:
	_m("START")
	print("")
	print("============================================================")
	print("  TEST G - PLANNING GENERALIZATION / BEHAVIORAL VALIDATION")
	print("  Reference planner harness-local | doc22 rev.3 frozen")
	print("============================================================")

	var dd := _read_json(DISPATCH_PATH)
	dispatch_map = dd.get("event_handlers", {})
	rules = _read_json(RULES_PATH)
	if dispatch_map.is_empty() or rules.is_empty():
		print("[FATAL] dispatch/rules missing")
		quit(1)
		return

	var fixtures := [fx1(), fx2(), fx3(), fx4(), fx5(), fx6(), fx7(), fx8(), fx9()]

	var results := {}
	var worlds_snapshot_pre := []

	for fx in fixtures:
		var fxd: Dictionary = fx
		worlds_snapshot_pre.append(canon(fxd))
		results[fxd["id"]] = plan(fxd)

	# ---------- G1..G8 ----------
	print("")
	print("-- G1..G8: per-fixture behavioral validity")
	var idx := 1
	for fx in fixtures:
		var fxd: Dictionary = fx
		var fid := String(fxd["id"])
		var res: Dictionary = results[fid]
		if fid == "F9":
			continue
		var expect_plan: bool = String(fxd["expect"]) == "PLAN"
		var ok: bool = res["status"] == "PLAN" and expect_plan
		var detail := str(res.get("chain", [])) + " cost=" + str(res.get("cost"))
		if ok:
			var rv := replay_validate(fxd, res["chain"])
			ok = bool(rv["ok"])
			detail += " replay=" + str(rv["ok"])
		_check("G%d %s returns a valid minimal-cost plan for structurally-distinct problem" % [idx, fid],
			ok, detail)
		idx += 1

	# ---------- G9 ----------
	print("")
	print("-- G9: unsolvable honesty")
	var r9: Dictionary = results["F9"]
	_check("G9 honestly reports NO-PLAN on unsolvable problem",
		r9["status"] == "NO-PLAN", str(r9["status"]))

	# ---------- G-det ----------
	var det_a := {}
	for fx in fixtures:
		var fxd: Dictionary = fx
		det_a[fxd["id"]] = canon(results[fxd["id"]])
	var det_b := {}
	for fx in fixtures:
		var fxd2: Dictionary = fx
		det_b[fxd2["id"]] = canon(plan(fxd2))
	var det_ok := canon(det_a) == canon(det_b)
	_check("G-det planner is bitwise-deterministic across runs", det_ok,
		"" if det_ok else "mismatch")

	# ---------- G-pure ----------
	var wpure: Dictionary = fx4()["world"]
	var snap := world_canon_of_dict(wpure)
	plan(fx4())
	_check("G-pure planning never mutates the real world",
		snap == world_canon_of_dict(fx4()["world"]), "")

	# ---------- G-audit ----------
	print("")
	print("-- G-audit: solution absence")
	var src := _read_text(SELF_PATH)
	var begin_f := src.find("# BEGIN FIXTURES")
	var end_f := src.find("# END FIXTURES")
	var core := src.substr(src.find("# BEGIN PLANNER CORE"),
		src.find("# END PLANNER CORE") - src.find("# BEGIN PLANNER CORE"))
	var bad_fixture_keys: Array = []
	var fixture_block := src.substr(begin_f, end_f - begin_f)
	var code_only: Array = []
	for ln in fixture_block.split("\n"):
		if not ln.strip_edges().begins_with("#"):
			code_only.append(ln)
	var code_text := "\n".join(PackedStringArray(code_only))
	for word in ["expected", "solution", "plan_"]:
		if code_text.to_lower().find(word) != -1:
			bad_fixture_keys.append(word)
	var leaked: Array = []
	for fx in fixtures:
		var fxd: Dictionary = fx
		for a in fxd["actions"]:
			var aid := String(a["action_id"])
			if core.find(aid) != -1:
				leaked.append(aid)
	_check("G-audit fixtures contain no solutions and planner contains no fixture-specific ids",
		bad_fixture_keys.is_empty() and leaked.is_empty(),
		str(bad_fixture_keys) + str(leaked))

	# ---------- G-greedy ----------
	print("")
	print("-- G-greedy: lookahead differential on trap F3")
	var d1 := plan(fx3(), 1)
	var dfull := plan(fx3(), N_MAX)
	_check("G-greedy depth-1 fails where depth-3 succeeds - lookahead value proven",
		d1["status"] == "NO-PLAN" and dfull["status"] == "PLAN",
		str(d1["status"]) + "/" + str(dfull["status"]))

	# ---------- G-cost ----------
	print("")
	print("-- G-cost: minimum declared cost among satisfiers (F6)")
	var r6: Dictionary = results["F6"]
	_check("G-cost chooses minimum total declared cost among satisfiers",
		String(r6["status"]) == "PLAN" and float(r6["cost"]) == 2.0,
		str(r6.get("cost")))

	# ---------- G-prune ----------
	print("")
	print("-- G-prune: active constraint separates equal-cost satisfiers (F4)")
	var r4: Dictionary = results["F4"]
	var chain_no_decoy := true
	for cid in r4["chain"]:
		if String(cid).find("DECOY") != -1:
			chain_no_decoy = false
	var stab_final := fact_value_path(r4["view"], "countries.B.stability")
	_check("G-prune forbidden-constraint alone separates two equal-cost goal-satisfiers",
		int(r4["bait_hits"]) >= 1 and chain_no_decoy
		and absf(stab_final - 0.46) < 1e-12,
		"bait=%d stab=%.18f" % [int(r4["bait_hits"]), stab_final])

	print("")
	_m("REACHED QUIT")
	print("============================================================")
	if fail_count == 0:
		print("  TEST G RESULT: PASS (%d checks)" % pass_count)
	else:
		print("  TEST G RESULT: FAIL (%d passed, %d failed)" % [pass_count, fail_count])
	print("============================================================")
	quit(1 if fail_count > 0 else 0)


func _strip_views(det: Dictionary) -> Dictionary:
	var o := {}
	for k in det.keys():
		var r: Dictionary = det[k]
		var c := {}
		for kk in r.keys():
			if kk != "view":
				c[kk] = r[kk]
		o[k] = c
	return o


func world_canon_of_dict(world_def: Dictionary) -> String:
	return canon(world_def)


func fact_value_path(view: Dictionary, path: String) -> float:
	return float(view["facts"].get(path, 0.0))


func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _m(tag: String) -> void:
	var f := FileAccess.open("C:/tmp/maestro engine/.ai/evidence/tests/test_g_milestones.log", FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open("C:/tmp/maestro engine/.ai/evidence/tests/test_g_milestones.log", FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line("[%d] %s" % [Time.get_ticks_msec(), tag])
		f.close()
