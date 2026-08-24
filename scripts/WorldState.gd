extends RefCounted
class_name WorldState

# كل حاجة Dictionary/Array عادي زي ما اتفقنا — لسه من غير ECS، لسه من غير Resource classes.
# لو الـPrototype أثبت نفسه، هنا بالظبط هنسأل: هل الـDictionary بقى مشكلة أداء؟

var countries: Dictionary = {}   # name -> Country Dictionary
var provinces: Dictionary = {}   # name -> Province Dictionary
var relations: Dictionary = {}   # name -> Array[String]  (نسخة مبسطة من Relevance Graph — نص 9)
var agencies: Dictionary = {}    # id -> Agency Dictionary (Phase 6 Step 1)
var agents: Dictionary = {}      # id -> Agent Dictionary (Phase 6 Step 1)

func add_country(name: String, data: Dictionary) -> void:
	countries[name] = data

func add_province(name: String, data: Dictionary) -> void:
	provinces[name] = data

func add_agency(id: String, data: Dictionary) -> void:
	agencies[id] = data

func add_agent(id: String, data: Dictionary) -> void:
	agents[id] = data

func set_relations(name: String, related_to: Array) -> void:
	relations[name] = related_to

func related_entities(name: String) -> Array:
	return relations.get(name, [])

# ============ Country factory (نص 1 في وثيقة الـPrototype) ============
static func make_country(name: String, population: float, gdp: float, military_power: float,
		stability: float, government: String, growth_rate: float) -> Dictionary:
	return {
		"name": name,
		"population": population,
		"gdp": gdp,
		"military_power": military_power,
		"stability": stability,
		"government": government,
		"military_threat_nearby": 0.0,
		"border_insecurity": 0.0,
		"economic_stability": stability, # تبسيط مؤقت لحد ما نحتاج تفصيل أكتر
		"growth": growth_rate,
		"security_score": 0.0,
		"prosperity_score": 0.0,
		"chosen_action": "none",
		"at_war_with": []
	}

static func make_province(name: String, owner: String, infrastructure: float,
		supply: float) -> Dictionary:
	return {
		"name": name,
		"owner": owner,
		"infrastructure": infrastructure,
		"supply": supply,
		"damage": 0.0
	}

# ============ Snapshot كامل — يُستخدم في اختبار الـDeterminism (نص 11) ============
func snapshot() -> Dictionary:
	return {
		"countries": countries.duplicate(true),
		"provinces": provinces.duplicate(true),
		"agencies": agencies.duplicate(true),
		"agents": agents.duplicate(true)
	}

# ============ Serialization ============
# to_dict: يشمل relations كمان (snapshot مش بيحفظها لأنها مش محتاجة للـ determinism test)
func to_dict() -> Dictionary:
	return {
		"countries": countries.duplicate(true),
		"provinces": provinces.duplicate(true),
		"relations": relations.duplicate(true),
		"agencies": agencies.duplicate(true),
		"agents": agents.duplicate(true),
	}

func from_dict(d: Dictionary) -> void:
	# الحقول هنا كلها String/float/Array[سترينج] — مفيش int حرج على المستوى ده
	countries = (d.get("countries", {})).duplicate(true)
	provinces = (d.get("provinces", {})).duplicate(true)
	relations = (d.get("relations", {})).duplicate(true)
	agencies  = (d.get("agencies", {})).duplicate(true)
	agents    = (d.get("agents", {})).duplicate(true)
