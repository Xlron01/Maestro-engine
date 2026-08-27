extends RefCounted
# ============================================================
# Economy Event Handlers — T3-Phase 1 (Representability Test)
# Economy layer ONLY — zero engine baseline modifications here.
# Registered via game_event_handlers.gd delegation + dispatch.json.
# ============================================================

var _sim: Node
var _config: Dictionary = {}
var _stocks: Dictionary = {}    # country -> commodity -> float
var _prices: Dictionary = {}    # commodity -> float
var _shortages: Array = []      # [{country, commodity, stock}]

# ---- Setup (called from game_event_handlers.setup via delegation) ----
func setup(p_sim: Node) -> void:
	_sim = p_sim
	_load_config()
	_init_stocks()
	_init_prices()
	_sim.scheduled.register("__economy__", "economy_tick", 1, 0)

func _load_config() -> void:
	var path := "res://economy/economy.json"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Economy: cannot open %s" % path)
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

# ---- Scheduled Job: economy_tick ----
func job_economy_tick(_job: Dictionary, _t: int) -> void:
	_apply_production()
	_apply_consumption()
	_apply_trade()
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

func _apply_consumption() -> void:
	var rates: Dictionary = _config.get("consumption_rates", {})
	for country in rates.keys():
		var ckey := String(country)
		if not _stocks.has(ckey):
			continue
		for commodity in (rates[country] as Dictionary).keys():
			var cmod := String(commodity)
			_stocks[ckey][cmod] = maxf(0.0, _stocks[ckey].get(cmod, 0.0) - float(rates[country][commodity]))

func _apply_trade() -> void:
	var routes: Array = _config.get("trade_routes", [])
	for route in routes:
		var from_c := String(route["from"])
		var to_c   := String(route["to"])
		var cmod   := String(route["commodity"])
		var volume := float(route["volume"])
		if not _stocks.has(from_c) or not _stocks.has(to_c):
			continue
		var available: float = _stocks[from_c].get(cmod, 0.0)
		var actual: float = minf(volume, available)
		_stocks[from_c][cmod] -= actual
		_stocks[to_c][cmod]    = _stocks[to_c].get(cmod, 0.0) + actual

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
		var base  := float(cfg.get("base_price",    100.0))
		var floor_p := float(cfg.get("price_floor",   0.0))
		var ceil_p  := float(cfg.get("price_ceiling", 9999.0))
		var new_price := base if supply <= 0.0 else base * (demand / supply)
		_prices[cmod] = clampf(new_price, floor_p, ceil_p)

func _detect_shortages() -> void:
	_shortages.clear()
	var threshold := float(_config.get("shortage_threshold", 50.0))
	for country in _stocks.keys():
		for commodity in (_stocks[country] as Dictionary).keys():
			if float(_stocks[country][commodity]) < threshold:
				_shortages.append({
					"country":   country,
					"commodity": commodity,
					"stock":     _stocks[country][commodity]
				})

# ---- Event: Trade_Offer ----
func evt_trade_offer(e: Dictionary, _t: int) -> void:
	var from_c  := String(e.get("source", ""))
	var payload := e.get("payload", {}) as Dictionary
	var to_c    := String(payload.get("to", ""))
	var cmod    := String(payload.get("commodity", ""))
	var volume  := float(payload.get("volume", 0.0))
	if not _stocks.has(from_c) or not _stocks.has(to_c):
		return
	var available: float = _stocks[from_c].get(cmod, 0.0)
	var actual: float = minf(volume, available)
	_stocks[from_c][cmod] -= actual
	_stocks[to_c][cmod]    = _stocks[to_c].get(cmod, 0.0) + actual

# ---- Read-only accessors ----
func get_stocks() -> Dictionary:
	return _stocks

func get_prices() -> Dictionary:
	return _prices

func get_shortages() -> Array:
	return _shortages
