extends RefCounted
class_name ComplianceQuery

# ============================================================
# COMPLIANCE LAYER — Deterministic Resolution (TASK-038)
# ------------------------------------------------------------
# العقد المقفول: Compliance(actor, action, target, context)
#   actor  = المستجيب الذي نقيّم امتثاله للأمر
#   target = مصدر الأمر / الطرف المقابل للعلاقة
#   → ComplianceAssessment ببُعدين مستقلين:
#     compliance_degree (0..1) · resistance_mode NONE|PASSIVE|ACTIVE
#     · resistance_strength (0..1 عند الصلة)
#   ممنوع probability: لا P(compliance) ولا P(resistance).
#
# Resolution Ordering المقفول:
#   Gate 1 — Feasibility: INFEASIBLE+COMPLETE ⇒ short-circuit (لا
#     compliance مختلق: degree/mode/strength = null). UNKNOWN+PARTIAL
#     لا يوقف الـresolution.
#   Stage 2 — Contextual Assessments: يُحسب فقط ما يحتاجه الـaction
#     (action.needs) — لا سلسلة dependency قسرية بين الـassessments.
#   Stage 3 — Deterministic Resolution: تركيب الأدلة المتاحة.
#
# عقد الاستخدام (§0-b-2): context["chains"] يجب أن يمرره الـcaller
# (ناتج control_chains محسوب مسبقًا) — هذه الطبقة لا تعيد حسابه.
#
# social_relations (§0-b-1): قناة loyalty تُقرأ من نفس الـedge
# متعدد القنوات الذي تقرأ منه Influence قناة trust — ليست نسخة مستقلة.
#
# v0 RESOLUTION (NON-FINAL — pending owner formula): جدول قواعد عتبة
# من compliance_config.json، بلا أوزان ولا مجاميع موزونة. الحالات تُبنى
# حالات القبول I الخمس بالتركيب من الأدلة لا بالثوابت. أي input غائب
# ⇒ PARTIAL + missing_inputs، والنتيجة تُنتج بأفضل دليل متاح.
# ============================================================

const T := preload("res://scripts/compliance/compliance_types.gd")
const CAP := preload("res://scripts/compliance/capability_query.gd")
const IQ := preload("res://scripts/compliance/influence_query.gd")
const LQ := preload("res://scripts/compliance/legitimacy_query.gd")

# عدّاد تشغيلي لقبول K (طبقة on-demand: لا يتحرك مع أي tick)
static var eval_count: int = 0


static func assess(actor_id: String, action: Dictionary, target_id: String,
		context: Dictionary) -> Dictionary:
	eval_count += 1
	var cfg: Dictionary = context.get("config", {})
	var entities: Dictionary = context.get("entities", {})
	var used: Array = []
	var missing: Array = []

	# ---------- Gate 1 — Feasibility ----------
	var cap := CAP.assess(actor_id, action, target_id, context)
	used.append("Capability")
	for m in (cap["missing_inputs"] as Array):
		missing.append(String(m))
	if String(cap["feasibility"]) == T.INFEASIBLE and String(cap["status"]) == T.COMPLETE:
		# لا تنفيذ ممكن ولا compliance مختلق — لا تحول إلى refusal
		missing.sort()
		used.sort()
		return T.compliance_assessment(null, null, null, String(cap["status"]),
			used, missing, true)
	# UNKNOWN+PARTIAL: الـresolution يستمر (ممنوع التوقف التلقائي)

	# ---------- Stage 2 — Contextual Assessments (فقط ما يحتاجه الـaction) ----------
	var needs: Array = action.get("needs",
		["authority", "loyalty", "goal_conflict", "legitimacy", "coercion"])
	var actor_ent: Dictionary = entities.get(actor_id, {})

	var authority_degree = null
	if needs.has("authority"):
		# الضغط الهيكلي = تأثير مصدر الأمر (target) في المستجيب (actor)
		var inf := IQ.assess(target_id, actor_id, context)
		used.append("Authority")
		authority_degree = inf["structural"]
		for m in (inf["missing_inputs"] as Array):
			missing.append("Authority." + String(m))

	var loyalty = null
	if needs.has("loyalty"):
		used.append("Loyalty")
		# نفس الـedge متعدد القنوات (§0-b-1) — قناة loyalty هنا
		loyalty = T.social_channel(entities, actor_id, target_id, T.CHANNEL_LOYALTY)
		if loyalty == null:
			missing.append(T.MISS_LOYALTY_REL)

	var conflict := false
	if needs.has("goal_conflict"):
		used.append("GoalConflict")
		var harms: Array = action.get("harms_interests", [])
		var gt: Dictionary = actor_ent.get("goal_table", {})
		var wmin := float(cfg.get("conflict_weight_min", 0.3))
		for ch in harms:
			var key := String(ch)
			if gt.has(key) and float(gt[key]) >= wmin:
				conflict = true

	var legit: Dictionary = {}
	if needs.has("legitimacy"):
		# شرعية الفعل المطلوب: subject = مصدر الأمر (target)،
		# والـAuthority داخله يقاس تأثيره في المستجيب (actor)
		var lctx: Dictionary = context.duplicate()
		lctx["authority_counterparty_id"] = actor_id
		legit = LQ.assess(target_id, "Action", actor_id, lctx)
		used.append("Legitimacy")
		for m in (legit["missing_inputs"] as Array):
			missing.append("Legitimacy." + String(m))

	if needs.has("coercion"):
		# ThreatAssessment = future dependency — لا FearSystem (ممنوعات صريحة)
		used.append("Coercion")
		if not context.has("threat_assessment"):
			missing.append(T.MISS_THREAT_ASSESSMENT)

	# ---------- Stage 3 — Deterministic Resolution (v0 NON-FINAL) ----------
	var loyal_min := float(cfg.get("loyal_min", 0.5))
	var pressure := (authority_degree != null) \
		and (float(authority_degree) >= float(cfg.get("pressure_min", 0.5)))

	var willingness := "NEUTRAL"
	if conflict:
		# تعارض مصالح مع ولاء عالٍ = ممزّق ⇒ NEUTRAL (حتمي وموثق)
		if loyalty != null and float(loyalty) < loyal_min:
			willingness = "OPPOSES"
	else:
		if loyalty != null and float(loyalty) >= loyal_min:
			willingness = "SUPPORTS"

	var degree
	var mode
	var strength
	match willingness:
		"SUPPORTS":
			degree = 1.0
			mode = T.RES_NONE
			strength = 0.0
		"NEUTRAL":
			if pressure:
				degree = float(cfg.get("partial_degree", 0.5))
				mode = T.RES_NONE
				strength = 0.0
			else:
				degree = 0.0
				mode = T.RES_PASSIVE
				strength = float(cfg.get("passive_strength", 0.5))
		_:
			if pressure:
				degree = float(cfg.get("partial_active_degree", 0.4))
				mode = T.RES_ACTIVE
				strength = float(cfg.get("active_strength", 0.7))
			else:
				degree = 0.0
				mode = T.RES_ACTIVE
				strength = float(cfg.get("active_strength", 0.7))

	var status := T.PARTIAL if not missing.is_empty() else T.COMPLETE
	missing.sort()
	used.sort()
	return T.compliance_assessment(degree, mode, strength, status, used, missing, false)
