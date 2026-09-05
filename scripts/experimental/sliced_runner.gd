extends RefCounted
class_name SlicedRunner

# ============================================================
# EXPERIMENTAL — T5-C (C2) — Sliced Runner (توزيع wall-clock داخل التكة)
# ------------------------------------------------------------
# منفّذ ظل يكرر حلقة Simulation.run_step() بندًا بندًا (مرجع: Simulation.gd
# run_step) مع checkpoint كل slice_size عنصر عمل (وظيفة/حدث).
# العقد الدلالي: زمن المحاكاة لا يتقدم (clock.advance_day مرة واحدة في
# begin_day) حتى يكتمل كل عمل اليوم — كل وظائف اليوم N ترى حالة بداية
# اليوم N وبنفس الترتيب (نفس due list، نفس ترتيب الصرف).
# ⇒ Semantic tick duration ≠ Wall-clock frame duration: هذا التوزيع
#   يحدّ زمن كل frame ولا يقلّص الزمن الكلي للعاصفة.
# صفر تعديل على النواة — يعمل عبر الأعضاء العامة/الخاصة لنسخة sim حية.
# step_completed.emit متروك (لا مشتركين في القياسات) — موثق بوصفه
# انحرافًا تشغيليًا لا دلاليًا، والبوابة هي تطابق SEM/SEQ/counters bitwise.
# ============================================================

var sim: Node
var slice_size: int = 5000

var _stage := "idle"            # idle | jobs | events
var _due_t: int = 0
var _pending_jobs: Array = []
var _job_idx: int = 0


func begin_day() -> void:
	# المطابق لبداية run_step: advance_day ثم clear activation ثم get_due_jobs.
	sim.clock.advance_day()
	_due_t = sim.clock.total_days()
	sim.activation.clear()
	_pending_jobs = sim.scheduled.get_due_jobs(_due_t).duplicate()
	_job_idx = 0
	_stage = "jobs" if _pending_jobs.size() > 0 else "events"


func has_work() -> bool:
	return _stage != "idle"


# ينفّذ حتى slice_size عنصر عمل ويرجع ما نُفّذ فعليًا في هذا frame.
func run_frame() -> int:
	var done := 0
	if _stage == "jobs":
		while _job_idx < _pending_jobs.size() and done < slice_size:
			var job: Dictionary = _pending_jobs[_job_idx]
			sim._run_scheduled_job(job, _due_t)
			var spec: Dictionary = sim._job_handlers.get(job["job_name"], {})
			if spec.get("one_shot", false):
				sim.scheduled.unregister(job["entity_id"], job["job_name"])
			else:
				sim.scheduled.reschedule(job, _due_t)
			_job_idx += 1
			done += 1
		if _job_idx >= _pending_jobs.size():
			_stage = "events"
	if _stage == "events" and done < slice_size:
		while sim.events.has_due_events(_due_t) and done < slice_size:
			var e: Dictionary = sim.events.pop_next()
			sim.events_processed_count += 1
			sim.last_event_type = e["type"]
			sim._process_event(e, _due_t)
			done += 1
		if not sim.events.has_due_events(_due_t):
			_finish_day()
	return done


func _finish_day() -> void:
	# المطابق لذيل run_step (سجل الـactivation المحدود بـ200).
	if sim.activation.active_count() > 0:
		sim.activation_log.append({
			"day": _due_t,
			"active_ids": sim.activation.active_ids().duplicate()
		})
		if sim.activation_log.size() > sim.ACTIVATION_LOG_CAP:
			sim.activation_log.pop_front()
	_stage = "idle"
