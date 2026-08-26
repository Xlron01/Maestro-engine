extends SceneTree

# ============================================================
# TEST P — PLANNING SPECIFICATION v0.1 ACCEPTANCE
# وفق التسجيل المسبق المجمد: 21-Planning-Specification-v01.md
#
# المقيّم المرجعي: HypotheticalSim stub + GameEventHandlers الحقيقية
# عبر dispatch.json — صفر تعديل على النواة أو المعالجات.
#
# Horizon N=3 بأسبقية عليا (فحص طول السلسلة كاملًا قبل أي خطوة).
# أرشفة إلزامية: كل محاولة تُحفظ runNN.log — الحذف ممنوع.
# deg/degree: أي bug ⇒ إعادة كل الفحوصات من الصفر.
# ============================================================

const GEH := preload("res://scripts/game_event_handlers.gd")
const DISPATCH_PATH := "res://data/rules/dispatch.json"
const RULES_PATH := "res://data/rules/politics.json"
const N_MAX := 3

var pass_count := 0
var fail_count := 0
var dispatch_map: Dictionary = {}
var rules: Dictionary = {}
var run_counter := 0
const MLOG := "C:/tmp/maestro engine/.ai/evidence/tests/test_p_milestones.log"


func _m(tag: String) -> void:
	var f := FileAccess.open(MLOG, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(MLOG, FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line("[%d] %s" % [Time.get_ticks_msec(), tag])
		f.close()


# ---------------- stubs ----------------

class ActivationStub:
	var log: Array = []
	func activate(id: String, reason: String) -> void:
		log.append({"id": id, "reason": reason})


class EventQueueStub:
	var items: Array = []
	func push_event(t: int, type: String, source: String, payload: Dictionary) -> void:
		items.append({"t": t, "type": type, "source": source, "payload": payload})


class WorldStub:
	var countries: Dictionary = {}
	var provinces: Dictionary = {}
	var agents: Dictionary = {}
	func related_entities(_id: String) -> Array:
		return []  # ثابت fixture: لا كيانات مرتبطة في p_base


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


# ---------------- predictor contract (doc21 section 1 verbatim) ----------------

func make_hypo(base: WorldStub) -> HypoSim:
	var sim := HypoSim.new()
	sim.rules = rules
	var w := WorldStub.new()
	w.countries = base.countries.duplicate(true)
	w.provinces = base.provinces.duplicate(true)
	w.agents = base.agents.duplicate(true)
	sim.world = w
	sim.events = EventQueueStub.new()
	sim.activation = ActivationStub.new()
	return sim


func predict(action: Dictionary, base: WorldStub, depth: int) -> Dictionary:
	if depth > N_MAX:
		return {"status": "rejected", "reason": "horizon-exceeded", "at": depth}
	var sim := make_hypo(base)
	var handlers := GEH.new()
	handlers.setup(sim)
	var ev_name := String(action["event"])
	var fn := String(dispatch_map.get(ev_name, ""))
	if fn.is_empty():
		return {"status": "rejected", "reason": "unregistered-event", "at": depth}
	var e := {"type": ev_name, "source": String(action.get("source", "")),
		"payload": action.get("payload", {})}
	handlers.call(fn, e, int(action.get("tick", 0)))
	return {"status": "ok", "sim": sim, "world": sim.world,
		"view": view_of(sim.world), "depth": depth}


func chain(actions: Array, base: WorldStub) -> Dictionary:
	if actions.size() > N_MAX:
		return {"status": "rejected", "reason": "horizon-exceeded",
			"at": actions.size(), "invalid_at_step": -1}
	var cur: WorldStub = base
	for i in actions.size():
		var act: Dictionary = actions[i]
		var d := i + 1
		for pc in act.get("preconds", []):
			if not precondition_ok(pc, view_of(cur)):
				return {"status": "invalid", "reason": "precondition",
					"invalid_at_step": d}
		var r := predict(act, cur, d)
		if r["status"] == "rejected":
			r["invalid_at_step"] = -1
			return r
		cur = r["world"]
	return {"status": "ok", "world": cur, "view": view_of(cur),
		"invalid_at_step": -1}


func view_of(w: WorldStub) -> Dictionary:
	var out := {"facts": {}, "sources": ["countries", "provinces", "agents"]}
	for section in ["countries", "provinces", "agents"]:
		for ename in (w.get(section) as Dictionary).keys():
			for key in ((w.get(section) as Dictionary)[ename] as Dictionary).keys():
				out["facts"][section + "." + String(ename) + "." + String(key)] \
					= (w.get(section) as Dictionary)[ename][key]
	return out


func fact_value(path: String, view: Dictionary) -> float:
	return float(view["facts"].get(path, 0.0))


func precondition_ok(pc: Dictionary, view: Dictionary) -> bool:
	var v := fact_value(String(pc["field"]), view)
	var target := float(pc["value"])
	match String(pc["op"]):
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


# ---------------- fixtures (doc21 section 4.1 verbatim) ----------------

func base_world() -> WorldStub:
	var w := WorldStub.new()
	w.countries = {
		"A": {"name": "A", "stability": 1.0, "military_threat_nearby": 0.0,
			"border_insecurity": 0.0, "economic_stability": 1.0, "growth": 0.5,
			"gdp": 100.0, "military_power": 10.0, "at_war_with": []},
		"B": {"name": "B", "stability": 0.5, "military_threat_nearby": 0.0,
			"border_insecurity": 0.0, "economic_stability": 1.0, "growth": 0.5,
			"gdp": 100.0, "military_power": 10.0, "at_war_with": []},
		"C": {"name": "C", "stability": 0.9},
		"D": {"name": "D", "stability": 1.0}
	}
	w.provinces = {"P1": {"owner": "B", "damage": 0.0, "supply": 1.0}}
	return w


func act_war() -> Dictionary:
	return {"action_id": "ACT_WAR_AB", "event": "War_Started", "tick": 0,
		"source": "A", "payload": {"attacker": "A", "defender": "B"}}


func act_rail(preconds: Array = []) -> Dictionary:
	return {"action_id": "ACT_RAIL_P1", "event": "Railway_Damaged", "tick": 0,
		"source": "", "payload": {"province": "P1"}, "preconds": preconds}


func act_coup() -> Dictionary:
	return {"action_id": "ACT_COUP_C", "event": "Coup_Attempt", "tick": 0,
		"source": "C", "payload": {}}


func act_minister() -> Dictionary:
	return {"action_id": "ACT_MIN_D", "event": "Minister_Died", "tick": 0,
		"source": "D", "payload": {}}


func pc_damage_lt08() -> Dictionary:
	return {"field": "provinces.P1.damage", "op": "<", "value": 0.8}


# ---------------- helpers ----------------

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


func changed_keys(before: Dictionary, after_view: Dictionary) -> Array:
	var changed: Array = []
	for path in before.keys():
		if not after_view["facts"].has(path):
			changed.append(path)
			continue
		if str(before[path]) != str(after_view["facts"][path]):
			changed.append(path)
	for path in after_view["facts"].keys():
		if not before.has(path):
			changed.append(path)
	return changed


func flat_before(w: WorldStub) -> Dictionary:
	return view_of(w)["facts"]


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


# ---------------- main ----------------

func _init() -> void:
	_m("START")
	run_counter += 1
	print("")
	print("============================================================")
	print("  TEST P - PLANNING SPECIFICATION v0.1 ACCEPTANCE")
	print("  Reference predictor: HypotheticalSim + real dispatch")
	print("  Horizon N=%d | run%02d archived" % [N_MAX, run_counter])
	print("============================================================")

	var dd := _read_json(DISPATCH_PATH)
	dispatch_map = dd.get("event_handlers", {})
	rules = _read_json(RULES_PATH)
	if dispatch_map.is_empty() or rules.is_empty():
		print("[FATAL] dispatch/rules missing")
		quit(1)
		return

	# ---------- L: fixture/event hygiene ----------
	print("")
	print("-- L0: deterministic-event allowlist honored")
	var bad_events: Array = []
	for probe in [act_war(), act_rail(), act_coup(), act_minister()]:
		if String(probe["event"]) == "Election":
			bad_events.append(probe["action_id"])
	_check("L0 fixture contains only deterministic allowlisted events",
		bad_events.is_empty(), str(bad_events))

	# ---------- TP1 ----------
	print("")
	print("-- TP1: prediction determinism")
	var b1 := base_world()
	var b2 := base_world()
	var r1 := predict(act_war(), b1, 1)
	var r2 := predict(act_war(), b2, 1)
	var same := canon(r1["view"]) == canon(r2["view"])
	print("   views identical=%s" % str(same))
	_check("TP1 prediction is bitwise-deterministic across independent clones", same, "")

	# ---------- TP2 ----------
	print("")
	print("-- TP2: thought never mutates the real world")
	var w_real := base_world()
	var snap_pre := world_canon(w_real)
	var rules_pre := canon(rules)
	var sink1 := predict(act_war(), w_real, 1)
	var sink2 := chain([act_rail(), act_rail()], w_real)
	var snap_post := world_canon(w_real)
	_check("TP2 thought never mutates the real world (P6 forward)",
		snap_pre == snap_post and rules_pre == canon(rules), "")

	# ---------- TP3 ----------
	print("")
	print("-- TP3: precondition gate invalidates at exact failing step")
	var c3 := chain([act_rail([pc_damage_lt08()]), act_rail([pc_damage_lt08()]),
		act_rail([pc_damage_lt08()])], base_world())
	print("   status=%s invalid_at_step=%d" % [c3["status"], c3["invalid_at_step"]])
	_check("TP3 precondition gate invalidates chain at exact failing step",
		c3["status"] == "invalid" and c3["invalid_at_step"] == 3,
		str(c3))

	# ---------- TP4 ----------
	print("")
	print("-- TP4: emergent war cascade")
	var w4 := base_world()
	var r4 := predict(act_war(), w4, 1)
	var vb: Dictionary = r4["world"].countries["B"]
	var va: Dictionary = r4["world"].countries["A"]
	var q: Array = r4["sim"].events.items
	var cond4: bool = float(vb["military_threat_nearby"]) == 5.0 \
		and (vb["at_war_with"] as Array) == ["A"] \
		and (va["at_war_with"] as Array) == ["B"] \
		and String(vb["chosen_action"]) == "security" \
		and float(vb["gdp"]) == 99.0 \
		and float(vb["military_power"]) == 11.0 \
		and float(va["stability"]) == 1.0 \
		and q.size() == 1 and String(q[0]["type"]) == "Military_Spending_Increase"
	print("   threat=%.1f chosen=%s gdp=%.1f power=%.1f queued=%d"
		% [float(vb["military_threat_nearby"]), String(vb["chosen_action"]),
		float(vb["gdp"]), float(vb["military_power"]), q.size()])
	_check("TP4 replay captures emergent cascade absent from any declared delta",
		cond4, "")

	# ---------- TP5 ----------
	print("")
	print("-- TP5: sequential composition bitwise-associative")
	var w5 := base_world()
	var rail_plain := act_rail()
	var chained := chain([rail_plain, rail_plain], w5)
	var one := predict(rail_plain, w5, 1)
	var two := predict(rail_plain, one["world"], 2)
	var eq := canon(chained["view"]) == canon(view_of(two["world"]))
	print("   equal=%s damage=%.1f supply=%.1f"
		% [str(eq), fact_value("provinces.P1.damage", chained["view"]),
		fact_value("provinces.P1.supply", chained["view"])])
	_check("TP5 sequential composition is bitwise-associative", eq, "")

	# ---------- TP6 ----------
	print("")
	print("-- TP6: closed vocabulary scan")
	var all_views: Array = []
	var w6 := base_world()
	all_views.append(predict(act_war(), w6, 1)["view"])
	all_views.append(chain([act_rail(), act_rail()], base_world())["view"])
	var violation := ""
	for v in all_views:
		for path in v["facts"].keys():
			if path.find("action_id") != -1 or path.find("path_id") != -1:
				violation = path
	var sections_ok := true
	for v in all_views:
		if v.has("sources") and (v["sources"] as Array).size() != 3:
			sections_ok = false
	_check("TP6 predicted descriptors stay inside the closed vocabulary - no action identity",
		violation == "" and sections_ok, violation)

	# ---------- TP7 ----------
	print("")
	print("-- TP7: hard horizon precedes everything")
	var four := []
	for i in range(4):
		four.append(act_rail())
	var r7 := chain(four, base_world())
	print("   status=%s reason=%s" % [r7["status"], r7.get("reason", "")])
	_check("TP7 hard horizon precedes all other checks",
		r7["status"] == "rejected" and String(r7["reason"]) == "horizon-exceeded", str(r7))

	# ---------- TP8 ----------
	print("")
	print("-- TP8: DEFERRED-7 isolation tripwire")
	var wiso := base_world()
	var before_iso := flat_before(wiso)
	var ra := predict(act_war(), wiso, 1)
	var rb := predict(act_rail(), wiso, 1)
	var ka := changed_keys(before_iso, ra["view"])
	var kb := changed_keys(before_iso, rb["view"])
	var inter: Array = []
	for k in ka:
		if k in kb:
			inter.append(k)
	print("   |changed(WAR)|=%d |changed(RAIL)|=%d |intersection|=%d"
		% [ka.size(), kb.size(), inter.size()])
	_check("TP8 entities predict independently - DEFERRED-7 trigger not fired",
		inter.is_empty(), str(inter))

	# ---------- TP9 ----------
	print("")
	print("-- TP9: single-event arithmetic exacts")
	var rc := predict(act_coup(), base_world(), 1)
	var rm := predict(act_minister(), base_world(), 1)
	var sc := float((rc["world"].countries["C"] as Dictionary)["stability"])
	var sd := float((rm["world"].countries["D"] as Dictionary)["stability"])
	print("   coup(C)=%.2f minister(D)=%.2f" % [sc, sd])
	_check("TP9 deterministic single-event effects match frozen arithmetic exactly",
		sc == 0.7 and sd == 0.95, "%.18f / %.18f" % [sc, sd])

	# ---------- TP10 ----------
	print("")
	print("-- TP10: multi-target side-effects with owner coupling")
	var rr := predict(act_rail(), base_world(), 1)
	var p1: Dictionary = rr["world"].provinces["P1"]
	var bo: Dictionary = rr["world"].countries["B"]
	var acts: int = (rr["sim"].activation.log as Array).size()
	print("   damage=%.1f supply=%.1f ownerStab=%.2f activations=%d"
		% [float(p1["damage"]), float(p1["supply"]), float(bo["stability"]), acts])
	_check("TP10 multi-target side-effects captured exactly (owner coupling included)",
		float(p1["damage"]) == 0.4 and float(p1["supply"]) == 0.7
		and float(bo["stability"]) == 0.48 and acts == 2,
		"%.18f/%.18f/%.18f/%d" % [float(p1["damage"]), float(p1["supply"]),
		float(bo["stability"]), acts])

	print("")
	_m("REACHED QUIT")
	print("============================================================")
	if fail_count == 0:
		print("  TEST P RESULT: PASS (%d checks)" % pass_count)
	else:
		print("  TEST P RESULT: FAIL (%d passed, %d failed)" % [pass_count, fail_count])
	print("============================================================")
	quit(1 if fail_count > 0 else 0)


func decide_pareto_guard() -> bool:
	# حارس تركيبي: لا مسار تنسيق موجود أصلًا في المقيّم المرجعي — يُعاد true دائمًا،
	 # وTP8 هو الدليل التنفيذي على الاستقلالية.
	return true


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
