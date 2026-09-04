extends SceneTree

# ============================================================
# T5-B — EXPERIMENTAL SCHEDULER BENCHMARK (Current vs Bucket vs Heap)
# الاستدعاء: --scheduler=current|bucket|heap
# حمل حقيقي عبر t5_p0 dataset + نفس Simulation/Handlers، صفر تعديل إنتاجي.
# ============================================================

const SimScript := preload("res://scripts/Simulation.gd")
const Bucket := preload("res://scripts/experimental/bucket_scheduler.gd")
const Heap := preload("res://scripts/experimental/heap_scheduler.gd")
const Probe := preload("res://scripts/experimental/scheduler_probe.gd")
const DATA_ROOT := "res://data/scenarios/t5_p0"
const N_DAYS := 90
const SEED := 12345

var mode := "current"
var sim
var probe


func _init() -> void:
	for a in OS.get_cmdline_args():
		if String(a).begins_with("--scheduler="):
			mode = String(a).split("=")[1]
	print("")
	print("============================================================")
	print("  T5-B SCHEDULER BENCHMARK | mode=%s | N=%d" % [mode, N_DAYS])
	print("============================================================")

	sim = SimScript.new()
	sim.data_root_override = DATA_ROOT
	sim.init_world(SEED)
	if sim.world.countries.is_empty():
		print("[FATAL] empty world")
		quit(2)
		return

	if mode == "bucket":
		probe = _transfer(Bucket.new())
	elif mode == "heap":
		probe = _transfer(Heap.new())
	else:
		probe = _wrap_current()
	sim.scheduled = probe

	print("world=%d jobs=%d t0 done" % [sim.world.countries.size(), probe.all_jobs().size()])

	var tick_times: Array = []
	var events_last := 0
	for day in N_DAYS:
		var t0 := Time.get_ticks_usec()
		sim.run_step()
		var tick_us := Time.get_ticks_usec() - t0
		tick_times.append(tick_us)
		var events_after: int = sim.events_processed_count
		var ev: int = events_after - events_last
		events_last = sim.events_processed_count
		var mem := ""
		if (day + 1) % 10 == 0:
			mem = str(OS.get_static_memory_usage())
		print("day=%03d tick_us=%d sched_us=%d due=%d events_d+%d mem=%s"
			% [day + 1, tick_us, probe.sched_us, probe.due_count, ev, mem])

	_report(tick_times)

	var world_hash := _canon_world().sha256_text()
	print("SEM_HASH=" + world_hash)
	print("SEQ_HASH=" + ("".join(probe.per_day_seq_hash)).sha256_text())
	print("COUNTERS events=%d coup=%d exposure=%d"
		% [sim.events_processed_count, sim.coup_evaluations_count, sim.exposure_propagation_count])
	print("=== END mode=%s ===" % mode)
	quit(0)


func _wrap_current():
	var p = Probe.new()
	p._inner = sim.scheduled
	return p


func _transfer(target):
	var p = Probe.new()
	p._inner = target
	for job in sim.scheduled.all_jobs():
		target.register(String(job["entity_id"]), String(job["job_name"]),
			int(job["frequency_days"]), int(job["next_check"]))
	return p


func _report(ticks: Array) -> void:
	ticks.sort()
	var n := ticks.size()
	var total: int = 0
	for v in ticks:
		total += int(v)
	var mean := float(total) / float(n)
	var p50 := float(ticks[n / 2])
	var p95 := float(ticks[int(n * 0.95)])
	var p99 := float(ticks[int(n * 0.99)])
	print("STATS total_us=%d mean_us=%.1f p50_us=%d p95_us=%d p99_us=%d max_us=%d"
		% [total, mean, p50, p95, p99, int(ticks[n - 1])])


func _canon_world() -> String:
	return JSON.stringify(_sort_rec(sim.world.to_dict()))


func _sort_rec(v):
	if v is Dictionary:
		var keys := (v as Dictionary).keys()
		keys.sort()
		var o := {}
		for k in keys:
			o[k] = _sort_rec(v[k])
		return o
	if v is Array:
		var arr: Array = []
		for x in v:
			arr.append(_sort_rec(x))
		return arr
	return v