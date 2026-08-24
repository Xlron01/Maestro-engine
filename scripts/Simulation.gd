extends Node

# ============================================================
# GSG Kernel Prototype — Simulation.gd
# ------------------------------------------------------------
# Phase 1 refactor: كل البيانات تيجي من ملفات خارجية عبر ContentLoader.
# مفيش hardcoded data — الـhardcoded اتحول لـ `data/` directory.
# مفيش أي اسم دومين في المحرك本身 (gypt/Country_B/Country_C) —
# الأسماء كلها تيجي من ملفات البيانات.
# ============================================================

signal step_completed(debug_info: Dictionary)

var clock: SimClock
var world: WorldState
var events: EventQueue
var scheduled: ScheduledQueue
var activation: ActivationSet
var rng: RandomNumberGenerator

# ---- Phase 10 Purification: Dispatch Registry من ملف خارجي ----
# المحرك يعرف الآلية العامة فقط؛ أسماء الأحداث/الوظائف ومنطق الدومين
# تعيش في طبقة المحتوى (game_event_handlers.gd) وترتبط عبر dispatch.json.
var _dispatch: Dictionary = {}
var _event_handlers: Dictionary = {}   # type -> Callable
var _job_handlers: Dictionary = {}     # job_name -> {"fn": Callable, "one_shot": bool}
var _content_handlers = null           # instance of content-layer handlers script

var seed_value: int = 12345
var events_processed_count: int = 0
var coup_evaluations_count: int = 0
var operation_evaluations_count: int = 0
var exposure_propagation_count: int = 0
var last_event_type: String = "(none)"
var running: bool = false

# ---- Save/Load version — تغييره = breaking change متعمد ----
const SAVE_VERSION: int = 1

# ---- Rules: كل المعاملات الرقمية تيجي من ملفات بيانات ----
var rules: Dictionary = {}

# ---- Activation Log (اختباري بس — يثبت إن الاستيقاظ محدود) ----
const ACTIVATION_LOG_CAP: int = 200
var activation_log: Array = []

func _ready() -> void:
	init_world(seed_value)

# ---------------- Phase 1-4: Setup ----------------
func init_world(p_seed: int) -> void:
	seed_value = p_seed
	clock = SimClock.new()
	world = WorldState.new()
	events = EventQueue.new()
	scheduled = ScheduledQueue.new()
	activation = ActivationSet.new()
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	events_processed_count = 0
	coup_evaluations_count = 0
	operation_evaluations_count = 0
	exposure_propagation_count = 0
	last_event_type = "(none)"

	# ---- تحميل البيانات من ملفات خارجية ----
	var load_result := ContentLoader.load_full()
	if not load_result.ok:
		push_error("Content loading failed with %d error(s):" % load_result.errors.size())
		for e in load_result.errors:
			push_error("  ERROR: " + e)
		return
	for w in load_result.warnings:
		push_warning("Content warning: " + w)

	var data = load_result.data

	# ---- Rules (politics.json) ----
	rules = data.get("rules", {})

	# ---- Dispatch Registry (Phase 10) — فشله = فشل init كامل ----
	if not _load_dispatch():
		return

	# ---- Countries: حمّل من ملفات البيانات ----
	for c in data.get("countries", []):
		var cid: String = c.get("id", "")
		if cid.is_empty():
			continue
		# أضف حقول Runtime state اللي مش موجودة في JSON
		c["military_threat_nearby"] = c.get("military_threat_nearby", 0.0)
		c["border_insecurity"] = c.get("border_insecurity", 0.0)
		c["economic_stability"] = c.get("stability", 0.0)
		c["security_score"] = 0.0
		c["prosperity_score"] = 0.0
		c["chosen_action"] = "none"
		c["at_war_with"] = []
		world.add_country(cid, c)

	# ---- Relations: من ملفات الدول ----
	for cid in world.countries:
		var c: Dictionary = world.countries[cid]
		var rels: Array = c.get("relations", [])
		world.set_relations(cid, rels)

	# ---- Provinces: حمّل من ملفات البيانات ----
	for p in data.get("provinces", []):
		var pname: String = p.get("name", "")
		if pname.is_empty():
			continue
		p["damage"] = 0.0
		world.add_province(pname, p)

	# ---- Agencies: حمّل من ملفات البيانات (Phase 6) ----
	for a in data.get("agencies", []):
		var aid: String = a.get("id", "")
		if not aid.is_empty():
			world.add_agency(aid, a)

	# ---- Agents: حمّل من ملفات البيانات (Phase 6) ----
	for ag in data.get("agents", []):
		var agid: String = ag.get("id", "")
		if not agid.is_empty():
			world.add_agent(agid, ag)

	# ---- Scheduled jobs: تسجيل من البيانات عبر الـ Registry ----
	var default_jobs: Dictionary = _dispatch.get("default_country_jobs", {})
	for cid in world.countries:
		for jname in default_jobs.keys():
			var spec: Dictionary = default_jobs[jname]
			var every := int(spec.get("every", 30))
			scheduled.register(cid, jname, every, every)

	# ---- Events: من ملفات البيانات ----
	for ev in data.get("events", []):
		var time_val: int = ev.get("time", 0)
		var type_val: String = ev.get("type", "")
		var source_val: String = ev.get("source", "")
		var payload_val: Dictionary = ev.get("payload", {})
		events.push_event(time_val, type_val, source_val, payload_val)

# ---------------- Phase 5-8: خطوة محاكاة واحدة ----------------
func run_step() -> Dictionary:
	clock.advance_day()
	var t = clock.total_days()
	activation.clear()

	# 1) Scheduled jobs المستحقة
	var due_jobs = scheduled.get_due_jobs(t)
	# نجمع نسخة (duplicate) لأن unregister قد يعدّل _jobs أثناء التكرار.
	# One-Shot يُحدَّد بعلم بيانات من الـ Registry (Phase 10) — لا مقارنة أسماء.
	for job in due_jobs.duplicate():
		_run_scheduled_job(job, t)
		var spec: Dictionary = _job_handlers.get(job["job_name"], {})
		if spec.get("one_shot", false):
			scheduled.unregister(job["entity_id"], job["job_name"])
		else:
			scheduled.reschedule(job, t)

	# 2) Events المستحقة
	while events.has_due_events(t):
		var e = events.pop_next()
		events_processed_count += 1
		last_event_type = e["type"]
		_process_event(e, t)

	if activation.active_count() > 0:
		activation_log.append({
			"day": t,
			"active_ids": activation.active_ids().duplicate()
		})
		if activation_log.size() > ACTIVATION_LOG_CAP:
			activation_log.pop_front()

	step_completed.emit(get_debug_info())
	return get_debug_info()

func run_steps(n: int) -> void:
	for i in range(n):
		run_step()

# ---------------- Phase 10: Dispatch Registry ----------------
# يحمّل data/rules/dispatch.json ويربط كل نوع حدث/وظيفة بدالة في طبقة المحتوى.
# فحص اكتمال قاطع: أي إدخال بلا دالة موجودة = فشل init (لا صمت).
func _load_dispatch() -> bool:
	var path := "res://data/rules/dispatch.json"
	if not FileAccess.file_exists(path):
		push_error("Dispatch registry missing: %s" % path)
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Dispatch registry invalid JSON: %s" % path)
		return false

	var script_path := String(parsed.get("handlers_script", ""))
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
		push_error("Dispatch handlers_script missing on disk: %s" % script_path)
		return false
	var handler_script = load(script_path)
	if handler_script == null:
		push_error("Cannot load handlers_script: %s" % script_path)
		return false
	_content_handlers = handler_script.new()
	if not _content_handlers.has_method("setup"):
		push_error("Handlers script missing setup(): %s" % script_path)
		return false
	_content_handlers.setup(self)

	_dispatch = parsed  # ← الإصلاح: تخزين الفهرس كاملًا (شمل default_country_jobs)

	_event_handlers.clear()
	_job_handlers.clear()

	var evt_map: Dictionary = parsed.get("event_handlers", {})
	for etype in evt_map.keys():
		var fn_name := String(evt_map[etype])
		if not _content_handlers.has_method(fn_name):
			push_error("Dispatch: event '%s' -> missing method '%s'" % [etype, fn_name])
			return false
		_event_handlers[String(etype)] = Callable(_content_handlers, fn_name)

	var job_map: Dictionary = parsed.get("job_handlers", {})
	for jname in job_map.keys():
		var entry = job_map[jname]
		var fn_name := String(entry.get("fn", "")) if entry is Dictionary else String(entry)
		var one_shot := bool(entry.get("one_shot", false)) if entry is Dictionary else false
		if fn_name.is_empty() or not _content_handlers.has_method(fn_name):
			push_error("Dispatch: job '%s' -> missing method '%s'" % [jname, fn_name])
			return false
		_job_handlers[String(jname)] = {
			"fn": Callable(_content_handlers, fn_name),
			"one_shot": one_shot
		}

	print("[Dispatch] Registry loaded: %d event handlers, %d job handlers" % [
		_event_handlers.size(), _job_handlers.size()])
	return true

# ---------------- تنفيذ الـScheduled Jobs (عبر Registry — Phase 10) ----------------
func _run_scheduled_job(job: Dictionary, _t: int) -> void:
	var spec: Dictionary = _job_handlers.get(job["job_name"], {})
	if spec.is_empty():
		# نوع غير مُسجَّل: سلوك مطابق للسقوط الصامت في match القديم
		return
	var fn: Callable = spec["fn"]
	fn.call(job, _t)

# ---------------- تنفيذ الـEvents (عبر Registry — Phase 10) ----------------
func _process_event(e: Dictionary, t: int) -> void:
	var source = e["source"]
	activation.activate(source, "event:" + e["type"])

	var fn: Callable = _event_handlers.get(e["type"], Callable())
	if fn.is_valid():
		fn.call(e, t)
	# نوع غير مُسجَّل: سلوك مطابق للسقوط الصامت في match القديم

# ---------------- Debug info ----------------
func get_debug_info() -> Dictionary:
	var total_entities = world.countries.size() + world.provinces.size()
	return {
		"day": clock.to_string_debug(),
		"total_entities": total_entities,
		"active": activation.active_count(),
		"sleeping": total_entities - activation.active_count(),
		"active_ids": activation.active_ids(),
		"events_queued": events.pending_count(),
		"events_processed": events_processed_count,
		"coup_evaluations": coup_evaluations_count,
		"operation_evaluations": operation_evaluations_count,
		"exposure_propagations": exposure_propagation_count,
		"last_event": last_event_type,
		"scheduled_jobs": scheduled.all_jobs().size(),
		"countries": world.countries
	}

# ---------------- Phase 2: Save / Load ----------------

func save_to_file(path: String) -> Dictionary:
	var save_data := {
		"save_version":              SAVE_VERSION,
		"seed":                      seed_value,
		"events_processed_count":    events_processed_count,
		"coup_evaluations_count":    coup_evaluations_count,
		"operation_evaluations_count": operation_evaluations_count,
		"exposure_propagation_count": exposure_propagation_count,
		"last_event_type":           last_event_type,
		# rng.state هو uint64 — بنخزّنه String عشان JSON double مش بيحتمل دقة uint64 (ما فوق 2^53 بيتكسر)
		"rng_state":              str(rng.state),
		"clock":                  clock.to_dict(),
		"world":                  world.to_dict(),
		"events":                 events.to_dict(),
		"scheduled":              scheduled.to_dict(),
	}
	var json_text := JSON.stringify(save_data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Cannot open for writing: %s (%s)" % [path, error_string(FileAccess.get_open_error())]}
	file.store_string(json_text)
	file.close()
	return {"ok": true, "error": ""}

func load_from_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "Save file not found: %s" % path}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Cannot open: %s (%s)" % [path, error_string(FileAccess.get_open_error())]}
	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(content) != OK:
		return {"ok": false, "error": "JSON parse error (line %d): %s" % [json.get_error_line(), json.get_error_message()]}

	var d = json.data
	if not d is Dictionary:
		return {"ok": false, "error": "Save file root must be a dictionary"}

	# --- Version guard ---
	var file_version := int(d.get("save_version", 0))
	if file_version != SAVE_VERSION:
		return {"ok": false, "error": "Unsupported save version: %d (expected %d)" % [file_version, SAVE_VERSION]}

	# --- استعادة الحقول البسيطة --- int() صريح لأن JSON.parse بتحوّل الأرقام لـ float
	seed_value                    = int(d.get("seed", 12345))
	events_processed_count        = int(d.get("events_processed_count", 0))
	coup_evaluations_count        = int(d.get("coup_evaluations_count", 0))
	operation_evaluations_count   = int(d.get("operation_evaluations_count", 0))
	exposure_propagation_count    = int(d.get("exposure_propagation_count", 0))
	last_event_type               = str(d.get("last_event_type", "(none)"))

	# --- RNG: state اتحفظ String — نرجعه لـ int هنا بدون فقد دقة ---
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	rng.state = int(str(d.get("rng_state", "0")))

	# --- استعادة الأنظمة الفرعية ---
	clock = SimClock.new()
	clock.from_dict(d.get("clock", {}))

	world = WorldState.new()
	world.from_dict(d.get("world", {}))

	events = EventQueue.new()
	events.from_dict(d.get("events", {}))

	scheduled = ScheduledQueue.new()
	scheduled.from_dict(d.get("scheduled", {}))

	# --- Rules: content مش state — بتيجي من ملفات البيانات، مش من الحفظة ---
	var content_result := ContentLoader.load_full()
	if not content_result.ok:
		return {"ok": false, "error": "Content loading failed during load_from_file (check data/ directory)"}
	rules = content_result.data.get("rules", {})

	# --- Dispatch Registry: content كذلك — يُعاد بناؤه بعد كل load ---
	if not _load_dispatch():
		return {"ok": false, "error": "Dispatch registry failed to load during load_from_file"}

	# --- Transient state (مش بتتحفظ ولا بتتعادل) ---
	activation = ActivationSet.new()
	activation_log = []
	running = false

	return {"ok": true, "error": ""}

func run_headless_determinism_test(p_seed: int, steps: int) -> bool:
	init_world(p_seed)
	run_steps(steps)
	var snapshot_a = world.snapshot()

	init_world(p_seed)
	run_steps(steps)
	var snapshot_b = world.snapshot()

	var same = _deep_equal(snapshot_a, snapshot_b)
	return same

func _deep_equal(a, b) -> bool:
	return JSON.stringify(a) == JSON.stringify(b)
