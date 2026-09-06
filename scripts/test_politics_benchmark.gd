extends SceneTree

# ============================================================
# TASK-039 — BATCH-A — ACTOR RUNTIME BENCHMARK (§11)
# ------------------------------------------------------------
# workload مركب من نفس موديلات Batch-A (لا toy loop):
#   N=100 دول × (حكومة + 4 أحزاب + تشريعية + 4 مناصب + 7 شخصيات)
#   + علاقات دعم + انتخابات + قوانين + ثقة + تكوينات حكومية
# يسجل: CPU · memory · counts · actions · assessments · events ·
# peak event burst · active actors/total · political evaluations per tick.
# حتمي بالكامل (بلا RNG) — نفس القوى الانتخابية في كل دولة.
# ============================================================

const PS := preload("res://scripts/politics/political_state.gd")
const IR := preload("res://scripts/politics/institutional_rules.gd")
const PA := preload("res://scripts/politics/political_actions.gd")
const CQ := preload("res://scripts/compliance/compliance_query.gd")
const SimScript := preload("res://scripts/Simulation.gd")

const N_COUNTRIES := 100


func _init() -> void:
	print("")
	print("============================================================")
	print("  TASK-039 BATCH-A — ACTOR RUNTIME BENCHMARK (N=%d countries)" % N_COUNTRIES)
	print("============================================================")
	var rules = IR.load()
	rules.raw = _rules_raw()

	# ---------- workload generation (deterministic) ----------
	var mem0 := OS.get_static_memory_usage()
	var t0 := Time.get_ticks_usec()
	var state = PS.load_from(_fixture())
	var entities := {}
	for i in range(N_COUNTRIES):
		entities["c_la_%d" % i] = {"social_relations": {"c_king_%d" % i: {"loyalty": 0.9, "trust": 0.5}}}
	var gen_us := Time.get_ticks_usec() - t0
	var mem1 := OS.get_static_memory_usage()

	# ---------- action stream (11 actions × N countries) ----------
	var ctx := {"rules": rules, "compliance_config": _cfg(), "compliance_entities": entities}
	var actions_before: int = PA.eval_count
	var cq_before: int = CQ.eval_count
	var events_before: int = 0
	var peak_burst := 0
	var actors_seen := {}
	var t1 := Time.get_ticks_usec()
	for i in range(N_COUNTRIES):
		var s := str(i)
		var king := "c_king_" + s
		var la := "c_la_" + s
		var pm_holder := la
		var stream := [
			["HoldElection", king, {"election_id": "el_" + s, "type": "general", "legislature_id": "leg_" + s}],
			["FormGovernment", "P%d_1" % i, {"government_id": "gov_" + s, "head": la,
				"legislature_id": "leg_" + s, "supporting_parties": ["P%d_1" % i, "P%d_2" % i],
				"offices": {"office_pm_%d" % i: la}}],
			["AppointOfficeholder", king, {"office_id": "office_pm_" + s, "candidate": la}],
			["AppointOfficeholder", la, {"office_id": "office_finance_" + s, "candidate": "c_fin_" + s}],
			["ProposeBill", "P%d_1" % i, {"bill_id": "bill_" + s, "legislature_id": "leg_" + s, "title": "Budget"}],
			["VoteBill", "leg_" + s, {"bill_id": "bill_" + s, "legislature_id": "leg_" + s,
				"votes": {"P%d_1" % i: "aye", "P%d_2" % i: "aye", "P%d_3" % i: "nay", "P%d_4" % i: "nay"}}],
			["VoteConfidence", "leg_" + s, {"government_id": "gov_" + s, "legislature_id": "leg_" + s,
				"votes": {"P%d_1" % i: "aye", "P%d_2" % i: "aye", "P%d_3" % i: "nay", "P%d_4" % i: "nay"}}],
			["SupportGovernment", "P%d_3" % i, {"government_id": "gov_" + s}],
			["WithdrawSupport", "P%d_3" % i, {"government_id": "gov_" + s}],
			["VoteNoConfidence", "leg_" + s, {"government_id": "gov_" + s, "legislature_id": "leg_" + s,
				"votes": {"P%d_3" % i: "aye", "P%d_4" % i: "aye"}}],
			["ContestElectionResult", "P%d_4" % i, {"election_id": "el_" + s, "dispute_id": "disp_" + s}]
		]
		for step in stream:
			executed_actors(actors_seen, String(step[1]))
			var before_events: int = state.event_log.size()
			var r = PA.execute(String(step[0]), String(step[1]), step[2], state, ctx)
			var burst: int = state.event_log.size() - before_events
			if burst > peak_burst:
				peak_burst = burst
			if not bool(r["ok"]):
				print("BENCH_UNEXPECTED_FAIL action=%s actor=%s reason=%s" % [step[0], step[1], r.get("reason")])
	var actions_us := Time.get_ticks_usec() - t1
	var mem2 := OS.get_static_memory_usage()

	var actions_executed: int = PA.eval_count - actions_before
	var assessments_executed: int = CQ.eval_count - cq_before
	var events_total := 0
	for g in state.governments:
		pass
	events_total = state.event_log.size()

	# ---------- no per-tick activity mid-workload ----------
	var sim = SimScript.new()
	sim.init_world(12345)
	var pa_before: int = PA.eval_count
	for i in range(30):
		sim.run_step()
	var ticks_eval_delta: int = PA.eval_count - pa_before

	# ---------- counts ----------
	var total_actors: int = state.parties.size() + state.governments.size() + state.characters.size()
	var relationships: int = state.government_support.size()
	for p in state.parties:
		relationships += ((state.parties[p] as Dictionary).get("membership", []) as Array).size()

	print("BENCH env=Godot-4.7.2-headless N_countries=%d" % N_COUNTRIES)
	print("BENCH cpu state_gen_us=%d actions_us=%d actions_total=%d mean_us_per_action=%.1f"
		% [gen_us, actions_us, actions_executed, float(actions_us) / float(max(actions_executed, 1))])
	print("BENCH memory static_before=%d static_after_gen=%d static_after_actions=%d delta_bytes=%d"
		% [mem0, mem1, mem2, mem2 - mem0])
	print("BENCH entities countries=%d parties=%d legislatures=%d offices=%d governments=%d bills=%d characters=%d"
		% [N_COUNTRIES, state.parties.size(), state.legislatures.size(), state.offices.size(),
			state.governments.size(), state.bills.size(), state.characters.size()])
	print("BENCH relationships support=%d memberships=%d total=%d"
		% [state.government_support.size(),
			relationships - state.government_support.size(), relationships])
	print("BENCH activity actions_executed=%d assessments_executed=%d events_total=%d peak_event_burst=%d"
		% [actions_executed, assessments_executed, events_total, peak_burst])
	print("BENCH actors active_actors=%d total_actors=%d active_ratio=%.3f"
		% [actors_seen.size(), total_actors, float(actors_seen.size()) / float(max(total_actors, 1))])
	print("BENCH per_tick political_evaluations_in_30_production_ticks=%d (must be 0)"
		% ticks_eval_delta)
	print("BENCH verdict=%s" % ["PASS" if ticks_eval_delta == 0 and actions_executed == N_COUNTRIES * 11 else "CHECK"])
	print("=== END BENCH ===")
	quit(0)


func executed_actors(seen: Dictionary, actor: String) -> void:
	seen[actor] = true


func _cfg() -> Dictionary:
	var cf := FileAccess.open("res://data/rules/compliance_config.json", FileAccess.READ)
	var c = JSON.parse_string(cf.get_as_text())
	cf.close()
	return c


func _fixture() -> Dictionary:
	var raw := {"characters": {}, "parties": {}, "legislatures": {}, "offices": {}, "governments": {}, "government_support": {}}
	for i in range(N_COUNTRIES):
		var s := str(i)
		raw["characters"]["c_king_" + s] = {"name": "Head of State"}
		raw["characters"]["c_la_" + s] = {"name": "Leader 1"}
		raw["characters"]["c_lb_" + s] = {"name": "Leader 2"}
		raw["characters"]["c_lc_" + s] = {"name": "Leader 3"}
		raw["characters"]["c_ld_" + s] = {"name": "Leader 4"}
		raw["characters"]["c_fin_" + s] = {"name": "Minister"}
		raw["characters"]["c_mp_" + s] = {"name": "MP"}
		var strengths := [0.40, 0.30, 0.20, 0.10]
		var seats := [40, 30, 20, 10]
		for k in range(4):
			var pid := "P%d_%d" % [i, k + 1]
			raw["parties"][pid] = {"party_id": pid, "leader": "c_l" + char(97 + k) + "_" + s,
				"membership": ["c_l" + char(97 + k) + "_" + s],
				"political_profile": {"electoral_strength": strengths[k], "ideology": "v%d" % (k + 1)},
				"seats": {"leg_" + s: seats[k]}}
		raw["legislatures"]["leg_" + s] = {"legislature_id": "leg_" + s, "chambers": ["lower"],
			"seats": {"P%d_1" % i: 40, "P%d_2" % i: 30, "P%d_3" % i: 20, "P%d_4" % i: 10},
			"procedural_state": {"dissolved": false, "term": 1}, "active_bills": [], "active_motions": []}
		raw["offices"]["office_president_" + s] = {"office_id": "office_president_" + s,
			"institution_id": "inst_state", "role": "head_of_state",
			"holder": "c_king_" + s, "status": "appointed"}
		for o in ["office_pm_" + s, "office_finance_" + s, "office_defense_" + s]:
			raw["offices"][o] = {"office_id": o, "institution_id": "inst_government",
				"role": "head_of_government" if o.begins_with("office_pm") else "minister",
				"holder": null, "status": "vacant"}
	return raw


# قواعد مؤسسية مولدة حتميًا لكل دولة (نمط حقن data-driven — لا magic code)
func _rules_raw() -> Dictionary:
	var inst := {}
	for i in range(N_COUNTRIES):
		var s := str(i)
		inst["legislature_leg_" + s] = {"kind": "legislature", "legislature_id": "leg_" + s,
			"rules": {"confidence_required_to_form": true, "formation_support_threshold": 0.5,
				"bill_pass_threshold": 0.5, "confidence_pass_threshold": 0.5,
				"no_confidence_removes_government": true,
				"confidence_fail_removes_government": false, "proposer_requires_seats": true}}
		inst["office_office_president_" + s] = {"kind": "office", "office_id": "office_president_" + s,
			"role": "head_of_state", "rules": {"appointing_authority": "", "dismissible_by": [],
				"succession_on_vacancy": "none"}}
		inst["office_office_pm_" + s] = {"kind": "office", "office_id": "office_pm_" + s,
			"role": "head_of_government", "rules": {"appointing_authority": "office_president_" + s,
				"dismissible_by": ["office_president_" + s], "succession_on_vacancy": "none"}}
		for o in ["office_finance_" + s, "office_defense_" + s]:
			inst["office_" + o] = {"kind": "office", "office_id": o, "role": "minister",
				"rules": {"appointing_authority": "office_pm_" + s,
					"dismissible_by": ["office_president_" + s, "office_pm_" + s],
					"succession_on_vacancy": "none"}}
	return {"_non_final": "benchmark-generated institutional rules", "institutions": inst,
		"elections": {"general": {"type": "general", "scope": "national",
			"rules": {"changes_composition": true, "changes_head": false,
				"electoral_authority_office": ""}}}}
