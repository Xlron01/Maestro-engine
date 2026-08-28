extends RefCounted
class_name DerivedImportance

# ============================================================
# Derived Importance — Phase 7 / Test 1 — RUN 2 (v2)
# ASSUMPTION CHANGE #1 (بقرار صاحب المشروع بعد Run 1):
#   نطاق مقام الـ normalization: Global → Local.
#   لا شيء آخر تغيّر: نفس العوالم الستة، نفس العدّاء byte-by-byte،
#   نفس التوقعات المسجلة مسبقًا.
#
# PROPAGATION SEMANTICS — كما في Run 1 (غير متغيرة):
#
# 1) eff_dep(O,C) = depends_on[O][C] * (1 - domestic_capacity[O][C])
#    domestic_capacity يُقصّ على [0,1]. تبسيط موثق: يقلص الاعتماد
#    المباشر على تلك القدرة فقط.
#
# 2) maxpath(P ⇝ C): أقصى حاصل ضرب أوزان الأسهم على أي مسار بلا
#    دورات من P إلى C عبر enables. P == C ⇒ 1.0، لا مسار ⇒ 0.0.
#
# 3) مسارات متعددة لنفس الزوج: أقوى مسار واحد فقط (max product)
#    — ممنوع الجمع المزدوج.
#
# 4) الدورات: تُتجاهل مع تسجيل تحذير في cycles_out.
#
# 5) propagated_dep(O,P) = Σ_C eff_dep(O,C) * maxpath(P ⇝ C)
#
# 6) derived_importance(O,T) = Σ_{Q ∈ produces[T]}
#        propagated_dep(O,Q) * share_local(O,T,Q)
#
# SEMANTICS الجديدة v2 — النطاق المحلي للمقام (تعريف مجمد قبل التشغيل):
#
#   DepNeighborhood(O) = مجموعة القدرات التي يقع المراقب O في حي
#   اعتماد عليها فعليًا: كل قدرة يعتمدها مباشرة + كل سلالف هذه
#   القدرات عبر رسم enables (مشية عكسية بـ visited-set، آمنة للدورات).
#
#   share_local(O,T,Q) =
#       0.0                                        إذا Q ∉ DepNeighborhood(O)
#       produces[T][Q] / Σ_P produces[P][Q]        وإلا
#       حيث P كل كيان منتج للقدرة Q في العالم.
#
#   المبرر: قدرة خارج حي اعتماد المراقب لا يُسمح لها بإدخال أي
#   معلومة عن منتجيها إلى حسابه — إغلاق ثقب التسريب الهيكلي
#   الموثق في Run 1 (حكم التصنيف ب).
#
# PREDICTION مسجل قبل التشغيل (قابل للتفنيد):
#   رياضيًا، إذا كانت Q ∉ DepNeighborhood(O) فإن propagated_dep(O,Q)=0
#   أصلًا، فحدّ النطاق الجديد يصفر حلمًا كان سيُضرب في صيفًا؛ وإذا كانت
#   Q ∈ DepNeighborhood(O) فإن مجموع المنتجين كما هو. لذلك التوقع:
#   v2 ≡ v1 رقميًا على أي مدخلات، بما فيها العوالم الستة — أي أن
#   الفحص الوحيد الفاشل في Run 1 سيظل فاشلًا بنفس الأرقام بالضبط.
#   الغاية من التشغيل: إثبات هذا التطابق تجريبيًا وفق منهجية
#   "غيّر assumption واحدًا وأعد نفس الاختبار"، لإنتاج الدليل بأن
#   المشكلة ليست في scope المقام وحدها (فرع "تحقيق أعمق" بشجرة القرار).
#
# الوحدة محايدة تمامًا: لا أسماء كيانات، لا تفرع بمعرّف عالم،
# مدخلات/مخرجات Dictionaries وأرقام فقط، حتمية 100%.
# ============================================================


static func effective_depends_on(depends_on: Dictionary, domestic_capacity: Dictionary, cap: String) -> float:
	var dep := float(depends_on.get(cap, 0.0))
	var dom := clampf(float(domestic_capacity.get(cap, 0.0)), 0.0, 1.0)
	return dep * (1.0 - dom)


static func _edge_weight(entry) -> float:
	if entry is Dictionary:
		return float(entry.get("weight", 1.0))
	return 1.0


static func _edge_cap(entry) -> String:
	if entry is Dictionary:
		return String(entry.get("cap", ""))
	return String(entry)


static func _maxpath_dfs(current: String, goal: String, enables: Dictionary,
		visited: Dictionary, cycles_out: Array) -> float:
	if current == goal:
		return 1.0
	visited[current] = true
	var best := 0.0
	var next_entries: Array = enables.get(current, [])
	for entry in next_entries:
		var nxt := _edge_cap(entry)
		if nxt.is_empty():
			continue
		if visited.has(nxt):
			cycles_out.append("%s->%s" % [current, nxt])
			continue
		var sub := _maxpath_dfs(nxt, goal, enables, visited, cycles_out)
		if sub > 0.0:
			var cand := _edge_weight(entry) * sub
			if cand > best:
				best = cand
	visited.erase(current)
	return best


static func propagated_dependency(depends_on: Dictionary, domestic_capacity: Dictionary,
		prerequisite: String, enables: Dictionary, cycles_out: Array) -> float:
	var total := 0.0
	for cap_key in depends_on.keys():
		var cap := String(cap_key)
		var mp := _maxpath_dfs(prerequisite, cap, enables, {}, cycles_out)
		total += effective_depends_on(depends_on, domestic_capacity, cap) * mp
	return total


# DepNeighborhood(O): القدرات المعتمدة مباشرة + كل سلالفها عبر enables.
# مشية عكسية بمجموعة visited مدمجة — آمنة للدورات وحتمية العضوية.
static func dependency_neighborhood(depends_on: Dictionary, enables: Dictionary) -> Dictionary:
	var reverse := {}
	for from_cap in enables.keys():
		for entry in enables[from_cap]:
			var to_cap := _edge_cap(entry)
			if to_cap.is_empty():
				continue
			if not reverse.has(to_cap):
				reverse[to_cap] = []
			reverse[to_cap].append(String(from_cap))
	var neigh := {}
	var stack: Array = []
	for cap_key in depends_on.keys():
		stack.append(String(cap_key))
	while not stack.is_empty():
		var cur := String(stack.pop_back())
		if neigh.has(cur):
			continue
		neigh[cur] = true
		for parent in reverse.get(cur, []):
			if not neigh.has(parent):
				stack.append(parent)
	return neigh


# v2: المقام المحلي — لا يُقرأ إنتاج العالم إلا لقدرة داخل حي اعتماد المراقب.
static func supply_share_scoped(target_produces: Dictionary, all_entities: Dictionary,
		cap: String, neighborhood: Dictionary) -> float:
	if not neighborhood.has(cap):
		return 0.0
	var mine := float(target_produces.get(cap, 0.0))
	if mine <= 0.0:
		return 0.0
	var total := 0.0
	for ent in all_entities.values():
		total += float((ent as Dictionary).get("produces", {}).get(cap, 0.0))
	if total <= 0.0:
		return 0.0
	return mine / total


# المخرج: {"value": float, "cycles": Array[String]} — قيمة رقمية فقط،
# لا قرار ولا هدف ولا أي منطق سلوكي مرفق (Sub-test 1.6).
static func evaluate(world: Dictionary, observer_name: String, target_name: String) -> Dictionary:
	var entities: Dictionary = world["entities"]
	var enables: Dictionary = world.get("enables", {})
	var observer: Dictionary = entities.get(observer_name, {})
	var target: Dictionary = entities.get(target_name, {})
	var cycles: Array = []
	var neighborhood := dependency_neighborhood(observer.get("depends_on", {}), enables)
	var total := 0.0
	var produces: Dictionary = target.get("produces", {})
	for cap_key in produces.keys():
		var cap := String(cap_key)
		var pd := propagated_dependency(
			observer.get("depends_on", {}),
			observer.get("domestic_capacity", {}),
			cap, enables, cycles)
		total += pd * supply_share_scoped(produces, entities, cap, neighborhood)
	return {"value": total, "cycles": cycles}


# ============================================================
# v3 — ADDITIVE API (قرار صاحب المشروع بعد Test 10 Run 1):
# إصلاح الـ implementation debt الموثق داخل GDScript قبل أي قرار Gate 2:
#   1) Supply Index: بدل مسح كل الكيانات لكل حد — فهرسة مرة واحدة.
#   2) Maxpath Memoization: maxpath دالة نقية في الزوج (Q,D) وبنية
#      enables فقط — تُحسب مرة واحدة لكل زوج وتُعاد من الذاكرة.
#
# عقود صريحة موثقة:
# - evaluate() أعلاه لم تُلمس إطلاقًا؛ هي المرجع الصحيح (oracle).
# - التكافؤ bitwise مطلوب بين المسارين: تراكم الإجماليات في الفهرس
#   يتم بنفس ترتيب المرور الأصلي (ترتيب إدراج الكيانات ثم قدراتها)
#   ⇒ نفس متتاليات الجمع العشري ⇒ نفس floats بالضبط.
#   memo لا يغير أي float — يخزن ناتج نفس الدالة نفسها.
# - صلاحية الفهرس: supply يُعاد بناؤه عند أي تغيير produces؛
#   memo صالح ما دامت بنية enables وأوزانها غير متغيرة (تغييرات
#   produces/depends_on/domestic_capacity لا تلمسه).
# - فرق سلوكي تشخيصي وحيد (لا يؤثر على القيم): تحذيرات cycles تُسجل
#   فقط عند أول حساب للزوج (memo miss) لا في كل استدعاء.
# ============================================================


static func build_world_index(world: Dictionary) -> Dictionary:
	var supply := {}
	var entities: Dictionary = world["entities"]
	for ename in entities.keys():
		var ent: Dictionary = entities[ename]
		var produces: Dictionary = ent.get("produces", {})
		for cap_key in produces.keys():
			var cap := String(cap_key)
			var val := float(produces[cap_key])
			if not supply.has(cap):
				supply[cap] = {"total": 0.0, "producers": {}}
			var entry: Dictionary = supply[cap]
			entry["total"] = entry["total"] + val
			entry["producers"][String(ename)] = val
	return {
		"world": world,
		"enables": world.get("enables", {}),
		"supply": supply,
		"maxpath": {},
		"dependency_neighborhoods": {},
	}


# إعادة بناء جزء العرض فقط بعد تغيّر إنتاج — memo يعيش (بنية enables لم تتغير).
static func refresh_supply_index(index: Dictionary) -> void:
	var supply := {}
	var entities: Dictionary = (index["world"] as Dictionary)["entities"]
	for ename in entities.keys():
		var ent: Dictionary = entities[ename]
		var produces: Dictionary = ent.get("produces", {})
		for cap_key in produces.keys():
			var cap := String(cap_key)
			var val := float(produces[cap_key])
			if not supply.has(cap):
				supply[cap] = {"total": 0.0, "producers": {}}
			var entry: Dictionary = supply[cap]
			entry["total"] = entry["total"] + val
			entry["producers"][String(ename)] = val
	index["supply"] = supply


static func _maxpath_memoized(from_cap: String, goal: String, enables: Dictionary,
		memo: Dictionary, cycles_out: Array) -> float:
	var key := from_cap + "|" + goal
	if memo.has(key):
		return float(memo[key])
	var w := _maxpath_dfs(from_cap, goal, enables, {}, cycles_out)
	memo[key] = w
	return w


# المسار الساخن — مكافئ الحسابي الكامل لـ evaluate() مع فهرسة العرض وميموIZATION للـ DFS.
static func evaluate_indexed(index: Dictionary, observer_name: String, target_name: String) -> Dictionary:
	var world: Dictionary = index["world"]
	var entities: Dictionary = world["entities"]
	var enables: Dictionary = index["enables"]
	var observer: Dictionary = entities.get(observer_name, {})
	var target: Dictionary = entities.get(target_name, {})
	var cycles: Array = []
	if not index.has("dependency_neighborhoods"):
		index["dependency_neighborhoods"] = {}
	var neighborhoods_cache: Dictionary = index["dependency_neighborhoods"]
	var neighborhood: Dictionary
	if neighborhoods_cache.has(observer_name):
		neighborhood = neighborhoods_cache[observer_name]
	else:
		neighborhood = dependency_neighborhood(observer.get("depends_on", {}), enables)
		neighborhoods_cache[observer_name] = neighborhood
	var depends_on: Dictionary = observer.get("depends_on", {})
	var domestic_capacity: Dictionary = observer.get("domestic_capacity", {})
	var memo: Dictionary = index["maxpath"]
	var supply_all: Dictionary = index["supply"]
	var total := 0.0
	var produces: Dictionary = target.get("produces", {})
	for cap_key in produces.keys():
		var cap := String(cap_key)
		if not neighborhood.has(cap):
			continue
		var mine := float(produces[cap_key])
		if mine <= 0.0:
			continue
		var share_entry: Dictionary = supply_all.get(cap, {})
		if share_entry.is_empty():
			continue
		var world_total := float(share_entry["total"])
		if world_total <= 0.0:
			continue
		var pd := 0.0
		for dep_key in depends_on.keys():
			var dcap := String(dep_key)
			var mp := _maxpath_memoized(cap, dcap, enables, memo, cycles)
			pd += effective_depends_on(depends_on, domestic_capacity, dcap) * mp
		total += pd * (mine / world_total)
	return {"value": total, "cycles": cycles}
