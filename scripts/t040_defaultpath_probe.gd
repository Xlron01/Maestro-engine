extends SceneTree

# ============================================================
# TASK-040 — DEFAULT-PATH BEHAVIOURAL A/B PROBE (no override)
# ------------------------------------------------------------
# يثبت أن المسار الافتراضي (data_root_override == "") بعد
# ENGINE TOUCH #5 + Decision-004 unification مطابق سلوكيًا
# للـbaseline bf2ea5b4: نفس political state + counters +
# world snapshot SHA-256 بعد 30 يومًا على مسار الإنتاج.
# TEST FIXTURE — بلا قيمة توازن لعب.
# ============================================================

const SimScript := preload("res://scripts/Simulation.gd")

const SEED := 12345
const N_DAYS := 30
const N_DAYS_DIR := 10            # t5_p0 شجرة 10K entities — يكفي لإثبات التكافؤ
const T5_TREE := "res://data/scenarios/t5_p0"  # شجرة override بلا محتوى سياسي

var _lines: Array = []

func _pl(s: String) -> void:
	print(s)
	_lines.append(s)

func _init() -> void:
	_pl("=== T040 DEFAULT-PATH A/B PROBE START ===")
	_pl("code: %s" % Engine.get_version_info().get("string", "4.7"))
	var sim = SimScript.new()
	# DEFAULT PATH — data_root_override يظل "" كما في الإنتاج
	sim.init_world(SEED)
	_pl("init: countries=%d provinces=%d data_root_override='%s'" % [
		sim.world.countries.size(), sim.world.provinces.size(),
		sim.data_root_override])

	# political state بعد init (التحميل الافتراضي: t040_world.json الفارغ)
	var ps = sim._content_handlers.get_political_state()
	_pl("political: governments=%d parties=%d legislatures=%d offices=%d characters=%d deadlines=%d" % [
		ps.governments.size(), ps.parties.size(), ps.legislatures.size(),
		ps.offices.size(), ps.characters.size(), ps.deadlines.size()])

	# counters + hash يوم 0
	var c0: Dictionary = sim._content_handlers.get_political_counters()
	_pl("counters@day0: %s" % JSON.stringify(c0))
	var h0 := _hash_world(sim)
	_pl("world_sha256@day0: %s" % h0)

	# تشغيل 30 يومًا على مسار الإنتاج
	for i in range(N_DAYS):
		sim.run_step()

	var day: int = sim.clock.total_days()
	var c1: Dictionary = sim._content_handlers.get_political_counters()
	_pl("day_after_run: %d" % day)
	_pl("counters@day30: %s" % JSON.stringify(c1))
	var h30 := _hash_world(sim)
	_pl("world_sha256@day30: %s" % h30)

	# الفحص الذاتي للطول قبل العرض (قاعدة الـhandoff)
	for t in [h0, h30]:
		if t.length() != 64 or not _is_hex(t):
			_pl("HASH FORMAT ERROR: len=%d" % t.length())
			quit(2)
	_pl("hash_format_ok: true (64-hex verified)")

	# ---------------- Phase 2: directory-override (non-political tree) ----------------
	# نفس فئة الفشل الصامت في الـcommit المرفوض: data_root_override = directory.
	# t5_p0 شجرة scenario كاملة بلا worlds/politics/world.json — السلوك المتوقع
	# في الاثنين (baseline والحالي): political state فارغة، بلا crash، وبلا حقن.
	_pl("--- phase2: directory-override t5_p0 ---")
	var sim2 = SimScript.new()
	sim2.data_root_override = T5_TREE
	sim2.init_world(SEED)
	_pl("init2: countries=%d provinces=%d override='%s'" % [
		sim2.world.countries.size(), sim2.world.provinces.size(),
		sim2.data_root_override])
	var ps2 = sim2._content_handlers.get_political_state()
	_pl("political2: governments=%d parties=%d legislatures=%d offices=%d characters=%d deadlines=%d" % [
		ps2.governments.size(), ps2.parties.size(), ps2.legislatures.size(),
		ps2.offices.size(), ps2.characters.size(), ps2.deadlines.size()])
	var hd0 := _hash_world(sim2)
	_pl("world2_sha256@day0: %s" % hd0)
	for i in range(N_DAYS_DIR):
		sim2.run_step()
	_pl("day2_after_run: %d" % sim2.clock.total_days())
	var cd: Dictionary = sim2._content_handlers.get_political_counters()
	_pl("counters2@day10: %s" % JSON.stringify(cd))
	var hd10 := _hash_world(sim2)
	_pl("world2_sha256@day10: %s" % hd10)
	for t in [hd0, hd10]:
		if t.length() != 64 or not _is_hex(t):
			_pl("HASH FORMAT ERROR: len=%d" % t.length())
			quit(2)
	_pl("hash_format_ok2: true (64-hex verified)")
	_pl("=== T040 DEFAULT-PATH A/B PROBE END ===")
	quit(0)

func _hash_world(sim) -> String:
	# نفس مصدر الحقيقة مثل ScenarioTest anchor: in-memory snapshot
	var snap: Dictionary = sim.world.snapshot()
	var s := JSON.stringify(snap)
	return _sha256(s)

func _sha256(text: String) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(text.to_utf8_buffer())
	var d := h.finish()
	return d.hex_encode()

func _is_hex(s: String) -> bool:
	for ch in s.to_lower():
		if not ("0123456789abcdef".contains(ch)):
			return false
	return true
