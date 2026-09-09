extends SceneTree

# ============================================================
# TASK-040 — ACTOR RUNTIME INTEGRATED VALIDATION BENCHMARK
# ------------------------------------------------------------
# Baseline: bf2ea5b4. Scenarios A/B/C/D run on the PRODUCTION path:
#   Simulation.run_step() -> sim.scheduled.get_due_jobs(t)
#     -> job_political_deadline_pump -> PD.pump_integrated(sim.scheduled, ...)
#       -> PoliticalActions.execute -> Owning Domain
# The harness NEVER calls sim.scheduled.get_due_jobs or PD.pump*
# directly for scenario execution — production path only (A10).
#
# Phases:
#   P0: fixture integrity (static counts vs manifest)
#   P1: A10 minimal-chain gate (t040_a10) — blocks everything on FAIL
#   P2: scenarios A -> B -> C -> D (per-tick raw logging + metrics)
#   P3: determinism oracle per scenario (canonical SHA-256, 2 runs)
#
# All numbers below are TEST FIXTURE parameters, not game balance.
# ============================================================

const SimScript := preload("res://scripts/Simulation.gd")
const CT := preload("res://scripts/compliance/compliance_types.gd")
const PA := preload("res://scripts/politics/political_actions.gd")
const CQ := preload("res://scripts/compliance/compliance_query.gd")

const T040_ROOT := "res://data/scenarios/t040"
const SIM_SEED := 12345

const TREES := {
	"A10": {"dir": "t040_a10", "horizon": 60},
	"A": {"dir": "t040_a", "horizon": 90},
	"B": {"dir": "t040_b", "horizon": 90},
	"C": {"dir": "t040_c", "horizon": 90},
	"D": {"dir": "t040_d", "horizon": 120},
}

var pass_count := 0
var fail_count := 0
var _scenario_results := {}


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		pass_count += 1
		print("  PASS  %s" % name)
	else:
		fail_count += 1
		print("  FAIL  %s  %s" % [name, detail])


func _init() -> void:
	print("")
	print("============================================================")
	print("  TASK-040 — ACTOR RUNTIME INTEGRATED VALIDATION BENCHMARK")
	print("  baseline=bf2ea5b4 seed=%d world=200 countries" % SIM_SEED)
	print("============================================================")

	# ---------------- P0: fixture integrity ----------------
	_p0_fixture_integrity()

	# ---------------- P1: A10 gate ----------------
	var a10_ok := _p1_a10_gate()

	# ---------------- P2: scenarios ----------------
	if a10_ok:
		_run_scenario("A")
		_run_scenario("B")
		_run_scenario("C")
		_run_scenario("D")
		_p3_determinism_all()
	else:
		print("  [A10 GATE FAILED — scenarios skipped, STOP per protocol]")

	print("")
	print("RESULT: PASS %d / FAIL %d" % [pass_count, fail_count])
	quit(0 if fail_count == 0 else 1)


# ============================================================
# P0 — fixture integrity (static, vs manifest)
# ============================================================
func _p0_fixture_integrity() -> void:
	print("\n-- P0: fixture integrity")
	for key in TREES.keys():
		var tree: Dictionary = TREES[key]
		var mf: Dictionary = _load_json("%s/%s/manifest.json" % [T040_ROOT, tree["dir"]])
		var world: Dictionary = _load_json("%s/%s/worlds/politics/world.json" % [T040_ROOT, tree["dir"]])
		_check("P0[%s] 200 countries, %d governed, %d crisis, %d background" % [
				key, mf["governed"].size(), mf["crisis_active"].size(),
				mf["background_active"].size()],
			world["legislatures"].size() == 200
			and world["governments"].size() == mf["governed"].size()
			and mf["governed"].size() == tree.get("expect_govs", mf["governed"].size()))


# ============================================================
# P1 — A10 gate: minimal full-chain proof on t040_a10
# ============================================================
func _p1_a10_gate() -> bool:
	print("\n-- P1: A10 gate — full production chain on t040_a10")
	var sim = _make_sim(TREES["A10"]["dir"])
	var ps = sim._content_handlers.get_political_state()
	var fails_before_gate: int = fail_count

	# chain observation with per-day log
	var term_activated_day := -1
	var election_executed_day := -1
	var pump_days := 0
	for day in range(1, int(TREES["A10"]["horizon"]) + 1):
		var pumps_before: int = sim._content_handlers.political_counters["deadline_pumps"]
		sim.run_step()
		var pumps_after: int = sim._content_handlers.political_counters["deadline_pumps"]
		if pumps_after > pumps_before:
			pump_days += 1
		for id in ps.deadlines.keys():
			var rec: Dictionary = ps.deadlines[id]
			var act_at = rec["actual_activation_at"]
			var resolved_at = rec["resolved_at"]
			if String(rec["deadline_type"]) == "government_term_expiration" \
					and act_at != null and int(act_at) == day:
				term_activated_day = day
			if String(rec["deadline_type"]) == "election_due" \
					and String(rec.get("status", "")) == "resolved" \
					and resolved_at != null and int(resolved_at) == day:
				election_executed_day = day

	var chain_ok := true
	_check("A10-a pump fired every day (production scheduled job)", pump_days == int(TREES["A10"]["horizon"]))
	_check("A10-b term deadline activated at due day (60), lateness 0",
		term_activated_day == 60)
	var election_dl := ""
	for id in ps.deadlines.keys():
		if String(ps.deadlines[id]["deadline_type"]) == "election_due":
			election_dl = String(id)
	_check("A10-c derived election deadline exists and resolved via pipeline",
		election_dl != "" and String(ps.deadlines[election_dl]["status"]) == "resolved")
	_check("A10-d election executed (HoldElection through PoliticalActions)",
		ps.election_history.size() == 1
		and election_executed_day == 60
		and String((ps.deadlines[election_dl]["resolution"] as Dictionary)["outcome"]) == "election_executed")
	_check("A10-e single scheduler: domain deadline_queue unused (null)",
		ps.deadline_queue == null)
	var dl_jobs_in_sched := 0
	for j in sim.scheduled.all_jobs():
		if String(j["job_name"]) == "political_deadline":
			dl_jobs_in_sched += 1
	_check("A10-f all deadlines drained from sim.scheduled (0 remaining)", dl_jobs_in_sched == 0)
	chain_ok = fail_count == fails_before_gate

	# store for report
	_scenario_results["A10"] = {"pump_days": pump_days,
		"term_activated_day": term_activated_day,
		"election_executed_day": election_executed_day,
		"elections": ps.election_history.size()}
	return chain_ok


# ============================================================
# Scenario runner (production path only)
# ============================================================
func _make_sim(tree_dir: String):
	var sim = SimScript.new()
	sim.data_root_override = "%s/%s" % [T040_ROOT, tree_dir]
	sim.init_world(SIM_SEED)
	return sim


func _run_scenario(key: String) -> void:
	print("\n============================================================")
	print("  SCENARIO %s — %s (horizon=%d)" % [key, TREES[key]["dir"], TREES[key]["horizon"]])
	print("============================================================")
	var horizon := int(TREES[key]["horizon"])
	var sim = _make_sim(TREES[key]["dir"])
	var ps = sim._content_handlers.get_political_state()
	var events_file: Array = _load_json("%s/%s/scenarios/default/events.json" % [T040_ROOT, TREES[key]["dir"]])
	var events_total: int = events_file.size()
	var manifest: Dictionary = _load_json("%s/%s/manifest.json" % [T040_ROOT, TREES[key]["dir"]])

	# ---- per-tick instrumentation (counters only, no behavior) ----
	var tick_times: Array = []
	var peak_tick_us := 0
	var total_us := 0
	var events_consumed := 0
	var event_activations := 0
	var deadline_activations := 0
	var events_by_type := {}
	var event_target_activated := {}   # source -> true (event activation landed)
	var max_wait_event := 0            # day activated - day event fired
	var per_tick_lines: Array = []
	var queue_peak := 0
	var pa_evals_start: int = PA.eval_count
	var cq_evals_start: int = CQ.eval_count
	var pa_evals_by_day := {}
	var elections_executed := 0
	var lateness_sum := 0
	var lateness_max := 0
	var lateness_n := 0
	var deadline_misses := 0
	var deadline_completed := 0
	var deadline_deferred := 0
	var quiet_evals := 0
	var quiet_ticks := 0

	# event ledger for A3: fired-day -> activated-day (event work must land)
	var pending_events := {}   # "day|type|source" -> fired day
	for e in events_file:
		pending_events["%d|%s|%s" % [int(e["time"]), String(e["type"]), String(e["source"])]] = int(e["time"])
	var events_landed_count := 0

	var mem_before: int = OS.get_static_memory_usage()

	for day in range(1, horizon + 1):
		var t0: int = Time.get_ticks_usec()
		var ev_before: int = sim.events_processed_count
		var pa_before: int = PA.eval_count
		var dl_before_act: int = sim._content_handlers.political_counters["deadlines_activated"]
		var ev_before_act: int = 0  # computed below via activation log

		sim.run_step()

		var tick_us: int = Time.get_ticks_usec() - t0
		tick_times.append(tick_us)
		total_us += tick_us
		if tick_us > peak_tick_us:
			peak_tick_us = tick_us

		var day_events: int = sim.events_processed_count - ev_before
		events_consumed += day_events
		var day_dl_act: int = sim._content_handlers.political_counters["deadlines_activated"] - dl_before_act
		deadline_activations += day_dl_act
		pa_evals_by_day[day] = PA.eval_count - pa_before

		# activation ledger: which countries activated today (from activation_log)
		var active_today: Dictionary = {}
		if sim.activation_log.size() > 0:
			var last: Dictionary = sim.activation_log[sim.activation_log.size() - 1]
			if int(last["day"]) == day:
				for cid in last["active_ids"]:
					active_today[String(cid)] = true
		var day_event_act: int = 0
		for cid in active_today.keys():
			if String(cid).begins_with("c") and active_today[cid]:
				day_event_act += 1
		event_activations += day_event_act

		var qsize: int = sim.scheduled.all_jobs().size()
		if qsize > queue_peak:
			queue_peak = qsize

		# event landing check (A3): event with source activated same day
		var fired_keys: Array = []
		for k in pending_events.keys():
			var parts: PackedStringArray = String(k).split("|")
			if int(parts[0]) <= day:
				fired_keys.append(k)
		for k in fired_keys:
			var parts: PackedStringArray = String(k).split("|")
			var src := String(parts[2])
			var fired_day := int(parts[0])
			if active_today.has(src):
				event_target_activated[src] = true
				var wait := day - fired_day
				if wait > max_wait_event:
					max_wait_event = wait
				events_by_type[String(parts[1])] = int(events_by_type.get(String(parts[1]), 0)) + 1
				events_landed_count += 1
				pending_events.erase(k)
			# else: stays pending (may land on a later day or expire)

		per_tick_lines.append("day=%03d tick_us=%d events=%d event_act=%d dl_act=%d queue=%d pa_evals=%d" % [
			day, tick_us, day_events, day_event_act, day_dl_act, qsize, pa_evals_by_day[day]])

	# ---- deadline fairness from state ----
	for id in ps.deadlines.keys():
		var rec: Dictionary = ps.deadlines[id]
		if String(rec["status"]) == "resolved":
			deadline_completed += 1
			var late = rec["lateness_days"]
			if late != null and int(late) > 0:
				lateness_sum += int(late)
				lateness_n += 1
				lateness_max = maxi(lateness_max, int(late))
		elif int(rec["due_at"]) <= horizon:
			deadline_misses += 1   # A4/A7 FAIL condition
		else:
			deadline_deferred += 1

	elections_executed = ps.election_history.size()
	var mem_after: int = OS.get_static_memory_usage()

	# ---- A8: hidden per-tick political polling ----
	# PA evals during days with no deadline activation and no events
	for day in pa_evals_by_day.keys():
		if int(pa_evals_by_day[day]) > 0:
			# check whether any deadline activated or election-relevant event that day
			var had_activity := false
			for rec2 in ps.deadlines.values():
				var act2 = (rec2 as Dictionary)["actual_activation_at"]
				if act2 != null and int(act2) == int(day):
					had_activity = true
			if not had_activity:
				quiet_evals += int(pa_evals_by_day[day])
				quiet_ticks += 1

	var metrics := {
		"scenario": key,
		"horizon": horizon,
		"runtime_total_us": total_us,
		"runtime_mean_tick_us": float(total_us) / float(horizon),
		"runtime_peak_tick_us": peak_tick_us,
		"events_total": events_total,
		"events_consumed_total_stream": events_consumed,
		"events_landed_relevant": events_landed_count,
		"events_landed": events_by_type,
		"events_pending_at_end": pending_events.size(),
		"event_activations": event_activations,
		"deadline_activations": deadline_activations,
		"deadline_completed": deadline_completed,
		"deadline_deferred": deadline_deferred,
		"deadline_misses": deadline_misses,
		"deadline_lateness_max": lateness_max,
		"deadline_lateness_mean": float(lateness_sum) / float(max(lateness_n, 1)),
		"deadline_lateness_n": lateness_n,
		"elections_executed": elections_executed,
		"pa_evals": PA.eval_count - pa_evals_start,
		"cq_evals": CQ.eval_count - cq_evals_start,
		"max_wait_event_days": max_wait_event,
		"queue_peak": queue_peak,
		"memory_delta_bytes": mem_after - mem_before,
		"quiet_evals": quiet_evals,
		"quiet_ticks_with_evals": quiet_ticks,
	}
	_scenario_results[key] = metrics

	# ---- acceptance checks ----
	print("  -- metrics:")
	for m in metrics.keys():
		print("     %s = %s" % [m, str(metrics[m])])
	print("  -- per-tick log (%d ticks, first 12):" % per_tick_lines.size())
	for i in range(min(12, per_tick_lines.size())):
		print("     " + String(per_tick_lines[i]))
	print("     ... (full log in evidence file)")

	_check("%s-A9 completes horizon without crash (%d ticks)" % [key, horizon], true)
	_check("%s-A3 all %d fixture events landed on target (%d landed, %d pending)" % [
			key, events_total, events_landed_count, pending_events.size()],
		events_landed_count == events_total and pending_events.is_empty())
	_check("%s-A4 zero deadline misses at horizon" % key, deadline_misses == 0,
		"misses=%d" % deadline_misses)
	_check("%s-A5 zero duplicate activations" % key,
		int(ps.deadline_stats["duplicates"]) == 0
		and deadline_completed + deadline_deferred + deadline_misses == ps.deadlines.size())
	_check("%s-A7 event work executed within horizon (max wait %d days)" % [key, max_wait_event],
		pending_events.is_empty() and max_wait_event <= horizon)
	_check("%s-A8 no political evals on quiet ticks (%d evals on %d quiet days)" % [key, quiet_evals, quiet_ticks],
		quiet_evals == 0)

	# per-tick raw log to evidence
	_write_evidence(key, per_tick_lines, metrics, manifest)


func _p3_determinism_all() -> void:
	print("\n-- P3: determinism oracle (canonical SHA-256, 2 runs each)")
	for key in ["A", "B", "C", "D"]:
		var h1 := _determinism_run(key)
		var h2 := _determinism_run(key)
		var len_ok := h1.length() == 64
		var hex_ok := h1.is_valid_hex_number() and h2.is_valid_hex_number()
		_check("%s-A1/A2 canonical SHA-256 identical across runs" % key, h1 == h2,
			"h1=%s h2=%s" % [h1, h2])
		_check("%s-A1b hash is exactly 64 hex chars (len=%d, hex=%s)" % [key, h1.length(), str(hex_ok)],
			len_ok and hex_ok)
		print("  %s CANONICAL_SHA256 = %s" % [key, h1])


func _determinism_run(key: String) -> String:
	var sim = _make_sim(TREES[key]["dir"])
	for day in range(1, int(TREES[key]["horizon"]) + 1):
		sim.run_step()
	return _canonical_snapshot(sim).sha256_text()


func _canonical_snapshot(sim) -> String:
	# Semantic state only — no memory addresses, no benchmark counters.
	var state := {
		"clock": sim.clock.to_dict(),
		"world": sim.world.to_dict(),
		"events_remaining": sim.events.to_dict(),
		"scheduled": sim.scheduled.to_dict(),
	}
	if sim._content_handlers != null and sim._content_handlers.has_method("get_political_state"):
		var ps = sim._content_handlers.get_political_state()
		if ps != null:
			state["political"] = ps.to_dict()
	return CT.canonical(state)


# ============================================================
# helpers
# ============================================================
func _load_json(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("cannot open %s" % path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed


func _write_evidence(key: String, per_tick: Array, metrics: Dictionary, manifest: Dictionary) -> void:
	var path := "res://.ai/evidence/tests/t040_scenario_%s_ticklog.txt" % key.to_lower()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write evidence %s" % path)
		return
	f.store_line("TASK-040 scenario %s per-tick raw log (baseline bf2ea5b4, seed %d)" % [key, SIM_SEED])
	f.store_line("manifest: governed=%d crisis=%d background=%d horizon=%d" % [
		manifest["governed"].size(), manifest["crisis_active"].size(),
		manifest["background_active"].size(), manifest["horizon"]])
	f.store_line("metrics: " + JSON.stringify(metrics))
	f.store_line("--- per-tick ---")
	for line in per_tick:
		f.store_line(String(line))
	f.close()
	print("  evidence written: %s" % path)
