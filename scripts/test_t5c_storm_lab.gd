extends SceneTree

# ============================================================
# T5-C — STORM LAB (مسار تجريبي معزول — صفر تعديل إنتاجي)
# ------------------------------------------------------------
# الاستدعاء:
#   --phase=e0        الأساس الرسمي: --scheduler=current|bucket --probe=on|off --days=90
#   --phase=decompose تفكيك مراحل العاصفة: --scheduler=current|bucket --days=90
#   --phase=negctl    ضابط سلبي day-shift: --variant=m29|m31|spread --days=35
# الحمل الحقيقي حصرًا: data/scenarios/t5_p0 (10K دولة، 40,002 jobs، seed=12345).
#
# بوابات مجمّدة (من T5-B — 90 يومًا):
#   SEM_HASH=bcd2763c957c1c21f73cf8e0f637fa81e1ca8d76eb3354feb20f63108956c2b4
#   SEQ_HASH=795365ba15cf63228be9d7672e36cad4dff9cd6ef938114c6e402d93a9c5b89d
#   COUNTERS events=30104 coup=6000 exposure=0
# أي اختلاف = FAIL موثق (البوابات تُطبق على تشغيلات 90 يومًا فقط).
#
# درس H2: التقاط SEQ يتم خارج التكة (مسح pre-tick خطي عبر PackedStringArray)
# لا داخل get_due_jobs — وprobe=off يعني بلا أي غلاف إطلاقًا.
# ============================================================

const SimScript := preload("res://scripts/Simulation.gd")
const Bucket := preload("res://scripts/experimental/bucket_scheduler.gd")
const HeavyProbe := preload("res://scripts/experimental/scheduler_probe.gd")
const LiteProbe := preload("res://scripts/experimental/scheduler_probe_lite.gd")
const EQProbe := preload("res://scripts/experimental/event_queue_probe.gd")
const SlicedRunnerScript := preload("res://scripts/experimental/sliced_runner.gd")
const BatchedEQ := preload("res://scripts/experimental/batched_event_queue.gd")

const DATA_ROOT := "res://data/scenarios/t5_p0"
const SEED := 12345

const GATE_SEM := "bcd2763c957c1c21f73cf8e0f637fa81e1ca8d76eb3354feb20f63108956c2b4"
const GATE_SEQ := "795365ba15cf63228be9d7672e36cad4dff9cd6ef938114c6e402d93a9c5b89d"
const GATE_EVENTS := 30104
const GATE_COUP := 6000
const GATE_EXPOSURE := 0

class TimedHandler extends RefCounted:
	# غلاف قياس لمكالمة handler واحدة (job أو event) — بديل توقيتان لكل نداء.
	var fn: Callable
	var calls: int = 0
	var us: int = 0

	func invoke(a, b) -> void:
		var t0 := Time.get_ticks_usec()
		fn.call(a, b)
		us += Time.get_ticks_usec() - t0
		calls += 1

var sim
var phase := "e0"
var sched_mode := "current"
var probe_mode := "off"
var days := 90
var variant := ""
var slice_size := 5000

var heavy_probe = null          # SchedulerProbe (وصفة T5-B الحرفية) في e0/probe=on
var lite_probe = null           # SchedulerProbeLite في decompose
var eq_probe = null             # EventQueueProbe في decompose
var batched_eq = null           # BatchedEventQueue في c1
var runner = null               # SlicedRunner في c2
var _job_timers := {}           # job_name -> TimedHandler
var _evt_timers := {}           # event_type -> TimedHandler
var _last_scan_due := 0         # عدد الواجبات من مسح pre-tick (خارج التوقيت)


func _parse_args() -> void:
	var raw: Array = OS.get_cmdline_args()
	raw.append_array(OS.get_cmdline_user_args())
	for a in raw:
		var s := String(a)
		if s.begins_with("--phase="):
			phase = s.split("=")[1]
		elif s.begins_with("--scheduler="):
			sched_mode = s.split("=")[1]
		elif s.begins_with("--probe="):
			probe_mode = s.split("=")[1]
		elif s.begins_with("--days="):
			days = int(s.split("=")[1])
		elif s.begins_with("--variant="):
			variant = s.split("=")[1]
		elif s.begins_with("--slice="):
			slice_size = int(s.split("=")[1])


func _init() -> void:
	_parse_args()
	var raw_args: Array = OS.get_cmdline_args()
	raw_args.append_array(OS.get_cmdline_user_args())
	print("")
	print("============================================================")
	print("  T5-C STORM LAB | phase=%s scheduler=%s probe=%s days=%d variant=%s"
		% [phase, sched_mode, probe_mode, days, variant])
	print("  args=%s" % [str(raw_args)])
	print("============================================================")

	sim = SimScript.new()
	sim.data_root_override = DATA_ROOT
	sim.init_world(SEED)
	if sim.world.countries.is_empty():
		print("[FATAL] empty world")
		quit(2)
		return

	var capture_seq := true
	if phase == "e0":
		if probe_mode == "on":
			heavy_probe = _attach_probe(sched_mode)
			capture_seq = false  # الـheavy probe يلتقط SEQ بنفسه (وصفة T5-B)
		else:
			_attach_plain(sched_mode)
	elif phase == "decompose":
		_attach_decompose(sched_mode)
	elif phase == "negctl":
		_attach_plain("current")
		_apply_shift(variant)
	elif phase == "c2":
		_attach_plain(sched_mode)
		runner = SlicedRunnerScript.new()
		runner.sim = sim
		runner.slice_size = slice_size
		print("SLICE runner=sliced slice_size=%d scheduler=%s" % [slice_size, sched_mode])
	elif phase == "c1":
		_attach_plain(sched_mode)
		batched_eq = BatchedEQ.new()
		batched_eq.from_dict(sim.events.to_dict())
		sim.events = batched_eq
		print("C1 batched_event_queue attached | scheduler=%s" % sched_mode)
	else:
		print("[FATAL] unknown phase=%s" % phase)
		quit(2)
		return

	print("world=%d jobs=%d t0 done" % [sim.world.countries.size(), sim.scheduled.all_jobs().size()])

	var tick_times: Array = []
	var events_last: int = sim.events_processed_count
	var seq_parts := PackedStringArray()

	for day_i in days:
		var day_num: int = day_i + 1
		var t_next: int = sim.clock.total_days() + 1

		if capture_seq:
			seq_parts.append(_capture_day_seq(t_next).sha256_text())

		var snap := _snapshot_timers()
		var t0 := 0
		var tick_us := 0
		var max_frame_us := 0
		var frames := 0
		if phase == "c2":
			t0 = Time.get_ticks_usec()
			runner.begin_day()
			while runner.has_work():
				var f0 := Time.get_ticks_usec()
				runner.run_frame()
				var fus := Time.get_ticks_usec() - f0
				if fus > max_frame_us:
					max_frame_us = fus
				frames += 1
			tick_us = Time.get_ticks_usec() - t0
		else:
			t0 = Time.get_ticks_usec()
			sim.run_step()
			tick_us = Time.get_ticks_usec() - t0
		tick_times.append(tick_us)

		var ev: int = sim.events_processed_count - events_last
		events_last = sim.events_processed_count

		var mem := ""
		if day_num % 10 == 0:
			mem = str(OS.get_static_memory_usage())

		if phase == "decompose":
			var dbg0 := Time.get_ticks_usec()
			sim.get_debug_info()
			var dbg_est := Time.get_ticks_usec() - dbg0
			var d := _phase_delta(snap, tick_us, dbg_est)
			print("day=%03d tick_us=%d sched_us=%d due=%d jobs_us=%d eqp_us=%d eqo_us=%d evh_us=%d resid_us=%d dbg_est_us=%d ev_d+%d mem=%s"
				% [day_num, tick_us, d["sched_us"], d["due"], d["jobs_us"], d["eqp_us"],
					d["eqo_us"], d["evh_us"], d["resid"], dbg_est, ev, mem])
			if day_num % 30 == 0:
				_print_storm_detail(day_num, d)
		elif phase == "c2":
			var mean_frame := float(tick_us) / float(maxi(frames, 1))
			print("day=%03d semantic_tick_us=%d frames=%d max_frame_us=%d mean_frame_us=%.1f due=%d events_d+%d mem=%s"
				% [day_num, tick_us, frames, max_frame_us, mean_frame, _last_scan_due, ev, mem])
			if day_num % 30 == 0:
				print("STORM_FRAME day=%03d semantic_tick_us=%d max_frame_us=%d budget30_pct_max_frame=%.1f%% frames=%d"
					% [day_num, tick_us, max_frame_us, 100.0 * float(max_frame_us) / 30000000.0, frames])
		else:
			var sched_us: int = heavy_probe.sched_us if heavy_probe != null else 0
			var due: int = heavy_probe.due_count if heavy_probe != null else _last_scan_due
			print("day=%03d tick_us=%d sched_us=%d due=%d events_d+%d mem=%s"
				% [day_num, tick_us, sched_us, due, ev, mem])

	_report(tick_times)
	_report_gates(seq_parts)
	print("=== END phase=%s scheduler=%s probe=%s days=%d variant=%s ==="
		% [phase, sched_mode, probe_mode, days, variant])
	quit(0)


# ---------------- الربط (أنماط T5-B الحرفية) ----------------

func _attach_plain(p_mode: String) -> void:
	# بلا أي غلاف: current يبقى كائن الإنتاج كما هو؛ bucket يُحقن بالتحويل فقط.
	if p_mode == "bucket":
		var target = Bucket.new()
		_transfer(target)
		sim.scheduled = target


func _attach_probe(p_mode: String):
	if p_mode == "bucket":
		var target = Bucket.new()
		_transfer(target)
		var p = HeavyProbe.new()
		p._inner = target
		sim.scheduled = p
		return p
	var p2 = HeavyProbe.new()
	p2._inner = sim.scheduled
	sim.scheduled = p2
	return p2


func _attach_decompose(p_mode: String) -> void:
	# 1) مجدول بغلاف خفيف (توقيت فقط — بلا سلاسل لكل واجب)
	if p_mode == "bucket":
		var target = Bucket.new()
		_transfer(target)
		lite_probe = LiteProbe.new()
		lite_probe._inner = target
	else:
		lite_probe = LiteProbe.new()
		lite_probe._inner = sim.scheduled
	sim.scheduled = lite_probe
	# 2) طابور أحداث بغلاف قياس (حقن post-init — أحداث السيناريو فقط قبل أول تكة)
	eq_probe = EQProbe.new()
	eq_probe.from_dict(sim.events.to_dict())
	sim.events = eq_probe
	# 3) لفّ handlers على مستوى العدّاء (طبقة المحتوى — إضافة قياس فقط)
	_wrap_handlers()


func _transfer(target) -> void:
	for job in sim.scheduled.all_jobs():
		target.register(String(job["entity_id"]), String(job["job_name"]),
			int(job["frequency_days"]), int(job["next_check"]))


func _wrap_handlers() -> void:
	var new_jobs := {}
	for jname in sim._job_handlers.keys():
		var entry: Dictionary = sim._job_handlers[jname]
		var th := TimedHandler.new()
		th.fn = entry["fn"]
		_job_timers[String(jname)] = th
		new_jobs[String(jname)] = {"fn": Callable(th, "invoke"), "one_shot": entry["one_shot"]}
	sim._job_handlers = new_jobs
	var new_evts := {}
	for etype in sim._event_handlers.keys():
		var th2 := TimedHandler.new()
		th2.fn = sim._event_handlers[etype]
		_evt_timers[String(etype)] = th2
		new_evts[String(etype)] = Callable(th2, "invoke")
	sim._event_handlers = new_evts


func _apply_shift(p_variant: String) -> void:
	var shifted := 0
	for job in sim.scheduled.all_jobs():
		if String(job["job_name"]) == "population_update":
			if p_variant == "m29":
				job["next_check"] = 29
			elif p_variant == "m31":
				job["next_check"] = 31
			elif p_variant == "spread":
				var cid := String(job["entity_id"])
				var idx := int(cid.substr(1)) if cid.length() > 1 else 0
				job["next_check"] = 1 + (idx % 30)
			else:
				print("[FATAL] unknown variant=%s" % p_variant)
				quit(2)
				return
			shifted += 1
	print("SHIFT variant=%s population_update jobs shifted=%d" % [p_variant, shifted])


# ---------------- التقاط SEQ خارج التكة (خطي) ----------------

func _capture_day_seq(t_next: int) -> String:
	# current: ترتيب _jobs نفسه = ترتيب التنفيذ.
	# bucket: نفس مجموعة الواجبات مرتبة بـ_seq (مطابق لفرز get_due_jobs).
	var jobs: Array = sim.scheduled.all_jobs()
	var due: Array = []
	var seq_key := false
	for job in jobs:
		if int(job["next_check"]) <= t_next:
			due.append(job)
			if job.has("_seq"):
				seq_key = true
	if seq_key:
		due.sort_custom(func(a, b): return int(a["_seq"]) < int(b["_seq"]))
	_last_scan_due = due.size()
	var parts := PackedStringArray()
	for j in due:
		parts.append(String(j["entity_id"]) + "|" + String(j["job_name"]) + ";")
	return "".join(parts)


# ---------------- تفكيك المراحل (decompose) ----------------

func _snapshot_timers() -> Dictionary:
	var s := {"eq_push_us": 0, "eq_push_n": 0, "eq_pop_us": 0, "eq_pop_n": 0, "eq_hasdue_us": 0}
	if eq_probe != null:
		s["eq_push_us"] = eq_probe.push_us
		s["eq_push_n"] = eq_probe.push_count
		s["eq_pop_us"] = eq_probe.pop_us
		s["eq_pop_n"] = eq_probe.pop_count
		s["eq_hasdue_us"] = eq_probe.hasdue_us
	var jt := {}
	for k in _job_timers:
		jt[k] = [_job_timers[k].calls, _job_timers[k].us]
	var et := {}
	for k in _evt_timers:
		et[k] = [_evt_timers[k].calls, _evt_timers[k].us]
	s["jobs"] = jt
	s["evts"] = et
	return s


func _phase_delta(snap: Dictionary, tick_us: int, dbg_est: int) -> Dictionary:
	var d := {}
	d["tick_us"] = tick_us
	d["dbg_est"] = dbg_est
	d["sched_us"] = lite_probe.sched_us if lite_probe != null else 0
	d["due"] = lite_probe.due_count if lite_probe != null else -1
	var eqp_us: int = eq_probe.push_us - int(snap["eq_push_us"])
	var eqo_us: int = (eq_probe.pop_us - int(snap["eq_pop_us"])) + (eq_probe.hasdue_us - int(snap["eq_hasdue_us"]))
	var push_n: int = eq_probe.push_count - int(snap["eq_push_n"])
	var pop_n: int = eq_probe.pop_count - int(snap["eq_pop_n"])
	var jobs_us := 0
	var job_detail := {}
	for k in _job_timers:
		var prev: Array = snap["jobs"][k]
		var du: int = _job_timers[k].us - int(prev[1])
		var dc: int = _job_timers[k].calls - int(prev[0])
		if dc > 0:
			job_detail[k] = {"calls": dc, "us": du}
			jobs_us += du
	var evh_us := 0
	var evt_detail := {}
	for k in _evt_timers:
		var prev2: Array = snap["evts"][k]
		var du2: int = _evt_timers[k].us - int(prev2[1])
		var dc2: int = _evt_timers[k].calls - int(prev2[0])
		if dc2 > 0:
			evt_detail[k] = {"calls": dc2, "us": du2}
			evh_us += du2
	d["eqp_us"] = eqp_us
	d["eqo_us"] = eqo_us
	d["push_n"] = push_n
	d["pop_n"] = pop_n
	d["jobs_us"] = jobs_us
	d["job_detail"] = job_detail
	d["evh_us"] = evh_us
	d["evt_detail"] = evt_detail
	d["resid"] = int(d["tick_us"]) - int(d["sched_us"]) - jobs_us - eqp_us - eqo_us - evh_us
	return d

func _print_storm_detail(day_num: int, d: Dictionary) -> void:
	var total := int(d["tick_us"])
	print("DETAIL day=%03d total_us=%d" % [day_num, total])
	print("  sched_scan_us=%d (%.1f%%) due=%d" % [int(d["sched_us"]), _pct(d["sched_us"], total), int(d["due"])])
	print("  jobs_us=%d (%.1f%%) pushes=%d eq_push_us=%d (%.1f%%) eq_pop_us=%d (%.1f%%)"
		% [int(d["jobs_us"]), _pct(d["jobs_us"], total), int(d["push_n"]),
			int(d["eqp_us"]), _pct(d["eqp_us"], total), int(d["eqo_us"]), _pct(d["eqo_us"], total)])
	print("  event_handlers_us=%d (%.1f%%) residual_us=%d (%.1f%%) dbg_est_us=%d"
		% [int(d["evh_us"]), _pct(d["evh_us"], total), int(d["resid"]), _pct(d["resid"], total), int(d["dbg_est"])])
	var names: Array = d["job_detail"].keys()
	names.sort()
	for k in names:
		var j: Dictionary = d["job_detail"][k]
		print("    job %-22s calls=%-6d us=%d" % [k, int(j["calls"]), int(j["us"])])
	var enames: Array = d["evt_detail"].keys()
	enames.sort()
	for k in enames:
		var e: Dictionary = d["evt_detail"][k]
		print("    evt %-28s calls=%-6d us=%d" % [k, int(e["calls"]), int(e["us"])])
	if eq_probe != null:
		var avg: float = 0.0
		if eq_probe.push_count > 0:
			avg = float(eq_probe.sum_array_at_push) / float(eq_probe.push_count)
		print("  EQ stats: push_max_arr=%d push_avg_arr=%.1f ties_consecutive=%d"
			% [eq_probe.max_array_at_push, avg, eq_probe.ties])


func _pct(part, total) -> float:
	if int(total) <= 0:
		return 0.0
	return 100.0 * float(part) / float(total)


# ---------------- التقارير والبوابات ----------------

func _report(ticks: Array) -> void:
	var sorted_ticks := ticks.duplicate()
	sorted_ticks.sort()
	var n := sorted_ticks.size()
	var total: int = 0
	for v in ticks:
		total += int(v)
	var mean := float(total) / float(n)
	print("STATS total_us=%d mean_us=%.1f p50_us=%d p95_us=%d p99_us=%d max_us=%d"
		% [total, mean, int(sorted_ticks[n / 2]), int(sorted_ticks[int(n * 0.95)]),
			int(sorted_ticks[int(n * 0.99)]), int(sorted_ticks[n - 1])])


func _report_gates(seq_parts: PackedStringArray) -> void:
	var sem := _canon_world().sha256_text()
	print("SEM_HASH=" + sem)
	if seq_parts.size() > 0:
		print("SEQ_HASH=" + ("".join(seq_parts)).sha256_text())
	elif heavy_probe != null:
		print("SEQ_HASH=" + ("".join(heavy_probe.per_day_seq_hash)).sha256_text())
	print("COUNTERS events=%d coup=%d exposure=%d"
		% [sim.events_processed_count, sim.coup_evaluations_count, sim.exposure_propagation_count])
	if days == 90:
		print("GATE sem=%s seq=%s counters=%s"
			% [_gate_str(sem == GATE_SEM),
				_gate_str(_seq_hash_available(seq_parts) == GATE_SEQ),
				_gate_str(sim.events_processed_count == GATE_EVENTS
					and sim.coup_evaluations_count == GATE_COUP
					and sim.exposure_propagation_count == GATE_EXPOSURE)])
	if eq_probe != null:
		var avg: float = 0.0
		if eq_probe.push_count > 0:
			avg = float(eq_probe.sum_array_at_push) / float(eq_probe.push_count)
		print("EVENT_DIAG pushes=%d pops=%d ties=%d max_arr=%d avg_arr=%.1f EVENT_SEQ_HASH=%s"
			% [eq_probe.push_count, eq_probe.pop_count, eq_probe.ties,
				eq_probe.max_array_at_push, avg, eq_probe.event_seq_hash()])
	if batched_eq != null:
		print("C1_DIAG pushes=%d pops=%d sorts=%d sort_us=%d EVENT_SEQ_HASH=%s"
			% [batched_eq.push_count, batched_eq.pop_count, batched_eq.sort_count,
				batched_eq.sort_us, batched_eq.event_seq_hash()])
	# عدادات طبقة المحتوى (T5-P0) — معلوماتية
	var ds: Dictionary = sim._content_handlers.decision_counters
	print("CONTENT_DIAG DS_calls=%d DS_us=%d" % [int(ds["evaluate_calls"]) + int(ds["apply_calls"]) + int(ds["coup_eval_calls"]), int(ds["total_us"])])


func _seq_hash_available(seq_parts: PackedStringArray) -> String:
	if seq_parts.size() > 0:
		return ("".join(seq_parts)).sha256_text()
	if heavy_probe != null:
		return ("".join(heavy_probe.per_day_seq_hash)).sha256_text()
	return ""


func _gate_str(ok: bool) -> String:
	return "PASS" if ok else "FAIL"


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
