extends RefCounted
class_name GameEventHandlers

# ============================================================
# GAME EVENT HANDLERS — طبقة المحتوى (ليست نواة)
# ------------------------------------------------------------
# كل منطق الدومين للأحداث والوظائف المجدولة يعيش هنا.
# هذه الملفات مسموح — ومطلوب — أن تحمل أسماء المحتوى، لأنها محتوى،
# وتُربط بالنواة حصراً عبر data/rules/dispatch.json (Registry).
# تستقبل مرجع المحاكاة عبر setup() وتقرأ القواعد من sim.rules —
# ممنوع الأرقام الحرفية خارج rules.get هنا أيضاً.
# ============================================================
# ENGINE TOUCH #1 (T3-Phase 1): إضافة delegation للـ economy module.
# صفر منطق دومين هنا — تمرير استدعاء فقط.
# ============================================================

# T3 delegation — economy module (pure bridge, no domain logic here)
const EconomyHandlers = preload("res://economy/economy_event_handlers.gd")
var _economy: EconomyHandlers

var sim: Node


func setup(p_sim: Node) -> void:
	sim = p_sim
	_economy = EconomyHandlers.new()
	_economy.setup(sim)


# ---------------- Events ----------------

func evt_minister_died(e: Dictionary, _t: int) -> void:
	var source: String = e["source"]
	if sim.world.countries.has(source):
		sim.world.countries[source]["stability"] -= \
			sim.rules.get("minister_death_stability_loss", 0.05)


func evt_railway_damaged(e: Dictionary, _t: int) -> void:
	var prov_name: String = e["payload"].get("province", "")
	if sim.world.provinces.has(prov_name):
		var prov: Dictionary = sim.world.provinces[prov_name]
		prov["damage"] += sim.rules.get("railway_damage_amount", 0.4)
		prov["supply"] -= sim.rules.get("railway_supply_loss", 0.3)
		sim.activation.activate(prov_name, "damaged_by:" + e["type"])
		var province_owner: String = prov["owner"]
		if sim.world.countries.has(province_owner):
			sim.activation.activate(province_owner, "supply_network_affected")
			sim.world.countries[province_owner]["stability"] -= \
				sim.rules.get("railway_stability_loss", 0.02)


func evt_election(e: Dictionary, _t: int) -> void:
	var source: String = e["source"]
	if sim.world.countries.has(source):
		var c: Dictionary = sim.world.countries[source]
		var swing_amount: float = sim.rules.get("election_stability_swing", 0.05)
		var swing: float = sim.rng.randf_range(-swing_amount, swing_amount)
		c["stability"] = clamp(c["stability"] + swing, 0.0, 1.0)


func evt_war_started(e: Dictionary, t: int) -> void:
	var attacker: String = e["payload"].get("attacker", "")
	var defender: String = e["payload"].get("defender", "")
	if sim.world.countries.has(attacker) and sim.world.countries.has(defender):
		sim.world.countries[attacker]["at_war_with"].append(defender)
		sim.world.countries[defender]["at_war_with"].append(attacker)
		sim.world.countries[defender]["military_threat_nearby"] += \
			sim.rules.get("war_threat_increase", 5.0)
		sim.activation.activate(defender, "war_declared_against_me")
		DecisionSystem.evaluate(sim.world.countries[defender], sim.rules)
		var outcome: Dictionary = DecisionSystem.apply_consequence(
			sim.world.countries[defender], sim.rules)
		var event_type: String = "Military_Spending_Increase"
		if outcome["path"] == "prosperity":
			event_type = "Economic_Investment"
		sim.events.push_event(t, event_type, defender,
			{"type": event_type, "country": outcome["country"]})

		for related in sim.world.related_entities(defender):
			if related != attacker:
				sim.activation.activate(related, "relation_to:" + defender)


func evt_noop(_e: Dictionary, _t: int) -> void:
	pass


func evt_coup_attempt(e: Dictionary, _t: int) -> void:
	var source: String = e["source"]
	if sim.world.countries.has(source):
		var c: Dictionary = sim.world.countries[source]
		c["stability"] = clamp(
			c["stability"] - float(sim.rules.get("coup_attempt_stability_loss", 0.2)),
			0.0, 1.0)


func evt_agent_exposed(e: Dictionary, _t: int) -> void:
	var agency_id: String = e["payload"].get("agency_id", "")
	var target_country: String = e["payload"].get("target_country", "")

	if not agency_id.is_empty():
		sim.activation.activate(agency_id, "agency:agent_exposed")
		sim.exposure_propagation_count += 1

	if sim.world.countries.has(target_country):
		sim.activation.activate(target_country, "counter_intel:agent_exposed")
		sim.world.countries[target_country]["stability"] -= \
			float(sim.rules.get("agent_exposure_stability_penalty", 0.03))
		sim.exposure_propagation_count += 1


# ---------------- Scheduled Jobs ----------------

func job_population_update(job: Dictionary, _t: int) -> void:
	var eid: String = job["entity_id"]
	if not sim.world.countries.has(eid):
		return
	var country: Dictionary = sim.world.countries[eid]
	sim.activation.activate(eid, "scheduled:" + job["job_name"])
	country["population"] += country["population"] * \
		float(sim.rules.get("population_growth_rate", 0.0008))


func job_gdp_update(job: Dictionary, _t: int) -> void:
	var eid: String = job["entity_id"]
	if not sim.world.countries.has(eid):
		return
	var country: Dictionary = sim.world.countries[eid]
	sim.activation.activate(eid, "scheduled:" + job["job_name"])
	country["gdp"] += country["gdp"] * country["growth"]


func job_military_readiness(job: Dictionary, t: int) -> void:
	var eid: String = job["entity_id"]
	if not sim.world.countries.has(eid):
		return
	var country: Dictionary = sim.world.countries[eid]
	sim.activation.activate(eid, "scheduled:" + job["job_name"])
	DecisionSystem.evaluate(country, sim.rules)
	var outcome: Dictionary = DecisionSystem.apply_consequence(country, sim.rules)
	var event_type: String = "Military_Spending_Increase"
	if outcome["path"] == "prosperity":
		event_type = "Economic_Investment"
	sim.events.push_event(t, event_type, eid,
		{"type": event_type, "country": outcome["country"]})


func job_coup_risk_check(job: Dictionary, t: int) -> void:
	var eid: String = job["entity_id"]
	if not sim.world.countries.has(eid):
		return
	var country: Dictionary = sim.world.countries[eid]
	var stab_threshold: float = float(sim.rules.get("coup_check_stability_threshold", 0.6))
	if country.get("stability", 1.0) < stab_threshold:
		sim.activation.activate(eid, "scheduled:coup_risk_check")
		sim.coup_evaluations_count += 1
		var risk_score: float = DecisionSystem.evaluate_coup_risk(country, sim.rules)
		# التخزين هنا (طبقة المحتوى) — Selective Activation: المستقرة لا تحصل على المفتاح
		country["coup_risk_score"] = risk_score
		var coup_threshold: float = float(sim.rules.get("coup_threshold", 0.6))
		if risk_score >= coup_threshold:
			sim.events.push_event(t, "Coup_Attempt", eid,
				{"country": eid, "coup_risk_score": risk_score})


func job_agent_operation(job: Dictionary, _t: int) -> void:
	var eid: String = job["entity_id"]
	if sim.world.agents.has(eid):
		var agent: Dictionary = sim.world.agents[eid]
		var agency_id: String = agent.get("agency_id", "")
		var agency: Dictionary = sim.world.agencies.get(agency_id, {})
		sim.activation.activate(eid, "scheduled:agent_operation_check")
		sim.operation_evaluations_count += 1
		DecisionSystem.evaluate_operation(agent, agency, sim.rules)


# ---------------- Economy Delegation (ENGINE TOUCH #1 — T3-Phase 1) ----------------
# Pure bridge — صفر منطق دومين. كل الـlogic في economy/economy_event_handlers.gd.

func job_economy_tick(job: Dictionary, t: int) -> void:
	_economy.job_economy_tick(job, t)


func evt_trade_offer(e: Dictionary, t: int) -> void:
	_economy.evt_trade_offer(e, t)
