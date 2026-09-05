extends EventQueue
class_name EventQueueProbe

# ============================================================
# EXPERIMENTAL — T5-C (E1) — EventQueue Measurement Wrapper
# ------------------------------------------------------------
# يلفّ EventQueue بخيط قياس رفيع: زمن وعدد push_event (وحجم المصفوفة عند كل
# دفعة)، وزمن has_due_events/pop_next، وعدّاد ties، وترتيب الصرف (تشخيصي).
# المسار الأصلي نفسه يُنفَّذ عبر super.* — صفر تغيير سلوكي.
# الحقن post-init عبر to_dict/from_dict (قبل أول تكة يكون الطابور فيه
# أحداث السيناريو فقط — roundtrip مطابق).
# الدرس من H2: لا بناء سلاسل ثقيل لكل عنصر داخل المسار الساخن؛ السلاسل
# تُجمع في PackedStringArray (خطي) للتصوير فقط.
# ============================================================

var push_count: int = 0
var push_us: int = 0
var max_array_at_push: int = 0
var sum_array_at_push: int = 0
var hasdue_calls: int = 0
var hasdue_us: int = 0
var pop_count: int = 0
var pop_us: int = 0
var ties: int = 0
var event_order_parts: PackedStringArray = PackedStringArray()  # "type|source" بترتيب الصرف
var _last_pop_time: int = -999999999


func push_event(time: int, type: String, source: String, payload: Dictionary = {}) -> void:
	var t0 := Time.get_ticks_usec()
	var size_before := _events.size()
	sum_array_at_push += size_before
	if size_before > max_array_at_push:
		max_array_at_push = size_before
	super.push_event(time, type, source, payload)
	push_count += 1
	push_us += Time.get_ticks_usec() - t0


func has_due_events(current_time: int) -> bool:
	hasdue_calls += 1
	var t0 := Time.get_ticks_usec()
	var r := super.has_due_events(current_time)
	hasdue_us += Time.get_ticks_usec() - t0
	return r


func pop_next() -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var e := super.pop_next()
	pop_us += Time.get_ticks_usec() - t0
	pop_count += 1
	var et := int(e["time"])
	if et == _last_pop_time:
		ties += 1
	_last_pop_time = et
	event_order_parts.append(String(e["type"]) + "|" + String(e["source"]))
	return e


func event_seq_hash() -> String:
	return "".join(event_order_parts).sha256_text()
