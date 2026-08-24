extends SceneTree

# ============================================================
# PHASE 7 — TEST 10: SCALE (Derived Importance)
# بقرار صاحب المشروع بعد إقفال Test 1 بنتيجة PASS 21/21.
#
# الغاية: قياس الأداء لا صحة المنطق — هل تكلفة الحساب تت behaves
# كـ O(الروابط ذات الصلة) أم O(كل الكيانات) عند حجم واقعي؟
# (القاعدة الأساسية في 01-مبادئ-المحرك.md وGate 2 في 02-المعمارية.md)
#
# المعاملات المجمدة قبل التشغيل:
#   N ∈ {50, 100, 150, 200} دولة
#   60 قدرة | 10 اعتمادات/دولة | 6 منتجين/قدرة | سلسلة enables 29 سهمًا
#   الكثافة ثابتة عبر كل الأحجام — هذا شرط التوقع الأساسي.
#   المولد حتمي بالكامل (strides حسابية + probing، صفر RNG).
#   العوالم تولَّد بنفس schema ملفات Test 1 وتُغذى مباشرة لنفس
#   DIModule.evaluate دون أي تفرّع — وحدة الاشتقاق v2 المجمدة
#   المتحقق منها في Runs 1-4، ممنوع تعديلها وسط الاختبار.
#
# التوقعات المسجلة قبل التشغيل (خصائص لا أرقام مطلقة):
#   P1 Flatness: بما أن كثافة الروابط لكل كيان ثابتة، فلو الكلفة
#      ∝ الروابط فزمن الاستعلام الواحد شبه مستقل عن N. معيار PASS:
#      per_query(200) <= 3x per_query(50). هامش 3x يتسع للضجيج
#      وكلفة الذاكرة، لكنه يكشف توقيع الـ O(N) المخفي المتوقع ~4x+
#      لو وُجد مسح شامل داخل الاستعلام.
#   P2 Targeted Advantage: عند حدث واحد (تغيير إنتاج منتج واحد)،
#      إعادة احتساب المتأثرين فقط يجب أن تكون أسرع بكثير من المسح
#      الكامل. معيار PASS عند N=200: full_sweep / targeted >= 10x
#      (المتوقع نظريًا ~20x بحساب أزواج المتأثرين).
#   P3 Budget: المسح الكامل عند N=200 يكتمل في أقل من ثانيتين.
#
# أي فشل = دليل Gate 2 حقيقي (يُوثَّق ولا يُصلَّح وسط الاختبار).
# ============================================================

const DIModule = preload("res://scripts/DerivedImportance.gd")

const SIZES: Array[int] = [50, 100, 150, 200]
const CAP_COUNT := 60
const DEPS_PER_COUNTRY := 10
const PRODUCERS_PER_CAP := 6
const ENABLE_CHAIN_LEN := 29
const EVENT_ENTITY_IDX := 0
const EVENT_CAP_IDX := 0
const EVENT_NEW_VALUE := 0.95
const TIMED_REPS := 3

# ---- معايير PASS المسجلة ----
const FLATNESS_TOLERANCE := 3.0
const TARGETED_MIN_ADVANTAGE := 10.0
const FULL_SWEEP_BUDGET_US := 2000000

var pass_count := 0
var fail_count := 0


func _init() -> void:
	print("")
	print("============================================================")
	print("  PHASE 7 / TEST 10 — SCALE")
	print("  Module: DerivedImportance v2 (FROZEN) | Generator: deterministic strides")
	print("  Density fixed across sizes: caps=%d deps/country=%d producers/cap=%d"
		% [CAP_COUNT, DEPS_PER_COUNTRY, PRODUCERS_PER_CAP])
	print("============================================================")
	print("")

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
	_check("P1 per-query cost flat across 4x entity growth (links-bound, not entities-bound)",
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
		print("  Any failure = documented Gate 2 evidence. Nothing was modified mid-test.")
	print("============================================================")

	quit(1 if fail_count > 0 else 0)


# ============================================================
# Deterministic generator — نفس schema عوالم Test 1
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
	return {"world_id": "scale_%d" % n, "enables": enables, "entities": entities}


# ============================================================
# Measurement
# ============================================================

func _run_size(n: int) -> Dictionary:
	var world := _gen_world(n)

	# Warmup (untimed)
	_full_sweep(world)

	# Timed full sweeps — نأخذ الأفضل من 3 (الأكثر استقرارًا للبنشمارك)
	var pairs := 0
	var best := 9223372036854775807
	for r in range(TIMED_REPS):
		var t0 := Time.get_ticks_usec()
		pairs = _full_sweep(world)
		var dt := Time.get_ticks_usec() - t0
		if dt < best:
			best = dt
	var per_query_us := float(best) / float(maxi(pairs, 1))

	# الحدث: منتج واحد يغير إنتاجه لقدرة واحدة
	var event_entity := "N_%03d" % EVENT_ENTITY_IDX
	var event_cap := "C_%03d" % EVENT_CAP_IDX
	world["entities"][event_entity]["produces"][event_cap] = EVENT_NEW_VALUE

	# إعادة الاحتساب المستهدفة (المتأثرون فقط) — والبحث عنهم داخل التوقيت
	var t1 := Time.get_ticks_usec()
	var reach := _forward_closure(event_cap, world["enables"])
	var affected_observers: Array[String] = []
	var affected_targets: Array[String] = []
	for ename in world["entities"].keys():
		var ent: Dictionary = world["entities"][ename]
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
			DIModule.evaluate(world, o, t)
			targeted_pairs += 1
	var targeted_us := Time.get_ticks_usec() - t1

	print("")
	print("N=%d | pairs=%d | sweep_best=%dus | per_query=%.4fus | affected(obs=%d,tgt=%d,pairs=%d) targeted=%dus"
		% [n, pairs, best, per_query_us,
		affected_observers.size(), affected_targets.size(), targeted_pairs, targeted_us])

	return {
		"pairs": pairs,
		"sweep_best_us": best,
		"per_query_us": per_query_us,
		"targeted_us": targeted_us,
		"targeted_pairs": targeted_pairs,
	}


func _full_sweep(world: Dictionary) -> int:
	var entities: Dictionary = world["entities"]
	var count := 0
	for o in entities.keys():
		for t in entities.keys():
			if String(o) == String(t):
				continue
			DIModule.evaluate(world, String(o), String(t))
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
