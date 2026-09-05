extends ScheduledQueue
class_name SchedulerProbeLite

# ============================================================
# EXPERIMENTAL — T5-C (E1) — Lightweight Scheduler Probe
# ------------------------------------------------------------
# يقيس زمن get_due_jobs فقط (استدعاءا مؤقّت لكل تكة) بلا أي بناء سلاسل
# لكل واجب — البديل الخفيف عن SchedulerProbe بعد اكتشاف فاتورته (H2).
# التقاط ترتيب التنفيذ (SEQ) يتم في العدّاء خارج التكة عبر مسح pre-tick
# خطي (PackedStringArray + join) — لا داخل get_due_jobs.
# كل الباقي delegation صرفة.
# ============================================================

var _inner: ScheduledQueue
var sched_us: int = 0
var due_count: int = 0


func init_with(inner: ScheduledQueue) -> void:
	_inner = inner


func register(entity_id: String, job_name: String, frequency_days: int, start_at: int) -> void:
	_inner.register(entity_id, job_name, frequency_days, start_at)


func get_due_jobs(current_time: int) -> Array:
	var t0 := Time.get_ticks_usec()
	var r := _inner.get_due_jobs(current_time)
	sched_us = Time.get_ticks_usec() - t0
	due_count = r.size()
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
