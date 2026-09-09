extends RefCounted
class_name GameEventHandlers

# ============================================================
# GAME EVENT HANDLERS - Content layer (not kernel)
# ------------------------------------------------------------
# All domain logic for events and scheduled jobs lives here.
# These files are allowed - and required - to carry content names,
# and are linked to the kernel solely via data/rules/dispatch.json (Registry).
# They receive the simulation reference via setup() and read rules from sim.rules.
# No hardcoded numbers outside rules.get here either.
# ============================================================
# ENGINE TOUCH #1 (T3-Phase 1): Economy module delegation.
# ENGINE TOUCH #3 (T3-Phase 2): Economy v2 delegation + Economy_Shortage_Occurred handler.
# ENGINE TOUCH #4 (TASK-040): Political deadline integration (A10).
# ENGINE TOUCH #5 (TASK-040): Fixture-tree political world/rules loading —
#   when data_root_override points at a self-contained scenario tree that has
#   worlds/politics/world.json + rules/institutional_rules.json, load them from
#   the tree (benchmark/fixture injection). Default behaviour unchanged.
# Zero kernel logic here - delegation only.
# ============================================================

# T3-Phase 1 delegation
const EconomyHandlers = preload("res://economy/economy_event_handlers.gd")
var _economy: EconomyHandlers

# T3-Phase 2 delegation - economy v2 (coal, independent instance)
const EconomyV2Handlers = preload("res://economy/economy_v2_handlers.gd")
var _economy_v2: EconomyV2Handlers

# TASK-040 - Political Deadline Integration (A10)
# Political state and deadline pumping integrated directly here
const PS = preload("res://scripts/politics/political_state.gd")
const IR = preload("res://scripts/politics/institutional_rules.gd")
const PA = preload("res://scripts/politics/political_actions.gd")
const PD = preload("res://scripts/politics/political_deadlines.gd")
const CT = preload("res://scripts/compliance/compliance_types.gd")

var _political_state: PS
var _political_rules: IR
var _political_ctx: Dictionary

# Political counters (additive - measurement only)
var political_counters = {
	"deadline_pumps": 0, "deadlines_due": 0, "deadlines_activated": 0,
	"deadlines_resolved": 0, "elections_held": 0
}

var _sim: Node

# T5-P0 counters (additive - measurement only, zero behavioral effect)
var decision_counters = {
	"evaluate_calls": 0, "apply_calls": 0,
	"coup_eval_calls": 0, "total_us": 0
}


func setup(p_sim: Node) -> void:
	_sim = p_sim
	_economy = EconomyHandlers.new()
	_economy.setup(_sim)
	_economy_v2 = EconomyV2Handlers.new()
	_economy_v2.setup(_sim)
	_init_political()


func _init_political() -> void:
	_political_rules = IR.load()
	_load_political_state()
	_init_political_compliance_context()
	# Register daily job to pump deadlines - goes through sim.scheduled (A10)
	_sim.scheduled.register("__political__", "political_deadline_pump", 1, 0)


func _load_political_state() -> void:
	# Load from data - in production from data/worlds/politics/*.json
	# ENGINE TOUCH #5 (TASK-040): fixture-tree injection — if data_root_override
	# points at a scenario tree carrying worlds/politics/world.json, load the
	# political world AND the tree's institutional rules from there.
	var data_root := ""
	if _sim.data_root_override != "":
		data_root = _sim.data_root_override
	var tree_world: String = data_root.path_join("worlds/politics/world.json")
	var tree_rules: String = data_root.path_join("rules/institutional_rules.json")
	if not data_root.is_empty() and FileAccess.file_exists(tree_world):
		var fw := FileAccess.open(tree_world, FileAccess.READ)
		var parsed_w = JSON.parse_string(fw.get_as_text())
		fw.close()
		if typeof(parsed_w) == TYPE_DICTIONARY:
			_political_state = PS.load_from(parsed_w)
			if FileAccess.file_exists(tree_rules):
				var fr := FileAccess.open(tree_rules, FileAccess.READ)
				var parsed_r = JSON.parse_string(fr.get_as_text())
				fr.close()
				if typeof(parsed_r) == TYPE_DICTIONARY:
					_political_rules.raw = parsed_r
			_schedule_existing_political_terms()
			return
		push_error("PoliticalHandlers: invalid fixture political world data")
		_political_state = PS.new()
		return
	if data_root.is_empty():
		data_root = "res://data/worlds/politics/t040_world.json"
	var f = FileAccess.open(data_root, FileAccess.READ)
	if f == null:
		# No political data - create empty state (for tests that don't need politics)
		_political_state = PS.new()
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("PoliticalHandlers: invalid political world data")
		_political_state = PS.new()
		return
	_political_state = PS.load_from(parsed)
	# Schedule existing government term expirations
	_schedule_existing_political_terms()


func _schedule_existing_political_terms() -> void:
	for gov_id in _political_state.governments.keys():
		var gov: Dictionary = _political_state.governments[gov_id]
		var leg_id = String(gov.get("legislature_id", ""))
		if leg_id.is_empty():
			continue
		var lrules: Dictionary = _political_rules.legislature_rules(leg_id)
		PD.schedule_term_integrated(_sim.scheduled, _political_state, gov_id, leg_id, lrules, _sim.clock.total_days())


func _init_political_compliance_context() -> void:
	var cfg_path = "res://data/rules/compliance_config.json"
	var cf = FileAccess.open(cfg_path, FileAccess.READ)
	var config = {}
	if cf != null:
		config = JSON.parse_string(cf.get_as_text())
		cf.close()
	var entities = {}
	_political_ctx = {
		"rules": _political_rules,
		"compliance_config": config,
		"compliance_entities": entities
	}


# ---- Scheduled Job: political_deadline_pump ----
# Called daily from sim.scheduled - this is the A10 integration point
func job_political_deadline_pump(_job: Dictionary, _t: int) -> void:
	political_counters["deadline_pumps"] += 1
	var day = _sim.clock.total_days()
	var result = PD.pump_integrated(_sim.scheduled, _political_state, day, _political_rules, PA, _political_ctx)
	political_counters["deadlines_due"] += int(result["due"])
	political_counters["deadlines_activated"] += int(result["activated"])
	political_counters["deadlines_resolved"] += int(result["resolved"])
	# Count elections executed TODAY (resolution is null while merely
	# scheduled — null-guard required; resolved_at == day makes the
	# counter a true cumulative total, not a daily recount)
	var day_i := int(day)
	for id in _political_state.deadlines.keys():
		var rec: Dictionary = _political_state.deadlines[id]
		var res = rec["resolution"]
		if String(rec["deadline_type"]) == "election_due" and res != null \
				and rec["resolved_at"] != null and int(rec["resolved_at"]) == day_i \
				and String((res as Dictionary).get("outcome", "")) == "election_executed":
			political_counters["elections_held"] += 1


# ---- Event Handlers (placeholder for future political events) ----

func evt_political_deadline_triggered(e: Dictionary, _t: int) -> void:
	# Placeholder for future political events
	pass


# ---- Read-only accessors ----
func get_political_state() -> PS:
	return _political_state

func get_political_counters() -> Dictionary:
	return political_counters.duplicate(true)


# ---------------- Events ----------------

func evt_minister_died(e: Dictionary, _t: int) -> void:
	var source = e["source"]
	if _sim.world.countries.has(source):
		_sim.world.countries[source]["stability"] -= \
			_sim.rules.get("minister_death_stability_loss", 0.05)


func evt_railway_damaged(e: Dictionary, _t: int) -> void:
	var prov_name = e["payload"].get("province", "")
	if _sim.world.provinces.has(prov_name):
		var prov = _sim.world.provinces[prov_name]
		prov["damage"] += _sim.rules.get("railway_damage_amount", 0.4)
		prov["supply"] -= _sim.rules.get("railway_supply_loss", 0.3)
		_sim.activation.activate(prov_name, "damaged_by:" + e["type"])
		var province_owner = prov["owner"]
		if _sim.world.countries.has(province_owner):
			_sim.activation.activate(province_owner, "supply_network_affected")
			_sim.world.countries[province_owner]["stability"] -= \
				_sim.rules.get("railway_stability_loss", 0.02)


func evt_election(e: Dictionary, _t: int) -> void:
	var source = e["source"]
	if _sim.world.countries.has(source):
		var c = _sim.world.countries[source]
		var swing_amount = _sim.rules.get("election_stability_swing", 0.05)
		var swing = _sim.rng.randf_range(-swing_amount, swing_amount)
		c["stability"] = clamp(c["stability"] + swing, 0.0, 1.0)


func evt_war_started(e: Dictionary, t: int) -> void:
	var attacker = e["payload"].get("attacker", "")
	var defender = e["payload"].get("defender", "")
	if _sim.world.countries.has(attacker) and _sim.world.countries.has(defender):
		_sim.world.countries[attacker]["at_war_with"].append(defender)
		_sim.world.countries[defender]["at_war_with"].append(attacker)
		_sim.world.countries[defender]["military_threat_nearby"] += \
			_sim.rules.get("war_threat_increase", 5.0)
		_sim.activation.activate(defender, "war_declared_against_me")
		DecisionSystem.evaluate(_sim.world.countries[defender], _sim.rules)
		var outcome = DecisionSystem.apply_consequence(
			_sim.world.countries[defender], _sim.rules)
		var event_type = "Military_Spending_Increase"
		if outcome["path"] == "prosperity":
			event_type = "Economic_Investment"
		_sim.events.push_event(t, event_type, defender,
			{"type": event_type, "country": outcome["country"]})

		for related in _sim.world.related_entities(defender):
			if related != attacker:
				_sim.activation.activate(related, "relation_to:" + defender)


func evt_noop(_e: Dictionary, _t: int) -> void:
	pass


func evt_coup_attempt(e: Dictionary, _t: int) -> void:
	var source = e["source"]
	if _sim.world.countries.has(source):
		var c = _sim.world.countries[source]
		c["stability"] = clamp(
			c["stability"] - float(_sim.rules.get("coup_attempt_stability_loss", 0.2)),
			0.0, 1.0)


func evt_agent_exposed(e: Dictionary, _t: int) -> void:
	var agency_id = e["payload"].get("agency_id", "")
	var target_country = e["payload"].get("target_country", "")

	if not agency_id.is_empty():
		_sim.activation.activate(agency_id, "agency:agent_exposed")
		_sim.exposure_propagation_count += 1

	if _sim.world.countries.has(target_country):
		_sim.activation.activate(target_country, "counter_intel:agent_exposed")
		_sim.world.countries[target_country]["stability"] -= \
			float(_sim.rules.get("agent_exposure_stability_penalty", 0.03))
		_sim.exposure_propagation_count += 1


# ---------------- Scheduled Jobs ----------------

func job_population_update(job: Dictionary, _t: int) -> void:
	var eid = job["entity_id"]
	if not _sim.world.countries.has(eid):
		return
	var country = _sim.world.countries[eid]
	_sim.activation.activate(eid, "scheduled:" + job["job_name"])
	country["population"] += country["population"] * \
		float(_sim.rules.get("population_growth_rate", 0.0008))


func job_gdp_update(job: Dictionary, _t: int) -> void:
	var eid = job["entity_id"]
	if not _sim.world.countries.has(eid):
		return
	var country = _sim.world.countries[eid]
	_sim.activation.activate(eid, "scheduled:" + job["job_name"])
	country["gdp"] += country["gdp"] * country["growth"]


func job_military_readiness(job: Dictionary, t: int) -> void:
	var eid = job["entity_id"]
	if not _sim.world.countries.has(eid):
		return
	var country = _sim.world.countries[eid]
	_sim.activation.activate(eid, "scheduled:" + job["job_name"])
	var t_ds0 = Time.get_ticks_usec()
	DecisionSystem.evaluate(country, _sim.rules)
	var outcome = DecisionSystem.apply_consequence(country, _sim.rules)
	decision_counters["total_us"] += Time.get_ticks_usec() - t_ds0
	decision_counters["evaluate_calls"] += 1
	decision_counters["apply_calls"] += 1
	var event_type = "Military_Spending_Increase"
	if outcome["path"] == "prosperity":
		event_type = "Economic_Investment"
	_sim.events.push_event(t, event_type, eid,
		{"type": event_type, "country": outcome["country"]})


func job_coup_risk_check(job: Dictionary, t: int) -> void:
	var eid = job["entity_id"]
	if not _sim.world.countries.has(eid):
		return
	var country = _sim.world.countries[eid]
	var stab_threshold = float(_sim.rules.get("coup_check_stability_threshold", 0.6))
	if country.get("stability", 1.0) < stab_threshold:
		_sim.activation.activate(eid, "scheduled:coup_risk_check")
		_sim.coup_evaluations_count += 1
		var t_ds1 = Time.get_ticks_usec()
		var risk_score = DecisionSystem.evaluate_coup_risk(country, _sim.rules)
		decision_counters["total_us"] += Time.get_ticks_usec() - t_ds1
		decision_counters["coup_eval_calls"] += 1
		# Storage here (content layer) - Selective Activation: stable countries don't get the key
		country["coup_risk_score"] = risk_score
		var coup_threshold = float(_sim.rules.get("coup_threshold", 0.6))
		if risk_score >= coup_threshold:
			_sim.events.push_event(t, "Coup_Attempt", eid,
				{"country": eid, "coup_risk_score": risk_score})


func job_agent_operation(job: Dictionary, _t: int) -> void:
	var eid = job["entity_id"]
	if _sim.world.agents.has(eid):
		var agent = _sim.world.agents[eid]
		var agency_id = agent.get("agency_id", "")
		var agency = _sim.world.agencies.get(agency_id, {})
		_sim.activation.activate(eid, "scheduled:agent_operation_check")
		_sim.operation_evaluations_count += 1
		DecisionSystem.evaluate_operation(agent, agency, _sim.rules)


# ---------------- Economy Delegation (ENGINE TOUCH #1 - T3-Phase 1) ----------------
# Pure bridge - zero domain logic. All logic in economy/economy_event_handlers.gd.

func job_economy_tick(job: Dictionary, t: int) -> void:
	_economy.job_economy_tick(job, t)


func evt_trade_offer(e: Dictionary, t: int) -> void:
	_economy.evt_trade_offer(e, t)


# ---------------- Economy v2 Delegation (ENGINE TOUCH #3 - T3-Phase 2) ----------------
# Pure bridge for coal module.

func job_economy_v2_tick(job: Dictionary, t: int) -> void:
	_economy_v2.job_economy_v2_tick(job, t)


# ---------------- Economy Feedback Handler (ENGINE TOUCH #3 - T3-Phase 2) ----------------
# Economy_Shortage_Occurred pushed from economy module -> handled here (authorized kernel)
# -> writes to WorldState.countries[country]["stability"].
# This is the only authorized write point - economy does not touch WorldState directly.

func evt_economy_shortage_occurred(e: Dictionary, _t: int) -> void:
	var payload = e.get("payload", {})
	var country = String(payload.get("country", ""))
	if country.is_empty():
		return
	if not _sim.world.countries.has(country):
		return
	var current = float(_sim.world.countries[country].get("stability", 1.0))
	var penalty = float(payload.get("stability_penalty", 0.05))
	_sim.world.countries[country]["stability"] = clampf(current - penalty, 0.0, 1.0)