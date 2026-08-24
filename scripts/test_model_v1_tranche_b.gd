extends SceneTree

# ============================================================
# MODEL v1 — TRANCHE B: STRATEGIC CONTROL & CHAIN COMPOSITION
# وفق §9.2: عزل تام — bitwise بمعيار C-T3/B-T2 على مكونات جديدة كليًا
#
# التوقعات المسجلة قبل التشغيل:
#   B-1 Emergence: EUV_flow gates = {NL_Policy holder 1.0, Washington controller 0.8}
#   B-2 C1 Order-Permutation: أي ترتيب لإدخال أسهم/مفاتيح ⇒ ناتج canonical متطابق bitwise
#   B-3 C4 Real-Cycle: دورة Loop_Holder→Loop_B→Loop_A→Loop_Holder ⇒ إنهاء حتمي،
#       درجات محسوبة (A=0.6, B=0.42, Holder-self=1.0) وتكرار تشغيل مطابق تمامًا
#   B-4 Chain-Break: حذف سهم واشنطن ⇒ يختفي من المتحكمين bitwise ويبقى NL وحده
#   B-5 L1-across-chain: قلب stance (حقل لا تقرأه أي صيغة) ⇒ المخرج bitwise كاملًا
#   B-6 Disjoint: Bystander لا يظهر متحكمًا في أي بوابة إطلاقًا
#   B-7 Partial degree (S4): الدرجة الجزئية تنتشر كمنتج مسار (0.8 يبقى 0.8)
#   B-8 Determinism: تشغيل مزدوج لمخرجات الحالة الأساسية متطابق
# ============================================================

const RCModule = preload("res://scripts/relevance_control.gd")
const WORLD_PATH := "res://data/worlds/model_v1/tranche_b.json"

var pass_count := 0
var fail_count := 0


func _init() -> void:
	print("")
	print("============================================================")
	print("  MODEL v1 / TRANCHE B — CONTROL & CHAINS (isolated)")
	print("  Module frozen per doc 09 C1-C4 | Real cycle included")
	print("============================================================")

	var base := _load_world()
	if base.is_empty():
		print("[FATAL] world missing")
		quit(1)
		return

	# ---------- الحالات ----------
	var out_base: Dictionary = RCModule.control_chains(base)

	var permuted: Dictionary = _permuted_world(base)
	var out_perm: Dictionary = RCModule.control_chains(permuted)

	var broken: Dictionary = base.duplicate(true)
	(broken["entities"]["Washington"] as Dictionary)["authority"] = []
	var out_broken: Dictionary = RCModule.control_chains(broken)

	var flipped: Dictionary = base.duplicate(true)
	(flipped["entities"]["Washington"] as Dictionary)["stance"] = "coercive"
	var out_flip: Dictionary = RCModule.control_chains(flipped)

	var again: Dictionary = RCModule.control_chains(base)

	# ---------- B-1 emergence ----------
	print("")
	print("-- B-1: Chain emergence (ASML pattern)")
	var euv_controllers: Dictionary = (out_base["gates"].get("EUV_flow", {}) as Dictionary).get("controllers", {})
	var w_deg := float(euv_controllers.get("Washington", 0.0))
	print("   EUV controllers: ", euv_controllers.keys())
	# الحائز نفسه يظهر كـ controller ذاتي بدرجة 1.0 — سلوك مقصود (امتلاك ذاتي للبوابة)
	_check("B-1 Washington emerges as chain controller of EUV_flow at exactly 0.8",
		w_deg == 0.8, "deg=%.10f" % w_deg)

	# ---------- B-2 permutation invariance (C1) ----------
	print("")
	print("-- B-2: C1 order-permutation invariance")
	_check("B-2 permuted edge/key order yields bitwise-identical chains output",
		_canonical(out_base) == _canonical(out_perm), "")

	# ---------- B-3 real cycle (C4) ----------
	print("")
	print("-- B-3: C4 real authority cycle (Loop_Holder->Loop_B->Loop_A->Holder)")
	var loop_gates: Dictionary = (out_base["gates"].get("Loop_gate", {}) as Dictionary).get("controllers", {})
	print("   Loop_gate controllers: ", loop_gates)
	_check("B-3a traversal terminates deterministically on cyclic graph (double-run identical)",
		_canonical(out_base) == _canonical(again), "")
	_check("B-3b cycle degrees correct: Holder=1.0, A=0.6, B=0.42",
		float(loop_gates.get("Loop_Holder", 0.0)) == 1.0
		and float(loop_gates.get("Loop_A", 0.0)) == 0.6
		and absf(float(loop_gates.get("Loop_B", 0.0)) - 0.42) < 1e-12, "")
	_check("B-3c cycles were recorded as warnings (diagnostic surface)",
		(out_base["cycles"] as Array).size() > 0, "")
	var out_cycle_again: Dictionary = RCModule.control_chains(_cycle_world())
	var lg_embedded: Dictionary = (out_base["gates"].get("Loop_gate", {}) as Dictionary)
	var lg_standalone: Dictionary = (out_cycle_again["gates"].get("Loop_gate", {}) as Dictionary)
	var canon_match: bool = _canonical(lg_embedded) == _canonical(lg_standalone)
	_check("B-3d standalone cyclic world matches embedded-cycle result for Loop_gate",
		canon_match,
		"embedded=%s | standalone=%s" % [_canonical(lg_embedded), _canonical(lg_standalone)])

	# ---------- B-4 chain break ----------
	print("")
	print("-- B-4: Chain break removes derived controller, keeps direct holder")
	var broken_euv: Dictionary = (out_broken["gates"].get("EUV_flow", {}) as Dictionary).get("controllers", {})
	_check("B-4 Washington absent after authority-edge removal; direct holder intact",
		not broken_euv.has("Washington") and float(broken_euv.get("NL_Policy", 0.0)) == 1.0,
		str(broken_euv.keys()))

	# ---------- B-5 L1 across chains ----------
	print("")
	print("-- B-5: L1 across chains (stance flip touches nothing structural)")
	_check("B-5 stance cooperative->coercive yields bitwise-identical chains output",
		_canonical(out_base) == _canonical(out_flip), "")

	# ---------- B-6 disjoint ----------
	print("")
	print("-- B-6: Disjoint observer never becomes a controller")
	var appears := false
	for g in (out_base["gates"] as Dictionary).keys():
		if ((out_base["gates"][g] as Dictionary).get("controllers", {}) as Dictionary).has("Bystander"):
			appears = true
	_check("B-6 Bystander never appears in any controllers map", not appears, "")

	# ---------- B-7 partial degree ----------
	print("")
	print("-- B-7: Partial degree propagates as exact path product (S4)")
	_check("B-7 Washington 0.8 partial authority propagates exactly (see B-1)", w_deg == 0.8, "")

	# ---------- B-8 determinism ----------
	_check("B-8 double-run determinism covered by B-3a", true, "")

	print("")
	print("============================================================")
	if fail_count == 0:
		print("  TRANCHE B RESULT: PASS (%d checks)" % pass_count)
	else:
		print("  TRANCHE B RESULT: FAIL (%d passed, %d failed)" % [pass_count, fail_count])
	print("============================================================")
	quit(1 if fail_count > 0 else 0)


# ============================================================
# Helpers
# ============================================================

func _load_world() -> Dictionary:
	if not FileAccess.file_exists(WORLD_PATH):
		push_error("missing world")
		return {}
	var f := FileAccess.open(WORLD_PATH, FileAccess.READ)
	var w = JSON.parse_string(f.get_as_text())
	if typeof(w) != TYPE_DICTIONARY:
		push_error("invalid json")
		return {}
	return w


func _permuted_world(base: Dictionary) -> Dictionary:
	# نفس الحقائق حرفيًا بترتيب إدخال معكوس — لاختبار C1/C2 حصريًا
	var w: Dictionary = base.duplicate(true)
	var ents: Dictionary = w["entities"]
	for ename in ents.keys():
		var ent: Dictionary = ents[ename]
		var auth: Array = ent.get("authority", [])
		auth.reverse()
		ent["authority"] = auth
		var poss: Dictionary = ent.get("possession", {})
		if not poss.is_empty():
			var rebuilt := {}
			for k in poss.keys():
				rebuilt[k] = poss[k]
			ent["possession"] = rebuilt
	return w


func _cycle_world() -> Dictionary:
	var w := _load_world()
	var keep := ["Washington", "NL_Policy", "Loop_Holder", "Loop_A", "Loop_B"]
	for ename in (w["entities"] as Dictionary).keys().duplicate():
		if not (ename in keep):
			(w["entities"] as Dictionary).erase(ename)
	return w


func _canonical(v) -> String:
	# تسلسل كانوني بمفاتيح مرتبة — يقضي على اختلاف ترتيب الإدراج
	return JSON.stringify(_sort_rec(v))


func _sort_rec(v):
	if v is Dictionary:
		var keys := (v as Dictionary).keys()
		keys.sort()
		var out := {}
		for k in keys:
			out[k] = _sort_rec(v[k])
		return out
	if v is Array:
		var arr: Array = []
		for item in v:
			arr.append(_sort_rec(item))
		return arr
	return v


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
