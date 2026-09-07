extends RefCounted
class_name PoliticalHandlers

# ============================================================
# POLITICAL HANDLERS - Content layer for political deadlines (TASK-040)
# ------------------------------------------------------------
# Owns PoliticalState and registers daily job to pump deadlines via
# sim.scheduled (A10 integration). No kernel logic here - content only.
# ============================================================

const PS := preload("res://scripts/politics/political_state.gd")
const IR := preload("res://scripts/politics/institutional_rules.gd")
const PA := preload("res://scripts/politics/political_actions.gd")
const PD := preload("res://scripts/politics/political_deadlines.gd")
const CT := preload("res://scripts/compliance/compliance_types.gd")

var _sim: Node
var _state: PoliticalState
var _rules: InstitutionalRules
var _ctx: Dictionary

# T5-P0 counters (additive - measurement only)
var activity_counters := {
	"deadline_pumps": 0, "deadlines_due": 0, "deadlines_activated": 0,
	"deadlines_resolved": 0, "elections_held": 0
}

func setup(p_sim: Node) -> void:
	_sim = p_sim
	_rules = IR.load()
	_load_political_state()
	_init_compliance_context()
	# Register daily job to pump deadlines - goes through sim.scheduled (A10)
	_sim.scheduled.register("__political__", "political_deadline_pump", 1, 0)

func _load_political_state() -> void:
	# Load from data - in production from data/worlds/politics/*.json
	var data_root := ""
	if _sim.has("data_root_override"):
		data_root = _sim.data_root_override
	if data_root.is_empty():
		data_root = "res://data/worlds/politics/t040_world.json"
	var f := FileAccess.open(data_root, FileAccess.READ)
	if f == null:
		# No political data - create empty state (for tests that don't need politics)
		_state = PS.new()
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("PoliticalHandlers: invalid political world data")
		_state = PS.new()
		return
	_state = PS.load_from(parsed)
	# Schedule existing government term expirations
	_schedule_existing_terms()

func _schedule_existing_terms() -> void:
	for gov_id in _state.governments.keys():
		var gov: Dictionary = _state.governments[gov_id]
		var leg_id := String(gov.get("legislature_id", ""))
		if leg_id.is_empty():
			continue
		var lrules: Dictionary = _rules.legislature_rules(leg_id)
		PD.schedule_term_integrated(_sim.scheduled, _state, gov_id, leg_id, lrules, _sim.clock.total_days())

func _init_compliance_context() -> void:
	var cfg_path := "res://data/rules/compliance_config.json"
	var cf := FileAccess.open(cfg_path, FileAccess.READ)
	var config: Dictionary = {}
	if cf != null:
		config = JSON.parse_string(cf.get_as_text())
		cf.close()
	# Entities for simulation - empty by default, populated from world data when needed
	var entities: Dictionary = {}
	_ctx := {
		"rules": _rules,
		"compliance_config": config,
		"compliance_entities": entities
	}

# ---- Scheduled Job: political_deadline_pump ----
# Called daily from sim.scheduled - this is the A10 integration point
func job_political_deadline_pump(_job: Dictionary, _t: int) -> void:
	activity_counters["deadline_pumps"] += 1
	var day: int = _sim.clock.total_days()
	var result := PD.pump_integrated(_sim.scheduled, _state, day, _rules, PA, _ctx)
	activity_counters["deadlines_due"] += int(result["due"])
	activity_counters["deadlines_activated"] += int(result["activated"])
	activity_counters["deadlines_resolved"] += int(result["resolved"])
	# Count executed elections
	for id in _state.deadlines.keys():
		var rec: Dictionary = _state.deadlines[id]
		if String(rec["deadline_type"]) == "election_due" and String(rec["resolution"].get("outcome", "")) == "election_executed":
			activity_counters["elections_held"] += 1

# ---- Event Handlers (placeholder for future political events) ----

func evt_political_deadline_triggered(e: Dictionary, _t: int) -> void:
	# Placeholder for future political events
	pass

# ---- Read-only accessors ----
func get_state() -> PoliticalState:
	return _state

func get_counters() -> Dictionary:
	return activity_counters.duplicate(true)