extends SceneTree

const RS := preload("res://scripts/relevance_supply.gd")
const RC := preload("res://scripts/relevance_control.gd")

func _load(p: String) -> Dictionary:
	var f := FileAccess.open(p, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func _layers(world: Dictionary, cfg: Dictionary) -> Dictionary:
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


func _diff(tag: String, ma: Dictionary, mb: Dictionary) -> void:
	print("--- %s ---" % tag)
	for o in ma.keys():
		if not mb.has(o):
			print("  [row-only-A] ", o)
			continue
		for t in ma[o].keys():
			if not (mb[o] as Dictionary).has(t):
				print("  [cell-only-A] %s->%s" % [o, t])
				continue
			if float(ma[o][t]) != float(mb[o][t]):
				print("  DIFF %s->%s : %.10f vs %.10f" % [o, t, float(ma[o][t]), float(mb[o][t])])


func _init() -> void:
	var cfg: Dictionary = RS.load_config()
	var w1: Dictionary = _load("res://data/worlds/model_v1/test1p_w1.json")
	var w2: Dictionary = _load("res://data/worlds/model_v1/test1p_w2.json")

	# ===== T3 probe: intent/hostility flip على W1 =====
	var w_flip: Dictionary = w1.duplicate(true)
	(w_flip["entities"]["Washington"] as Dictionary)["stance"] = "coercive"
	(w_flip["entities"]["China_Entity"] as Dictionary)["hostile_relation_with"] = ["Washington"]
	var l_base := _layers(w1, cfg)
	var l_flip := _layers(w_flip, cfg)
	print("===== T3 W1P FLIP DIFFS =====")
	_diff("supply", l_base["supply"], l_flip["supply"])
	_diff("access", l_base["access"], l_flip["access"])
	var cb: Dictionary = RC.control_chains(w1)
	var cf: Dictionary = RC.control_chains(w_flip)
	print("chains equal: ", JSON.stringify(cb["gates"]) == JSON.stringify(cf["gates"]))
	print("cycles B/F sizes: ", (cb["cycles"] as Array).size(), "/", (cf["cycles"] as Array).size())

	# ===== T5b probe: إزالة possession من NL =====
	var w_gc: Dictionary = w1.duplicate(true)
	(w_gc["entities"]["NL_Entity"] as Dictionary).erase("possession")
	var l_gc := _layers(w_gc, cfg)
	print("")
	print("===== T5B GATE-CLOSE SUPPLY DIFFS =====")
	_diff("base", l_base["supply"], l_gc["supply"])

	# ===== T9 probe: لماذا access الصفرية في W2 =====
	print("")
	print("===== T9 W2P ACCESS VALUES =====")
	var l2 := _layers(w2, cfg)
	for o in l2["access"].keys():
		for t in l2["access"][o].keys():
			print("  access(%s->%s)=%.10f" % [o, t, float(l2["access"][o][t])])
	print("gates in w2p output: ", (l2["chains"]["gates"] as Dictionary).keys())

	quit(0)
