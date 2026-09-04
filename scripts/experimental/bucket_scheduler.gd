extends ScheduledQueue
class_name BucketScheduler

# ============================================================
# EXPERIMENTAL — Bucket Scheduler (day-indexed)
# الوراثة من ScheduledQueue لأسباب توافق النوع فقط (Simulation.scheduled مُصرَّح به
# بالنوع المحدد). وظيفيًا نُلغي كل التخزين الأصلي ونحل محله تخزيننا —
# جميع الدوال مجتازة بالكامل، والملف الإنتاجي `scripts/ScheduledQueue.gd` لم يُمسّ حرفة واحدة.
# ============================================================

var _exp_jobs: Array = []        # ترتيب الإدراج (نظير _jobs في baseline)
var _buckets: Dictionary = {}    # day:int -> Array[{"job","seq"}]
var _seq := 0

func register(entity_id: String, job_name: String, frequency_days: int, start_at: int) -> void:
	var job := {
		"entity_id": entity_id,
		"job_name": job_name,
		"frequency_days": frequency_days,
		"next_check": start_at,
		"_seq": _seq
	}
	_exp_jobs.append(job)
	_put_in_bucket(job, start_at)

func _put_in_bucket(job: Dictionary, day: int) -> void:
	if not _buckets.has(day):
		_buckets[day] = []
	(_buckets[day] as Array).append({"job": job, "seq": int(job["_seq"])})
	_seq += 1

func get_due_jobs(current_time: int) -> Array:
	var days := _buckets.keys()
	if days.is_empty():
		return []
	days.sort()
	var due: Array = []
	for d in days:
		var dd := int(d)
		if dd > current_time:
			break
		for entry in (_buckets[dd] as Array):
			due.append(entry)
		_buckets.erase(dd)
	# الحفاظ على ترتيب baseline العالمي: الدمج مرتب بـ seq (رقم الإدراج العالمي)
	due.sort_custom(func(a, b): return int(a["seq"]) < int(b["seq"]))
	var out: Array = []
	for entry in due:
		out.append(entry["job"])
	return out

func reschedule(job: Dictionary, current_time: int) -> void:
	var nxt := current_time + int(job["frequency_days"])
	job["next_check"] = nxt
	if not _buckets.has(nxt):
		_buckets[nxt] = []
	(_buckets[nxt] as Array).append({"job": job, "seq": int(job["_seq"])})

func unregister(entity_id: String, job_name: String) -> void:
	for i in range(_exp_jobs.size() - 1, -1, -1):
		var job: Dictionary = _exp_jobs[i]
		if String(job["entity_id"]) == entity_id and String(job["job_name"]) == job_name:
			_exp_jobs.remove_at(i)

func all_jobs() -> Array:
	return _exp_jobs

# ============ Serialization ============
func to_dict() -> Dictionary:
	return {"jobs": _exp_jobs.duplicate(true)}

func from_dict(d: Dictionary) -> void:
	_exp_jobs.clear()
	_buckets.clear()
	for job in d.get("jobs", []):
		var nj := {
			"entity_id": String(job.get("entity_id", "")),
			"job_name": String(job.get("job_name", "")),
			"frequency_days": int(job.get("frequency_days", 1)),
			"next_check": int(job.get("next_check", 0)),
		}
		_exp_jobs.append(nj)
		_put_in_bucket(nj, int(nj["next_check"]))
