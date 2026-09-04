extends ScheduledQueue
class_name HeapScheduler

# ============================================================
# EXPERIMENTAL — Heap Scheduler (min-heap by next_check, stable by insertion seq)
# البديل التجريبي #2 لـ ScheduledQueue — واجهة API متطابقة تمامًا.
# الدلالات مجمدة كنظيرها: نفس مجموعات الاستحقاق، وترتيب التنفيذ = ترتيب الإدراج عند التعادل.
# الترتيب بين أيام متعددة داخل التكة الواحدة لا يتساوى بالضرورة مع baseline — لكن هذا
# لا يحدث في مسار Elbow الواحد (get_due_jobs يُنادي مرة في اليوم وليس أحداث عالقة).
#
# الموقع: تجريبي — scripts/experimental/. لا يُلمس أي ملف إنتاجي.
# ============================================================

var _exp_jobs: Array = []
var _heap: Array = []            # Array of {"day": int, "seq": int, "job": Dictionary}
var _seq := 0

func register(entity_id: String, job_name: String, frequency_days: int, start_at: int) -> void:
	var job := {
		"entity_id": entity_id,
		"job_name": job_name,
		"frequency_days": frequency_days,
		"next_check": start_at,
		"_seq": _exp_jobs.size()
	}
	_exp_jobs.append(job)
	_push(start_at, job)

func _push(day: int, job: Dictionary) -> void:
	_heap.append({"day": day, "seq": int(job["_seq"]), "job": job})
	_sift_up(_heap.size() - 1)

func _less(a: Dictionary, b: Dictionary) -> bool:
	if int(a["day"]) != int(b["day"]):
		return int(a["day"]) < int(b["day"])
	return int(a["seq"]) < int(b["seq"])

func _swap(i: int, j: int) -> void:
	var tmp: Dictionary = _heap[i]
	_heap[i] = _heap[j]
	_heap[j] = tmp

func _sift_up(i: int) -> void:
	while i > 0:
		var p := (i - 1) / 2
		if _less(_heap[i], _heap[p]):
			_swap(i, p)
			i = p
		else:
			break

func _sift_down(i: int) -> void:
	var n := _heap.size()
	while true:
		var l := 2 * i + 1
		var r := 2 * i + 2
		var m := i
		if l < n and _less(_heap[l], _heap[m]):
			m = l
		if r < n and _less(_heap[r], _heap[m]):
			m = r
		if m == i:
			break
		_swap(i, m)
		i = m

func _pop_min() -> Dictionary:
	# ({day, seq, job})
	var top: Dictionary = _heap[0]
	var last: Dictionary = _heap.pop_back()
	if _heap.size() > 0:
		_heap[0] = last
		_sift_down(0)
	return top

func get_due_jobs(current_time: int) -> Array:
	var out: Array = []
	while not _heap.is_empty() and int(_heap[0]["day"]) <= current_time:
		var e := _pop_min()
		out.append(e["job"])
	return out

func reschedule(job: Dictionary, current_time: int) -> void:
	var nxt := current_time + int(job["frequency_days"])
	job["next_check"] = nxt
	_push(nxt, job)

func unregister(entity_id: String, job_name: String) -> void:
	for i in range(_exp_jobs.size() - 1, -1, -1):
		var job: Dictionary = _jobs[i]
		if String(job["entity_id"]) == entity_id and String(job["job_name"]) == job_name:
			_exp_jobs.remove_at(i)
	# lazy: تبقى في heap كـtombstone؟ نتجنبه هنا لأن واحد-shot لا يُستخدم في عاملنا؛ فحص تسليمي:
	var rebuilt: Array = []
	for e in _heap:
		var j: Dictionary = (e as Dictionary)["job"]
		if String(j["entity_id"]) == entity_id and String(j["job_name"]) == job_name:
			continue
		rebuilt.append(e)
	_heap = rebuilt
	_heapify()

func _heapify() -> void:
	for i in range(_heap.size(), -1, -1):
		_sift_down(i)

func all_jobs() -> Array:
	return _exp_jobs

# ============ Serialization ============
func to_dict() -> Dictionary:
	return {"jobs": _exp_jobs.duplicate(true)}

func from_dict(d: Dictionary) -> void:
	_exp_jobs.clear()
	_heap.clear()
	_seq = 0
	for job in d.get("jobs", []):
		var nj := {
			"entity_id": String(job.get("entity_id", "")),
			"job_name": String(job.get("job_name", "")),
			"frequency_days": int(job.get("frequency_days", 1)),
			"next_check": int(job.get("next_check", 0)),
		}
		_exp_jobs.append(nj)
		_push(int(nj["next_check"]), nj)
