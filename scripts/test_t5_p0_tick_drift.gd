extends SceneTree

# ============================================================
# T5-P0 — Tick-Drift Characterization (Production Path)
# N=10,000 entities · 100 days عبر SimClock الحقيقي + run_step()
# Systems: كل المسجَّل فعليًا (economy_tick + economy_v2_tick + default jobs)
# Characterization gate — لا PASS/FAIL تلقائي.
# ============================================================

const SimScript := preload("res://scripts/Simulation.gd")
const DATA_ROOT := "res://data/scenarios/t5_p0"
const N_DAYS := 30
const WARMUP := 10
const BASELINE_START := 11
const BASELINE_END := 30
const HARD_STOP_US := 30_000_000  # 30s per tick

var sim
var days := []          # Array[{"t","tick_us","jobs","prod","cons","shortage","invest","mem"}]


func _median(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var a := arr.duplicate()
	a.sort()
	var n := a.size()
	if n % 2 == 1:
		return float(a[n / 2])
	return (float(a[n / 2 - 1]) + float(a[n / 2])) / 2.0


func _init() -> void:
	print("=== T5-P0 TICK-DRIFT CHARACTERIZATION START ===")
	print("data_root=%s | N_days=%d" % [DATA_ROOT, N_DAYS])

	sim = SimScript.new()
	sim.data_root_override = DATA_ROOT
	sim.init_world(12345)   # نفس الinit_world الذي يستدعيه _ready — مسار الإنتاج الحقيقي

	if sim.world == null or sim.world.countries.is_empty():
		print("[FATAL] init_world failed or empty world")
		quit(2)
		return

	print("world countries=%d | jobs_registered=%d"
		% [sim.world.countries.size(), sim.scheduled.all_jobs().size()])

	var econ = sim._content_handlers.get("_economy") if sim._content_handlers != null else null
	var econ_v2 = sim._content_handlers.get("_economy_v2") if sim._content_handlers != null else null

	for day in range(N_DAYS):
		var t0 := Time.get_ticks_usec()
		sim.run_step()
		var t1 := Time.get_ticks_usec()
		var tick_us := t1 - t0

		var c1 = econ.get("activity_counters").duplicate() if econ != null else {}
		var c2 = econ_v2.get("activity_counters").duplicate() if econ_v2 != null else {}
		var prod = int(c1.get("production_updates", 0)) + int(c2.get("production_updates", 0))
		var cons = int(c1.get("consumption_updates", 0)) + int(c2.get("consumption_updates", 0))
		var short = int(c1.get("shortage_events", 0)) + int(c2.get("shortage_events", 0))
		var invest = int(c1.get("investment_triggers", 0))
		var dc = sim._content_handlers.get("decision_counters").duplicate() if sim._content_handlers != null else {}
		var dec_calls = int(dc.get("evaluate_calls", 0)) + int(dc.get("apply_calls", 0)) + int(dc.get("coup_eval_calls", 0))
		var dec_us = int(dc.get("total_us", 0))

		var mem := -1
		if day % 10 == 9:  # نهاية نافذة 10 أيام
			mem = OS.get_static_memory_usage()

		days.append({
			"t": sim.clock.total_days(), "tick_us": tick_us,
			"prod": prod, "cons": cons, "shortage": short,
			"invest": invest, "mem": mem
		})

		print("day=%03d t=%03d tick_us=%d prod=%d cons=%d shortage=%d invest=%d mem=%d DS_calls=%d DS_us=%d"
			% [day + 1, sim.clock.total_days(), tick_us, prod, cons, short, invest, mem, dec_calls, dec_us])

		if tick_us > HARD_STOP_US:
			print("[HARD_STOP] tick_us=%d exceeds %d at day=%d" % [tick_us, HARD_STOP_US, day + 1])
			break

	# ---- التحليل ----
	print("")
	print("=== T5-P0 ANALYSIS ===")
	var nd := days.size()
	if nd <= WARMUP:
		print("[NO-POST-WARMUP-DATA] days=%d" % nd)
		quit(0)
		return
	var baseline_end_clamped := mini(BASELINE_END, nd)
	var baseline_ticks := []
	for i in range(BASELINE_START - 1, baseline_end_clamped):
		baseline_ticks.append(days[i]["tick_us"])
	var b_median := _median(baseline_ticks)
	print("baseline days %d-%d median_tick_us=%.1f (%d samples)"
		% [BASELINE_START, baseline_end_clamped, b_median, baseline_ticks.size()])

	var flagged := []
	for start in range(30, nd, 10):
		var win := []
		for i in range(start, mini(start + 10, nd)):
			win.append(days[i]["tick_us"])
		if win.is_empty():
			continue
		var m := _median(win)
		var d := m / b_median if b_median > 0.0 else -1.0
		print("window days %02d-%02d median_tick_us=%.1f D=%.4f"
			% [start + 1, mini(start + 10, nd), m, d])
		if d > 2.0:
			flagged.append("D>2x @ days %d-%d (D=%.4f)" % [start + 1, mini(start + 10, nd), d])

	print("")
	print("FLAGS: %s" % ("NONE" if flagged.is_empty() else str(flagged)))
	print("=== T5-P0 END ===")
	quit(0)


func mini(a: int, b: int) -> int:
	return a if a < b else b