extends RefCounted
# ============================================================
# Economy v2 Handlers — T3-Phase 2 (Reusability Test)
# Manages Coal commodity independently of Economy v1.
# ============================================================

var _sim: Node
var _config: Dictionary = {}
var _stocks: Dictionary = {}    # country -> commodity -> float
var _prices: Dictionary = {}    # commodity -> float
var _shortages: Array = []      # [{country, commodity, stock}]

# T5-P0 counters (additive — measurement only, zero behavioral effect)
var activity_counters := {
	"production_updates": 0, "consumption_updates": 0, "shortage_events": 0
}

func setup(p_sim: Node) -> void:
	_sim = p_sim
	_load_config()
	_init_stocks()
	_init_prices()
	_sim.scheduled.register("__economy_v2__", "economy_v2_tick", 1, 0)

func _load_config() -> void:
	var path := "res://economy/economy_v2.json"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Economy v2: cannot open %s" % path)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_config = parsed

func _init_stocks() -> void:
	var init: Dictionary = _config.get("initial_stocks", {})
	for country in init.keys():
		_stocks[String(country)] = {}
		for commodity in (init[country] as Dictionary).keys():
			_stocks[String(country)][String(commodity)] = float(init[country][commodity])

func _init_prices() -> void:
	var commodities: Dictionary = _config.get("commodities", {})
	for commodity in commodities.keys():
		_prices[String(commodity)] = float((commodities[commodity] as Dictionary).get("base_price", 0.0))

func job_economy_v2_tick(_job: Dictionary, _t: int) -> void:
	_apply_production()
	_apply_consumption()
	_compute_prices()
	_detect_shortages()

func _apply_production() -> void:
	var rates: Dictionary = _config.get("production_rates", {})
	for country in rates.keys():
		var ckey := String(country)
		if not _stocks.has(ckey):
			continue
		for commodity in (rates[country] as Dictionary).keys():
			var cmod := String(commodity)
			_stocks[ckey][cmod] = _stocks[ckey].get(cmod, 0.0) + float(rates[country][commodity])
			activity_counters["production_updates"] += 1

func _apply_consumption() -> void:
	var rates: Dictionary = _config.get("consumption_rates", {})
	for country in rates.keys():
		var ckey := String(country)
		if not _stocks.has(ckey):
			continue
		for commodity in (rates[country] as Dictionary).keys():
			var cmod := String(commodity)
			_stocks[ckey][cmod] = maxf(0.0, _stocks[ckey].get(cmod, 0.0) - float(rates[country][commodity]))
			activity_counters["consumption_updates"] += 1

func _compute_prices() -> void:
	var commodities: Dictionary = _config.get("commodities", {})
	var prod_rates: Dictionary  = _config.get("production_rates", {})
	var cons_rates: Dictionary  = _config.get("consumption_rates", {})
	for commodity in commodities.keys():
		var cmod   := String(commodity)
		var cfg    := commodities[commodity] as Dictionary
		var supply := 0.0
		var demand := 0.0
		for country in prod_rates.keys():
			supply += float((prod_rates[country] as Dictionary).get(cmod, 0.0))
		for country in cons_rates.keys():
			demand += float((cons_rates[country] as Dictionary).get(cmod, 0.0))
		var base  := float(cfg.get("base_price",    150.0))
		var floor_p := float(cfg.get("price_floor",   30.0))
		var ceil_p  := float(cfg.get("price_ceiling", 600.0))
		var new_price := base if supply <= 0.0 else base * (demand / supply)
		_prices[cmod] = clampf(new_price, floor_p, ceil_p)

func _detect_shortages() -> void:
	_shortages.clear()
	var threshold := float(_config.get("shortage_threshold", 20.0))
	for country in _stocks.keys():
		for commodity in (_stocks[country] as Dictionary).keys():
			if float(_stocks[country][commodity]) < threshold:
				_shortages.append({
					"country":   country,
					"commodity": commodity,
					"stock":     _stocks[country][commodity]
				})
				activity_counters["shortage_events"] += 1

func get_stocks() -> Dictionary:
	return _stocks

func get_prices() -> Dictionary:
	return _prices

func get_shortages() -> Array:
	return _shortages
