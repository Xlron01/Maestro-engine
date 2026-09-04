extends SceneTree

# تشخيص تسلسلي حتمي — get_due_jobs لـ t=1/30 بدون تشغيل المحرك.
const SimScript := preload("res://scripts/Simulation.gd")
const Bucket := preload("res://scripts/experimental/bucket_scheduler.gd")
const Heap := preload("res://scripts/experimental/heap_scheduler.gd")
const DATA_ROOT := "res://data/scenarios/t5_p0"


func _init() -> void:
	var sim = SimScript.new()
	sim.data_root_override = DATA_ROOT
	sim.init_world(12345)
	var base: ScheduledQueue = sim.scheduled
	var bu := Bucket.new()
	var he := Heap.new()
	for job in base.all_jobs():
		var jid := String(job["entity_id"]); var jn := String(job["job_name"])
		var freq := int(job["frequency_days"]); var nc := int(job["next_check"])
		bu.register(jid, jn, freq, nc)
		he.register(jid, jn, freq, nc)
	for t in [1, 30]:
		var ref := _fresh_ref(base)
		var a: Array = ref.get_due_jobs(t)
		var b := bu.get_due_jobs(t)
		var h := he.get_due_jobs(t)
		print("t=%d counts base=%d bucket=%d heap=%d" % [t, a.size(), b.size(), h.size()])
		var order_ok := true
		var first := ""
		if a.size() != b.size():
			order_ok = false
		else:
			for i in a.size():
				var ka := "%s|%s" % [String(a[i]["entity_id"]), String(a[i]["job_name"])]
				var kb := "%s|%s" % [String(b[i]["entity_id"]), String(b[i]["job_name"])]
				if ka != kb:
					order_ok = false
					first = "%d: %s vs %s" % [i, ka, kb]
					break
		print("t=%d bucket-order==baseline-order: %s %s" % [t, order_ok, first])
		# نفس المقارنة للـ Heap:
		var order_h := true
		var firsth := ""
		if a.size() != h.size():
			order_h = false
		else:
			for i in a.size():
				var ka2 := "%s|%s" % [String(a[i]["entity_id"]), String(a[i]["job_name"])]
				var kh2 := "%s|%s" % [String(h[i]["entity_id"]), String(h[i]["job_name"])]
				if ka2 != kh2:
					order_h = false
					firsth = "%d: %s vs %s" % [i, ka2, kh2]
					break
		print("t=%d heap-order==baseline-order: %s %s" % [t, order_h, firsth])
		# الحالة العكسية: الـ get_due_jobs لـbucket/heap تحرق البوابات — أعد البناء للحصّة التالية
		if t == 1:
			# تعاد بناء bucket/heap من الصفر عشان t=30 يرى نفس الحالة المتوقعة (الواجبات القشرية تُعاد تسجيل)
			bu = Bucket.new()
			he = Heap.new()
			for job in base.all_jobs():
				var jid := String(job["entity_id"]); var jn := String(job["job_name"])
				var freq := int(job["frequency_days"]); var nc := int(job["next_check"])
				bu.register(jid, jn, freq, nc)
				he.register(jid, jn, freq, nc)
	quit(0)


func _fresh_ref(base) -> ScheduledQueue:
	var ref := ScheduledQueue.new()
	for job in base.all_jobs():
		ref.register(String(job["entity_id"]), String(job["job_name"]),
			int(job["frequency_days"]), int(job["next_check"]))
	return ref


func _purge(sch: Variant, _t: int) -> bool:
	return true
