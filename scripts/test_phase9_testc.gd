extends SceneTree

# ============================================================
# PHASE 9 — TEST C: STRUCTURAL EMERGENCE
# («نفس العالم، شخصيات مختلفة») — وفق التعريف المجمد في 00-خطة-الطريق.md
#
# ⚠️ توضيح نطاق ملزم: Phase 9 تثبت الأساس اللازم لأي شخصية لاحقة
# (عمى عن الهوية، حساسية للبنية فقط) — وليست اختبار شخصيات فعلية،
# وده مؤجل لمرحلة Derived Traits.
#
# الوحدة: DerivedImportance.gd v3 — مجمّدة بالكامل. أي حاجة لتعديلها
# = توقف فوري ورفع القرار لصاحب المشروع (حدود Phase 9).
#
# التوقعات المسجلة قبل أول تشغيل (من خطة الطريق):
#   C-T1 Profile Differentiation:
#     imp(HD->Prime) > imp(LD->Prime) > 0
#     imp(Chain_Buyer->Prime) > 0 ; imp(Side_Buyer_C->Prime) == 0.0
#   C-T2 Clone Determinism:
#     صف HD_Clone الكامل == صف Heavy_Dep bitwise (تقاطع الأهداف)،
#     وصف Heavy_Dep لم يتغير عن الأساس bitwise.
#   C-T3 Name-Swap Invariance:
#     بعد تبادل كتلتي اعتماد Heavy/Light بين الاسمين:
#     صف Heavy_Dep(المبادَّل) == صف Light_Dep في الأساس bitwise والعكس.
#   C-T4 Dependency Monotonicity:
#     imp(HD->Prime) > imp(CovD->Prime) > imp(LD->Prime).
#   C-T5 Cross-Operation Invariance:
#     Anchor_Null ≡ 0.0 وصفوف Side_Buyer_C/Provider_T bitwise ثابتة
#     عبر base/clone/swapped كلها.
#   C-T6 Neutrality Audits:
#     مدخلات نظيفة + roles مكتملة صحيحة + مصدر نظيف من أسماء السيناريو.
# ============================================================

const DIModule = preload("res://scripts/DerivedImportance.gd")
const WORLD_PATH := "res://data/worlds/testc/w.json"
const FORBIDDEN_KEYS: Array[String] = [
	"priority", "goal", "importance", "intent", "preference", "cares_about"
]
const VALID_ROLES: Array[String] = [
	"zero_dependency_anchor", "affected_direct", "affected_direct_weak",
	"affected_indirect", "invariant_disjoint", "producer_subject",
	"affected_heavy", "affected_light", "affected_covered"
]
const ENGINE_SOURCE_PATH := "res://scripts/DerivedImportance.gd"
const STATES: Array[String] = ["base", "clone", "swapped"]

var pass_count := 0
var fail_count := 0


func _init() -> void:
	print("")
	print("============================================================")
	print("  PHASE 9 / TEST C — STRUCTURAL EMERGENCE")
	print("  Module v3 FROZEN | One fixed world | base / clone-added / name-swapped")
	print("============================================================")
	print("")

	var world := _load_world()
	if world.is_empty():
		print("[FATAL] Missing/invalid world file.")
		quit(1)
		return

	# ---------- C-T6 audits ----------
	var findings: Array = []
	_scan_forbidden_keys(world, "testc_w", findings)
	_audit_roles(world, "testc_w", findings)
	_check("C-T6a Input audit: no forbidden keys, all entities carry valid roles",
		findings.is_empty(), str(findings))
	var src_findings := _audit_engine_source(world)
	_check("C-T6b Engine source neutral: no scenario names, no 'if world_id'",
		src_findings.is_empty(), str(src_findings))

	# ---------- الحالات الثلاث ----------
	var states := {}
	for st in STATES:
		var w: Dictionary = world.duplicate(true)
		if st == "clone":
			w["entities"]["Heavy_Dep_Clone"] = {
				"role": "affected_heavy",
				"depends_on": { "Res_S": 0.80 }
			}
		elif st == "swapped":
			var hd: Dictionary = w["entities"]["Heavy_Dep"]["depends_on"]
			var ld: Dictionary = w["entities"]["Light_Dep"]["depends_on"]
			w["entities"]["Heavy_Dep"]["depends_on"] = ld
			w["entities"]["Light_Dep"]["depends_on"] = hd
		var idx := DIModule.build_world_index(w)
		states[st] = _collect_matrix(idx)

	# ---------- النتائج الخام قبل أي حكم ----------
	print("")
	print("---------------- RAW RESULTS ----------------")
	for st in STATES:
		print("")
		print("state: %s" % st)
		var m: Dictionary = states[st]
		for o in m.keys():
			for t in m[o].keys():
				print("  imp(%s -> %s) = %.10f" % [o, t, m[o][t]])
	print("")
	print("----------------------------------------------")

	# ---------- Sub-test verdicts ----------
	print("")
	print("---------------- SUB-TEST VERDICTS ----------------")
	print("")
	_ct1(states)
	_ct2(states)
	_ct3(states)
	_ct4(states)
	_ct5(states)
	_ct6(findings.is_empty(), src_findings.is_empty())

	print("")
	print("============================================================")
	if fail_count == 0:
		print("  OVERALL RESULT: PASS (%d checks)" % pass_count)
	else:
		print("  OVERALL RESULT: FAIL (%d passed, %d failed)" % [pass_count, fail_count])
		print("  Test C = FAIL. Nothing modified post-hoc.")
	print("============================================================")

	quit(1 if fail_count > 0 else 0)


# ============================================================
# Helpers
# ============================================================

func _load_world() -> Dictionary:
	if not FileAccess.file_exists(WORLD_PATH):
		return {}
	var f := FileAccess.open(WORLD_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _collect_matrix(idx: Dictionary) -> Dictionary:
	var entities: Dictionary = (idx["world"] as Dictionary)["entities"]
	var res := {}
	for o in entities.keys():
		res[o] = {}
		for t in entities.keys():
			if String(o) == String(t):
				continue
			var out: Dictionary = DIModule.evaluate_indexed(idx, String(o), String(t))
			res[o][t] = float(out["value"])
	return res


func _scan_forbidden_keys(node, origin: String, findings: Array) -> void:
	if node is Dictionary:
		for k in node.keys():
			if String(k).to_lower() in FORBIDDEN_KEYS:
				findings.append("%s: forbidden key '%s'" % [origin, k])
			_scan_forbidden_keys(node[k], origin, findings)
	elif node is Array:
		for item in node:
			_scan_forbidden_keys(item, origin, findings)


func _audit_roles(world: Dictionary, origin: String, findings: Array) -> void:
	var entities: Dictionary = world["entities"]
	for ename in entities.keys():
		var role = (entities[ename] as Dictionary).get("role", "")
		if not (String(role) in VALID_ROLES):
			findings.append("%s/%s: missing or invalid role '%s'" % [origin, ename, role])


func _audit_engine_source(world: Dictionary) -> Array:
	var findings: Array = []
	var f := FileAccess.open(ENGINE_SOURCE_PATH, FileAccess.READ)
	if f == null:
		return ["engine source unreadable"]
	var text := f.get_as_text()
	for ename in (world["entities"] as Dictionary).keys():
		if text.contains(String(ename)):
			findings.append("source contains entity name '%s'" % ename)
	for cap in world.get("capabilities_declared", []):
		if text.contains(String(cap)):
			findings.append("source contains capability name '%s'" % cap)
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
			msg += " | %s" % detail
		print(msg)


func _v(st: String, states: Dictionary, o: String, t: String) -> float:
	return float(states[st][o][t])


func _row_equal(m1: Dictionary, m2: Dictionary, obs: String) -> bool:
	# مقارنة صف كامل على تقاطع الأهداف — bitwise
	var targets: Array = m1[obs].keys()
	for t in targets:
		if not m2.has(obs) or not (m2[obs] as Dictionary).has(t):
			continue
		if float(m1[obs][t]) != float(m2[obs][t]):
			return false
	return true


# ============================================================
# Sub-tests
# ============================================================

func _ct1(states: Dictionary) -> void:
	print("-- C-T1: Profile Differentiation (positions differ -> profiles differ)")
	var hd := _v("base", states, "Heavy_Dep", "Maker_Prime")
	var ld := _v("base", states, "Light_Dep", "Maker_Prime")
	var cb := _v("base", states, "Chain_Buyer", "Maker_Prime")
	var sb := _v("base", states, "Side_Buyer_C", "Maker_Prime")
	print("   HD=%.10f LD=%.10f Chain=%.10f Side=%.10f" % [hd, ld, cb, sb])
	_check("C-T1a imp(HD->Prime) > imp(LD->Prime) > 0", hd > ld and ld > 0.0, "")
	_check("C-T1b indirect dependent reaches the supplier through the chain (> 0)", cb > 0.0, "")
	_check("C-T1c disjoint-market observer shows exactly 0.0 toward Res_S supplier",
		sb == 0.0, "")


func _ct2(states: Dictionary) -> void:
	print("-- C-T2: Clone Determinism (identical structure => identical profile, bitwise)")
	var clone_ok := true
	var checked := 0
	var row_targets: Array = states["clone"]["Heavy_Dep_Clone"].keys()
	for t in row_targets:
		# تقاطع الأهداف: استبعاد ذاتيّ الطرفين (صف الكلون يستثني الكلون، وصف الأصل يستثني الأصل)
		if t == "Heavy_Dep" or t == "Heavy_Dep_Clone":
			continue
		if not (states["clone"]["Heavy_Dep"] as Dictionary).has(t):
			continue
		checked += 1
		if _v("clone", states, "Heavy_Dep_Clone", t) != _v("clone", states, "Heavy_Dep", t):
			clone_ok = false
	_check("C-T2a clone full row == original full row bitwise (%d shared targets)"
		% checked, clone_ok, "")
	var orig_stable := _row_equal(states["base"], states["clone"], "Heavy_Dep")
	_check("C-T2b adding a consumer clone disturbs nothing (original row == baseline bitwise)",
		orig_stable, "")


func _ct3(states: Dictionary) -> void:
	print("-- C-T3: Name-Swap Invariance (behavior follows structure, never the name)")
	# تقاطع الأهداف: صف المبادَّل يستثني اسمه، والصف المرجعي يستثني صاحبه الأصلي
	var hd_ok := true
	for t in states["swapped"]["Heavy_Dep"].keys():
		if t == "Heavy_Dep" or t == "Light_Dep":
			continue
		if _v("swapped", states, "Heavy_Dep", t) != _v("base", states, "Light_Dep", t):
			hd_ok = false
	var ld_ok := true
	for t in states["swapped"]["Light_Dep"].keys():
		if t == "Light_Dep" or t == "Heavy_Dep":
			continue
		if _v("swapped", states, "Light_Dep", t) != _v("base", states, "Heavy_Dep", t):
			ld_ok = false
	_check("C-T3a entity named Heavy_Dep now carries Light_Dep's exact baseline profile (bitwise)",
		hd_ok, "")
	_check("C-T3b entity named Light_Dep now carries Heavy_Dep's exact baseline profile (bitwise)",
		ld_ok, "")


func _ct4(states: Dictionary) -> void:
	print("-- C-T4: Dependency Monotonicity (effective dependency orders concern)")
	var hd := _v("base", states, "Heavy_Dep", "Maker_Prime")
	var cd := _v("base", states, "Covered_Dep", "Maker_Prime")
	var ld := _v("base", states, "Light_Dep", "Maker_Prime")
	print("   HD(0.80)=%.10f CovD(eff 0.30)=%.10f LD(0.20)=%.10f" % [hd, cd, ld])
	_check("C-T4 imp(HD) > imp(CovD) > imp(LD) toward the same supplier", hd > cd and cd > ld, "")


func _ct5(states: Dictionary) -> void:
	print("-- C-T5: Cross-Operation Invariance (disjoint market + anchor untouched by clone & swap)")
	var anchor_zero := true
	for st in STATES:
		for t in states[st]["Anchor_Null"].keys():
			if _v(st, states, "Anchor_Null", t) != 0.0:
				anchor_zero = false
	_check("C-T5a Anchor_Null importance identically 0.0 in every state", anchor_zero, "")

	var disjoint_ok := true
	for obs in ["Side_Buyer_C", "Provider_T"]:
		if not _row_equal(states["base"], states["clone"], obs):
			disjoint_ok = false
		if not _row_equal(states["base"], states["swapped"], obs):
			disjoint_ok = false
	_check("C-T5b disjoint-market rows bitwise constant across base/clone/swapped",
		disjoint_ok, "")


func _ct6(inputs_clean: bool, source_neutral: bool) -> void:
	print("-- C-T6: Neutrality Audits")
	_check("All testc inputs are neutral world facts with valid roles", inputs_clean, "")
	_check("Derivation module contains no scenario names and no world branching",
		source_neutral, "")
