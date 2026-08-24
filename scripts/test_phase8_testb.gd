extends SceneTree

# ============================================================
# PHASE 8 — TEST B: WORLD-SENSITIVITY VALIDATION
# («نفس الدولة، عالم مختلف») — وفق التعريف المجمد في 00-خطة-الطريق.md
#
# السؤال: لو غيّرنا متغيرًا واحدًا في العالم (مش الصيغة)، هل القيمة
# المشتقة تتغير تلقائيًا للكيان المرتبط، وتبقى ثابتة bitwise
# للكيان غير المرتبط هيكليًا؟
#
# الوحدة: DerivedImportance.gd v3 — مجمّدة بالكامل. أي حاجة لتعديلها
# = توقف فوري ورفع القرار لصاحب المشروع (حدود Phase 8).
#
# التوقعات المسجلة قبل أول تشغيل (اتجاهية — من خطة الطريق):
#   B-T1 Response Direction:
#     imp(Buyer_1→Maker_A) تنخفض في B1-a عن الأساس.
#     imp(Route_Buyer→Maker_A) تنخفض في B2-a رغم اعتماده غير المباشر.
#   B-T2 Disjoint-Graph Invariance:
#     كل أزواج Side_Buyer وChain_Side_Buyer bitwise ثابتة (فرق == 0.0)
#     عبر base/a/b — قيمها قد تكون غير صفرية والمطلوب الثبات لا الصفر.
#     ممنوع استخدام weakly-connected كموضوع لهذا الفحص (درس Run 1).
#   B-T3 Zero-Dependency Anchor:
#     Outsider وWatcher: كل الأزواج == 0.0 bitwise في كل الـruns.
#   B-T4 Reversibility:
#     مصفوفة كل عالم كاملة في run-b == مصفوفة الأساس bitwise.
#   B-T5 Target Emergence:
#     imp(Buyer_1→Maker_C) وimp(Route_Buyer→Maker_C): 0.0 في الأساس، >0 في run-a.
#   B-T6 Neutrality Audits:
#     مدخلات بلا مفاتيح نية/أولوية + كل كيان يحمل role صحيح
#     + مصدر الوحدة نظيف من أسماء سيناريوهات B ومن "if world_id".
# ============================================================

const DIModule = preload("res://scripts/DerivedImportance.gd")
const WORLDS := {
	"b1": "res://data/worlds/testb/b1.json",
	"b2": "res://data/worlds/testb/b2.json",
}
const FORBIDDEN_KEYS: Array[String] = [
	"priority", "goal", "importance", "intent", "preference", "cares_about"
]
const VALID_ROLES: Array[String] = [
	"zero_dependency_anchor", "affected_direct", "affected_direct_weak",
	"affected_indirect", "invariant_disjoint", "producer_subject"
]
const ENGINE_SOURCE_PATH := "res://scripts/DerivedImportance.gd"
const RUN_STATES: Array[String] = ["base", "a", "b"]
const EVENT_VALUE := 0.40

var pass_count := 0
var fail_count := 0


func _init() -> void:
	print("")
	print("============================================================")
	print("  PHASE 8 / TEST B — WORLD-SENSITIVITY VALIDATION")
	print("  Module v3 FROZEN | Pre-registered directional expectations")
	print("============================================================")
	print("")

	var worlds := _load_worlds()
	if worlds.is_empty():
		print("[FATAL] Missing/invalid world files.")
		quit(1)
		return

	# ---------- Step 1 audits ----------
	var findings: Array = []
	for wname in worlds.keys():
		_scan_forbidden_keys(worlds[wname], wname, findings)
		_audit_roles(worlds[wname], wname, findings)
	_check("Step1a Input audit: no priority/goal/intent keys in any testb world",
		findings.is_empty(), str(findings))

	var src_findings := _audit_engine_source(worlds)
	_check("Step1b Engine source neutral: no scenario names, no 'if world_id'",
		src_findings.is_empty(), str(src_findings))

	# ---------- الحالات الثلاث لكل عالم (تجاوز أحادي المتغير) ----------
	var states := {}
	for wname in worlds.keys():
		states[wname] = {}
		for st in RUN_STATES:
			var w: Dictionary = (worlds[wname] as Dictionary).duplicate(true)
			if st == "a":
				w["entities"]["Maker_C"]["produces"] = {"Comp_X": EVENT_VALUE}
			elif st == "b":
				w["entities"]["Maker_C"]["produces"] = {"Comp_X": 0.0}
			var idx := DIModule.build_world_index(w)
			states[wname][st] = _collect_matrix(idx)

	# ---------- النتائج الخام قبل أي حكم ----------
	print("")
	print("---------------- RAW RESULTS ----------------")
	for wname in worlds.keys():
		for st in RUN_STATES:
			print("")
			print("%s / %s:" % [wname, st])
			var m: Dictionary = states[wname][st]
			for o in m.keys():
				for t in m[o].keys():
					print("  imp(%s -> %s) = %.10f" % [o, t, m[o][t]])
	print("")
	print("----------------------------------------------")

	# ---------- Sub-test verdicts ----------
	print("")
	print("---------------- SUB-TEST VERDICTS ----------------")
	print("")
	_bt1(states)
	_bt2(states)
	_bt3(states)
	_bt4(states)
	_bt5(states)
	_bt6(findings.is_empty(), src_findings.is_empty())

	print("")
	print("============================================================")
	if fail_count == 0:
		print("  OVERALL RESULT: PASS (%d checks)" % pass_count)
	else:
		print("  OVERALL RESULT: FAIL (%d passed, %d failed)" % [pass_count, fail_count])
		print("  Test B = FAIL. Nothing modified post-hoc.")
	print("============================================================")

	quit(1 if fail_count > 0 else 0)


# ============================================================
# Helpers
# ============================================================

func _load_worlds() -> Dictionary:
	var out := {}
	for wname in WORLDS.keys():
		if not FileAccess.file_exists(WORLDS[wname]):
			push_error("missing %s" % WORLDS[wname])
			return {}
		var f := FileAccess.open(WORLDS[wname], FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("invalid json %s" % WORLDS[wname])
			return {}
		out[wname] = parsed
	return out


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


func _audit_engine_source(worlds: Dictionary) -> Array:
	var findings: Array = []
	var f := FileAccess.open(ENGINE_SOURCE_PATH, FileAccess.READ)
	if f == null:
		return ["engine source unreadable"]
	var text := f.get_as_text()
	for wname in worlds.keys():
		for ename in ((worlds[wname] as Dictionary)["entities"] as Dictionary).keys():
			if text.contains(String(ename)):
				findings.append("source contains entity name '%s'" % ename)
		for cap in (worlds[wname] as Dictionary).get("capabilities_declared", []):
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


func _v(wname: String, states: Dictionary, st: String, o: String, t: String) -> float:
	return float(states[wname][st][o][t])


# ============================================================
# Sub-tests
# ============================================================

func _bt1(states: Dictionary) -> void:
	print("-- B-T1: Response Direction (linked observers move as pre-registered)")
	var b1_base := _v("b1", states, "base", "Buyer_1", "Maker_A")
	var b1_a := _v("b1", states, "a", "Buyer_1", "Maker_A")
	print("   B1 Buyer_1->Maker_A: base=%.10f after=%.10f" % [b1_base, b1_a])
	_check("B1: imp(Buyer_1->Maker_A) drops when alternative emerges", b1_a < b1_base, "")

	var b2_base := _v("b2", states, "base", "Route_Buyer", "Maker_A")
	var b2_a := _v("b2", states, "a", "Route_Buyer", "Maker_A")
	print("   B2 Route_Buyer->Maker_A: base=%.10f after=%.10f (indirect via enables)" % [b2_base, b2_a])
	_check("B2: imp(Route_Buyer->Maker_A) drops through the chain despite indirect dependency",
		b2_a < b2_base, "")


func _bt2(states: Dictionary) -> void:
	print("-- B-T2: Disjoint-Graph Invariance (bitwise row constancy for invariant_disjoint)")
	for cfg in [["b1", "Side_Buyer"], ["b2", "Chain_Side_Buyer"]]:
		var wname: String = cfg[0]
		var obs: String = cfg[1]
		var max_diff := 0.0
		var targets: Array = states[wname]["base"][obs].keys()
		for t in targets:
			var vb := _v(wname, states, "base", obs, t)
			for st in ["a", "b"]:
				var d := absf(_v(wname, states, st, obs, t) - vb)
				if d > max_diff:
					max_diff = d
		_check("%s: %s full row bitwise constant across all runs (max_diff == 0.0)"
			% [wname, obs], max_diff == 0.0, "max_diff=%.18f" % max_diff)


func _bt3(states: Dictionary) -> void:
	print("-- B-T3: Zero-Dependency Anchor (importance identically 0.0)")
	for cfg in [["b1", "Outsider"], ["b2", "Watcher"]]:
		var wname: String = cfg[0]
		var obs: String = cfg[1]
		var all_zero := true
		for st in RUN_STATES:
			for t in states[wname][st][obs].keys():
				if _v(wname, states, st, obs, t) != 0.0:
					all_zero = false
		_check("%s: %s importance == 0.0 exactly in every state" % [wname, obs], all_zero, "")


func _bt4(states: Dictionary) -> void:
	print("-- B-T4: Reversibility (collapse-by-zeroing returns FULL matrices to baseline bitwise)")
	for wname in worlds_keys():
		var same := true
		for o in states[wname]["base"].keys():
			for t in states[wname]["base"][o].keys():
				if _v(wname, states, "base", o, t) != _v(wname, states, "b", o, t):
					same = false
		_check("%s: entire matrix after collapse == baseline matrix bitwise" % wname, same, "")


func _bt5(states: Dictionary) -> void:
	print("-- B-T5: Target Emergence (new producer appears as a derived target)")
	for cfg in [["b1", "Buyer_1"], ["b2", "Route_Buyer"]]:
		var wname: String = cfg[0]
		var obs: String = cfg[1]
		var vb := _v(wname, states, "base", obs, "Maker_C")
		var va := _v(wname, states, "a", obs, "Maker_C")
		_check("%s: imp(%s->Maker_C) == 0.0 at baseline and > 0 after emergence"
			% [wname, obs], vb == 0.0 and va > 0.0, "base=%.10f after=%.10f" % [vb, va])


func _bt6(inputs_clean: bool, source_neutral: bool) -> void:
	print("-- B-T6: Neutrality Audits")
	_check("All testb inputs are neutral world facts with valid roles", inputs_clean, "")
	_check("Derivation module contains no scenario names and no world branching",
		source_neutral, "")


func worlds_keys() -> Array:
	return WORLDS.keys()
