extends SceneTree

# ============================================================
# PHASE 10 — PURIFICATION AUDIT (v2 — بعد معايرة Baseline الأول)
#
# تصنيف العدلين:
#   VIOLATION (تحكمي — بوابة الفشل على Simulation.gd):
#     سلسلة دومين داخل تدفق تحكم (match أو مقارنة ==) أو كسر عشري
#     خارج rules.get (باستثناء 0.0/1.0 الهوياتية وملف Schema البنيوي).
#   PASSTHROUGH (جرد معلوماتي غير مانع):
#     سلسلة دومين كمفتاح/قيمة payload تمر عبر الكود بلا تفرع —
#     توثيق دَين لا يفتح هذا الطور (مهمة متابعة منفصلة).
#
# المنهجية الملزمة: Baseline قبل التعديل + Post بعده — الـ delta هو الدليل.
# ============================================================

const KERNEL_FILES: Array[String] = [
	"res://scripts/SimClock.gd",
	"res://scripts/WorldState.gd",
	"res://scripts/EventQueue.gd",
	"res://scripts/ScheduledQueue.gd",
	"res://scripts/ActivationSet.gd",
	"res://scripts/DecisionSystem.gd",
	"res://scripts/ContentLoader.gd",
	"res://scripts/ContentSchema.gd",
	"res://scripts/Simulation.gd",
]
# ملف تعريفات الحقول بالكامل — مكانه الطبيعي للـ defaults/ranges (معفى من فحص الأرقام)
const NUMERIC_EXEMPT_FILES: Array[String] = ["res://scripts/ContentSchema.gd"]
# حروف هوياتية لا تمثل بارامترات لعب
const IDENTITY_LITERALS: Array[String] = ["0.0", "1.0"]

const GATE_FILE := "res://scripts/Simulation.gd"
const EVENTS_PATH := "res://data/scenarios/default/events.json"
const DISPATCH_PATH := "res://data/rules/dispatch.json"

const FALLBACK_DOMAIN_STRINGS: Array[String] = [
	"Minister_Died", "Railway_Damaged", "Election", "War_Started",
	"Military_Spending_Increase", "Economic_Investment", "Coup_Attempt", "Agent_Exposed",
	"population_update", "gdp_update", "military_readiness", "coup_risk_check",
	"agent_operation_check", "coup_risk_score",
]
const FALLBACK_ENTITY_STRINGS: Array[String] = [
	"egypt", "country_b", "country_c", "france", "alexandria", "cia", "agent_007", "agent_rookie",
]

var gate_violations := 0
var inventory_count := 0


func _init() -> void:
	print("")
	print("============================================================")
	print("  PHASE 10 — PURIFICATION AUDIT (v2)")
	print("  Gate file: Simulation.gd | Inventory: all 9 kernel files")
	print("============================================================")

	var domain_strings := _collect_domain_strings()
	print("Domain vocabulary size: %d strings" % domain_strings.size())
	print("")

	for path in KERNEL_FILES:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			gate_violations += 1
			print("[GATE-ERROR] cannot open %s" % path)
			continue
		var lines := f.get_as_text().split("\n")
		var regex := RegEx.new()
		regex.compile("\\d+\\.\\d+")
		var numeric_exempt := path in NUMERIC_EXEMPT_FILES

		for i in range(lines.size()):
			var line := String(lines[i])
			var is_gate_file := path == GATE_FILE

			for s in domain_strings:
				if not line.contains(s):
					continue
				var is_branch := false
				if line.strip_edges().begins_with("\"%s\":" % s):
					is_branch = true  # case label في match — يبدأ السطر المقصوص
				elif line.contains("match ") and line.contains(s):
					is_branch = true
				elif _has_equality_compare(line, s):
					is_branch = true
				if is_branch:
					_flag(is_gate_file, "DOMAIN-CONTROL", path, i + 1, s)
				else:
					_note("DOMAIN-PASSTHROUGH", path, i + 1, s)

			if numeric_exempt:
				continue
			# النمط المعتمد في المشروع: rules.get("key", default) — الافتراضي ليس دينًا
			if line.contains("rules.get"):
				continue
			for m in regex.search_all(line):
				var lit := m.get_string()
				if lit in IDENTITY_LITERALS:
					continue
				_flag(is_gate_file, "MAGIC-NUMBER", path, i + 1, lit)

	# ---------- Registry completeness (بعد الإصلاح فقط) ----------
	if FileAccess.file_exists(DISPATCH_PATH):
		var df := FileAccess.open(DISPATCH_PATH, FileAccess.READ)
		var d = JSON.parse_string(df.get_as_text())
		if typeof(d) != TYPE_DICTIONARY:
			gate_violations += 1
			print("[REGISTRY-ERROR] dispatch.json invalid")
		else:
			var script_path := String(d.get("handlers_script", ""))
			var hf := FileAccess.open(script_path, FileAccess.READ)
			if hf == null:
				gate_violations += 1
				print("[REGISTRY-ERROR] handlers_script missing: %s" % script_path)
			else:
				var htext := hf.get_as_text()
				for section in ["event_handlers", "job_handlers"]:
					var sec: Dictionary = d.get(section, {})
					for key in sec.keys():
						var entry = sec[key]
						var fn_name := String(entry.get("fn", "")) if entry is Dictionary else String(entry)
						if not htext.contains("func %s(" % fn_name):
							gate_violations += 1
							print("[REGISTRY-ERROR] '%s' -> func '%s' missing in %s" % [key, fn_name, script_path])
				var ef := FileAccess.open(EVENTS_PATH, FileAccess.READ)
				if ef != null:
					var ev = JSON.parse_string(ef.get_as_text())
					if ev is Array:
						for evd in ev:
							var etype := String((evd as Dictionary).get("type", ""))
							if etype != "" and not (d.get("event_handlers", {}) as Dictionary).has(etype):
								gate_violations += 1
								print("[REGISTRY-ERROR] event type '%s' unmapped" % etype)

	print("")
	print("============================================================")
	print("  Gate (Simulation.gd) violations : %d" % gate_violations)
	print("  Inventory (deferred, non-gating): %d note(s)" % inventory_count)
	if gate_violations == 0:
		print("  AUDIT RESULT: CLEAN")
	else:
		print("  AUDIT RESULT: FAIL")
	print("============================================================")
	quit(0 if gate_violations == 0 else 1)


func _has_equality_compare(line: String, s: String) -> bool:
	var parts := line.split("\"")
	for pi in range(parts.size()):
		if parts[pi] == s and pi > 0:
			var before := String(parts[pi - 1]).strip_edges()
			var after := ""
			if pi + 1 < parts.size():
				after = String(parts[pi + 1]).strip_edges()
			if before.ends_with("==") or before.begins_with("==") or after.begins_with("=="):
				return true
	return false


func _flag(gate: bool, kind: String, path: String, line_no: int, what: String) -> void:
	if gate:
		gate_violations += 1
		print("[GATE-%s] %s:%d '%s'" % [kind, path, line_no, what])
	else:
		inventory_count += 1
		print("[INVENTORY-%s] %s:%d '%s'" % [kind, path, line_no, what])


func _note(kind: String, path: String, line_no: int, what: String) -> void:
	inventory_count += 1
	print("[%s] %s:%d '%s'" % [kind, path, line_no, what])


func _collect_domain_strings() -> Array[String]:
	var out: Array[String] = []
	for s in FALLBACK_DOMAIN_STRINGS:
		out.append(s)
	for s in FALLBACK_ENTITY_STRINGS:
		out.append(s)

	var ef := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	if ef != null:
		var ev = JSON.parse_string(ef.get_as_text())
		if ev is Array:
			for evd in ev:
				var t := String((evd as Dictionary).get("type", ""))
				if t != "" and not out.has(t):
					out.append(t)

	var dir := DirAccess.open("res://data/countries")
	if dir != null:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if dir.current_is_dir() and not fname.begins_with("."):
				var id := fname.to_lower()
				if not out.has(id):
					out.append(id)
			fname = dir.get_next()
		dir.list_dir_end()

	for extra_dir in ["res://data/agencies", "res://data/agents"]:
		var d2 := DirAccess.open(extra_dir)
		if d2 == null:
			continue
		d2.list_dir_begin()
		var f2 := d2.get_next()
		while f2 != "":
			if d2.current_is_dir() and not f2.begins_with("."):
				var id2 := f2.to_lower()
				if not out.has(id2):
					out.append(id2)
			f2 = d2.get_next()
		d2.list_dir_end()

	if FileAccess.file_exists(DISPATCH_PATH):
		var df := FileAccess.open(DISPATCH_PATH, FileAccess.READ)
		var d = JSON.parse_string(df.get_as_text())
		if d is Dictionary:
			for section in ["event_handlers", "job_handlers"]:
				for k in (d.get(section, {}) as Dictionary).keys():
					var ks := String(k)
					if not out.has(ks):
						out.append(ks)

	return out
