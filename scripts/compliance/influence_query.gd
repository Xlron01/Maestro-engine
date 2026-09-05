extends RefCounted
class_name InfluenceQuery

# ============================================================
# COMPLIANCE LAYER — Influence Query (TASK-038)
# ------------------------------------------------------------
# العقد المقفول: Influence(source, target, context) — استعلام سياقي
# بقناتين مستقلتين، ممنوع تخزين global influence score:
#   structural ← ناتج control_chains المُمرَّر (سلطة/سلسلة سيطرة)
#   informal   ← sparse social_relations (قناة trust — §0-b-1)
#
# عقد الاستخدام (precondition — توضيح المالك §0-b-2):
#   الـcaller هو المسؤول عن استدعاء RelevanceControl.control_chains()
#   مرة واحدة وتمرير ناتجه في context["chains"]. هذه الطبقة لا تعيد
#   حسابه ولا تفترض وجوده إلا كمدخل: غيابها ⇒ structural = null +
#   missing_inputs += ControlChains (وليس إعادة حساب).
#
# قناتان ليستا alias: القيمتان تُحسبان من مصدرين مختلفين تمامًا (قبول F).
# غياب edge اجتماعي = حقيقة (لا علاقة ⇒ informal 0.0) — ليس نقص
# dependency، فالعلاقة غير الموجودة حالة معرفة لا نظام ناقص.
# ============================================================

const T := preload("res://scripts/compliance/compliance_types.gd")
const RC := preload("res://scripts/relevance_control.gd")


static func assess(source_id: String, target_id: String, context: Dictionary) -> Dictionary:
	var used: Array = []
	var missing: Array = []

	# ---- structural: من chains المُمرَّرة حصرًا (عقد الاستخدام أعلاه) ----
	var structural = null
	var chains = context.get("chains")
	if chains == null:
		missing.append(T.MISS_CONTROL_CHAINS)
	else:
		used.append("ControlChains")
		structural = _structural(source_id, target_id, chains)

	# ---- informal: قناة trust من الـedge الاجتماعي الواحد (§0-b-1) ----
	var entities: Dictionary = context.get("entities", {})
	var trust = T.social_channel(entities, source_id, target_id, T.CHANNEL_TRUST)
	var informal := 0.0
	if trust != null:
		used.append("social_relations:trust")
		informal = float(trust)

	var status := T.PARTIAL if not missing.is_empty() else T.COMPLETE
	missing.sort()
	used.sort()
	return T.influence_assessment(structural, informal, status, used, missing)


# structural influence(S→T) = أعلى درجة سيطرة لـS على أي gate يحمله T.
# يستهلك ناتج control_chains كما هو — بلا إعادة DFS (ملكية النظام).
static func _structural(source_id: String, target_id: String, chains: Dictionary) -> float:
	var gates: Dictionary = chains.get("gates", {})
	var best := 0.0
	for gkey in gates.keys():
		var gd: Dictionary = gates[gkey]
		var holders: Dictionary = gd.get("holders", {})
		if not holders.has(target_id):
			continue
		var controllers: Dictionary = gd.get("controllers", {})
		if controllers.has(source_id):
			best = maxf(best, float(controllers[source_id]))
	return best
