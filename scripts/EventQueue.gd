extends RefCounted
class_name EventQueue

# Event = { "time": int, "type": String, "source": String, "payload": Dictionary }
# مش priority queue حقيقية دلوقتي — array بسيط بيتترتب وقت الإضافة.
# لو العدد كبر، هنا بالظبط المكان اللي يتحول لـ binary heap لاحقًا (evidence-based، مش قبلها).

var _events: Array = []

func push_event(time: int, type: String, source: String, payload: Dictionary = {}) -> void:
	var event = {
		"time": time,
		"type": type,
		"source": source,
		"payload": payload
	}
	_events.append(event)
	_events.sort_custom(func(a, b): return a["time"] < b["time"])

func has_due_events(current_time: int) -> bool:
	return _events.size() > 0 and _events[0]["time"] <= current_time

func pop_next() -> Dictionary:
	return _events.pop_front()

func peek_next_time() -> int:
	if _events.size() == 0:
		return -1
	return _events[0]["time"]

func pending_count() -> int:
	return _events.size()

func pending_summary() -> Array:
	var out = []
	for e in _events:
		out.append("%s @t=%d" % [e["type"], e["time"]])
	return out

# ============ Serialization ============
func to_dict() -> Dictionary:
	return {"events": _events.duplicate(true)}

func from_dict(d: Dictionary) -> void:
	_events.clear()
	for ev in d.get("events", []):
		var ev_copy: Dictionary = (ev as Dictionary).duplicate(true)
		# int() صريح — JSON.parse بتحوّل time لـ float، وهيجب يكون int للمقارنة والـ sort
		ev_copy["time"] = int(ev_copy.get("time", 0))
		_events.append(ev_copy)
	# إعادة الترتيب بعد التحميل
	_events.sort_custom(func(a, b): return a["time"] < b["time"])
