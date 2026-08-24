extends RefCounted
class_name ContentLoader

# ============================================================
# ContentLoader — يقرأ ملفات بيانات خارجية (JSON) عبر FileAccess
# ويفحصها بـ ContentSchema، ويرجّع Result structs.
# ------------------------------------------------------------
# مبدأ 4 في 01-مبادئ-المحرك.md: "بيانات > كود"
# مبدأ 7: أي معامل رقمي لا يوضع داخل الكود أبدًا
# قرار Phase 1: FileAccess يدوي (مش ResourceLoader) → أعزل فصلًا
# ============================================================

const DATA_DIR := "res://data"

# ---------- Structs ----------

# {
#   "ok": bool,
#   "data": Dictionary,  # المحتوى الفعلي (مقبول = true)
#   "errors": Array[String],
#   "warnings": Array[String],
# }
#
# مفيش Exception — caller يقرر يوقف ولا لأ (Phase 1 سؤال 4)

static func _empty_result() -> Dictionary:
	return {
		"ok": true,
		"data": {},
		"errors": [],
		"warnings": [],
	}

# ---------- Country ----------

static func load_country_file(path: String) -> Dictionary:
	var result := _empty_result()
	var raw = _read_json_file(path, result)
	if raw == null:
		return result

	if not raw is Dictionary:
		result.errors.append("%s: root must be a dictionary, got %s" % [path, _describe_type(raw)])
		result.ok = false
		return result

	# Validate against schema
	var validation := ContentSchema.validate(raw, ContentSchema.SCHEMA_COUNTRY, path)
	if not validation.ok:
		result.errors.append_array(validation.errors)
		result.ok = false
	result.warnings.append_array(validation.warnings)

	if result.ok:
		result.data = raw
	return result

# حمّل كل ملفات الدول في مجلد، يرجّع مصفوفة كل البيانات + أخطاء مجمّعة
# البنية: data/countries/<id>/country.json — كل دولة مجلد فيه ملف واحد
static func load_country_dir(dir_path: String) -> Dictionary:
	var result := {
		"ok": true,
		"countries": [],       # Array of Dictionary (كل واحد = بيانات state واحدة)
		"errors": [],
		"warnings": [],
	}

	var dir := DirAccess.open(dir_path)
	if dir == null:
		result.errors.append("Cannot open directory: %s (error: %s)" % [dir_path, DirAccess.get_open_error()])
		result.ok = false
		return result

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		# كل مجلد فرعي = دولة واحدة، الملف جواه لازم يبقى country.json
		if dir.dir_exists(entry) and not entry.begins_with("."):
			var country_dir := dir_path.path_join(entry)
			var country_file := country_dir.path_join("country.json")
			if FileAccess.file_exists(country_file):
				var sub := load_country_file(country_file)
				if sub.ok:
					result.countries.append(sub.data)
				else:
					result.errors.append_array(sub.errors)
					result.ok = false
				result.warnings.append_array(sub.warnings)
			else:
				result.warnings.append("No country.json in: %s" % country_dir)
		entry = dir.get_next()
	dir.list_dir_end()

	# Cross-file reference validation: فحص إن كل relation تشير لدولة موجودة
	var known_ids := []
	for c in result.countries:
		known_ids.append(c.get("id", ""))

	for c in result.countries:
		var ref_result := ContentSchema.validate_references(c, known_ids, c.get("id", "unknown"))
		if not ref_result.ok:
			result.errors.append_array(ref_result.errors)
			result.ok = false
		result.warnings.append_array(ref_result.warnings)

	return result

# ---------- Events ----------

static func load_events_file(path: String) -> Dictionary:
	var result := _empty_result()
	var raw = _read_json_file(path, result)
	if raw == null:
		return result

	# الأحداث لازم تكون array of dicts
	if not raw is Array:
		result.errors.append("%s: root must be an array of events, got %s" % [path, _describe_type(raw)])
		result.ok = false
		return result

	var events := []
	for i in range(raw.size()):
		var ev = raw[i]
		if not ev is Dictionary:
			result.errors.append("%s[%d]: event must be a dictionary, got %s" % [path, i, _describe_type(ev)])
			result.ok = false
			continue
		var validation := ContentSchema.validate(ev, ContentSchema.SCHEMA_EVENT, "%s[%d]" % [path, i])
		if validation.ok:
			events.append(ev)
		else:
			result.errors.append_array(validation.errors)
			result.ok = false
		result.warnings.append_array(validation.warnings)

	if result.ok:
		result.data = {"events": events}
	return result

# ---------- Rules ----------

static func load_rules_file(path: String) -> Dictionary:
	var result := _empty_result()
	var raw = _read_json_file(path, result)
	if raw == null:
		return result

	if not raw is Dictionary:
		result.errors.append("%s: root must be a dictionary, got %s" % [path, _describe_type(raw)])
		result.ok = false
		return result

	# Validate against schema — كل حقل اختياري، الـdefaults بتسند القيم
	var validation := ContentSchema.validate(raw, ContentSchema.SCHEMA_POLITICS_RULES, path)
	if not validation.ok:
		result.errors.append_array(validation.errors)
		result.ok = false
	result.warnings.append_array(validation.warnings)

	if result.ok:
		result.data = raw
	return result

# ---------- Provinces ----------

static func load_province_file(path: String) -> Dictionary:
	var result := _empty_result()
	var raw = _read_json_file(path, result)
	if raw == null:
		return result

	if not raw is Dictionary:
		result.errors.append("%s: root must be a dictionary, got %s" % [path, _describe_type(raw)])
		result.ok = false
		return result

	var validation := ContentSchema.validate(raw, ContentSchema.SCHEMA_PROVINCE, path)
	if not validation.ok:
		result.errors.append_array(validation.errors)
		result.ok = false
	result.warnings.append_array(validation.warnings)

	if result.ok:
		result.data = raw
	return result

# ---------- Full load: load entire data directory ----------

# يحمّل كل الملفات ويجمع الأخطاء — يرجّع بنية كاملة
# caller يقرّر يوقف ولا لا بناءً على ok
static func load_full(data_path: String = DATA_DIR) -> Dictionary:
	var result := {
		"ok": true,
		"data": {
			"countries": [],    # Array[Dictionary]
			"provinces": [],    # Array[Dictionary]
			"events": [],       # Array[Dictionary]
			"rules": {},        # Dictionary
			"agencies": [],     # Array[Dictionary] (Phase 6)
			"agents": [],       # Array[Dictionary] (Phase 6)
		},
		"errors": [],
		"warnings": [],
	}

	# 1) Rules
	var rules_path := data_path.path_join("rules/politics.json")
	if FileAccess.file_exists(rules_path):
		var rules_result := load_rules_file(rules_path)
		if rules_result.ok:
			result.data["rules"] = rules_result.data
		else:
			result.errors.append_array(rules_result.errors)
			result.ok = false
		result.warnings.append_array(rules_result.warnings)
	else:
		result.errors.append("Missing rules file: %s" % rules_path)
		result.ok = false

	# 2) Countries
	var countries_path := data_path.path_join("countries")
	if DirAccess.dir_exists_absolute(countries_path):
		var countries_result := load_country_dir(countries_path)
		result.data["countries"] = countries_result.countries
		if not countries_result.ok:
			result.errors.append_array(countries_result.errors)
			result.ok = false
		result.warnings.append_array(countries_result.warnings)
	else:
		result.errors.append("Missing countries directory: %s" % countries_path)
		result.ok = false

	# 3) Events
	var events_path := data_path.path_join("scenarios/default/events.json")
	if FileAccess.file_exists(events_path):
		var events_result := load_events_file(events_path)
		if events_result.ok:
			result.data["events"] = events_result.data.get("events", [])
		else:
			result.errors.append_array(events_result.errors)
			result.ok = false
		result.warnings.append_array(events_result.warnings)
	else:
		# Events are not required at startup — error but non-fatal
		result.warnings.append("No events file found: %s (running without events)" % events_path)

	# 4) Provinces — optional for now
	var provinces_path := data_path.path_join("provinces")
	if DirAccess.dir_exists_absolute(provinces_path):
		var dir := DirAccess.open(provinces_path)
		if dir:
			dir.list_dir_begin()
			var fname := dir.get_next()
			while fname != "":
				if fname.ends_with(".json") and not fname.begins_with("."):
					var fpath := provinces_path.path_join(fname)
					var prov_result := load_province_file(fpath)
					if prov_result.ok:
						result.data["provinces"].append(prov_result.data)
					else:
						result.errors.append_array(prov_result.errors)
						result.ok = false
					result.warnings.append_array(prov_result.warnings)
				fname = dir.get_next()
			dir.list_dir_end()

	# 5) Agencies — optional (Phase 6 Step 1)
	var agencies_path := data_path.path_join("agencies")
	if DirAccess.dir_exists_absolute(agencies_path):
		var dir := DirAccess.open(agencies_path)
		if dir:
			dir.list_dir_begin()
			var sub_name := dir.get_next()
			while sub_name != "":
				if not sub_name.begins_with("."):
					var json_file := agencies_path.path_join(sub_name).path_join("agency.json")
					if FileAccess.file_exists(json_file):
						var raw = _read_json_file(json_file, result)
						if raw is Dictionary:
							result.data["agencies"].append(raw)
				sub_name = dir.get_next()
			dir.list_dir_end()

	# 6) Agents — optional (Phase 6 Step 1)
	var agents_path := data_path.path_join("agents")
	if DirAccess.dir_exists_absolute(agents_path):
		var dir := DirAccess.open(agents_path)
		if dir:
			dir.list_dir_begin()
			var sub_name := dir.get_next()
			while sub_name != "":
				if not sub_name.begins_with("."):
					var json_file := agents_path.path_join(sub_name).path_join("agent.json")
					if FileAccess.file_exists(json_file):
						var raw = _read_json_file(json_file, result)
						if raw is Dictionary:
							result.data["agents"].append(raw)
				sub_name = dir.get_next()
			dir.list_dir_end()

	return result

# ---------- Internal ----------

static func _read_json_file(path: String, result: Dictionary):
	if not FileAccess.file_exists(path):
		result.errors.append("File not found: %s" % path)
		result.ok = false
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		result.errors.append("Cannot open file: %s (error: %s)" % [path, error_string(FileAccess.get_open_error())])
		result.ok = false
		return null

	var content := file.get_as_text()
	file.close()

	if content.strip_edges().is_empty():
		result.errors.append("File is empty: %s" % path)
		result.ok = false
		return null

	var json := JSON.new()
	var parse_err := json.parse(content)
	if parse_err != OK:
		result.errors.append("JSON parse error in %s (line %d): %s" % [path, json.get_error_line(), json.get_error_message()])
		result.ok = false
		return null

	return json.data

static func _describe_type(value) -> String:
	match typeof(value):
		TYPE_STRING: return "string"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_BOOL: return "bool"
		TYPE_ARRAY: return "array"
		TYPE_DICTIONARY: return "dict"
		TYPE_NIL: return "null"
		_: return "type(%d)" % typeof(value)
