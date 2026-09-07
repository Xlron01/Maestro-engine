extends RefCounted
class_name PoliticalDeadlines

# ============================================================
# TASK-040-pre — POLITICAL DEADLINE ACTIVATION PATH
# ------------------------------------------------------------
# الـdeadline = نقطة مجدولة في زمن المحاكاة تصبح عندها التزام سياسي
# معرفًا مؤهلًا للتنشيط:
#   {deadline_id, deadline_type, owner, due_at, scheduled_at,
#    status, actual_activation_at, resolved_at, payload, resolution}
#
# دورة الحياة المفروضة: scheduled → due → activated → resolved
# — الـdeadline الذي يستحق لا يختفي بصمت (سجل دائم في state.deadlines).
#
# الأهلية الزمنية (1 step = 1 day): current_simulation_day >= due_at.
# lateness_days = actual_activation_at - due_at  (تشخيصي في هذه المهمة).
#
# إعادة استخدام مقفولة (لا مجدول ثاني — قبول A7):
#   الأهلية عبر instance من ScheduledQueue النواة نفسه (state.deadline_queue)
#   والتنشيط عبر PoliticalActions.execute الحالي (Actor → Action →
#   Resolution → Owning Domain) — صفر كتابة حالة مباشرة هنا.
#
# الأنواع في v1:
#   government_term_expiration — يُجدول عند تكوين الحكومة فقط إذا طلبت
#     القواعد المؤسسية (government_term_days).
#   election_due — يُنشأ من انتهاء مدة الحكومة حيث تشترط القواعد، أو
#     يُجدول مستقلًا حيث تسمح القواعد (schedulable_independently) —
#     لا افتراض أن انتهاء المدة يسبب انتخابًا عالميًا (قبول A4).
#
# محظور هنا: periodic political reassessment (future dependency) —
# البنية لا تفترض استحالته لاحقًا لكن لا شيء ينفذه الآن.
# ============================================================

const SQ := preload("res://scripts/ScheduledQueue.gd")

const JOB_NAME := "political_deadline"


# ---------------- Registration / Scheduling ----------------

static func schedule(state, deadline_id: String, deadline_type: String, owner: String,
		due_at: int, current_day: int, payload: Dictionary) -> Dictionary:
	if state.deadline_queue == null:
		state.deadline_queue = SQ.new()
	var rec := {
		"deadline_id": deadline_id,
		"deadline_type": deadline_type,
		"owner": owner,
		"due_at": int(due_at),
		"scheduled_at": int(current_day),
		"status": "scheduled",
		"actual_activation_at": null,
		"resolved_at": null,
		"lateness_days": null,
		"activation_count": 0,
		"payload": payload.duplicate(true),
		"resolution": null
	}
	state.deadlines[deadline_id] = rec
	# next_check = due_at — الأهلية عبر get_due_jobs(day) القائمة
	state.deadline_queue.register(deadline_id, JOB_NAME, 0, int(due_at))
	state.deadline_stats["scheduled"] = int(state.deadline_stats["scheduled"]) + 1
	return rec


# انتهاء مدة الحكومة: يُجدول فقط إذا طلبت القاعدة المؤسسية المدة أصلًا
static func schedule_term(state, government_id: String, legislature_id: String,
		lrules: Dictionary, current_day: int) -> Dictionary:
	var term_days := int(lrules.get("government_term_days", 0))
	if term_days <= 0:
		return {}
	return schedule(state, "dl_term_" + government_id, "government_term_expiration",
		government_id, current_day + term_days, current_day,
		{"legislature_id": legislature_id, "term_duration_days": term_days})


# ---------------- Eligibility / Activation / Resolution ----------------

# يُستدعى من الـorchestrator عند تقدم زمن المحاكاة (1 استدعاء/يوم محاكاك).
# التعليق المؤقت على production run_step غير مطلوب في هذا الإثبات —
# نقطة الدمج الموثقة: بعد run_step في الـorchestrator.
static func pump(state, current_day: int, rules, actions_module, ctx: Dictionary) -> Dictionary:
	if state.deadline_queue == null:
		return {"day": current_day, "due": 0, "activated": 0, "resolved": 0,
			"duplicates": 0, "lateness_max": 0, "queue_size": 0}
	var jobs := state.deadline_queue.get_due_jobs(current_day)
	var ids: Array = []
	for j in jobs:
		ids.append(String(j["entity_id"]))
	ids.sort()  # ترتيب تنشيط حتمي
	var activated := 0
	var resolved := 0
	var duplicates := 0
	var lateness_max := 0
	for id in ids:
		if not state.deadlines.has(id):
			continue
		var rec: Dictionary = state.deadlines[id]
		if String(rec["status"]) != "scheduled":
			# A3: لا تنشيط مزدوج — الـdeadline المعالج لا يُعاد
			state.deadline_stats["duplicates"] = int(state.deadline_stats["duplicates"]) + 1
			duplicates += 1
			continue
		# scheduled → due → activated
		rec["status"] = "due"
		state.deadline_stats["due"] = int(state.deadline_stats["due"]) + 1
		rec["actual_activation_at"] = int(current_day)
		rec["lateness_days"] = int(current_day) - int(rec["due_at"])
		lateness_max = maxi(lateness_max, int(rec["lateness_days"]))
		state.emit_event("DeadlineActivated", {"deadline_id": id,
			"deadline_type": String(rec["deadline_type"]), "day": int(current_day),
			"lateness_days": int(rec["lateness_days"])})
		# activation عبر pipeline القائم — لا كتابة حالة مباشرة هنا (A6)
		var resolution := _activate(rec, current_day, state, rules, actions_module, ctx)
		rec["activation_count"] = int(rec["activation_count"]) + 1
		rec["resolution"] = resolution
		rec["status"] = "resolved"
		rec["resolved_at"] = int(current_day)
		state.deadline_stats["activated"] = int(state.deadline_stats["activated"]) + 1
		state.deadline_stats["resolved"] = int(state.deadline_stats["resolved"]) + 1
		activated += 1
		resolved += 1
		state.emit_event("DeadlineResolved", {"deadline_id": id,
			"deadline_type": String(rec["deadline_type"]), "day": int(current_day),
			"outcome": String(resolution.get("outcome", ""))})
		# إزالة من طابور الأهلية — منع التكرار بنيويًا (A3)
		state.deadline_queue.unregister(id, JOB_NAME)
	return {"day": int(current_day),
		"due": int(state.deadline_stats["due"]),
		"activated": activated, "resolved": resolved,
		"duplicates": duplicates, "lateness_max": lateness_max,
		"queue_size": state.deadline_queue.pending_count() if state.deadline_queue != null else 0}


# التنشيط: تقييم القواعد المؤسسية ثم التنفيذ عبر pipeline القائم
static func _activate(rec: Dictionary, current_day: int, state, rules,
		actions_module, ctx: Dictionary) -> Dictionary:
	var dtype := String(rec["deadline_type"])
	if dtype == "government_term_expiration":
		var leg_id := String((rec["payload"] as Dictionary).get("legislature_id", ""))
		var lrules: Dictionary = rules.legislature_rules(leg_id)
		# السببية عبر القواعد فقط — لا افتراض عالمي (A4)
		if bool(lrules.get("term_expiration_causes_election", false)):
			var call_days := int(lrules.get("election_call_days", 0))
			var election_id := "el_due_" + String(rec["deadline_id"])
			var dl_id := "dl_election_" + String(rec["deadline_id"])
			schedule(state, dl_id, "election_due", String(rec["owner"]),
				current_day + call_days, current_day,
				{"legislature_id": leg_id, "election_id": election_id, "type": etype_of(el_rules)})
			return {"outcome": "election_deadline_scheduled", "election_deadline_id": dl_id}
		return {"outcome": "no_election_required_per_rules"}
	if dtype == "election_due":
		var payload: Dictionary = rec["payload"]
		var etype := String(payload.get("type", "general"))
		var el_rules: Dictionary = rules.election_rules(etype)
		var auth_office := String(el_rules.get("electoral_authority_office", ""))
		var owner := String(rec["owner"])
		if auth_office != "":
			owner = state.holder_of(auth_office)
		var r = actions_module.execute("HoldElection", owner,
			{"election_id": String(payload.get("election_id", "")),
				"type": etype,
				"legislature_id": String(payload.get("legislature_id", ""))},
			state, ctx)
		return {"outcome": "election_executed", "ok": bool(r["ok"]),
			"action_outcome": String(r["outcome"])}
	return {"outcome": "unknown_deadline_type"}


static func etype_of(el_rules: Dictionary) -> String:
	return String(el_rules.get("type", "general"))
