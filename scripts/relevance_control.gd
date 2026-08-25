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
				gates[gate] = {
					"holders": {}, "controllers": {}, "paths_count": 0,
					"visits": [], "cycle_events": [], "steps": 0
				}
			(gates[gate]["holders"] as Dictionary)[String(hname)] = pdeg

			var slot: Dictionary = gates[gate]
			var controllers: Dictionary = {}
			var used := _dfs_up(String(hname), pdeg, rev, {String(hname): true},
				controllers, slot, cycles, entities)
			slot["controllers"] = controllers
			slot["paths_count"] = int(slot["paths_count"]) + controllers.size()
			slot["steps"] = used

	return {"gates": gates, "cycles": cycles}


# يعيد عدد الخطوات المنفذة (زيارة + فحص حافة) — دليل إنهاء الدورات (طلب المراجعة)
static func _dfs_up(node: String, prod: float, rev: Dictionary, visited: Dictionary,
		out_controllers: Dictionary, gate_slot: Dictionary, cycles: Array,
		_entities: Dictionary) -> int:
	var steps := 1
	gate_slot["visits"].append({"node": node, "degree": prod})
	if not out_controllers.has(node):
		out_controllers[node] = prod
	else:
		out_controllers[node] = maxf(float(out_controllers[node]), prod)
	for e in rev.get(node, []):
		steps += 1
		var nxt := String((e as Dictionary).get("from", ""))
		var deg := float((e as Dictionary).get("degree", 0.0))
		if deg <= 0.0 or nxt.is_empty():
			continue
		if visited.has(nxt):
			cycles.append("%s->%s" % [node, nxt])
			(gate_slot["cycle_events"] as Array).append({"at": node, "blocked": nxt})
			continue
		var v2 := visited.duplicate()
		v2[nxt] = true
		steps += _dfs_up(nxt, prod * deg, rev, v2, out_controllers, gate_slot, cycles, _entities)
	return steps


# ExerciseCapability: تمرير شفاف لتصنيف المحتوى (بنيوي، بلا نية)
static func exercise_capability(projection_class: String, projection_table: Dictionary) -> float:
	return float(projection_table.get(projection_class, projection_table.get("default", 0.0)))


const RS := preload("res://scripts/relevance_supply.gd")

# §3.2 من الوثيقة 10 (مجمدة حرفيًا): تعرض العبور عبر ممر لقدرة محددة
static func exposure_transit(world: Dictionary, cfg: Dictionary, y: String, route_gate: String) -> float:
	var entities: Dictionary = world["entities"]
	var consumer: Dictionary = entities.get(y, {})
	var transit: Dictionary = (consumer.get("transit_dependency", {}) as Dictionary).get(route_gate, {})
	var criticality: Dictionary = cfg.get("criticality", {})
	var total := 0.0
	for cap_key in transit.keys():
		var dep := clampf(float(transit[cap_key]), 0.0, 1.0)
		var crit := RS.sector_criticality(consumer, String(cap_key), criticality)
		total += dep * crit
	return total


# Relevance_Access(Y ⇐ X): قناة الوصول (§5) — مجموع حدين لكل بوابة تحت سيطرة X:
#   حد العبور : DP(X,gate) × ExCap(X,gate) × ExposureTransit(Y ⇐ gate)
#   حد الإمداد خلف البوابة: DP × ExCap × Σ ExposureSupply(Y⇐holder, guarded_cap)
static func relevance_access(world: Dictionary, chains: Dictionary, cfg: Dictionary,
		y: String, x: String) -> Dictionary:
	var entities: Dictionary = world["entities"]
	var gates: Dictionary = chains["gates"]
	var projection_table: Dictionary = cfg.get("projection_table", {})
	var gates_guard: Dictionary = cfg.get("gates_guard", {})
	var criticality: Dictionary = cfg.get("criticality", {})
	var ex_cap := exercise_capability(
		String((entities[x] as Dictionary).get("projection_class", "default")),
		projection_table)
	var total := 0.0
	for gate in gates.keys():
		var gd: Dictionary = gates[gate]
		var dp := float((gd["controllers"] as Dictionary).get(x, 0.0))
		if dp <= 0.0 or ex_cap <= 0.0:
			continue

		# حد العبور (§3.2): ممر يمرر قدرات يعتمد عليها Y
		var transit_expo := exposure_transit(world, cfg, y, gate)
		if transit_expo > 0.0:
			total += dp * ex_cap * transit_expo

		# حد الإمداد خلف البوابة: الحائز ينتج قدرة مُحراسة (نمط ترخيص ASML)
		for guarded in (gates_guard.get(gate, []) as Array):
			var gcap := String(guarded)
			for holder in (gd["holders"] as Dictionary).keys():
				var holder_produces: Dictionary = (entities[holder] as Dictionary).get("produces", {})
				var share := RS.supply_share(holder_produces, entities.values(), gcap)
				if share <= 0.0:
					continue
				var eff := RS.effective_depends_on(entities[y], gcap)
				var crit := RS.sector_criticality(entities[y], gcap, criticality)
				total += eff * share * crit * dp * ex_cap
	return {"value": total}
