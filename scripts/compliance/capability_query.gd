extends RefCounted
class_name CapabilityQuery

# ============================================================
# COMPLIANCE LAYER — Capability / Feasibility Query (TASK-038)
# ------------------------------------------------------------
# العقد المقفول:
#   Capability(actor, action, target, context) → CapabilityAssessment
#   feasibility = FEASIBLE | INFEASIBLE | UNKNOWN
#   status      = COMPLETE | PARTIAL
#
# قاعدة المالك المقفولة: Capability "تستهلك ولا تملك" — يُسمح لها
# باستهلاك World Facts الخام مباشرة (Geography/Position/Distance/
# Resources/Infrastructure...) لأنها جزء مباشر من الظاهرة المقيَّمة،
# بينما تظل الأنظمة الأخرى مالكة لتلك البيانات. هنا لا نُنشئ أي نظام —
# الـquery يقرأ dict حقول خام يمرره الـcaller في context["facts"].
#
# v0 (NON-FINAL): الـaction يعلن requires = [{path, op, value}] حيث
# path مسار منقط داخل facts (مثال: "Unit_B.supplies" أو
# "Geography.distance_to_target"). الغياب ⇒ UNKNOWN + PARTIAL +
# missing_inputs (لا INFEASIBLE كاذبة ولا default) — قبول C.
# فشل متطلب بمعلومة موجودة ⇒ INFEASIBLE (دليل كامل إن لم يوجد نقص).
# ============================================================

const T := preload("res://scripts/compliance/compliance_types.gd")


static func assess(actor_id: String, action: Dictionary, target_id: String,
		context: Dictionary) -> Dictionary:
	var facts: Dictionary = context.get("facts", {})
	var reqs: Array = action.get("requires", [])

	var used: Array = []
	var missing: Array = []
	var limiting: Array = []
	var any_fail := false
	var any_unknown := false

	for r in reqs:
		var req: Dictionary = r
		var path := String(req.get("path", ""))
		var op := String(req.get("op", "gte"))
		var rhs := float(req.get("value", 0.0))
		used.append("fact:" + path)

		var fact = _lookup(facts, path)
		if fact == null:
			# غياب الحقيقة الخام = UNKNOWN — ممنوع INFEASIBLE الكاذبة
			any_unknown = true
			missing.append(path)
			continue
		var v := float(fact)
		var ok := false
		match op:
			"gte":
				ok = v >= rhs
			"lte":
				ok = v <= rhs
			_:
				ok = false
		if ok:
			continue
		any_fail = true
		limiting.append(path)

	var feasibility: String
	if any_fail:
		feasibility = T.INFEASIBLE
	elif any_unknown:
		feasibility = T.UNKNOWN
	else:
		feasibility = T.FEASIBLE

	# status يعكس نقص الأدلة، feasibility يعكس الحكم على المتاح — مستقلان
	var status := T.PARTIAL if any_unknown else T.COMPLETE
	missing.sort()
	limiting.sort()
	used.sort()
	return T.capability_assessment(feasibility, status, used, missing, limiting)


# مسار منقط "a.b.c" داخل dict الحقوق الخام — null إن لم يوجد
static func _lookup(facts: Dictionary, path: String):
	var parts := path.split(".", false)
	if parts.is_empty():
		return null
	var cur = facts
	for i in range(parts.size()):
		var d = cur
		if not (d is Dictionary) or not (d as Dictionary).has(parts[i]):
			return null
		cur = (d as Dictionary)[parts[i]]
	return cur
