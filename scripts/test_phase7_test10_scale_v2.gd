extends SceneTree

# ============================================================
# PHASE 7 — TEST 10 v2: SCALE (بعد إصلاح الـ implementation debt)
# بقرار صاحب المشروع: أرخص إصلاح أولًا داخل GDScript قبل أي قرار Gate 2.
#
# التغييران المعتمدان في الموديول (v3 additive):
#   1) Supply Index — بدل مسح كل الكيانات لكل حد.
#   2) Maxpath Memoization — دالة نقية في الزوج (Q,D) تُحسب مرة واحدة.
#
# نفس معايير Run 1 حرفيًا (لا تغيير على العتبات):
#   P1 Flatness: per_query(200) <= 3x per_query(50) بكثافة ثابتة
#   P2 Targeted: full/targeted >= 10x عند N=200
#   P3 Budget : full sweep عند N=200 < 2 ثانية
#
# بوابة تكافؤ إلزامية مسجلة قبل أي قياس:
#   E0: على العوالم الستة لـ Test 1، كل زوج من evaluate_indexed يجب أن
#       يساوي evaluate() bitwise. أي انحراف يلغي صحة كل أرقام الأداء
#       ويُنهي الاختبار FAIL فورًا (المسار السريع غير مطابق للمرجع).
#
# تدفق الحدث الواقعي: تغيير إنتاج منتج واحد => refresh_supply_index فقط
# (memo يعيش لأن enables لم تتغير) — وكل ذلك داخل منطقة توقيت المسار المستهدف.
#
# المولد والمعاملات مطابقة لـ Run 1 (حتمية بالكامل).
# ============================================================

const DIModule = preload("res://scripts/DerivedImportance.gd")
const WORLD_DIR := "res://data/worlds/test1"
const WORLDS: Array[String] = ["world_1", "world_2", "world_3", "world_4", "world_5", "world_6"]

const SIZES: Array[int] = [50, 100, 150, 200]
const CAP_COUNT := 60
const DEPS_PER_COUNTRY := 10
const PRODUCERS_PER_CAP := 6
const ENABLE_CHAIN_LEN := 29
const EVENT_ENTITY_IDX := 0
const EVENT_CAP_IDX := 0
const EVENT_NEW_VALUE := 0.95
const TIMED_REPS := 3

const FLATNESS_TOLERANCE := 3.0
const TARGETED_MIN_ADVANTAGE := 10.0
const FULL_SWEEP_BUDGET_US := 2000000

var pass_count := 0
var fail_count := 0


func _init() -> void:
	print("")
	print("============================================================")
	print("  PHASE 7 / TEST 10 v2 — SCALE (indexed + memoized module v3)")
	print("  Same generator, same density, SAME criteria as Run 1")
	print("============================================================")
	print("")

	# ---------- E0: بوابة التكافؤ (قبل أي قياس) ----------
	var eq := _equivalence_gate()
	_check("E0 equivalence: evaluate_indexed == evaluate bitwise across all 6 worlds (%d checked)"
		% [eq[2]], eq[0], "mismatches=%d" % eq[1])
	if not eq[0]:
		print("[FATAL] Indexed path diverges from oracle. Timing results are void.")
		quit(1)
		return

	var results := {}
	for n in SIZES:
		results[n] = _run_size(n)

	print("")
	print("---------------- PRE-REGISTERED CRITERIA ----------------")
	var pq50: float = results[50]["per_query_us"]
	var pq200: float = results[200]["per_query_us"]
	var flat_ratio: float = pq200 / maxf(pq50, 0.000001)
	print("P1 Flatness : per_query(200)=%.4fus / per_query(50)=%.4fus = %.2fx (limit %.1fx)"
		% [pq200, pq50, flat_ratio, FLATNESS_TOLERANCE])
	_check("P1 per-query cost flat across 4x entity growth",
		flat_ratio <= FLATNESS_TOLERANCE, "")

	var full_us: int = results[200]["sweep_best_us"]
	var tgt_us: int = results[200]["targeted_us"]
	var adv: float = float(full_us) / float(maxi(tgt_us, 1))
	print("P2 Targeted : full=%dus / targeted=%dus = %.1fx (min %.1fx) | affected_pairs=%d of %d"
		% [full_us, tgt_us, adv, TARGETED_MIN_ADVANTAGE,
		results[200]["targeted_pairs"], results[200]["pairs"]])
	_check("P2 single-event targeted recompute beats full sweep by >= %.0fx at N=200"
		% TARGETED_MIN_ADVANTAGE, adv >= TARGETED_MIN_ADVANTAGE, "")

	print("P3 Budget   : full sweep at N=200 = %dus (budget %dus)" % [full_us, FULL_SWEEP_BUDGET_US])
	_check("P3 full sweep at N=200 completes under 2 seconds",
		full_us <= FULL_SWEEP_BUDGET_US, "")

	print("")
	print("============================================================")
	if fail_count == 0:
		print("  OVERALL RESULT: PASS (%d checks)" % pass_count)
	else:
		print("  OVERALL RESULT: FAIL (%d passed, %d failed)" % [pass_count, fail_count])
	print("============================================================")

	quit(1 if fail_count > 0 else 0)


func _equivalence_gate() -> Array:
	var mismatches := 0
	var checked := 0
	for wname in WORLDS:
		var f := FileAccess.open("%s/%s.json" % [WORLD_DIR, wname], FileAccess.READ)
		if f == null:
			return [false, -1, checked]
		var world = JSON.parse_string(f.get_as_text())
		if typeof(world) != TYPE_DICTIONARY:
			return [false, -1, checked]
		var idx := DIModule.build_world_index(world)
		var entities: Dictionary = world["entities"]
		for o in entities.keys():
			for t in entities.keys():
				if String(o) == String(t):
					continue
				var a: Dictionary = DIModule.evaluate(world, String(o), String(t))
				var b: Dictionary = DIModule.evaluate_indexed(idx, String(o), String(t))
				checked += 1
				if float(a["value"]) != float(b["value"]):
					mismatches += 1
					if mismatches <= 5:
						print("  [E0-MISMATCH] %s %s->%s : %.18f vs %.18f"
							% [wname, o, t, float(a["value"]), float(b["value"])])
	return [mismatches == 0, mismatches, checked]


# ============================================================
# Deterministic generator — مطابق لـ Run 1
# ============================================================

func _gen_world(n: int) -> Dictionary:
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
	return {"world_id": "scale_v2_%d" % n, "enables": enables, "entities": entities}


# ============================================================
# Measurement — indexed paths
# ============================================================

func _run_size(n: int) -> Dictionary:
	var world := _gen_world(n)

	var tb := Time.get_ticks_usec()
	var idx := DIModule.build_world_index(world)
	var build_us := Time.get_ticks_usec() - tb

	_full_sweep(idx)

	var pairs := 0
	var best := 9223372036854775807
	for r in range(TIMED_REPS):
		var t0 := Time.get_ticks_usec()
		pairs = _full_sweep(idx)
		var dt := Time.get_ticks_usec() - t0
		if dt < best:
			best = dt
	var per_query_us := float(best) / float(maxi(pairs, 1))

	var event_entity := "N_%03d" % EVENT_ENTITY_IDX
	var event_cap := "C_%03d" % EVENT_CAP_IDX
	world["entities"][event_entity]["produces"][event_cap] = EVENT_NEW_VALUE

	var t1 := Time.get_ticks_usec()
	DIModule.refresh_supply_index(idx)
	var reach := _forward_closure(event_cap, idx["enables"])
	var affected_observers: Array[String] = []
	var affected_targets: Array[String] = []
	for ename in (idx["world"] as Dictionary)["entities"].keys():
		var ent: Dictionary = (idx["world"] as Dictionary)["entities"][ename]
		for dkey in ent["depends_on"].keys():
			if reach.has(String(dkey)):
				affected_observers.append(String(ename))
				break
		if (ent["produces"] as Dictionary).has(event_cap):
			affected_targets.append(String(ename))
	var targeted_pairs := 0
	for o in affected_observers:
		for t in affected_targets:
			if o == t:
				continue
			DIModule.evaluate_indexed(idx, o, t)
			targeted_pairs += 1
	var targeted_us := Time.get_ticks_usec() - t1

	print("")
	print("N=%d | index_build=%dus | pairs=%d | sweep_best=%dus | per_query=%.4fus | affected(obs=%d,tgt=%d,pairs=%d) targeted=%dus"
		% [n, build_us, pairs, best, per_query_us,
		affected_observers.size(), affected_targets.size(), targeted_pairs, targeted_us])

	return {
		"pairs": pairs,
		"sweep_best_us": best,
		"per_query_us": per_query_us,
		"targeted_us": targeted_us,
		"targeted_pairs": targeted_pairs,
	}


func _full_sweep(idx: Dictionary) -> int:
	var entities: Dictionary = (idx["world"] as Dictionary)["entities"]
	var count := 0
	for o in entities.keys():
		for t in entities.keys():
			if String(o) == String(t):
				continue
			DIModule.evaluate_indexed(idx, String(o), String(t))
			count += 1
	return count


func _forward_closure(start: String, enables: Dictionary) -> Dictionary:
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


func _check(label: String, cond: bool, detail: String) -> void:
	if cond:
		pass_count += 1
		print("[PASS] %s" % label)
	else:
		fail_count += 1
		var msg := "[FAIL] %s" % label
		if detail != "":
			msg += " | %s" % detail
		print(msg)
