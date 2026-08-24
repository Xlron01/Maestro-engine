extends RefCounted
class_name SimClock

# 1 simulation step = 1 day (زي ما اتفقنا في نص 1)

var day: int = 0
var month: int = 1
var year: int = 1

func advance_day() -> void:
	day += 1
	if day > 30: # شهر مبسط = 30 يوم، مفيش حاجة اسمها تقويم دقيق دلوقتي
		day = 1
		month += 1
		if month > 12:
			month = 1
			year += 1

func total_days() -> int:
	# يوم مطلق منذ بداية المحاكاة — يُستخدم كـ "وقت" لكل event/scheduled job
	return (year - 1) * 360 + (month - 1) * 30 + day

func is_month_start() -> bool:
	return day == 1

func is_quarter_start() -> bool:
	return day == 1 and (month == 1 or month == 4 or month == 7 or month == 10)

func is_year_start() -> bool:
	return day == 1 and month == 1

func to_string_debug() -> String:
	return "Year %d, Month %d, Day %d (t=%d)" % [year, month, day, total_days()]

# ============ Serialization ============
func to_dict() -> Dictionary:
	return {"day": day, "month": month, "year": year}

func from_dict(d: Dictionary) -> void:
	# int() صريح لأن JSON.parse بتحوّل كل الأرقام لـ float تلقائياً
	day   = int(d.get("day",   0))
	month = int(d.get("month", 1))
	year  = int(d.get("year",  1))
