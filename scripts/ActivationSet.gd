extends RefCounted
class_name ActivationSet

# ده قلب التجربة (نص 4 و8 في وثيقة الـPrototype).
# أي entity_id مش هنا = "نايم" ومحدش بيحسبله حاجة الـtick ده.

var _active: Dictionary = {} # id -> true (Dictionary كـ set، مفيش Set نوع في GDScript)
var _wake_reasons: Dictionary = {} # id -> String (للـ debug UI، نعرف ليه استيقظ)

func activate(entity_id: String, reason: String = "") -> void:
	_active[entity_id] = true
	if reason != "":
		_wake_reasons[entity_id] = reason

func is_active(entity_id: String) -> bool:
	return _active.has(entity_id)

func clear() -> void:
	_active.clear()
	_wake_reasons.clear()

func active_ids() -> Array:
	return _active.keys()

func active_count() -> int:
	return _active.size()

func reason_for(entity_id: String) -> String:
	return _wake_reasons.get(entity_id, "")
