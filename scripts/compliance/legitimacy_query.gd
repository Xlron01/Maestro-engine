extends RefCounted
class_name LegitimacyQuery

# ============================================================
# COMPLIANCE LAYER — Legitimacy Query (TASK-038)
# ------------------------------------------------------------
# العقد المقفول: Legitimacy(subject, domain, audience, context)
#   domains = State | Regime | Government | Action
#   ممنوع Actor.Legitimacy كـscore عالمي — استعلام سياقي بحالة.
#
# مصادر مقفولة:
#   Primitive facts (تُستهلك إن وُجدت): founding/regime/constitution/
#     succession/election/foreign_recognition — من كيان الـsubject.
#   Derived states ملك لأنظمة أخرى — لا يُعاد حساب أي منها:
#     Stability/EconomicPerformance/PublicOrder/PopularSupport.
#   نقص أي منها ⇒ PARTIAL + missing_inputs (لا default value) — قبول G.
#
# ConstitutionalValidity = future dependency (قبول H): ممنوع بناء
# Constitutional System — غيابها ⇒ PARTIAL + missing فقط.
#
# v0 value (NON-FINAL): متوسط قيم الحقائق البدائية المتاحة فقط —
# ليس formula نهائية؛ الحساب من المتاح مستمر حتى مع PARTIAL (قبول H).
# ============================================================

const T := preload("res://scripts/compliance/compliance_types.gd")
const IQ := preload("res://scripts/compliance/influence_query.gd")

const DOM_STATE := "State"
const DOM_REGIME := "Regime"
const DOM_GOVERNMENT := "Government"
const DOM_ACTION := "Action"


static func assess(subject_id: String, domain: String, audience_id: String,
		context: Dictionary) -> Dictionary:
	match domain:
		DOM_STATE, DOM_REGIME, DOM_GOVERNMENT:
			return _domain_assess(subject_id, domain, context)
		DOM_ACTION:
			return _action_assess(subject_id, context)
		_:
			return T.legitimacy_assessment(null, T.PARTIAL,
				[], ["UnknownDomain:" + domain])


# State/Regime/Government: بدائيات متاحة + derived states غائبة دائمًا في v0
static func _domain_assess(subject_id: String, domain: String, context: Dictionary) -> Dictionary:
	var cfg: Dictionary = context.get("config", {})
	var fact_map: Dictionary = cfg.get("legitimacy_primitive_facts", {})
	var facts: Array = fact_map.get(domain, [])
	var entities: Dictionary = context.get("entities", {})
	var ent: Dictionary = entities.get(subject_id, {})

	var used: Array = []
	var missing: Array = []
	var vals: Array = []
	for f in facts:
		var key := String(f)
		if ent.has(key):
			used.append("fact:" + key)
			vals.append(float(ent[key]))
		else:
			missing.append("fact:" + key)

	# derived states ملك لغيرها — غيابها معلن لا مختلق
	missing.append(T.MISS_POPULAR_SUPPORT)
	if domain == DOM_GOVERNMENT:
		missing.append(T.MISS_PUBLIC_ORDER)
	missing.append(T.MISS_AUDIENCE_VIEW)

	var value = null
	if not vals.is_empty():
		var s := 0.0
		for v in vals:
			s += float(v)
		value = s / float(vals.size())

	var status := T.PARTIAL if not missing.is_empty() else T.COMPLETE
	missing.sort()
	used.sort()
	return T.legitimacy_assessment(value, status, used, missing)


# Action: يستهلك State/Regime/Government + Authority + ConstitutionalValidity
static func _action_assess(subject_id: String, context: Dictionary) -> Dictionary:
	var used: Array = []
	var missing: Array = []
	var vals: Array = []

	for sub in [DOM_STATE, DOM_REGIME, DOM_GOVERNMENT]:
		var sa := _domain_assess(subject_id, sub, context)
		used.append("Legitimacy:" + sub)
		if sa["value"] != null:
			vals.append(float(sa["value"]))
		for m in (sa["missing_inputs"] as Array):
			missing.append(String(sub) + "." + String(m))

	# Authority: من chains المُمرَّرة عبر InfluenceQuery — بلا إعادة حساب.
	# القياس: تأثير subject (مصدر الفعل) في الطرف المقابل للمطالبة بالامتثال
	# (authority_counterparty_id — يحدده ComplianceQuery)، وإلا subject نفسه.
	var inf := IQ.assess(subject_id,
		String(context.get("authority_counterparty_id", subject_id)), context)
	used.append("Authority")
	if inf["structural"] != null:
		vals.append(float(inf["structural"]))
	for m in (inf["missing_inputs"] as Array):
		missing.append("Authority." + String(m))

	# ConstitutionalValidity: future dependency — لا بناء نظام (قبول H)
	missing.append(T.MISS_CONSTITUTIONAL_VALIDITY)

	var value = null
	if not vals.is_empty():
		var s := 0.0
		for v in vals:
			s += float(v)
		value = s / float(vals.size())

	var status := T.PARTIAL if not missing.is_empty() else T.COMPLETE
	missing.sort()
	used.sort()
	return T.legitimacy_assessment(value, status, used, missing)
