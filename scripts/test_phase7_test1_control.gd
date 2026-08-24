extends SceneTree

# ============================================================
# PHASE 7 / TEST 1 — RUN 3: ZERO-DEPENDENCY ISOLATION CONTROL
# بقرار صاحب المشروع بعد Run 2.
#
# الغاية: حسم المستوى الأول فقط (Isolation):
#   هل dependency = 0.0 تعني importance = 0.0 بالضبط مهما تغيّر
#   إنتاج الموردين في العالم؟
#
# التصميم المجمد قبل التشغيل:
#   - نفس الدالة DerivedImportance.gd v2 — صفر تعديل عليها.
#   - نفس عالم world_1.json — تحميل وتعديل متغير واحد فقط في الذاكرة:
#       Turkey.depends_on[semiconductors]: 0.05 → 0.0
#     (تركيا تصبح كيانًا بلا أي اعتماد مسجل — Isolated Entity حقيقي).
#   - ثلاث تجارب معزولة تغيّر Taiwan.produces[semiconductors] فقط:
#       0.80 (أساس) / 0.90 (زيادة) / 0.70 (نقصان)
#
# التوقع المسجل مسبقًا (صاحب المشروع):
#   derived_importance(Turkey -> Taiwan) = 0.0 بالضبط في التجارب الثلاث.
#   PASS إذا: القيم الثلاث == 0.0 bitwise (لا فرق ولا مهلة).
#   FAIL إذا: أي قيمة غير صغيرة — أي انزياح ولو 1e-15.
#
# فصل مستويات صريح (بقرار صاحب المشروع):
#   المستوى الأول — Isolation: يُحسم هنا.
#   المستوى الثاني — Sensitivity (هل يعقل أن كيان اعتماده 0.02 يتأثر
#   بتغير السوق؟): سؤال نمذجة مفتوح، لا يُحسم هنا ولا يُختبر هنا.
#   قيم مصر (اعتمادها 0.02) تُطبع كسياق خام فقط — بلا أي assertion.
# ============================================================

const DIModule = preload("res://scripts/DerivedImportance.gd")
const WORLD_PATH := "res://data/worlds/test1/world_1.json"
const PRODUCE_RUNS: Array[float] = [0.80, 0.90, 0.70]

var pass_count := 0
var fail_count := 0


func _init() -> void:
	print("")
	print("============================================================")
	print("  PHASE 7 / TEST 1 — RUN 3: ZERO-DEPENDENCY CONTROL")
	print("  Same module (v2, untouched) | Same world_1 | Single-variable overrides")
	print("============================================================")
	print("")

	if not FileAccess.file_exists(WORLD_PATH):
		print("[FATAL] Missing world file.")
		quit(1)
		return
	var f := FileAccess.open(WORLD_PATH, FileAccess.READ)
	var base_world = JSON.parse_string(f.get_as_text())
	if typeof(base_world) != TYPE_DICTIONARY:
		print("[FATAL] Invalid JSON.")
		quit(1)
		return

	var control_values := {}
	var context_egypt := {}
	for produce_val in PRODUCE_RUNS:
		var w: Dictionary = base_world.duplicate(true)
		# المتغير الوحيد للكيان المحكوم: صفر اعتماد مسجل تمامًا
		w["entities"]["Turkey"]["depends_on"] = {"semiconductors": 0.0}
		# المتغير المعزول تحت الاختبار: إنتاج تايوان فقط
		w["entities"]["Taiwan"]["produces"]["semiconductors"] = produce_val

		var out_t: Dictionary = DIModule.evaluate(w, "Turkey", "Taiwan")
		control_values[produce_val] = float(out_t["value"])

		var out_e: Dictionary = DIModule.evaluate(w, "Egypt", "Taiwan")
		context_egypt[produce_val] = float(out_e["value"])

		if not (out_t["cycles"] as Array).is_empty():
			print("[WARN] cycles: %s" % [out_t["cycles"]])

		print("Run Taiwan.produces=%.2f  =>  Turkey(dep=0.0) -> Taiwan = %.15f  |  [context only] Egypt(dep=0.02) -> Taiwan = %.10f"
			% [produce_val, control_values[produce_val], context_egypt[produce_val]])

	print("")
	print("---------------- CONTROL VERDICTS ----------------")
	for produce_val in PRODUCE_RUNS:
		_check_exact_zero(produce_val, control_values[produce_val])
	_check("All three control runs bitwise identical to each other",
		control_values[PRODUCE_RUNS[0]] == control_values[PRODUCE_RUNS[1]]
		and control_values[PRODUCE_RUNS[0]] == control_values[PRODUCE_RUNS[2]], "")

	print("")
	print("============================================================")
	if fail_count == 0:
		print("  RUN 3 RESULT: PASS (%d checks)" % pass_count)
		print("  Isolation mechanism holds: dependency=0.0 => importance=0.0 exactly,")
		print("  regardless of supplier output changes in the world.")
	else:
		print("  RUN 3 RESULT: FAIL (%d passed, %d failed)" % [pass_count, fail_count])
	print("============================================================")

	quit(1 if fail_count > 0 else 0)


func _check_exact_zero(produce_val: float, value: float) -> void:
	if value == 0.0:
		pass_count += 1
		print("[PASS] Turkey(dep=0.0)->Taiwan == 0.0 exactly @ produces=%.2f" % produce_val)
	else:
		fail_count += 1
		print("[FAIL] Turkey(dep=0.0)->Taiwan != 0.0 @ produces=%.2f (value=%.18f)" % [produce_val, value])


func _check(label: String, cond: bool, _detail: String) -> void:
	if cond:
		pass_count += 1
		print("[PASS] %s" % label)
	else:
		fail_count += 1
		print("[FAIL] %s" % label)
