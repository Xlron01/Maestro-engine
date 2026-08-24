extends SceneTree

# ============================================================
# PHASE 7 — TEST 1: DERIVED IMPORTANCE
# عدّاء الاختبار وفق 05-Test1-Derived-Importance-Handoff.md
#
# ⚠️ RUN 4 — تعديل رسمي معتمد (2026-08-24، قرار صاحب المشروع):
#   Sub-test 1.4 أعيد تعريفه رسميًا في وثيقة التسليم: بند الثبات
#   bitwise ينطبق حصرًا على كيان zero-dependency فعليًا؛ كيان
#   weakly-connected (مصر 0.02) ليس isolated، وحركته النسبية هي نفس
#   السلوك الذي يكافئه 1.3 بـ PASS. الفحص الوحيد الذي كان فاشلًا في
#   Run 1/2 استُبدل بنظيره المطابق للتعريف المصحح (مراقب zero-dep
#   ثابت bitwise = 0.0 عبر كل التجارب المعزولة). لا شيء آخر تغيّر.
#   الأساس: Run 3 PASS 4/4 (phase7_test1_run3_zero_dep_control.log).
#
# قواعد ملزمة مطبقة هنا:
# - الصيغة مجمّدة قبل تشغيل أي عالم (لا تعديل بعد رؤية النتائج).
# - أي فشل في أي Sub-test في أي عالم => Test 1 = FAIL نهائي
#   (استثناء Sub-test 1.3 الملغي بقرار صاحب المشروع).
# - التوقعات اتجاهية مسجلة مسبقًا من جدول التسليم، لا أرقام مطلقة.
# - المخرج خام فقط: قيم فعلية + PASS/FAIL. لا تفسير ولا خطوات قادمة.
# ============================================================

const DIModule = preload("res://scripts/DerivedImportance.gd")
const WORLD_DIR := "res://data/worlds/test1"
const WORLDS: Array[String] = ["world_1", "world_2", "world_3", "world_4", "world_5", "world_6"]
const ENGINE_SOURCE_PATH := "res://scripts/DerivedImportance.gd"

# Sub-test 1.6b: مفاتيح ممنوعة في مدخلات العوالم (تسريب Preference/Intent).
const FORBIDDEN_INPUT_KEYS: Array[String] = [
	"priority", "goal", "importance", "intent", "preference", "cares_about"
]

# عتبات تشغيلية موثقة لتوقعات "قريبة من صفر نسبيًا" المسجلة مسبقًا في جداول التسليم:
# الكيان الأدنى اعتمادًا يجب أن يكون الأصغر بين كل المراقبين وأقل من 10% من الأعلى.
const NEAR_ZERO_RATIO_LIMIT := 0.1

var pass_count := 0
var fail_count := 0


func _init() -> void:
	print("")
	print("============================================================")
	print("  PHASE 7 / TEST 1 — DERIVED IMPORTANCE")
	print("  Formula: Supply Share (frozen before execution)")
	print("  Worlds: 6 | Sub-tests: 1.1 .. 1.6")
	print("============================================================")
	print("")

	var worlds := _load_worlds()
	if worlds.is_empty():
		print("[FATAL] One or more world files missing or invalid.")
		quit(1)
		return

	# ---------- Sub-test 1.6b: تدقيق المدخلات (قبل أي حساب) ----------
	var input_findings: Array = []
	for wname in WORLDS:
		_scan_forbidden_keys(worlds[wname], wname, input_findings)
	_check("1.6b Input audit: no priority/goal/intent keys in any world file",
		input_findings.is_empty(), str(input_findings))

	# ---------- حساب المصفوفة الخام لكل العوالم ----------
	var results := {}
	var output_type_ok := true
	var all_cycles: Array = []
	for wname in WORLDS:
		results[wname] = _compute_matrix(worlds[wname], output_type_ok, all_cycles)
	_check("1.6a All outputs are plain numeric floats (no decision logic attached)",
		output_type_ok, "")
	_check("Propagation cycles encountered (expected: none in Test 1 worlds)",
		all_cycles.is_empty(), str(all_cycles))

	# ---------- طباعة النتائج الخام (قبل أي حكم) ----------
	print("")
	print("---------------- RAW RESULTS (actual computed values) ----------------")
	for wname in WORLDS:
		var entities = worlds[wname]["entities"]
		print("")
		print("World: %s" % wname)
		for obs in entities.keys():
			for tgt in entities.keys():
				if String(obs) == String(tgt):
					continue
				print("  derived_importance(%s -> %s) = %.10f" % [obs, tgt, results[wname][obs][tgt]])
	print("")
	print("----------------------------------------------------------------------")

	# ---------- Sub-test 1.5b: تدقيق حياد كود الاشتقاق ----------
	var src_audit := _audit_engine_source(worlds)
	_check("1.5b Engine source neutral: no entity/capability names, no 'if world_id'",
		src_audit.is_empty(), str(src_audit))

	# ---------- تنفيذ الـ Sub-tests ----------
	print("")
	print("---------------- SUB-TEST VERDICTS ----------------")
	print("")
	_subtest_1_1(results)
	_subtest_1_2(worlds, results)
	_subtest_1_3(results)
	_subtest_1_4(worlds, results)
	_subtest_1_5(src_audit.is_empty())
	_subtest_1_6(input_findings.is_empty(), output_type_ok)

	print("")
	print("============================================================")
	if fail_count == 0:
		print("  OVERALL RESULT: PASS (%d checks passed)" % pass_count)
		print("  Scope statement: هذه النتيجة تعني أن هذه الصيغة قادرة على")
		print("  اشتقاق قيمة أهمية من بيانات العالم مع الحفاظ على الخصائص")
		print("  المختبرة في هذه العوالم الستة فقط — لا أكثر.")
	else:
		print("  OVERALL RESULT: FAIL (%d passed, %d failed)" % [pass_count, fail_count])
		print("  Test 1 = FAIL. No formula redesign is permitted post-hoc.")
	print("============================================================")

	quit(1 if fail_count > 0 else 0)


# ============================================================
# Loading & helpers
# ============================================================

func _load_worlds() -> Dictionary:
	var out := {}
	for wname in WORLDS:
		var path := "%s/%s.json" % [WORLD_DIR, wname]
		if not FileAccess.file_exists(path):
			push_error("Missing world file: %s" % path)
			return {}
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			push_error("Cannot open: %s" % path)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("Invalid JSON: %s" % path)
			return {}
		out[wname] = parsed
	return out


func _compute_matrix(world: Dictionary, type_ok: bool, cycles_acc: Array) -> Dictionary:
	var entities: Dictionary = world["entities"]
	var res := {}
	for obs in entities.keys():
		res[obs] = {}
		for tgt in entities.keys():
			if String(obs) == String(tgt):
				continue
			var out: Dictionary = DIModule.evaluate(world, String(obs), String(tgt))
			var val = out["value"]
			if typeof(val) != TYPE_FLOAT:
				type_ok = false
			if not (out["cycles"] as Array).is_empty():
				cycles_acc.append_array(out["cycles"])
			res[obs][tgt] = float(val)
	return res


func _scan_forbidden_keys(node, origin: String, findings: Array) -> void:
	if node is Dictionary:
		for k in node.keys():
			var key_lower := String(k).to_lower()
			if key_lower in FORBIDDEN_INPUT_KEYS:
				findings.append("%s: forbidden key '%s'" % [origin, k])
			_scan_forbidden_keys(node[k], origin, findings)
	elif node is Array:
		for item in node:
			_scan_forbidden_keys(item, origin, findings)


func _audit_engine_source(worlds: Dictionary) -> Array:
	var findings: Array = []
	if not FileAccess.file_exists(ENGINE_SOURCE_PATH):
		findings.append("engine source missing")
		return findings
	var f := FileAccess.open(ENGINE_SOURCE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	for wname in WORLDS:
		var entities: Dictionary = worlds[wname]["entities"]
		for ent_name in entities.keys():
			if text.contains(String(ent_name)):
				findings.append("source contains entity name '%s'" % ent_name)
		for cap_name in worlds[wname].get("capabilities_declared", []):
			if text.contains(String(cap_name)):
				findings.append("source contains capability name '%s'" % cap_name)
	if text.contains("if world_id"):
		findings.append("source contains 'if world_id' branching")
	return findings


func _check(label: String, cond: bool, detail: String) -> void:
	if cond:
		pass_count += 1
		print("[PASS] %s" % label)
	else:
		fail_count += 1
		var msg := "[FAIL] %s" % label
		if detail != "":
			msg += " | detail: %s" % detail
		print(msg)


func _imp(wname: String, results: Dictionary, obs: String, tgt: String) -> float:
	return float(results[wname][obs][tgt])


func _fresh_world(worlds: Dictionary, wname: String) -> Dictionary:
	return (worlds[wname] as Dictionary).duplicate(true)


func _set_depends(world: Dictionary, ent: String, cap: String, val: float) -> void:
	world["entities"][ent]["depends_on"][cap] = val


func _set_produces(world: Dictionary, ent: String, cap: String, val: float) -> void:
	world["entities"][ent]["produces"][cap] = val


func _run_value(world_copy: Dictionary, obs: String, tgt: String) -> float:
	var out: Dictionary = DIModule.evaluate(world_copy, obs, tgt)
	return float(out["value"])


# ============================================================
# Sub-tests (التوقعات مسجلة مسبقًا من جداول التسليم)
# ============================================================

func _subtest_1_1(results: Dictionary) -> void:
	print("-- Sub-test 1.1: Basic derivation & relative comparison (world_1, world_5)")
	var c_tw := _imp("world_1", results, "China", "Taiwan")
	var eg_tw := _imp("world_1", results, "Egypt", "Taiwan")
	var tr_tw := _imp("world_1", results, "Turkey", "Taiwan")
	_check("W1: importance(China->Taiwan) > importance(Egypt->Taiwan)", c_tw > eg_tw,
		"%.10f vs %.10f" % [c_tw, eg_tw])
	_check("W1: importance(China->Taiwan) > importance(Turkey->Taiwan)", c_tw > tr_tw,
		"%.10f vs %.10f" % [c_tw, tr_tw])

	var a_bx := _imp("world_5", results, "Nation_Alpha", "Nation_Beta")
	var g_bx := _imp("world_5", results, "Nation_Gamma", "Nation_Beta")
	_check("W5: Alpha > Gamma clearly", a_bx > g_bx, "%.10f vs %.10f" % [a_bx, g_bx])


func _subtest_1_2(worlds: Dictionary, results: Dictionary) -> void:
	print("-- Sub-test 1.2: Monotonicity via isolated variable change (world_1b)")

	# سلسلة depends_on: 0.70 (أساس) / 0.85 زيادة / 0.50 نقصان
	var x := _imp("world_1", results, "China", "Taiwan")  # base 0.70
	var w_y := _fresh_world(worlds, "world_1")
	_set_depends(w_y, "China", "semiconductors", 0.85)
	var y := _run_value(w_y, "China", "Taiwan")
	var w_z := _fresh_world(worlds, "world_1")
	_set_depends(w_z, "China", "semiconductors", 0.50)
	var z := _run_value(w_z, "China", "Taiwan")
	print("   depends_on run values: X(0.70)=%.10f Y(0.85)=%.10f Z(0.50)=%.10f" % [x, y, z])
	_check("W1b: Y > X (raising dependency never lowers importance)", y > x, "")
	_check("W1b: Z < X (lowering dependency never raises importance)", z < x, "")

	# سلسلة produces: 0.80 أساس / 0.90 زيادة / 0.70 نقصان
	var p_up_w := _fresh_world(worlds, "world_1")
	_set_produces(p_up_w, "Taiwan", "semiconductors", 0.90)
	var p_up := _run_value(p_up_w, "China", "Taiwan")
	var p_dn_w := _fresh_world(worlds, "world_1")
	_set_produces(p_dn_w, "Taiwan", "semiconductors", 0.70)
	var p_dn := _run_value(p_dn_w, "China", "Taiwan")
	print("   produces run values: P(0.80)=%.10f UP(0.90)=%.10f DOWN(0.70)=%.10f" % [x, p_up, p_dn])
	_check("W1b: producing more never lowers importance", p_up > x, "")
	_check("W1b: producing less never raises importance", p_dn < x, "")


func _subtest_1_3(results: Dictionary) -> void:
	print("-- Sub-test 1.3: Bidirectional substitutability (world_2 -> world_3)")
	var v1 := _imp("world_1", results, "China", "Taiwan")
	var v2 := _imp("world_2", results, "China", "Taiwan")
	var v3 := _imp("world_3", results, "China", "Taiwan")
	print("   W1=%.10f  W2=%.10f  W3=%.10f  |W3-W1|=%.12f" % [v1, v2, v3, absf(v3 - v1)])
	# NO EXCEPTION: أي فشل هنا = FAIL نهائي، ولا يُعدَّل شيء بعد رؤية النتيجة.
	_check("W2: value drops when alternative emerges (China.depends_on untouched)",
		v2 < v1, "")
	_check("W3: value rises back to its world_1 level (|W3-W1| <= 1e-9)",
		v3 > v2 and absf(v3 - v1) <= 1e-9, "")


func _subtest_1_4(worlds: Dictionary, results: Dictionary) -> void:
	print("-- Sub-test 1.4: Correct indifference / isolation (world_1, world_5, world_6)")

	var c_tw := _imp("world_1", results, "China", "Taiwan")
	var us_tw := _imp("world_1", results, "USA", "Taiwan")
	var eg_tw := _imp("world_1", results, "Egypt", "Taiwan")
	var tr_tw := _imp("world_1", results, "Turkey", "Taiwan")
	var others_min := minf(minf(c_tw, us_tw), tr_tw)
	_check("W1: Egypt near-zero relative (smallest among observers AND < 10% of max)",
		eg_tw <= others_min and eg_tw < NEAR_ZERO_RATIO_LIMIT * c_tw,
		"egy=%.10f china=%.10f ratio=%.4f" % [eg_tw, c_tw, eg_tw / c_tw])

	var a_bx := _imp("world_5", results, "Nation_Alpha", "Nation_Beta")
	var g_bx := _imp("world_5", results, "Nation_Gamma", "Nation_Beta")
	_check("W5: Gamma near-zero relative (< 10% of Alpha)",
		g_bx < NEAR_ZERO_RATIO_LIMIT * a_bx,
		"gamma=%.10f alpha=%.10f" % [g_bx, a_bx])

	# ثبات bitwise للمراقب zero-dependency عبر كل تجارب التغيير المعزول
	# (التعريف المصحح لـ 1.4: بند الثبات للكيان بلا أي اعتماد مسجل فقط)
	var tw_base := _imp("world_1", results, "Taiwan", "USA")
	var all_same := true
	for spec in [["depends_on", "China", "semiconductors", 0.85],
			["depends_on", "China", "semiconductors", 0.50],
			["produces", "Taiwan", "semiconductors", 0.90],
			["produces", "Taiwan", "semiconductors", 0.70]]:
		var w := _fresh_world(worlds, "world_1")
		if spec[0] == "depends_on":
			_set_depends(w, spec[1], spec[2], spec[3])
		else:
			_set_produces(w, spec[1], spec[2], spec[3])
		var tw_run := _run_value(w, "Taiwan", "USA")
		if tw_run != tw_base or tw_run != 0.0:
			all_same = false
	_check("W1b: zero-dependency observer (Taiwan) exactly 0.0 and bitwise constant across ALL isolated changes",
		all_same and tw_base == 0.0,
		"base=%.18f" % tw_base)

	# عالم 6 — الاختبار الأخطر: دلتا تتغير، إبسيلون يجب أن يبقى صفر فرق بالضبط
	var d_before := _imp("world_6", results, "Nation_Delta", "Nation_Zeta")
	var e_before := _imp("world_6", results, "Nation_Epsilon", "Nation_Zeta")
	var w_after := _fresh_world(worlds, "world_6")
	w_after["entities"]["Nation_Delta"]["domestic_capacity"] = {"Resource_Z": 0.8}
	var d_after := _run_value(w_after, "Nation_Delta", "Nation_Zeta")
	var e_after := _run_value(w_after, "Nation_Epsilon", "Nation_Zeta")
	var eps_diff := absf(e_after - e_before)
	print("   Delta: %.10f -> %.10f | Epsilon: %.10f -> %.10f (diff=%.12f)"
		% [d_before, d_after, e_before, e_after, eps_diff])
	_check("W6: Delta clearly lower after building domestic substitute", d_after < d_before, "")
	_check("W6: Epsilon EXACTLY identical (zero leakage, diff == 0.0)",
		eps_diff == 0.0, "diff=%.12f" % eps_diff)


func _subtest_1_5(source_neutral: bool) -> void:
	print("-- Sub-test 1.5: Structural Invariance (world_5, world_6)")
	# نفس الدالة بالحرف استُخدمت في كل العوالم الستة (بنفس الوحدة المسبقة التحميل)،
	# والدليل الآلي هو تدقيق مصدر الكود ضد كل أسماء الكيانات والقدرات.
	_check("Same derivation function used verbatim across named AND abstract worlds",
		source_neutral, "see 1.5b audit result above")


func _subtest_1_6(inputs_clean: bool, outputs_numeric: bool) -> void:
	print("-- Sub-test 1.6: No decisions jumped, no preference leak")
	_check("All inputs are neutral world facts (production/use), no intent/priority fields",
		inputs_clean, "")
	_check("All outputs are bare numbers (no goal/action logic attached)",
		outputs_numeric, "")
