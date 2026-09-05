extends RefCounted
class_name ComplianceTypes

# ============================================================
# COMPLIANCE RUNTIME LAYER — Assessment Contracts (TASK-038)
# ------------------------------------------------------------
# العقود المقفولة من المالك (رسالة 2026-09-06 + مراجعة الخطة rev.2):
#   status      = COMPLETE | PARTIAL          (PARTIAL ≠ failure — نقص
#               dependency لا يتحول إلى default ولا false كاذب)
#   feasibility = FEASIBLE | INFEASIBLE | UNKNOWN
#   resistance  = NONE | PASSIVE | ACTIVE      (بُعد مستقل عن degree)
#
# توضيح المالك المعتمد (§0-b-1) — social_relations قاموس واحد متعدد القنوات:
#   social_relations[target] = { "loyalty": x, "trust": y, "kinship": z, ... }
#   Influence يقرأ قناته (trust/kinship) وCompliance يقرأ قناته (loyalty)
#   من نفس الحقل الخام. هذه "قراءة قنوات مختلفة من نفس الـedge" —
#   ليست نسخًا مستقلة من المفهوم لكل نظام، ولا تكرار بيانات.
#
# صفر stochastic — كل الدوال نقية وحتمية. لا world mutation هنا إطلاقًا.
# طبقة استعلام on-demand حصرًا: ممنوع ربطها بـ tick loop أو dispatch —
# (العقد موثق في وثيقة 27 وقبول K يراقبه).
# ============================================================

const FEASIBLE := "FEASIBLE"
const INFEASIBLE := "INFEASIBLE"
const UNKNOWN := "UNKNOWN"

const COMPLETE := "COMPLETE"
const PARTIAL := "PARTIAL"

const RES_NONE := "NONE"
const RES_PASSIVE := "PASSIVE"
const RES_ACTIVE := "ACTIVE"

# أسماء الـfuture dependencies الموحدة (تظهر حرفيًا داخل missing_inputs —
# لا أنظمة وهمية تُبنى لها — وثيقة 27 §Contracts)
const MISS_POPULAR_SUPPORT := "PopularSupport"
const MISS_CONSTITUTIONAL_VALIDITY := "ConstitutionalValidity"
const MISS_THREAT_ASSESSMENT := "ThreatAssessment"
const MISS_PUBLIC_ORDER := "PublicOrder"
const MISS_AUDIENCE_VIEW := "AudienceView"
const MISS_CONTROL_CHAINS := "ControlChains"
const MISS_LOYALTY_REL := "LoyaltyRelationship"

# قنوات الـedge الاجتماعي الواحد (§0-b-1)
const CHANNEL_LOYALTY := "loyalty"   # تستهلكها Compliance
const CHANNEL_TRUST := "trust"       # تستهلكها Influence (informal)
const CHANNEL_KINSHIP := "kinship"   # متاحة حاليًا غير مستهلَكة (future)

const CONFIG_PATH := "res://data/rules/compliance_config.json"


static func load_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_error("compliance_config.json missing: %s" % CONFIG_PATH)
		return {}
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("compliance_config.json invalid")
		return {}
	return parsed


# ---------------- Assessment factories (أشكال مقفولة) ----------------

static func capability_assessment(feasibility: String, status: String,
		used: Array, missing: Array, limiting: Array) -> Dictionary:
	return {
		"feasibility": feasibility,
		"status": status,
		"limiting_factors": limiting,
		"used_inputs": used,
		"missing_inputs": missing
	}


static func legitimacy_assessment(value, status: String,
		used: Array, missing: Array) -> Dictionary:
	return {
		"value": value,
		"status": status,
		"used_inputs": used,
		"missing_inputs": missing
	}


static func influence_assessment(structural, informal: float,
		status: String, used: Array, missing: Array) -> Dictionary:
	return {
		"structural": structural,
		"informal": informal,
		"status": status,
		"used_inputs": used,
		"missing_inputs": missing
	}


static func compliance_assessment(degree, mode, strength, status: String,
		used: Array, missing: Array, short_circuited: bool) -> Dictionary:
	return {
		"compliance_degree": degree,
		"resistance_mode": mode,
		"resistance_strength": strength,
		"status": status,
		"used_inputs": used,
		"missing_inputs": missing,
		"short_circuited": short_circuited
	}


# ---------------- أدوات مشتركة (نقية) ----------------

# دمج missing_inputs: إزالة تكرار + ترتيب معجمي (حتمية الـserialization)
static func merge_missing(lists: Array) -> Array:
	var seen := {}
	var out: Array = []
	for l in lists:
		for item in (l as Array):
			var k := String(item)
			if not seen.has(k):
				seen[k] = true
				out.append(k)
	out.sort()
	return out


# canonical: JSON بمفاتيح مفروزة تع recursيًا — أساس بوابة A/J bitwise
static func canonical(v) -> String:
	return JSON.stringify(_sort_rec(v))


static func _sort_rec(v):
	if v is Dictionary:
		var keys := (v as Dictionary).keys()
		keys.sort()
		var o := {}
		for k in keys:
			o[k] = _sort_rec(v[k])
		return o
	if v is Array:
		var arr: Array = []
		for x in v:
			arr.append(_sort_rec(x))
		return arr
	return v


# قراءة قناة من الـedge الاجتماعي الواحد (§0-b-1) — النظر عبر الاتجاهين
# بترتيب حتمي معلن: src→tgt أولًا ثم tgt→src. يعيد null إن لم يوجد edge.
static func social_channel(entities: Dictionary, src: String, tgt: String,
		channel: String):
	var e_src: Dictionary = entities.get(src, {})
	var e_tgt: Dictionary = entities.get(tgt, {})
	var edge = null
	var sr: Dictionary = e_src.get("social_relations", {})
	if sr.has(tgt):
		edge = sr[tgt]
	else:
		var tr: Dictionary = e_tgt.get("social_relations", {})
		if tr.has(src):
			edge = tr[src]
	if edge == null:
		return null
	var d: Dictionary = edge
	if d.has(channel):
		return float(d[channel])
	return null
