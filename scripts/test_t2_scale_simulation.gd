extends SceneTree

# ============================================================
# T2 Scale Stress Test — Maestro Engine
# Profiles:
#   0 = Structural   : WorldState build (N countries + N provinces + 5 relations each)
#   1 = StateUpdate  : ScheduledQueue register(N×2) + get_due_jobs(1)
#   2 = Relations    : WorldState.related_entities query scan for all N
#   3 = DI-Targeted  : DerivedImportance targeted recompute after single prod change
# Points:   1K, 5K, 10K, 25K, 50K
# Runs:     2 warm-up (discarded) + 5 measured, raw + median/min/max stored
# Metrics:  tick_time_us, OS.get_static_memory_usage() delta
# Stop rules:
#   Hard Stop  — tick median >30,000,000 us (priority, logged as failure_reason)
#   Shape Stop — R>4 in 2 consecutive N-transitions (secondary, logged as note)
#   No auto-continue to 100K+ — human review required
# ============================================================

const DIModule = preload("res://scripts/DerivedImportance.gd")

const WARMUP_RUNS  := 2
const MEASURE_RUNS := 5
const HARD_STOP_US := 30_000_000   # 30 seconds
const SHAPE_R_LIMIT := 4.0
const SEED := 20240826

# DI generator constants (mirroring test_phase7_test10_scale_v2.gd exactly)
const CAP_COUNT := 60
const DEPS_PER_COUNTRY := 10
const PRODUCERS_PER_CAP := 6
const ENABLE_CHAIN_LEN := 29
const EVENT_ENTITY_IDX := 0
const EVENT_CAP_IDX := 0
const EVENT_NEW_VALUE := 0.95

func _init() -> void:
	print("=== T2 SCALE STRESS TEST START ===")
	_print_env()
	_run_all()
	print("=== T2 SCALE STRESS TEST END ===")
	quit()

func _print_env() -> void:
	var out := []
	OS.execute("git", ["rev-parse", "HEAD"], out, true)
	var git_hash: String = out[0].strip_edges() if out.size() > 0 else "UNKNOWN"
	print("ENV | seed=%d | git=%s | godot=%s | static_mem_baseline=%d" % [
		SEED,
		git_hash,
		Engine.get_version_info().get("string", "?"),
		OS.get_static_memory_usage()
	])

# ──────────────────────────────────────────────────────────────
# World generators
# ──────────────────────────────────────────────────────────────

func _make_country_dict(rng: RandomNumberGenerator, name: String) -> Dictionary:
	return {
		"name": name,
		"population": float(rng.randi_range(1_000_000, 100_000_000)),
		"gdp": float(rng.randi_range(10, 10000)) * 1e9,
		"military_power": rng.randf(),
		"stability": rng.randf(),
		"government": "republic",
		"military_threat_nearby": 0.0,
		"border_insecurity": 0.0,
		"economic_stability": rng.randf(),
		"growth": rng.randf() * 0.05,
		"security_score": 0.0,
		"prosperity_score": 0.0,
		"chosen_action": "none",
		"at_war_with": []
	}

func _build_structural_ws(n: int) -> WorldState:
	var ws := WorldState.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in n:
		var cname := "country_%d" % i
		ws.add_country(cname, _make_country_dict(rng, cname))
		ws.add_province("province_%d" % i, {
			"name": "province_%d" % i,
			"owner": cname,
			"infrastructure": rng.randf(),
			"supply": rng.randf(),
			"damage": 0.0
		})
	for i in n:
		var related: Array = []
		for r in 5:
			related.append("country_%d" % ((i + r + 1) % n))
		ws.set_relations("country_%d" % i, related)
	return ws

func _gen_di_world(n: int) -> Dictionary:
	# Mirrors test_phase7_test10_scale_v2.gd _gen_world(n) verbatim
	var entities := {}
	for i in range(n):
		var deps := {}
		var j := 0
		var guard := 0
		while j < DEPS_PER_COUNTRY and guard < CAP_COUNT * 4:
			var cap := "C_%03d" % ((i * DEPS_PER_COUNTRY + j * 7) % CAP_COUNT)
			if not deps.has(cap):
				deps[cap] = 0.05 + float((i + j) % 12) * 0.06
				j += 1
			guard += 1
		entities["N_%03d" % i] = {"produces": {}, "depends_on": deps, "domestic_capacity": {}}
	for c in range(CAP_COUNT):
		var placed := 0
		var t := 0
		var guard := 0
		var cap := "C_%03d" % c
		while placed < PRODUCERS_PER_CAP and guard < n * 4:
			var ename := "N_%03d" % ((c * PRODUCERS_PER_CAP + t * 11) % n)
			var prod: Dictionary = entities[ename]["produces"]
			if not prod.has(cap):
				prod[cap] = 0.10 + float((c + t * 3) % 9) * 0.08
				placed += 1
			t += 1
			guard += 1
	var enables := {}
	for e in range(ENABLE_CHAIN_LEN):
		enables["C_%03d" % e] = ["C_%03d" % (e + 1)]
	return {"world_id": "t2_%d" % n, "enables": enables, "entities": entities}

# ──────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────

func _median(vals: Array) -> float:
	var s := vals.duplicate()
	s.sort()
	var mid := s.size() / 2
	if s.size() % 2 == 1:
		return float(s[mid])
	return (float(s[mid - 1]) + float(s[mid])) * 0.5

func _forward_closure(start: String, enables: Dictionary) -> Dictionary:
	# BFS/DFS from start in enables graph — same as test_phase7_test10_scale_v2.gd
	var seen := {start: true}
	var stack: Array = [start]
	while not stack.is_empty():
		var cur := String(stack.pop_back())
		for entry in enables.get(cur, []):
			var nxt := String(entry)
			if not seen.has(nxt):
				seen[nxt] = true
				stack.append(nxt)
	return seen

# ──────────────────────────────────────────────────────────────
# Profile runners
# ──────────────────────────────────────────────────────────────

# Profile 0: WorldState structural build time
func _run_p0_structural(n: int) -> Array:
	var times := []
	for rep in (WARMUP_RUNS + MEASURE_RUNS):
		var t0 := Time.get_ticks_usec()
		var ws := _build_structural_ws(n)
		var t1 := Time.get_ticks_usec()
		# WorldState is RefCounted — freed when ws goes out of scope
		if rep >= WARMUP_RUNS:
			times.append(t1 - t0)
	return times

# Profile 1: ScheduledQueue — register N*2 jobs + get_due_jobs(1)
# Measures the scheduling layer overhead, which scales with N countries
func _run_p1_state_update(n: int) -> Array:
	var times := []
	for rep in (WARMUP_RUNS + MEASURE_RUNS):
		var sq := ScheduledQueue.new()
		var t0 := Time.get_ticks_usec()
		for i in n:
			var cname := "country_%d" % i
			sq.register(cname, "population_update", 1, 1)
			sq.register(cname, "military_readiness", 1, 1)
		var _due = sq.get_due_jobs(1)
		var t1 := Time.get_ticks_usec()
		if rep >= WARMUP_RUNS:
			times.append(t1 - t0)
	return times

# Profile 2: WorldState relations query scan for all N countries
func _run_p2_relations(n: int) -> Array:
	var ws := _build_structural_ws(n)
	var times := []
	for rep in (WARMUP_RUNS + MEASURE_RUNS):
		var t0 := Time.get_ticks_usec()
		for i in n:
			ws.related_entities("country_%d" % i)
		var t1 := Time.get_ticks_usec()
		if rep >= WARMUP_RUNS:
			times.append(t1 - t0)
	return times

# Profile 3: DI targeted recompute after single production change
func _run_p3_di_targeted(n: int) -> Array:
	var world := _gen_di_world(n)
	var times := []
	for rep in (WARMUP_RUNS + MEASURE_RUNS):
		var idx := DIModule.build_world_index(world)
		var event_entity := "N_%03d" % EVENT_ENTITY_IDX
		var event_cap    := "C_%03d" % EVENT_CAP_IDX
		# Mutate one production value (slightly different per rep to avoid caching)
		world["entities"][event_entity]["produces"][event_cap] = EVENT_NEW_VALUE + float(rep) * 0.001

		var t0 := Time.get_ticks_usec()
		DIModule.refresh_supply_index(idx)
		var reach := _forward_closure(event_cap, idx["enables"])
		# Build affected lists (same logic as test_phase7_test10_scale_v2.gd)
		var affected_observers: Array = []
		var affected_targets: Array = []
		var all_entities: Dictionary = (idx["world"] as Dictionary)["entities"]
		for ename in all_entities.keys():
			var ent: Dictionary = all_entities[ename]
			for dkey in ent["depends_on"].keys():
				if reach.has(String(dkey)):
					affected_observers.append(String(ename))
					break
			if (ent["produces"] as Dictionary).has(event_cap):
				affected_targets.append(String(ename))
		for o in affected_observers:
			for t in affected_targets:
				if o == t:
					continue
				DIModule.evaluate_indexed(idx, o, t)
		var t1 := Time.get_ticks_usec()
		if rep >= WARMUP_RUNS:
			times.append(t1 - t0)
	return times

# ──────────────────────────────────────────────────────────────
# Main runner
# ──────────────────────────────────────────────────────────────

func _run_all() -> void:
	var N_LIST := [1000, 5000, 10000, 25000, 50000]
	var PROFILE_NAMES := ["Structural", "StateUpdate", "Relations", "DI-Targeted"]

	for profile in 4:
		print("\n--- PROFILE %d (%s) ---" % [profile, PROFILE_NAMES[profile]])
		var hard_stopped := false
		var last_median := -1.0
		var shape_violations := 0

		for n in N_LIST:
			if hard_stopped:
				print("SKIPPED | N=%d | profile=%d | reason=prior_hard_stop" % [n, profile])
				continue

			var mem_before := OS.get_static_memory_usage()
			var times: Array = []

			match profile:
				0: times = _run_p0_structural(n)
				1: times = _run_p1_state_update(n)
				2: times = _run_p2_relations(n)
				3: times = _run_p3_di_targeted(n)

			var mem_after := OS.get_static_memory_usage()
			var med := _median(times)
			var mn  := float(times.min())
			var mx  := float(times.max())

			# Shape-stop check (secondary — logged, not fatal by itself)
			var shape_note := ""
			if last_median > 0.0:
				var r := med / maxf(last_median, 1.0)
				if r > SHAPE_R_LIMIT:
					shape_violations += 1
					shape_note = " | SHAPE_WARN R=%.2f (violation #%d)" % [r, shape_violations]
					if shape_violations >= 2:
						shape_note += " | SHAPE_STOP"
				else:
					shape_violations = 0

			print("RESULT | N=%d | profile=%d | median_us=%.0f | min_us=%.0f | max_us=%.0f | mem_delta=%d | raw=%s%s" % [
				n, profile,
				med, mn, mx,
				int(mem_after) - int(mem_before),
				str(times),
				shape_note
			])

			last_median = med
			# Hard Stop check (priority — halts further N for this profile)
			if med > HARD_STOP_US:
				print("HARD_STOP | N=%d | profile=%d | failure_reason=tick_median_exceeded_30s | median_us=%.0f" % [
					n, profile, med
				])
				hard_stopped = true
