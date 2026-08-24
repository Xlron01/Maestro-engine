extends RefCounted
class_name RelevanceControl

# ============================================================
# MODEL v1 — TRANCHE B: STRATEGIC CONTROL & CHAIN COMPOSITION
# وفق 10-Strategic-Relevance-Model-v1.md §3.4/§4 وقواعد C1–C4 المجمدة (وثيقة 09)
#
# C1 Path Product  : درجة السلطة المشتقة = حاصل ضرب درجات أسهم المسار
#                    (الضرب تبديلي ⇒ مستقل لترتيب الإدخال — خاصية مجمدة)
# C2 Per-Path      : كل مسار بسيط يُحسب ويُفهرس بنفسه
# C3 Max-for-report: أقوى مسار فقط يُعرض لكل متحكم؛ الكل محسوب
# C4 Cycle Skip    : visited على المسار الحالي — الدورات تُسجل وتُقطع
#
# L1: لا مدخل نيّة/عداء هنا إطلاقًا. L2: مخرجات زوجية مفهرسة.
# L3: لا قيمة تهديد — المخرج "بوابات ومتحكمون ودرجات" فقط.
# ============================================================


# يعيد: {gates: {gate: {holders: {}, controllers: {controller: degree}, paths_count}}}
# + cycles: تحذيرات تسجيل الدورات المقابولة (تشخيصي فقط)
static func control_chains(world: Dictionary) -> Dictionary:
	var entities: Dictionary = world["entities"]

	# عكس أسهم السلطة: من الحائز صعودًا نحو من يملك سلطة عليه
	var rev := {}
	for ename in entities.keys():
		for e in (entities[ename] as Dictionary).get("authority", []):
			var to := String((e as Dictionary).get("to", ""))
			var deg := float((e as Dictionary).get("degree", 0.0))
			if to.is_empty():
				continue
			if not rev.has(to):
				rev[to] = []
			rev[to].append({"from": String(ename), "degree": deg})

	var gates := {}
	var cycles: Array = []

	for hname in entities.keys():
		var possession: Dictionary = (entities[hname] as Dictionary).get("possession", {})
		for gkey in possession.keys():
			var gate := String(gkey)
			var pdeg := clampf(float(possession[gkey]), 0.0, 1.0)
			if not gates.has(gate):
				gates[gate] = {"holders": {}, "controllers": {}, "paths_count": 0}
			(gates[gate]["holders"] as Dictionary)[String(hname)] = pdeg

			var controllers: Dictionary = {}
			_dfs_up(String(hname), pdeg, rev, {String(hname): true},
				controllers, cycles, entities)
			gates[gate]["controllers"] = controllers
			gates[gate]["paths_count"] = int(gates[gate]["paths_count"]) + controllers.size()

	return {"gates": gates, "cycles": cycles}


static func _dfs_up(node: String, prod: float, rev: Dictionary, visited: Dictionary,
		out_controllers: Dictionary, cycles: Array, _entities: Dictionary) -> void:
	# كل عقدة على مسار بسيط نحو الحائز = مرشح متحكم بدرجة المنتج حتى الآن.
	if not out_controllers.has(node):
		out_controllers[node] = prod
	else:
		out_controllers[node] = maxf(float(out_controllers[node]), prod)
	for e in rev.get(node, []):
		var nxt := String((e as Dictionary).get("from", ""))
		var deg := float((e as Dictionary).get("degree", 0.0))
		if deg <= 0.0 or nxt.is_empty():
			continue
		if visited.has(nxt):
			cycles.append("%s->%s" % [node, nxt])
			continue
		var v2 := visited.duplicate()
		v2[nxt] = true
		_dfs_up(nxt, prod * deg, rev, v2, out_controllers, cycles, _entities)


# ExerciseCapability: تمرير شفاف لتصنيف المحتوى (بنيوي، بلا نية) — v1 placeholder
static func exercise_capability(projection_class: String, projection_table: Dictionary) -> float:
	return float(projection_table.get(projection_class, projection_table.get("default", 0.0)))
