extends RefCounted
class_name DecisionSystem

# ============================================================
# DecisionSystem — قاعدة قرار "security vs prosperity"
# مبني على بيانات مخزّنة في politics.json (مبدأ 7 و8 في 01-مبادئ-المحرك.md)
# كل المعاملات تيجي من rules dict — مفيش magic numbers هنا.
# ============================================================

# Evaluate: يقرأ الأوزان من rules، يحسب القيمتين، يختار أعلاهم عبر evaluate_weighted_score
static func evaluate(country: Dictionary, rules: Dictionary = {}) -> String:
	var threshold: float = rules.get("decision_threshold", 0.0)

	var sec_map = [["military_threat_nearby", "sec_weight_threat"], ["border_insecurity", "sec_weight_border"]]
	var prosp_map = [["economic_stability", "prosp_weight_stability"], ["growth", "prosp_weight_growth"]]

	var security_score: float = evaluate_weighted_score(country, sec_map, rules)
	var prosperity_score: float = evaluate_weighted_score(country, prosp_map, rules)

	country["security_score"] = security_score
	country["prosperity_score"] = prosperity_score

	if security_score > prosperity_score + threshold:
		country["chosen_action"] = "security"
	else:
		country["chosen_action"] = "prosperity"

	return country["chosen_action"]

# ============================================================
# evaluate_weighted_score — دالة عامة مجردة لحساب المجموع الموزون
# ------------------------------------------------------------
# entity: كائن البيانات
# factor_weight_map: Array of [factor_key, weight_rule_key, default_weight]
# rules: قاموس القواعد والأوزان
# ============================================================
static func evaluate_weighted_score(entity: Dictionary, factor_weight_map: Array, rules: Dictionary) -> float:
	var total_score: float = 0.0
	for item in factor_weight_map:
		var factor_key: String = item[0]
		var weight_rule_key: String = item[1]
		var factor_value: float = float(entity.get(factor_key, 0.0))
		var weight: float = float(rules.get(weight_rule_key, 0.0))
		total_score += factor_value * weight
	return total_score

# ============================================================
# evaluate_coup_risk — تقييم الانقلاب باستخدام نفس الدالة العامة
# نقية: ترجع النتيجة فقط؛ التخزين في حالة الدولة مسؤولية المستدعي
# (طبقة المحتوى) — Selective Activation يبقى سليمًا تلقائيًا.
# ============================================================
static func evaluate_coup_risk(country: Dictionary, rules: Dictionary) -> float:
	var coup_map = [
		["war_exhaustion",           "coup_weight_war_exhaustion"],
		["coup_ideology_support",    "coup_weight_ideology_support"],
		["current_ideology_support", "coup_weight_current_ideology"],
		["coup_party_popularity",    "coup_weight_party_popularity"],
		["stability",                "coup_weight_stability"],
		["foreign_support_for_coup", "coup_weight_foreign_support"],
		["urban_ideology_mismatch",  "coup_weight_urban_mismatch"],
		["literacy",                 "coup_weight_literacy"],
		["war_generation_loss",      "coup_weight_war_generation"]
	]
	return evaluate_weighted_score(country, coup_map, rules)

# ============================================================
# evaluate_operation — تقييم تنفيذ عملية لـ Agent باستخدام الدالة العامة الموحدة
# ============================================================
static func evaluate_operation(agent: Dictionary, agency: Dictionary, rules: Dictionary) -> Dictionary:
	var op_map = [
		["xp", "operation_weight_agent_xp"],
		["budget", "operation_weight_agency_budget"]
	]
	var context = agent.duplicate()
	context["budget"] = agency.get("budget", 0.0)

	var score: float = evaluate_weighted_score(context, op_map, rules)
	var threshold: float = float(rules.get("operation_success_threshold", 5.0))

	var is_success: bool = (score >= threshold)
	var xp_gain: int = int(rules.get("operation_xp_gain_success", 25)) if is_success else int(rules.get("operation_xp_gain_failure", 5))

	var old_xp: int = int(agent.get("xp", 0))
	var new_xp: int = old_xp + xp_gain
	agent["xp"] = new_xp

	return {
		"agent_id": agent.get("id", ""),
		"success": is_success,
		"score": score,
		"threshold": threshold,
		"old_xp": old_xp,
		"xp_gain": xp_gain,
		"new_xp": new_xp
	}

# Apply consequence: يعدّل الـstate ويحدد المسار المتبع — بداية سلسلة سببية (نص 7 في Prototype).
# محايد الدومين: يرجّع المسار فقط؛ تحويله إلى نوع حدث مسؤولية طبقة المحتوى.
static func apply_consequence(country: Dictionary, rules: Dictionary = {}) -> Dictionary:
	if country["chosen_action"] == "security":
		country["military_power"] += rules.get("military_power_gain", 1.0)
		country["gdp"] -= country["gdp"] * rules.get("military_spending_gdp_cost", 0.01)
	else:
		country["gdp"] += country["gdp"] * rules.get("prosperity_gdp_gain", 0.015)
	return {"country": country["name"], "path": country["chosen_action"]}
