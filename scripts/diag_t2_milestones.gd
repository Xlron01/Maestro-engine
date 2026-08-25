extends SceneTree

const RS := preload("res://scripts/relevance_supply.gd")
const RC := preload("res://scripts/relevance_control.gd")
const WORLD_PATH := "res://data/worlds/model_v1/test2_base.json"
const MLOG := "C:/tmp/maestro engine/.ai/evidence/tests/t2_milestones.log"

var cfg: Dictionary = {}
var worlds := {}
var outputs := {}


func _m(tag: String) -> void:
	var f := FileAccess.open(MLOG, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(MLOG, FileAccess.WRITE)
	f.seek_end()
	f.store_line("[%s] %s" % [Time.get_ticks_msec(), tag])
	f.close()


func _init() -> void:
	_m("START")
	cfg = RS.load_config()
	_m("cfg loaded, empty=" + str(cfg.is_empty()))
	for st in ["base", "v_friendly", "v_hostile", "v_no_intent", "v_goal_swap",
			"v_goal_zero_rel", "pc_fact"]:
		_m("building " + st)
		worlds[st] = _load_world_variant(st)
		_m("layers computing " + st)
		outputs[st] = _layers(worlds[st])
		_m("layers done " + st)

	_m("RAW begin")
	for st in ["base", "v_friendly", "v_hostile", "v_no_intent", "v_goal_swap",
			"v_goal_zero_rel", "pc_fact"]:
		_m("raw " + st)
	_m("RAW end")

	_m("VERDICTS begin")
	for st in ["base", "v_friendly", "v_hostile", "v_no_intent", "v_goal_swap",
			"v_goal_zero_rel", "pc_fact"]:
		_l2_l3_for_state(outputs[st]["chains"], outputs[st], st)
		_m("laws done " + st)
	_m("ALL DONE - no hang in phases; hang must be elsewhere/none")


func _load_world_variant(st: String) -> Dictionary:
	var f := FileAccess.open(WORLD_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
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


func _l2_l3_for_state(chains: Dictionary, layered: Dictionary, tag: String) -> void:
	pass
