extends SceneTree

# ============================================================
# MODEL v1 — TRANCHE A: SUPPLY CHANNEL (Inherited lineage)
# وفق بروتوكول §9.1 المجمد في 10-Strategic-Relevance-Model-v1.md
#
# التوقعات المسجلة قبل التشغيل:
#   A-1 اتجاهية: relevance(HD→Prime) > relevance(LD→Prime) > 0
#   A-2 رتابة اعتماد: HD 0.80→0.90 ⇒ relevance↑ حصريًا لصفه
#   A-3 بدائل↑: Third(0.40) ⇒ انخفاض صارم لدى كل معتمدي Comp_X نحو
#       الموردين القدامى + ظهور HD→Third>0.
#       ⚠️ لماذا اتجاهية لا bitwise-between-dependents (توثيق المراجعة):
#          نسبة الحركة = T/(T+m) × (RF'/RF)؛ المكوّن الأول موحد سوقيًا،
#          لكن RF'/RF يعتمد على slack المستهلك نفسه (احتياطيه) — فالتطابق
#          الكامل يحدث فقط بين متساويي الاحتياطي وليس قاعدة عامة. لذلك
#          المعيار الصح: اتجاه صارم للجميع + اختلاف الاستجابة بين من يختلف
#          احتياطه هو خاصية تُؤكد (A-3d) لا تُخفى.
#   A-4 احتياطي↑: HD reserves 90→300 ⇒ صف HD كاملًا نحو موردي Comp_X ينخفض،
#       وباقي العالم bitwise (الاحتياطي حقfact خاص بالحائز فقط).
#   A-5 Criticality: تحويل Light إلى defense بنفس الوزن ⇒ ارتفاع قيمته فقط
#   A-6 عزل: Anchor_Null ≡ 0.0 bitwise في كل الحالات
#   A-7 حتمية: تشغيل مزدوج لنفس الحالة ⇒ مصفوفة متطابقة تمامًا
#
# أي فشل = توقف وتوثيق — لا تعديل post-hoc. أي مفاجأة سلوكية حتى مع PASS
# تُرفع لصاحب المشروع قبل Tranche B (تعليمات صريحة).
# ============================================================

const RSModule = preload("res://scripts/relevance_supply.gd")
const WORLD_PATH := "res://data/worlds/model_v1/tranche_a.json"
const CONFIG_PATH := "res://data/rules/relevance_config.json"
const STATES: Array[String] = ["base", "dep_up", "alt_add", "res_up", "sector_flip"]

var pass_count := 0
var fail_count := 0


func _init() -> void:
	print("")
	print("============================================================")
	print("  MODEL v1 / TRANCHE A — SUPPLY CHANNEL")
	print("  Frozen formulas per doc 10 section 3 | ReplacementFactor = 1 - EoR")
	print("============================================================")

	var world := _load_world()
	if world.is_empty():
		print("[FATAL] world/config missing")
		quit(1)
		return

	var states := {}
	for st in STATES:
		var w: Dictionary = world.duplicate(true)
		match st:
			"dep_up":
				w["entities"]["Heavy_Dep"]["depends_on"]["Comp_X"] = 0.90
			"alt_add":
				w["entities"]["Maker_Second"]["produces"]["Comp_X"] = 0.30
				w["entities"]["Maker_Prime"]["produces"]["Comp_X"] = 0.70
				w["entities"]["Maker_Third"] = {
					"role": "producer_subject",
					"produces": { "Comp_X": 0.40 }
				}
			"res_up":
				w["entities"]["Heavy_Dep"]["reserves_days"]["Comp_X"] = 300
			"sector_flip":
				w["entities"]["Light_Dep"]["sectors"]["Comp_X"] = "defense"
		states[st] = _collect(w)

	# ---------- النتائج الخام ----------
	print("")
	print("---------------- RAW RESULTS ----------------")
	for st in STATES:
		print("")
		print("state: %s" % st)
		var m: Dictionary = states[st]
		for o in m.keys():
			for t in m[o].keys():
				if float(m[o][t]) != 0.0 or String(o) == "Heavy_Dep":
					print("  rel(%s -> %s) = %.10f" % [o, t, m[o][t]])
	print("")
	print("----------------------------------------------")

	# ---------- Verdicts ----------
	print("")
	print("---------------- TRANCHE A VERDICTS ----------------")
	print("")
	_a1_directional(states)
	_a2_monotone(states, world)
	_a3_alternatives(states, world)
	_a4_reserves(states, world)
	_a5_criticality(states, world)
	_a6_anchor(states)
	_a7_determinism(world)

	print("")
	print("============================================================")
	if fail_count == 0:
		print("  TRANCHE A RESULT: PASS (%d checks)" % pass_count)
	else:
		print("  TRANCHE A RESULT: FAIL (%d passed, %d failed)" % [pass_count, fail_count])
	print("============================================================")

	quit(1 if fail_count > 0 else 0)


func _load_world() -> Dictionary:
	if not FileAccess.file_exists(WORLD_PATH):
		push_error("missing world")
		return {}
	var f := FileAccess.open(WORLD_PATH, FileAccess.READ)
	var w = JSON.parse_string(f.get_as_text())
	if typeof(w) != TYPE_DICTIONARY:
		push_error("invalid json")
		return {}
	if RSModule.load_config(CONFIG_PATH).is_empty():
		return {}
	return w


func _collect(world: Dictionary) -> Dictionary:
	var cfg := RSModule.load_config(CONFIG_PATH)
	var res := {}
	var entities: Dictionary = world["entities"]
	for o in entities.keys():
		res[o] = {}
		for t in entities.keys():
			if String(o) == String(t):
				continue
			var out: Dictionary = RSModule.relevance_supply(world, cfg, String(o), String(t))
			res[o][t] = float(out["value"])
	return res


func _v(st: String, states: Dictionary, o: String, t: String) -> float:
	return float(states[st][o][t])


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		pass_count += 1
		print("[PASS] %s" % label)
	else:
		fail_count += 1
		var msg := "[FAIL] %s" % label
		if detail != "":
			msg += " | %s" % detail
		print(msg)


func _rows_equal(m1: Dictionary, m2: Dictionary, obs: String) -> bool:
	if not (m1.has(obs) and m2.has(obs)):
		return false
	for t in m1[obs].keys():
		if float(m1[obs][t]) != float(m2[obs][t]):
			return false
	return true


func _whole_equal(m1: Dictionary, m2: Dictionary, skip_rows: Array = []) -> bool:
	for o in m1.keys():
		if o in skip_rows:
			continue
		if not _rows_equal(m1, m2, o):
			return false
	return true


# ============================================================
# Sub-tests
# ============================================================

func _a1_directional(states: Dictionary) -> void:
	print("-- A-1: Directional dependence (heavier dependency => higher relevance)")
	var hd := _v("base", states, "Heavy_Dep", "Maker_Prime")
	var ld := _v("base", states, "Light_Dep", "Maker_Prime")
	print("   HD=%.10f LD=%.10f" % [hd, ld])
	_check("A-1 relevance(HD->Prime) > relevance(LD->Prime) > 0", hd > ld and ld > 0.0, "")


func _a2_monotone(states: Dictionary, world: Dictionary) -> void:
	print("-- A-2: Dependency monotonicity (isolated change on Heavy_Dep only)")
	var base := _v("base", states, "Heavy_Dep", "Maker_Prime")
	var up := _v("dep_up", states, "Heavy_Dep", "Maker_Prime")
	print("   0.80=%.10f -> 0.90=%.10f" % [base, up])
	_check("A-2 dep 0.80->0.90 raises relevance strictly", up > base,
		"base=%.10f up=%.10f" % [base, up])
	var others_untouched := _whole_equal(states["base"], states["dep_up"], ["Heavy_Dep"])
	_check("A-2b all other rows bitwise untouched by Heavy's isolated change",
		others_untouched, "")


func _a3_alternatives(states: Dictionary, world: Dictionary) -> void:
	print("-- A-3: Alternatives emergence lowers dominant-supplier relevance")
	# A-3c′ (المعتمد): الاتجاه الصارم هو المعيار — التطابق bitwise بين
	# المعتمدين ليس معيارًا لأن استجابة RF تعتمد على slack كل مستهلك (§ header).
	var dependents := ["Heavy_Dep", "Light_Dep", "Covered_Dep"]
	var all_incumbents_drop := true
	for dep in dependents:
		for supplier in ["Maker_Prime", "Maker_Second"]:
			if _v("base", states, dep, supplier) <= _v("alt_add", states, dep, supplier):
				all_incumbents_drop = false
				print("   [VIOLATION] %s->%s did not drop" % [dep, supplier])
	_check("A-3c-prime every Comp_X dependent strictly drops toward BOTH incumbents",
		all_incumbents_drop, "")
	var new_target := _v("alt_add", states, "Heavy_Dep", "Maker_Third")
	_check("A-3b relevance(HD->Third) > 0 after emergence", new_target > 0.0,
		"%.10f" % new_target)

	# A-3d (توثيق حساسية المخزون كخاصية مؤكدة): اختلاف نسبة الاستجابة بين
	# من يختلف احتياطيه — Heavy(90d) مقابل Covered(30d).
	var r_hd := _v("alt_add", states, "Heavy_Dep", "Maker_Prime") / _v("base", states, "Heavy_Dep", "Maker_Prime")
	var r_cov := _v("alt_add", states, "Covered_Dep", "Maker_Prime") / _v("base", states, "Covered_Dep", "Maker_Prime")
	print("   response ratio HD=%.6f Covered=%.6f (consumer-specific via slack)" % [r_hd, r_cov])
	_check("A-3d response ratio is consumer-specific (slack 90d != 30d)",
		r_hd != r_cov, "")


func _a4_reserves(states: Dictionary, world: Dictionary) -> void:
	print("-- A-4: Reserve depth lowers the holder's whole row toward cap suppliers only")
	var hd_prime_base := _v("base", states, "Heavy_Dep", "Maker_Prime")
	var hd_prime_up := _v("res_up", states, "Heavy_Dep", "Maker_Prime")
	var hd_second_base := _v("base", states, "Heavy_Dep", "Maker_Second")
	var hd_second_up := _v("res_up", states, "Heavy_Dep", "Maker_Second")
	print("   HD->Prime %.10f -> %.10f | HD->Second %.10f -> %.10f"
		% [hd_prime_base, hd_prime_up, hd_second_base, hd_second_up])
	_check("A-4a deeper reserves lower relevance toward Prime", hd_prime_up < hd_prime_base, "")
	_check("A-4a2 deeper reserves lower relevance toward Second equally-sourced",
		hd_second_up < hd_second_base, "")
	var others_untouched := _whole_equal(states["base"], states["res_up"], ["Heavy_Dep"])
	_check("A-4b every OTHER observer row bitwise identical (reserves are holder-private)",
		others_untouched, "")


func _a5_criticality(states: Dictionary, world: Dictionary) -> void:
	print("-- A-5: Sector criticality ordering (defense > civilian at same weight)")
	var civ := _v("base", states, "Light_Dep", "Maker_Prime")
	var def_val := _v("sector_flip", states, "Light_Dep", "Maker_Prime")
	print("   Light civilian=%.10f -> defense=%.10f" % [civ, def_val])
	_check("A-5 defense classification raises exposure at identical dependency",
		def_val > civ, "")
	var others_untouched := _whole_equal(states["base"], states["sector_flip"], ["Light_Dep"])
	_check("A-5b flip is isolated to Light_Dep (others bitwise identical)",
		others_untouched, "")


func _a6_anchor(states: Dictionary) -> void:
	print("-- A-6: Zero-dependency anchor")
	var all_zero := true
	for st in STATES:
		for t in states[st]["Anchor_Null"].keys():
			if _v(st, states, "Anchor_Null", t) != 0.0:
				all_zero = false
	_check("A-6 Anchor_Null identically 0.0 in every state", all_zero, "")


func _a7_determinism(world: Dictionary) -> void:
	print("-- A-7: Determinism (same state computed twice)")
	var a1 := _collect(world.duplicate(true))
	var a2 := _collect(world.duplicate(true))
	_check("A-7 double computation yields fully identical matrices",
		JSON.stringify(a1) == JSON.stringify(a2), "")
