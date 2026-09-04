extends ScheduledQueue
class_name SchedulerProbe

# ============================================================
# EXPERIMENTAL — Scheduler Probe (decorator for measurement only)
# يلفّ أي Scheduler (الأصلي أو التجريبي) بخيط قياس رفيع:
#   - زمن استدعاء get_due_jobs لكل تكة (sched_us)
#   - عدد الواجبات الراجعة (due_count)
#   - توقيع تنفيذي حتمي: تسلسل (entity|job) لكل تكة، مجمّعًا بـSHA256
# صفر منطق إضافي — بعد البناء كل شيء delegation صرفة.
#
# الامتداد من ScheduledQueue ضروري فقط لتوافق نوع Simulation.scheduled المُصرَّح.
# ============================================================

var _inner: ScheduledQueue
var sched_us: int = 0
var due_count: int = 0
var per_day_seq_hash: Array = []   # String per day (sha256 of joined ids)
var _buf: Array = []


func init_with(inner: ScheduledQueue) -> void:
	_inner = inner


func register(entity_id: String, job_name: String, frequency_days: int, start_at: int) -> void:
	_inner.register(entity_id, job_name, frequency_days, start_at)


func get_due_jobs(current_time: int) -> Array:
	var t0 := Time.get_ticks_usec()
	var r := _inner.get_due_jobs(current_time)
	sched_us = Time.get_ticks_usec() - t0
	due_count = r.size()
	var sb := ""
	for j in r:
		sb += String(j["entity_id"]) + "|" + String(j["job_name"]) + ";"
	per_day_seq_hash.append(sb.sha256_text())
	return r


func reschedule(job: Dictionary, current_time: int) -> void:
	_inner.reschedule(job, current_time)


func unregister(entity_id: String, job_name: String) -> void:
	_inner.unregister(entity_id, job_name)


func all_jobs() -> Array:
	return _inner.all_jobs()


func to_dict() -> Dictionary:
	return _inner.to_dict()


func from_dict(d: Dictionary) -> void:
	_inner.from_dict(d)
