extends Control

@onready var output_label: RichTextLabel = $VBox/Output
@onready var step_button: Button = $VBox/Buttons/StepDayButton
@onready var step_month_button: Button = $VBox/Buttons/StepMonthButton
@onready var run_100_button: Button = $VBox/Buttons/Run100Button
@onready var determinism_button: Button = $VBox/Buttons/DeterminismTestButton
@onready var goto_war_button: Button = $VBox/Buttons/GotoWarDayButton
@onready var show_log_button: Button = $VBox/Buttons/ShowActivationLogButton

var showing_log: bool = false

func _ready() -> void:
	step_button.pressed.connect(_on_step_day)
	step_month_button.pressed.connect(_on_step_month)
	run_100_button.pressed.connect(_on_run_100)
	determinism_button.pressed.connect(_on_determinism_test)
	goto_war_button.pressed.connect(_on_goto_war_day)
	show_log_button.pressed.connect(_on_show_log)
	_refresh(Simulation.get_debug_info())

func _on_goto_war_day() -> void:
	# War_Started متجدولة يوم 45 في init_world — بنوقف بالظبط هناك
	# عشان نشوف مين اتفعّل ومين فضل نايم لحظة الحدث نفسه (معيار 2، نص 12)
	while Simulation.clock.total_days() < 45:
		Simulation.run_step()
	_refresh(Simulation.get_debug_info())

func _on_show_log() -> void:
	showing_log = not showing_log
	_refresh(Simulation.get_debug_info())

func _on_step_day() -> void:
	var info = Simulation.run_step()
	_refresh(info)

func _on_step_month() -> void:
	Simulation.run_steps(30)
	_refresh(Simulation.get_debug_info())

func _on_run_100() -> void:
	Simulation.run_steps(100)
	_refresh(Simulation.get_debug_info())

func _on_determinism_test() -> void:
	var ok = Simulation.run_headless_determinism_test(12345, 60)
	output_label.append_text("\n[b]Determinism Test (seed=12345, 60 steps):[/b] " + ("PASS ✅" if ok else "FAIL ❌") + "\n")

func _refresh(info: Dictionary) -> void:
	if showing_log:
		_render_activation_log()
		return

	var txt = ""
	txt += "[b]%s[/b]\n\n" % info["day"]
	txt += "Entities: %d   Active: %d   Sleeping: %d\n" % [info["total_entities"], info["active"], info["sleeping"]]
	txt += "Events queued: %d   Events processed: %d\n" % [info["events_queued"], info["events_processed"]]
	txt += "Last event: %s\n" % info["last_event"]
	txt += "Scheduled jobs registered: %d\n\n" % info["scheduled_jobs"]

	txt += "[b]Activated this step:[/b]\n"
	if info["active_ids"].size() == 0:
		txt += "  (none)\n"
	for id in info["active_ids"]:
		# reason_for بيوضح ليه بالظبط اتفعّل — scheduled ولا event ولا relation (معيار 2، نص 12)
		var reason = Simulation.activation.reason_for(id)
		txt += "  - %s  [%s]\n" % [id, reason]
	txt += "\n"

	txt += "[b]Countries:[/b]\n"
	for cname in info["countries"]:
		var c = info["countries"][cname]
		txt += "  %s | pop=%.0f gdp=%.1f mil=%.1f stability=%.2f action=%s at_war_with=%s\n" % [
			cname, c["population"], c["gdp"], c["military_power"], c["stability"],
			c["chosen_action"], str(c["at_war_with"])
		]

	output_label.clear()
	output_label.append_text(txt)

func _render_activation_log() -> void:
	# بيعرض بس الأيام اللي فعلاً حصل فيها استيقاظ (مش كل الأيام) — المفروض
	# دي أقلية صغيرة جدًا من إجمالي الأيام لو Sleep/Wake شغالة صح
	var log_data = Simulation.activation_log
	var txt = "[b]Activation Log — آخر %d يوم فيهم استيقاظ (من إجمالي %d يوم اتشغلوا)[/b]\n\n" % [
		log_data.size(), Simulation.clock.total_days()
	]
	for entry in log_data:
		txt += "[b]Day %d:[/b]\n" % entry["day"]
		for id in entry["active_ids"]:
			txt += "    - %s\n" % id
	if log_data.size() == 0:
		txt += "(مفيش أي استيقاظ سُجّل لحد دلوقتي)\n"

	output_label.clear()
	output_label.append_text(txt)
