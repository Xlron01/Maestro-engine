extends SceneTree

# ============================================================
# TEST 1-PRIME — RELEVANCE PIPELINE TEST (over FROZEN Model v1)
# وفق 10-Strategic-Relevance-Model-v1.md §9: إعادة بناء روح Test 1
# فوق المفردات الكاملة، مع خاصيتين جديدتين:
#   ظهور Relevance عبر قناة الوصول/السلسلة بلا أي إنتاج أو اعتماد مباشر
#   جمود البنية تحت انقلاب نية خارجي (S7/S8 منفذًا لا نظريًا)
#
# التوقعات المسجلة قبل التشغيل:
#   W1P:
#     T1 supply emergence: rel_supply(China→NL) > 0
#     T2 access emergence: rel_access(China→Washington) > 0 — بدون إنتاج
#        ولا اعتماد مباشر بين China وWashington (سلسلة سلطة فقط)
#     T3 L1-joint: انقلاب stance + إضافة hostile_relation ⇒ الطبقات الثلاث bitwise
#     T4 alt_add: Third(0.5) ⇒ supply_rel(China→NL)↓ صارمًا + access_rel(China→Wash)↓
#        صارمًا (تخفيف خلف البوابة يمر عبر القناتين) + Third هدف جديد > 0
#     T5 gate_close: سحب possession من NL ⇒ access(China→Washington)==0.0 بالضبط
#        وsupply_rel(China→NL) bitwise ثابت (الإنتاج لم يتغير)
#     T6 authority_break: حذف سهم السلطة ⇒ نفس انهيار الوصول مع بقاء الحيازة
#     T7 res_up: احتياطي China ↑ ⇒ supply_rel نحو NL ↓ وصفه وحده
#     T8 عزل: Anchor ≡ 0.0 bitwise في كل الحالات
#   W2P (هرمز-style):
#     T9 access emergence: access(Importer_J→Strait_Authority) > 0
#     T10 net-exporter: كل قيم Net_Exporter == 0.0 bitwise (يبدو مهمًا وليس كذلك)
#     T11 عزل: Bystander_W2 ≡ 0.0 bitwise
#   Joint:
#     J-1 L2: صفر مفاتيح تجميعية في مخرجات العالمين
#     J-2 L3: كل القيم المشتقة float خالص
#     J-3 حتمية: تشغيل مزدوج لكل عالم متطابق
#
# أي فشل = توقف وتوثيق — النموذج المجمد لا يُعدل post-hoc.
# ============================================================

const RS := preload("res://scripts/relevance_supply.gd")
const RC := preload("res://scripts/relevance_control.gd")
const WORLDS := {
	"w1p": "res://data/worlds/model_v1/test1p_w1.json",
	"w2p": "res://data/worlds/model_v1/test1p_w2.json",
}

var pass_count := 0
var fail_count := 0
var worlds_cache := {}


func _init() -> void:
	print("")
	print("============================================================")
	print("  TEST 1-PRIME — RELEVANCE PIPELINE OVER FROZEN MODEL v1")
	print("============================================================")

	var cfg: Dictionary = RS.load_config()
	if cfg.is_empty():
		print("[FATAL] missing relevance config")
		quit(1)
		return

	var worlds := {}
	var outputs := {}
	for wname in WORLDS.keys():
		print("[phase] computing %s" % wname)
		var w := _load(WORLDS[wname])
		if w.is_empty():
			print("[FATAL] missing world %s" % wname)
			quit(1)
			return
		worlds[wname] = w
		outputs[wname] = _layers(w, cfg)
	worlds_cache = worlds
	print("[phase] outputs computed")

	# ---------- النتائج الخام ----------
	print("")
	print("[phase] printing raw results")
	print("---------------- RAW RESULTS ----------------")
	var printed := 0
	for wname in worlds.keys():
		var chains: Dictionary = outputs[wname]["chains"]
		for gate in chains["gates"].keys():
			var gd: Dictionary = chains["gates"][gate]
			print("")
			print("%s / gate=%s holder(s): %s" % [wname, gate, gd["holders"].keys()])
			for c in gd["controllers"].keys():
				print("   controller %s deg=%.10f" % [c, float(gd["controllers"][c])])
				printed += 1
		var sup: Dictionary = outputs[wname]["supply"]
		for o in sup.keys():
			for t in sup[o].keys():
				if float(sup[o][t]) != 0.0:
					print("   rel_supply(%s -> %s) = %.10f" % [o, t, float(sup[o][t])])
					printed += 1
		var acc: Dictionary = outputs[wname]["access"]
		for o in acc.keys():
			for t in acc[o].keys():
				if float(acc[o][t]) != 0.0:
					print("   rel_access(%s -> %s) = %.10f" % [o, t, float(acc[o][t])])
					printed += 1
	print("")
	print("[phase] raw done, %d lines" % printed)
	print("----------------------------------------------")

	# ---------- Verdicts ----------
	print("")
	print("[phase] verdicts starting")
	print("---------------- TEST 1-PRIME VERDICTS ----------------")
	print("")
	_w1_emergence(outputs)
	print("[phase] T1/T2 done")
	_w1_l1_joint(worlds, cfg, outputs)
	print("[phase] T3 done")
	_w1_alternatives(worlds, cfg, outputs)
	print("[phase] T4 done")
	_w1_gate_close(worlds, cfg, outputs)
	print("[phase] T5 done")
	_w1_authority_break(worlds, cfg, outputs)
	print("[phase] T6 done")
	_w1_reserves(worlds, cfg, outputs)
	print("[phase] T7 done")
	_w2_transit(outputs)
	print("[phase] T9 done")
	_w2_net_exporter(outputs)
	print("[phase] T10 done")
	_joint_anchors(worlds, outputs)
	print("[phase] anchors done")
	_joint_l2(outputs)
	print("[phase] J-1 done")
	_joint_l3(outputs)
	print("[phase] J-2 done")
	_joint_determinism(cfg)
	print("[phase] J-3 done")

	print("")
	print("============================================================")
	if fail_count == 0:
		print("  TEST 1-PRIME RESULT: PASS (%d checks)" % pass_count)
	else:
		print("  TEST 1-PRIME RESULT: FAIL (%d passed, %d failed)" % [pass_count, fail_count])
	print("============================================================")
	quit(1 if fail_count > 0 else 0)


# ============================================================
# Helpers
# ============================================================

func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("missing %s" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("invalid json")
		return {}
	return parsed


func _layers(world: Dictionary, cfg: Dictionary) -> Dictionary:
	var chains: Dictionary = RC.control_chains(world)
	var supply: Dictionary = {}
	var access: Dictionary = {}
	var entities: Dictionary = world["entities"]
	for y in entities.keys():
		supply[y] = {}
		access[y] = {}
		for x in entities.keys():
			if String(y) == String(x):
				continue
			supply[y][x] = float(RS.relevance_supply(world, cfg, String(y), String(x))["value"])
			access[y][x] = float(RC.relevance_access(world, chains, cfg, String(y), String(x))["value"])
	return {"chains": chains, "supply": supply, "access": access}


func _v(layer: String, outputs: Dictionary, wname: String, o: String, t: String) -> float:
	return float(outputs[wname][layer][o][t])


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


func _rows_bitwise_equal(layer: String, a_out: Dictionary, b_out: Dictionary,
		wname: String, skip_obs: Array = []) -> bool:
	var ma: Dictionary = a_out[layer]
	var mb: Dictionary = b_out[layer]
	for o in ma.keys():
		if o in skip_obs:
			continue
		if not mb.has(o):
			return false
		for t in ma[o].keys():
			if float(ma[o][t]) != float(mb[o][t]):
				return false
	return true


func _row_zero(layer_map: Dictionary, obs: String) -> bool:
	for t in layer_map[obs].keys():
		if float(layer_map[obs][t]) != 0.0:
			return false
	return true


# ============================================================
# W1P verdicts
# ============================================================

func _w1_emergence(outputs: Dictionary) -> void:
	print("-- T1/T2: Dual-channel emergence over the frozen model")
	var s := _v("supply", outputs, "w1p", "China_Entity", "NL_Entity")
	var a := _v("access", outputs, "w1p", "China_Entity", "Washington")
	print("   supply(China→NL)=%.10f access(China→Washington)=%.10f" % [s, a])
	_check("T1 supply emergence via production dependence", s > 0.0, "")
	_check("T2 access emergence via authority chain only (no production/deps on Washington)",
		a > 0.0, "")


func _w1_l1_joint(worlds: Dictionary, cfg: Dictionary, outputs: Dictionary) -> void:
	print("-- T3: L1 joint across the full pipeline (intent/hostility flip)")
	var w: Dictionary = (worlds["w1p"] as Dictionary).duplicate(true)
	(w["entities"]["Washington"] as Dictionary)["stance"] = "coercive"
	(w["entities"]["China_Entity"] as Dictionary)["hostile_relation_with"] = ["Washington"]
	var flipped := _layers(w, cfg)
	var diffs := []
	for o in outputs["w1p"]["supply"].keys():
		for t in outputs["w1p"]["supply"][o].keys():
			if float(outputs["w1p"]["supply"][o][t]) != float(flipped["supply"][o][t]):
				diffs.append("supply %s->%s" % [o, t])
	for o in outputs["w1p"]["access"].keys():
		for t in outputs["w1p"]["access"][o].keys():
			if float(outputs["w1p"]["access"][o][t]) != float(flipped["access"][o][t]):
				diffs.append("access %s->%s" % [o, t])
	print("   [debug] differing cells: ", diffs if diffs.size() > 0 else "NONE")
	var ok_supply := diffs.is_empty()
	var ok_access := diffs.is_empty()
	var ok_chains := _canonical(_strip_diag(outputs["w1p"]["chains"])) == \
		_canonical(_strip_diag(flipped["chains"]))
	_check("T3 supply channel bitwise frozen under intent/hostility flips", ok_supply,
		"diffs=%d" % diffs.size())
	_check("T3 access channel bitwise frozen under intent/hostility flips", ok_access, "")
	_check("T3 chain composition bitwise frozen under intent/hostility flips", ok_chains, "")


func chains_of(out: Dictionary) -> Dictionary:
	return out["chains"]


func _w1_alternatives(worlds: Dictionary, cfg: Dictionary, outputs: Dictionary) -> void:
	print("-- T4: Alternative producer dilutes BOTH channels toward the incumbent")
	var s_base := _v("supply", outputs, "w1p", "China_Entity", "NL_Entity")
	var s_alt := _alt_value(cfg, "supply")
	var a_base := _v("access", outputs, "w1p", "China_Entity", "Washington")
	var a_alt := _alt_value(cfg, "access")
	print("   supply %.10f -> %.10f | access %.10f -> %.10f" % [s_base, s_alt, a_base, a_alt])
	_check("T4a supply channel drops strictly when alternative enters", s_alt < s_base, "")
	_check("T4b access channel drops strictly (gate guards the diluted flow)", a_alt < a_base, "")


func _alt_value(cfg: Dictionary, channel: String) -> float:
	var w: Dictionary = (worlds_cache["w1p"] as Dictionary).duplicate(true)
	w["entities"]["Fab_Secondary"]["produces"]["EUV_flow"] = 0.30 + 0.50
	w["entities"]["Alt_Fab"] = {"role": "producer_subject", "produces": {"EUV_flow": 0.50}}
	var layers := _layers(w, cfg)
	return float(layers[channel]["China_Entity"]["NL_Entity"])


func _w1_gate_close(worlds: Dictionary, cfg: Dictionary, outputs: Dictionary) -> void:
	print("-- T5: Gate closure removes derived control entirely (exactly zero)")
	var w: Dictionary = (worlds["w1p"] as Dictionary).duplicate(true)
	(w["entities"]["NL_Entity"] as Dictionary).erase("possession")
	var layers := _layers(w, cfg)
	var acc := float(layers["access"]["China_Entity"]["Washington"])
	var sup_stable := _rows_bitwise_equal("supply", outputs["w1p"], layers, "w1p")
	_check("T5a gate closure collapses access relevance to exactly 0.0", acc == 0.0,
		"%.18f" % acc)
	_check("T5b supply channel bitwise unchanged by gate closure", sup_stable, "")
	var chains_after: Dictionary = RC.control_chains(w)
	var euv_ctrl: Dictionary = (chains_after["gates"].get("EUV_gate", {}) as Dictionary).get("controllers", {})
	_check("T5c EUV_gate has zero controllers after possession removal",
		euv_ctrl.is_empty(), str(euv_ctrl.keys()))


func _w1_authority_break(worlds: Dictionary, cfg: Dictionary, outputs: Dictionary) -> void:
	print("-- T6: Authority break collapses chain control, keeps direct supply intact")
	var w: Dictionary = (worlds["w1p"] as Dictionary).duplicate(true)
	(w["entities"]["Washington"] as Dictionary)["authority"] = []
	var layers := _layers(w, cfg)
	var acc := float(layers["access"]["China_Entity"]["Washington"])
	var sup_same := float(layers["supply"]["China_Entity"]["NL_Entity"]) == \
		float(outputs["w1p"]["supply"]["China_Entity"]["NL_Entity"])
	_check("T6a authority break collapses Washington access to exactly 0.0", acc == 0.0,
		"%.18f" % acc)
	_check("T6b direct supply channel untouched by authority break (bitwise)", sup_same, "")


func _w1_reserves(worlds: Dictionary, cfg: Dictionary, outputs: Dictionary) -> void:
	print("-- T7: Reserve depth lowers the holder's row only")
	var w: Dictionary = (worlds["w1p"] as Dictionary).duplicate(true)
	w["entities"]["China_Entity"]["reserves_days"]["EUV_flow"] = 300
	var layers := _layers(w, cfg)
	var base_v := float(outputs["w1p"]["supply"]["China_Entity"]["NL_Entity"])
	var up_v := float(layers["supply"]["China_Entity"]["NL_Entity"])
	var others_same := true
	for o in outputs["w1p"]["supply"].keys():
		if String(o) == "China_Entity":
			continue
		for t in outputs["w1p"]["supply"][o].keys():
			if float(outputs["w1p"]["supply"][o][t]) != float(layers["supply"][o][t]):
				others_same = false
	print("   China->NL: %.10f -> %.10f | other rows identical: %s"
		% [base_v, up_v, others_same])
	_check("T7 deeper reserves lower holder's own relevance", up_v < base_v, "")
	_check("T7b all non-China rows bitwise identical", others_same, "")


func _w2_transit(outputs: Dictionary) -> void:
	print("-- T9: Transit-gate leverage emerges for the gated importer")
	var a := _v("access", outputs, "w2p", "Importer_J", "Strait_Authority")
	print("   Importer_J->Strait_Authority = %.10f" % a)
	_check("T9 transit gate produces positive access leverage for the importer", a > 0.0, "")


func _w2_net_exporter(outputs: Dictionary) -> void:
	print("-- T10: Net exporter is structurally irrelevant to its own export gate")
	var all_zero := true
	for t in outputs["w2p"]["supply"]["Net_Exporter"].keys():
		if _v("supply", outputs, "w2p", "Net_Exporter", t) != 0.0:
			all_zero = false
	for t in outputs["w2p"]["access"]["Net_Exporter"].keys():
		if _v("access", outputs, "w2p", "Net_Exporter", t) != 0.0:
			all_zero = false
	_check("T10 Net_Exporter rows are identically 0.0 across both channels "
		+ "(seemingly-important-but-isn't, executed)", all_zero, "")


func _joint_anchors(worlds: Dictionary, outputs: Dictionary) -> void:
	print("-- T8/T11: Zero-dependency anchors across both worlds")
	var ok := true
	for pair in [["w1p", "Bystander_W1"], ["w2p", "Bystander_W2"]]:
		for layer in ["supply", "access"]:
			for t in outputs[pair[0]][layer][pair[1]].keys():
				if float(outputs[pair[0]][layer][pair[1]][t]) != 0.0:
					ok = false
	_check("Anchors identically 0.0 in every channel of every state", ok, "")


func _joint_l2(outputs: Dictionary) -> void:
	print("-- J-1: L2 no aggregate keys anywhere")
	var forbidden := ["total_danger", "threat_level", "global_threat", "overall_risk"]
	var found := false
	for wname in outputs.keys():
		for section in ["chains", "supply", "access"]:
			_scan_aggregate(outputs[wname][section], forbidden, found, wname + "/" + section)
	_check("J-1 no aggregate keys in any derived output", not found, "")


func _scan_aggregate(node, forbidden: Array, found_ref, tag: String) -> void:
	if node is Dictionary:
		for k in node.keys():
			if String(k) in forbidden:
				found_ref = true
				print("  [AGGREGATE] %s: %s" % [tag, k])
			_scan_aggregate(node[k], forbidden, found_ref, tag)
	elif node is Array:
		for item in node:
			_scan_aggregate(item, forbidden, found_ref, tag)


func _joint_l3(outputs: Dictionary) -> void:
	print("-- J-2: L3 every emitted derived value is a bare float")
	var all_floats := true
	for wname in outputs.keys():
		for section in ["supply", "access"]:
			var sec: Dictionary = outputs[wname][section]
			for o in sec.keys():
				for t in sec[o].keys():
					if typeof(sec[o][t]) != TYPE_FLOAT:
						all_floats = false
		var ch: Dictionary = outputs[wname]["chains"]
		for g in ch["gates"].keys():
			var gd: Dictionary = ch["gates"][g]
			for h in (gd["holders"] as Dictionary).values():
				if typeof(h) != TYPE_FLOAT:
					all_floats = false
			for c in (gd["controllers"] as Dictionary).values():
				if typeof(c) != TYPE_FLOAT:
					all_floats = false
	_check("J-2 all emitted values across both worlds are bare floats", all_floats, "")


func _joint_determinism(cfg: Dictionary) -> void:
	print("-- J-3: Determinism double-run per world")
	var ok := true
	for wname in WORLDS.keys():
		var w: Dictionary = (worlds_cache[wname] as Dictionary).duplicate(true)
		var r1 := _layers(w, cfg)
		var r2 := _layers(w.duplicate(true), cfg)
		if JSON.stringify(r1) != JSON.stringify(r2):
			ok = false
	_check("J-3 double-run fully identical for both worlds", ok, "")


func _canonical(v) -> String:
	# كانوني مع تجريد الحقول التشخيصية
	return JSON.stringify(_sort_rec(_strip_diag(v)))


func _strip_diag(v):
	if v is Dictionary:
		var o := {}
		for k in (v as Dictionary).keys():
			var ks := String(k)
			if ks in ["visits", "cycle_events", "steps"]:
				continue
			o[ks] = _strip_diag(v[k])
		return o
	if v is Array:
		var a: Array = []
		for item in v:
			a.append(_strip_diag(item))
		return a
	return v


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
