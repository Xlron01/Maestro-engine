extends RefCounted
class_name ScheduledQueue

# Job = { "entity_id": String, "job_name": String, "frequency_days": int, "next_check": int }
# ده الـ "monthly / quarterly / yearly" scheduling من وثيقة الـArchitecture (Tiered Scheduler المبسط)

var _jobs: Array = []

func register(entity_id: String, job_name: String, frequency_days: int, start_at: int) -> void:
	_jobs.append({
		"entity_id": entity_id,
		"job_name": job_name,
		"frequency_days": frequency_days,
		"next_check": start_at
	})

func get_due_jobs(current_time: int) -> Array:
	var due = []
	for job in _jobs:
		if job["next_check"] <= current_time:
			due.append(job)
	return due

func reschedule(job: Dictionary, current_time: int) -> void:
	job["next_check"] = current_time + job["frequency_days"]

func all_jobs() -> Array:
	return _jobs

func unregister(entity_id: String, job_name: String) -> void:
	for i in range(_jobs.size() - 1, -1, -1):
		var job = _jobs[i]
		if job["entity_id"] == entity_id and job["job_name"] == job_name:
			_jobs.remove_at(i)

# ============ Serialization ============
func to_dict() -> Dictionary:
	return {"jobs": _jobs.duplicate(true)}

func from_dict(d: Dictionary) -> void:
	_jobs.clear()
	for job in d.get("jobs", []):
		# int() صريح على كل الحقول الـ int — JSON.parse بتحوّلها لـ float
		_jobs.append({
			"entity_id":      str(job.get("entity_id", "")),
			"job_name":       str(job.get("job_name", "")),
			"frequency_days": int(job.get("frequency_days", 1)),
			"next_check":     int(job.get("next_check", 0)),
		})
