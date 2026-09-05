extends EventQueue
class_name BatchedEventQueue

# ============================================================
# EXPERIMENTAL — T5-C (C1) — Batched EventQueue
# ------------------------------------------------------------
# الجذر المقاس (E1): 99.2-99.5% من زمن عاصفة T5-P0 هو إعادة sort_custom
# لكامل مصفوفة الأحداث مع كل دفعة (EventQueue.push_event) — ~10K دفعات
# بمصفوفة تكبر حتى ~10K عنصر يوم العاصفة.
# الحل هنا بنيوي لا دلالي: push = append فقط، وفرز واحد lazy عند أول
# قراءة بعد أي دفعة، وصرف عبر مؤشر رأس بدل pop_front (O(E)).
# المقارنة الزمنية مع baseline نفسها (نفس المقارن حرفيًا):
#   - الأزمنة المتميزة ⇒ نفس ترتيب الصرف bitwise.
#   - الروابط المتساوية الزمن ⇒ قد يختلف ترتيبها عن baseline (فرز
#     غير مستقر أصلاً هناك) — موثق عبر EVENT_SEQ_HASH التشخيصي؛ البوابة
#     الرسمية هي SEM_HASH/SEQ_HASH/counters bitwise.
# عدادات قياس داخلية رفيعة (push/pop/sort) بلا أي مؤقّت داخل push.
# ============================================================

var push_count: int = 0
var pop_count: int = 0
var sort_count: int = 0
var sort_us: int = 0
var event_order_parts: PackedStringArray = PackedStringArray()  # "type|source" بترتيب الصرف

var _dirty := false
var _head := 0


func push_event(time: int, type: String, source: String, payload: Dictionary = {}) -> void:
	_events.append({
		"time": time,
		"type": type,
		"source": source,
		"payload": payload
	})
	_dirty = true
	push_count += 1


func _ensure_sorted() -> void:
	if not _dirty:
		return
	# ضغط الرأس قبل الفرز حتى لا تتسرب عناصر pending خارج نافذة [head, size)
	if _head > 0:
		_events = _events.slice(_head)
		_head = 0
	var t0 := Time.get_ticks_usec()
	_events.sort_custom(func(a, b): return a["time"] < b["time"])
	sort_us += Time.get_ticks_usec() - t0
	sort_count += 1
	_dirty = false


func has_due_events(current_time: int) -> bool:
	if _head >= _events.size():
		_events.clear()
		_head = 0
		return false
	_ensure_sorted()
	return _events[_head]["time"] <= current_time


func pop_next() -> Dictionary:
	_ensure_sorted()
	var e: Dictionary = _events[_head]
	_head += 1
	pop_count += 1
	event_order_parts.append(String(e["type"]) + "|" + String(e["source"]))
	if _head >= _events.size():
		_events.clear()
		_head = 0
	return e


func peek_next_time() -> int:
	if _head >= _events.size():
		_events.clear()
		_head = 0
		return -1
	_ensure_sorted()
	return _events[_head]["time"]


func pending_count() -> int:
	var n := _events.size() - _head
	if n <= 0:
		_events.clear()
		_head = 0
		return 0
	return n


func pending_summary() -> Array:
	_ensure_sorted()
	var out := []
	for i in range(_head, _events.size()):
		var e: Dictionary = _events[i]
		out.append("%s @t=%d" % [e["type"], e["time"]])
	return out


func event_seq_hash() -> String:
	return "".join(event_order_parts).sha256_text()


# ============ Serialization ============
func to_dict() -> Dictionary:
	# الصرف الأصلي يُبقي pending فقط؛ المكافئ هنا [head, size)
	_ensure_sorted()
	var arr := []
	for i in range(_head, _events.size()):
		arr.append((_events[i] as Dictionary).duplicate(true))
	return {"events": arr}


func from_dict(d: Dictionary) -> void:
	_events.clear()
	_head = 0
	for ev in d.get("events", []):
		var ev_copy: Dictionary = (ev as Dictionary).duplicate(true)
		# int() صريح — JSON.parse بتحوّل time لـ float
		ev_copy["time"] = int(ev_copy.get("time", 0))
		_events.append(ev_copy)
	_dirty = true
