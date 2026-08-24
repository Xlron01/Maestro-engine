extends RefCounted
class_name RelevanceSupply

# ============================================================
# MODEL v1 — TRANCHE A: SUPPLY CHANNEL PRIMITIVES
# وفق 10-Strategic-Relevance-Model-v1.md §3.1/§3.3/§5 (صيغ مجمّدة عند بدء هذا الترانش)
#
# التجميد الدلالي (موثق قبل أول تشغيل):
#   EaseOfReplacement(C, cap | losing X) ∈ [0,1] — ارتفاعه = استبدال أسهل.
#   عامل التضخيم على أهمية المورد هو معكوسه:
#       ReplacementFactor = 1 − EaseOfReplacement      (1 = يستحيل التعويض)
#   وبالتالي: بدائل أكثر / احتياطي أطول ⇒ EoR↑ ⇒ RF↓ ⇒ Relevance نحو المورد ↓
#   (اتجاه مسجل في توقعات §9.1 — ليس نتيجة).
#
# المدخلات: حقائق بنيوية حصرًا (L1) — لا علاقات ولا نيّة.
# الفهرسة: زوجية لكل (Y, X, cap) (L2). لا مخرج تهديد (L3).
# ============================================================

const DEFAULT_CONFIG_PATH := "res://data/rules/relevance_config.json"


static func load_config(path: String = DEFAULT_CONFIG_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Relevance config missing: %s" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Relevance config invalid JSON: %s" % path)
		return {}
	var cfg: Dictionary = parsed
	for required in ["weights", "criticality", "relevance_eor_weight", "leadtime_months_standard"]:
		if not cfg.has(required):
			push_error("Relevance config missing section: %s" % required)
			return {}
	return cfg


static func supply_share(producer_produces: Dictionary, all_entities: Array, cap: String) -> float:
	var mine := float(producer_produces.get(cap, 0.0))
	if mine <= 0.0:
		return 0.0
	var total := 0.0
	for ent in all_entities:
		total += float((ent as Dictionary).get("produces", {}).get(cap, 0.0))
	if total <= 0.0:
		return 0.0
	return mine / total


static func effective_depends_on(consumer: Dictionary, cap: String) -> float:
	var dep := float((consumer.get("depends_on", {}) as Dictionary).get(cap, 0.0))
	var dom := clampf(float((consumer.get("domestic_capacity", {}) as Dictionary).get(cap, 0.0)), 0.0, 1.0)
	return dep * (1.0 - dom)


static func ease_of_replacement(consumer: Dictionary, cap: String, losing_share: float,
		w_alternatives: float, w_slack: float, leadtime_months: float,
		default_reserve_days: float) -> float:
	var alternatives_share: float = 1.0 - losing_share
	var reserve_days := float((consumer.get("reserves_days", {}) as Dictionary).get(cap, default_reserve_days))
	var slack := clampf(reserve_days / maxf(leadtime_months * 30.0, 1.0), 0.0, 1.0)
	return clampf(w_alternatives * alternatives_share + w_slack * slack, 0.0, 1.0)


static func sector_criticality(consumer: Dictionary, cap: String, criticality: Dictionary) -> float:
	var sector := String((consumer.get("sectors", {}) as Dictionary).get(cap, "default"))
	return float(criticality.get(sector, criticality.get("default", 1.0)))


# Relevance_Supply(Y ⇐ X): مجموع عبر قدرات X المنتجة.
# يرجّع {"value": float} — قيمة رقمية فقط (L3)، زوجية (L2)، مدخلات بنيوية (L1).
static func relevance_supply(world: Dictionary, cfg: Dictionary, consumer_name: String,
		producer_name: String) -> Dictionary:
	var entities: Array = []
	for ename in world["entities"].keys():
		entities.append(world["entities"][ename])
	var consumer: Dictionary = world["entities"].get(consumer_name, {})
	var producer: Dictionary = world["entities"].get(producer_name, {})
	var weights: Dictionary = cfg["weights"]
	var w_alt := float(weights.get("w_alternatives", 0.6))
	var w_slack := float(weights.get("w_slack", 0.4))
	var w_eor := float(cfg.get("relevance_eor_weight", 1.0))
	var lead_months := float(cfg.get("leadtime_months_standard", 12.0))
	var def_res := float(cfg.get("default_reserve_days", 0.0))
	var criticality: Dictionary = cfg["criticality"]

	var total := 0.0
	var produces: Dictionary = producer.get("produces", {})
	for cap_key in produces.keys():
		var cap := String(cap_key)
		var share := supply_share(produces, entities, cap)
		if share <= 0.0:
			continue
		var eff_dep := effective_depends_on(consumer, cap)
		var crit := sector_criticality(consumer, cap, criticality)
		var eor := ease_of_replacement(consumer, cap, share, w_alt, w_slack, lead_months, def_res)
		var replacement_factor := 1.0 - eor
		total += eff_dep * share * crit * replacement_factor * w_eor
	return {"value": total}
