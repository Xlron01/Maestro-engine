extends RefCounted
class_name ContentSchema

# ============================================================
# ContentSchema — تعريفات شكل (Schema) لملفات البيانات + Validator
# ------------------------------------------------------------
# يدوي وبسيط — مش JSON Schema خارجي (قرار Phase 1: أرخص حل يحقق
# معيار القبول: "رسالة واضحة بدل كسر صامت").
# ============================================================

# ---------- Type constants (T_* عشان ما يتعارضوش مع Godot built-in TYPE_*) ----------

const T_STRING := "string"
const T_INT := "int"
const T_FLOAT := "float"
const T_BOOL := "bool"
const T_ARRAY_STRING := "array:string"
const T_DICT := "dict"

# ---------- Schema definitions ----------

const SCHEMA_COUNTRY := [
	["id",            T_STRING,        true,  null,        null],
	["name",          T_STRING,        true,  null,        null],
	["population",    T_FLOAT,         true,  null,        [0.0, 10_000_000_000.0]],
	["gdp",           T_FLOAT,         true,  null,        [0.0, 1_000_000_000_000.0]],
	["military_power", T_FLOAT,        true,  null,        [0.0, 100_000.0]],
	["stability",     T_FLOAT,         true,  null,        [0.0, 1.0]],
	["government",    T_STRING,        true,  null,        null],
	["growth",        T_FLOAT,         false, 0.02,        [-0.1, 0.5]],
	["relations",     T_ARRAY_STRING,  false, [],          null],
	["military_threat_nearby", T_FLOAT, false, 0.0,        [0.0, 1000.0]],
	["border_insecurity",      T_FLOAT, false, 0.0,        [0.0, 1000.0]],
	["war_exhaustion",           T_FLOAT, false, 0.0,        [0.0, 1.0]],
	["coup_ideology_support",    T_FLOAT, false, 0.1,        [0.0, 1.0]],
	["current_ideology_support", T_FLOAT, false, 0.7,        [0.0, 1.0]],
	["coup_party_popularity",    T_FLOAT, false, 0.1,        [0.0, 1.0]],
	["foreign_support_for_coup", T_FLOAT, false, 0.0,        [0.0, 1.0]],
	["urban_ideology_mismatch",  T_FLOAT, false, 0.0,        [0.0, 1.0]],
	["literacy",                 T_FLOAT, false, 0.7,        [0.0, 1.0]],
	["war_generation_loss",      T_FLOAT, false, 0.0,        [0.0, 1.0]],
]

const SCHEMA_PROVINCE := [
	["name",          T_STRING,        true,  null,        null],
	["owner",         T_STRING,        true,  null,        null],
	["infrastructure", T_FLOAT,        true,  null,        [0.0, 1.0]],
	["supply",        T_FLOAT,         true,  null,        [0.0, 1.0]],
]

const SCHEMA_EVENT := [
	["time",   T_INT,    true,  null, [0, 100000]],
	["type",   T_STRING, true,  null, null],
	["source", T_STRING, true,  null, null],
	["payload", T_DICT,  false, {},   null],
]

const SCHEMA_POLITICS_RULES := [
	["decision_threshold",           T_FLOAT, false, 0.0,  [-100.0, 100.0]],
	["sec_weight_threat",            T_FLOAT, false, 1.0,  [-10.0, 10.0]],
	["sec_weight_border",            T_FLOAT, false, 1.0,  [-10.0, 10.0]],
	["prosp_weight_stability",       T_FLOAT, false, 1.0,  [-10.0, 10.0]],
	["prosp_weight_growth",          T_FLOAT, false, 1.0,  [-10.0, 10.0]],
	["military_spending_gdp_cost",   T_FLOAT, false, 0.01, [0.0, 0.5]],
	["prosperity_gdp_gain",          T_FLOAT, false, 0.015,[0.0, 0.5]],
	["military_power_gain",          T_FLOAT, false, 1.0,  [0.0, 100.0]],
	["population_growth_rate",       T_FLOAT, false, 0.0008, [-0.01, 0.1]],
	["election_stability_swing",     T_FLOAT, false, 0.05, [0.0, 0.5]],
	["minister_death_stability_loss", T_FLOAT, false, 0.05, [0.0, 0.5]],
	["railway_stability_loss",       T_FLOAT, false, 0.02, [0.0, 0.5]],
	["war_threat_increase",          T_FLOAT, false, 5.0,  [0.0, 100.0]],
	["coup_check_stability_threshold", T_FLOAT, false, 0.6, [0.0, 1.0]],
	["coup_threshold",               T_FLOAT, false, 0.6,  [-10.0, 10.0]],
	["coup_weight_war_exhaustion",   T_FLOAT, false, 0.3,  [-10.0, 10.0]],
	["coup_weight_ideology_support", T_FLOAT, false, 0.4,  [-10.0, 10.0]],
	["coup_weight_current_ideology", T_FLOAT, false, -0.2, [-10.0, 10.0]],
	["coup_weight_party_popularity", T_FLOAT, false, 0.25, [-10.0, 10.0]],
	["coup_weight_stability",        T_FLOAT, false, -0.5, [-10.0, 10.0]],
	["coup_weight_foreign_support",  T_FLOAT, false, 0.15, [-10.0, 10.0]],
	["coup_weight_urban_mismatch",   T_FLOAT, false, 0.2,  [-10.0, 10.0]],
	["coup_weight_literacy",         T_FLOAT, false, -0.1, [-10.0, 10.0]],
	["coup_weight_war_generation",   T_FLOAT, false, 0.15, [-10.0, 10.0]],
	["operation_weight_agent_xp",      T_FLOAT, false, 0.05,  [-10.0, 10.0]],
	["operation_weight_agency_budget", T_FLOAT, false, 0.0001,[-10.0, 10.0]],
	["operation_success_threshold",   T_FLOAT, false, 5.0,   [-100.0, 100.0]],
	["operation_xp_gain_success",     T_INT,   false, 25,    [0, 1000]],
	["operation_xp_gain_failure",     T_INT,   false, 5,     [0, 1000]],
	["agent_exposure_stability_penalty", T_FLOAT, false, 0.03, [0.0, 1.0]],
	["railway_damage_amount",        T_FLOAT, false, 0.4,  [0.0, 10.0]],
	["railway_supply_loss",          T_FLOAT, false, 0.3,  [0.0, 1.0]],
	["coup_attempt_stability_loss",  T_FLOAT, false, 0.2,  [0.0, 1.0]],
]

# ---------- Public API ----------

static func validate(data: Dictionary, schema: Array, path_prefix: String = "") -> Dictionary:
	var result := _empty_result()
	if data == null or data.is_empty():
		result.errors.append("%s: data is null or empty" % path_prefix)
		return result

	for spec in schema:
		var field_name: String = spec[0]
		var field_type: String = spec[1]
		var required: bool = spec[2]
		var default_val = spec[3]
		var value_range = spec[4]
		var full_path = _join_path(path_prefix, field_name)

		if not data.has(field_name):
			if required:
				result.errors.append("%s: missing required field" % full_path)
			else:
				data[field_name] = default_val
			continue

		var value = data[field_name]
		if not _check_type(value, field_type):
			result.errors.append("%s: expected type %s, got %s" % [full_path, field_type, _typeof_name(value)])
			continue

		if value_range != null and (field_type == T_FLOAT or field_type == T_INT):
			var v: float = float(value)
			var lo: float = float(value_range[0])
			var hi: float = float(value_range[1])
			if v < lo or v > hi:
				result.warnings.append("%s: value %s outside expected range [%s, %s]" % [full_path, str(v), str(lo), str(hi)])

	for key in data.keys():
		var known := false
		for spec in schema:
			if spec[0] == key:
				known = true
				break
		if not known:
			result.warnings.append("%s: unknown field '%s' (will be ignored)" % [path_prefix, str(key)])

	result.ok = result.errors.is_empty()
	return result

static func validate_references(data: Dictionary, known_country_ids: Array, path_prefix: String = "") -> Dictionary:
	var result := _empty_result()

	if data.has("relations"):
		var rels = data["relations"]
		if rels is Array:
			for r in rels:
				if not (r is String):
					result.errors.append("%s.relations: entry must be string, got %s" % [path_prefix, _typeof_name(r)])
					continue
				if r == data.get("id", ""):
					result.warnings.append("%s.relations: self-reference to '%s'" % [path_prefix, r])
					continue
				if not known_country_ids.has(r):
					result.errors.append("%s.relations: refers to unknown country id '%s'" % [path_prefix, r])

	if data.has("owner") and not known_country_ids.has(data["owner"]):
		result.errors.append("%s.owner: refers to unknown country id '%s'" % [path_prefix, data["owner"]])

	result.ok = result.errors.is_empty()
	return result

static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := _empty_result()
	out.errors.append_array(a.errors)
	out.errors.append_array(b.errors)
	out.warnings.append_array(a.warnings)
	out.warnings.append_array(b.warnings)
	out.ok = out.errors.is_empty()
	return out

# ---------- Internal helpers ----------

static func _empty_result() -> Dictionary:
	return {
		"ok": true,
		"errors": [],
		"warnings": [],
	}

static func _check_type(value, expected_type: String) -> bool:
	if expected_type == T_ARRAY_STRING:
		if not (value is Array):
			return false
		for item in value:
			if not (item is String):
				return false
		return true
	if expected_type == T_FLOAT:
		return value is float or value is int
	if expected_type == T_INT:
		return value is int or (value is float and value == int(value))
	if expected_type == T_STRING:
		return value is String
	if expected_type == T_BOOL:
		return value is bool
	if expected_type == T_DICT:
		return value is Dictionary
	return false

static func _typeof_name(value) -> String:
	if value is String: return "string"
	if value is int: return "int"
	if value is float: return "float"
	if value is bool: return "bool"
	if value is Array: return "array"
	if value is Dictionary: return "dict"
	if value == null: return "null"
	return "unknown"

static func _join_path(prefix: String, name: String) -> String:
	if prefix == "":
		return name
	return prefix + "." + name
