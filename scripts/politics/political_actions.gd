extends RefCounted
class_name PoliticalActions

# ============================================================
# BATCH-A — POLITICAL ACTIONS (12) — Action Pipeline (TASK-039)
# ------------------------------------------------------------
# المسار الملزم لكل action:
#   Actor → Action → Required Queries/Assessments → Resolution
#   → Event(s) → Owning Domain mutates State
# ممنوع: Actor → direct World State mutation، أو أن الـQuery نفسه يطبق
# التغيير. كل كتابة حالة تمر عبر دوال apply_* / emit_event في
# PoliticalState (المالك الوحيد).
#
# الاستعلامات معاد استخدامها كما هي (Compliance — TASK-038): نقص
# dependency ⇒ PARTIAL + missing_inputs بلا defaults.
#
# v0 Resolution (NON-FINAL): قواعد مؤسسية data-driven من
# institutional_rules.json — حتمية بالكامل، بلا RNG/Time. النتيجة
# تمثل: succeeds / fails / remains incomplete حسب القواعد.
#
# on-demand حصرًا: لا polling — عدّاد eval_count يراقبه قبول J.
# ============================================================

const T := preload("res://scripts/compliance/compliance_types.gd")
const CQ := preload("res://scripts/compliance/compliance_query.gd")

static var eval_count: int = 0

const ACTIONS := [
	"FormGovernment", "AppointOfficeholder", "DismissOfficeholder",
	"ResignGovernment", "ProposeBill", "VoteBill", "VoteConfidence",
	"VoteNoConfidence", "SupportGovernment", "WithdrawSupport",
	"HoldElection", "ContestElectionResult"
]


static func execute(action: String, actor_id: String, payload: Dictionary,
		state, context: Dictionary) -> Dictionary:
	eval_count += 1
	var rules = context["rules"]
	var outcome := {"ok": false, "outcome": "rejected", "reason": "unknown_action",
		"events": [], "assessments": []}
	match action:
		"FormGovernment":
			outcome = _form_government(actor_id, payload, state, rules)
		"AppointOfficeholder":
			outcome = _appoint_officeholder(actor_id, payload, state, rules, context)
		"DismissOfficeholder":
			outcome = _dismiss_officeholder(actor_id, payload, state, rules)
		"ResignGovernment":
			outcome = _resign_government(actor_id, payload, state)
		"ProposeBill":
			outcome = _propose_bill(actor_id, payload, state, rules)
		"VoteBill":
			outcome = _vote_bill(actor_id, payload, state, rules)
		"VoteConfidence":
			outcome = _vote_confidence(actor_id, payload, state, rules)
		"VoteNoConfidence":
			outcome = _vote_no_confidence(actor_id, payload, state, rules)
		"SupportGovernment":
			outcome = _support_government(actor_id, payload, state)
		"WithdrawSupport":
			outcome = _withdraw_support(actor_id, payload, state)
		"HoldElection":
			outcome = _hold_election(actor_id, payload, state, rules)
		"ContestElectionResult":
			outcome = _contest_election_result(actor_id, payload, state)
	outcome["action"] = action
	outcome["actor_id"] = actor_id
	return outcome


static func _res(ok: bool, outcome: String, reason: String, events: Array,
		assessments: Array) -> Dictionary:
	return {"ok": ok, "outcome": outcome, "reason": reason,
		"events": events, "assessments": assessments}


# ---------------- 1. FormGovernment ----------------

static func _form_government(actor_id: String, payload: Dictionary, state, rules) -> Dictionary:
	var leg_id := String(payload.get("legislature_id", ""))
	if not state.legislatures.has(leg_id):
		return _res(false, "failed", "unknown_legislature", [], [])
	var supporting: Array = payload.get("supporting_parties", [])
	for p in supporting:
		if not state.parties.has(String(p)):
			return _res(false, "failed", "unknown_party", [], [])
	var share = state.seat_share(leg_id, supporting)
	var lrules: Dictionary = rules.legislature_rules(leg_id)
	var threshold := float(lrules.get("formation_support_threshold", 0.5))

	if supporting.is_empty():
		state.emit_event("FormationFailed", {"government_id": String(payload.get("government_id", "")), "by": actor_id})
		return _res(false, "failed", "no_supporting_parties", [], [])

	var gov_id := String(payload["government_id"])
	if share < threshold:
		# remains incomplete — الحكومة قائمة كـforming بلا ثقة بعد
		state.apply_government({
			"government_id": gov_id, "head": String(payload.get("head", "")),
			"officeholders": [], "status": "forming",
			"formation_metadata": {"formed_by": actor_id, "legislature_id": leg_id,
				"supporting_parties": supporting.duplicate()}
		})
		var ev = state.emit_event("FormationIncomplete", {"government_id": gov_id,
			"support_share": share, "threshold": threshold})
		return _res(true, "incomplete", "support_below_threshold", [ev], [])

	# succeeds
	state.apply_government({
		"government_id": gov_id, "head": String(payload.get("head", "")),
		"officeholders": [], "status": "active",
		"formation_metadata": {"formed_by": actor_id, "legislature_id": leg_id,
			"supporting_parties": supporting.duplicate(),
			"formed_at_seq": state.event_log.size()}
	})
	var events: Array = [state.emit_event("GovernmentFormed",
		{"government_id": gov_id, "head": String(payload.get("head", "")),
			"support_share": share, "by": actor_id})]
	state.apply_regime({"regime_id": "reg_" + gov_id, "head": String(payload.get("head", "")),
		"government_id": gov_id, "change": "started"})
	var offices: Dictionary = payload.get("offices", {})
	var okeys: Array = offices.keys()
	okeys.sort()
	var officeholders: Array = (state.governments[gov_id] as Dictionary)["officeholders"]
	for oid in okeys:
		var office_id := String(oid)
		var candidate := String(offices[oid])
		var prev = state.holder_of(office_id)
		state.apply_office_fill(office_id, candidate)
		officeholders.append(office_id)
		events.append(state.emit_event("OfficeAssignment",
			{"office_id": office_id, "holder": candidate, "government_id": gov_id}))
		if prev != "" and prev != candidate:
			state.apply_succession({"succession_id": _suc_id(state), "office_id": office_id,
				"out_holder": prev, "in_holder": candidate,
				"cause": "government_formation", "election_id": null})
	return _res(true, "formed", "support_meets_threshold", events, [])


# ---------------- 2. AppointOfficeholder ----------------

static func _appoint_officeholder(actor_id: String, payload: Dictionary, state,
		rules, context: Dictionary) -> Dictionary:
	var office_id := String(payload.get("office_id", ""))
	var candidate := String(payload.get("candidate", ""))
	var can: Dictionary = rules.can_appoint(office_id, actor_id, state)
	if not bool(can["ok"]):
		return _res(false, "rejected", String(can["reason"]), [], [])
	if not state.characters.has(candidate):
		return _res(false, "rejected", "unknown_character", [], [])

	# Compliance: قبول المرشح — استهلاك assessment لا تنفيذ مباشر (قبول G/H)
	var cctx := {
		"entities": context.get("compliance_entities", {}),
		"chains": null,
		"config": context.get("compliance_config", {}),
		"action": {"id": "AcceptAppointment", "requires": [], "harms_interests": []},
		"actor_id": candidate, "target_id": actor_id
	}
	var assessment := CQ.assess(candidate, cctx["action"], actor_id, cctx)
	var assessments: Array = [assessment]
	if bool(assessment.get("short_circuited", false)):
		return _res(false, "candidate_infeasible", "capability_short_circuit", [], assessments)

	var prev = state.holder_of(office_id)
	state.apply_office_fill(office_id, candidate)
	var events: Array = [state.emit_event("OfficeFilled", {"office_id": office_id,
		"holder": candidate, "compliance_degree": assessment["compliance_degree"],
		"compliance_status": assessment["status"]})]
	if prev != "" and prev != candidate:
		state.apply_succession({"succession_id": _suc_id(state), "office_id": office_id,
			"out_holder": prev, "in_holder": candidate, "cause": "appointment",
			"election_id": null})
		events.append(state.emit_event("SuccessionOccurred", {"office_id": office_id,
			"cause": "appointment"}))
	return _res(true, "appointed", "office_filled", events, assessments)


# ---------------- 3. DismissOfficeholder ----------------

static func _dismiss_officeholder(actor_id: String, payload: Dictionary, state, rules) -> Dictionary:
	var office_id := String(payload.get("office_id", ""))
	var can: Dictionary = rules.can_dismiss(office_id, actor_id, state)
	if not bool(can["ok"]):
		return _res(false, "rejected", String(can["reason"]), [], [])
	var prev = state.holder_of(office_id)
	if prev == "":
		return _res(false, "rejected", "office_already_vacant", [], [])
	state.apply_office_vacate(office_id)
	var ev = state.emit_event("OfficeVacated", {"office_id": office_id, "out_holder": prev})
	# succession_on_vacancy: v0 يدعم "none" فقط (بيانات الـfixture) —
	# القيم الأخرى future work موثق، لا اختراع خلف تلقائي.
	return _res(true, "vacated", "office_vacated", [ev], [])


# ---------------- 4. ResignGovernment ----------------

static func _resign_government(actor_id: String, payload: Dictionary, state) -> Dictionary:
	var gov_id := String(payload.get("government_id", ""))
	if not state.governments.has(gov_id):
		return _res(false, "rejected", "unknown_government", [], [])
	var gov: Dictionary = state.governments[gov_id]
	if String(gov["head"]) != actor_id:
		return _res(false, "rejected", "not_head", [], [])
	state.apply_government_status(gov_id, "resigned")
	var ev = state.emit_event("GovernmentResigned", {"government_id": gov_id, "by": actor_id})
	return _res(true, "resigned", "government_resigned", [ev], [])


# ---------------- 5. ProposeBill ----------------

static func _propose_bill(actor_id: String, payload: Dictionary, state, rules) -> Dictionary:
	var leg_id := String(payload.get("legislature_id", ""))
	if not state.legislatures.has(leg_id):
		return _res(false, "rejected", "unknown_legislature", [], [])
	var lrules: Dictionary = rules.legislature_rules(leg_id)
	if bool(lrules.get("proposer_requires_seats", true)):
		var seats: Dictionary = (state.legislatures[leg_id] as Dictionary).get("seats", {})
		if int(seats.get(actor_id, 0)) <= 0:
			return _res(false, "rejected", "proposer_without_seats", [], [])
	var bill := {"bill_id": String(payload["bill_id"]), "legislature_id": leg_id,
		"proposer": actor_id, "title": String(payload.get("title", "")),
		"status": "proposed"}
	state.apply_bill(bill)
	var ev = state.emit_event("BillProposed", {"bill_id": bill["bill_id"],
		"proposer": actor_id, "legislature_id": leg_id})
	return _res(true, "proposed", "bill_proposed", [ev], [])


# ---------------- 6/7/8. Votes (التصويت ≠ النتيجة) ----------------

static func _tally_aye_share(state, leg_id: String, votes: Dictionary) -> float:
	var aye: Array = []
	for p in votes.keys():
		if String(votes[p]) == "aye":
			aye.append(String(p))
	return state.seat_share(leg_id, aye)


static func _vote_bill(actor_id: String, payload: Dictionary, state, rules) -> Dictionary:
	var bill_id := String(payload.get("bill_id", ""))
	if not state.bills.has(bill_id):
		return _res(false, "rejected", "unknown_bill", [], [])
	var bill: Dictionary = state.bills[bill_id]
	if String(bill["status"]) != "proposed":
		return _res(false, "rejected", "bill_not_open", [], [])
	var leg_id := String(bill["legislature_id"])
	var share := _tally_aye_share(state, leg_id, payload.get("votes", {}))
	var threshold := float(rules.legislature_rules(leg_id).get("bill_pass_threshold", 0.5))
	var events: Array = [state.emit_event("BillVoted", {"bill_id": bill_id,
		"aye_share": share, "threshold": threshold})]
	if share >= threshold:
		state.apply_bill_status(bill_id, "passed")
		events.append(state.emit_event("BillPassed", {"bill_id": bill_id}))
		return _res(true, "passed", "threshold_met", events, [])
	state.apply_bill_status(bill_id, "rejected")
	events.append(state.emit_event("BillRejected", {"bill_id": bill_id}))
	return _res(true, "rejected", "threshold_not_met", events, [])


static func _vote_confidence(actor_id: String, payload: Dictionary, state, rules) -> Dictionary:
	var gov_id := String(payload.get("government_id", ""))
	if not state.governments.has(gov_id):
		return _res(false, "rejected", "unknown_government", [], [])
	var leg_id := String(payload.get("legislature_id", ""))
	var share := _tally_aye_share(state, leg_id, payload.get("votes", {}))
	var threshold := float(rules.legislature_rules(leg_id).get("confidence_pass_threshold", 0.5))
	var events: Array = [state.emit_event("ConfidenceMotionVoted",
		{"government_id": gov_id, "aye_share": share, "threshold": threshold})]
	if share >= threshold:
		events.append(state.emit_event("ConfidencePassed", {"government_id": gov_id}))
		return _res(true, "ConfidencePassed", "threshold_met", events, [])
	events.append(state.emit_event("ConfidenceFailed", {"government_id": gov_id}))
	# consequence فقط حيث تسمح القواعد المؤسسية — لا افتراض تلقائي
	if bool(rules.legislature_rules(leg_id).get("confidence_fail_removes_government", false)):
		state.apply_government_status(gov_id, "removed")
		events.append(state.emit_event("GovernmentRemoved", {"government_id": gov_id,
			"cause": "confidence_failed"}))
	return _res(true, "ConfidenceFailed", "threshold_not_met", events, [])


static func _vote_no_confidence(actor_id: String, payload: Dictionary, state, rules) -> Dictionary:
	var gov_id := String(payload.get("government_id", ""))
	if not state.governments.has(gov_id):
		return _res(false, "rejected", "unknown_government", [], [])
	var leg_id := String(payload.get("legislature_id", ""))
	var share := _tally_aye_share(state, leg_id, payload.get("votes", {}))
	var threshold := float(rules.legislature_rules(leg_id).get("confidence_pass_threshold", 0.5))
	var events: Array = [state.emit_event("NoConfidenceMotionVoted",
		{"government_id": gov_id, "aye_share": share, "threshold": threshold})]
	if share >= threshold:
		events.append(state.emit_event("NoConfidencePassed", {"government_id": gov_id}))
		if bool(rules.legislature_rules(leg_id).get("no_confidence_removes_government", false)):
			state.apply_government_status(gov_id, "removed")
			events.append(state.emit_event("GovernmentRemoved",
				{"government_id": gov_id, "cause": "no_confidence"}))
		return _res(true, "NoConfidencePassed", "threshold_met", events, [])
	events.append(state.emit_event("NoConfidenceFailed", {"government_id": gov_id}))
	return _res(true, "NoConfidenceFailed", "threshold_not_met", events, [])


# ---------------- 9/10. Support ----------------

static func _support_government(actor_id: String, payload: Dictionary, state) -> Dictionary:
	var gov_id := String(payload.get("government_id", ""))
	if not state.parties.has(actor_id):
		return _res(false, "rejected", "actor_not_party", [], [])
	if not state.governments.has(gov_id):
		return _res(false, "rejected", "unknown_government", [], [])
	# الدعم يستهدف حكومة نشطة أو تحت التكوين (لا محالة/مستقيلة)
	var gstatus := String((state.governments[gov_id] as Dictionary).get("status", ""))
	if gstatus != "active" and gstatus != "forming":
		return _res(false, "rejected", "government_not_supportable", [], [])
	state.apply_support(actor_id, gov_id)
	var ev = state.emit_event("GovernmentSupportChanged",
		{"party_id": actor_id, "government_id": gov_id})
	return _res(true, "supported", "support_recorded", [ev], [])


static func _withdraw_support(actor_id: String, payload: Dictionary, state) -> Dictionary:
	if not state.parties.has(actor_id):
		return _res(false, "rejected", "actor_not_party", [], [])
	var gov_id := String(state.government_support.get(actor_id, ""))
	if gov_id == "":
		return _res(false, "rejected", "no_support_relation", [], [])
	state.apply_withdraw_support(actor_id)
	# سقوط الحكومة لا يحدث من هذا Action مباشرة — عبر institutional resolution
	var ev = state.emit_event("GovernmentSupportWithdrawn",
		{"party_id": actor_id, "government_id": gov_id})
	return _res(true, "withdrawn", "support_withdrawn", [ev], [])


# ---------------- 11. HoldElection ----------------

static func _hold_election(actor_id: String, payload: Dictionary, state, rules) -> Dictionary:
	var etype := String(payload.get("type", "general"))
	var el_rules: Dictionary = rules.election_rules(etype)
	if el_rules.is_empty():
		return _res(false, "rejected", "unknown_election_type", [], [])
	var auth_office := String(el_rules.get("electoral_authority_office", ""))
	if auth_office != "" and state.holder_of(auth_office) != actor_id:
		return _res(false, "rejected", "not_electoral_authority", [], [])
	var leg_id := String(payload.get("legislature_id", ""))
	if not state.legislatures.has(leg_id):
		return _res(false, "rejected", "unknown_legislature", [], [])
	var election_id := String(payload["election_id"])

	# توزيع حتمي: quota بقوة كل حزب + largest remainder (كسور التعادل بمعرف الحزب)
	var pids: Array = state.parties.keys()
	pids.sort()
	var total = state.seats_total(leg_id)
	var seats := {}
	var used := 0
	var fracs: Array = []
	for p in pids:
		var q := float((state.parties[p] as Dictionary)["political_profile"]["electoral_strength"]) * float(total)
		var fl := int(floor(q))
		seats[p] = fl
		used += fl
		fracs.append({"p": p, "frac": q - float(fl)})
	var rem = total - used
	fracs.sort_custom(func(a, b):
		if a["frac"] != b["frac"]:
			return a["frac"] > b["frac"]
		return String(a["p"]) < String(b["p"]))
	var i := 0
	while rem > 0 and fracs.size() > 0:
		seats[fracs[i % fracs.size()]["p"]] = int(seats[fracs[i % fracs.size()]["p"]]) + 1
		rem -= 1
		i += 1

	# winner: أعلى قوة، التعادل لمعرف الحزب الأصغر (pids مرتبة + مقارنة صارمة)
	var winner := ""
	var best := -1.0
	for p in pids:
		var s := float((state.parties[p] as Dictionary)["political_profile"]["electoral_strength"])
		if s > best:
			best = s
			winner = p

	var tally: Array = []
	for p in pids:
		tally.append({"party_id": p,
			"electoral_strength": float((state.parties[p] as Dictionary)["political_profile"]["electoral_strength"]),
			"seats": int(seats[p])})
	state.apply_election(
		{"election_id": election_id, "type": etype,
			"scope": String(el_rules.get("scope", "national")),
			"legislature_id": leg_id, "held_by": actor_id},
		{"election_id": election_id, "tally": tally, "winner_party": winner})

	var events: Array = [state.emit_event("ElectionHeld", {"election_id": election_id, "type": etype}),
		state.emit_event("ElectionResultAnnounced", {"election_id": election_id, "winner_party": winner})]

	if bool(el_rules.get("changes_composition", false)):
		state.apply_seats(leg_id, seats)
		events.append(state.emit_event("CompositionChanged", {"legislature_id": leg_id}))

	if bool(el_rules.get("changes_head", false)):
		var head_office := String(el_rules.get("head_office", ""))
		var out_holder = state.holder_of(head_office)
		var incumbent_party = state.party_of_leader(out_holder)
		if out_holder != "" and incumbent_party != winner:
			var in_holder := String((state.parties[winner] as Dictionary)["leader"])
			state.apply_succession({"succession_id": _suc_id(state), "office_id": head_office,
				"out_holder": out_holder, "in_holder": in_holder,
				"cause": "election", "election_id": election_id})
			state.apply_office_fill(head_office, in_holder)
			state.apply_regime({"regime_id": "reg_suc_" + election_id, "head": in_holder,
				"change": "election", "election_id": election_id})
			events.append(state.emit_event("SuccessionOccurred",
				{"office_id": head_office, "cause": "election", "election_id": election_id}))
		# الفائز الحالي نفسه ⇒ لا succession إلزامي (Election ≠ Succession)
	return _res(true, "held", "election_completed", events, [])


# ---------------- 12. ContestElectionResult ----------------

static func _contest_election_result(actor_id: String, payload: Dictionary, state) -> Dictionary:
	var election_id := String(payload.get("election_id", ""))
	var found := false
	for e in state.election_history:
		if String(e["election_id"]) == election_id:
			found = true
	if not found:
		return _res(false, "rejected", "unknown_election", [], [])
	state.apply_dispute({"dispute_id": String(payload.get("dispute_id", "")),
		"election_id": election_id, "disputant": actor_id, "status": "raised"})
	var ev = state.emit_event("ElectionDisputeRaised",
		{"dispute_id": String(payload.get("dispute_id", "")), "election_id": election_id,
			"disputant": actor_id})
	return _res(true, "disputed", "dispute_raised", [ev], [])


static func _suc_id(state) -> String:
	return "suc_%d" % (state.succession_history.size() + 1)
