extends SceneTree

func _init() -> void:
	print("")
	print("============================================")
	print("  PHASE 1 VALIDATION TEST")
	print("============================================")
	print("")

	# ---- TEST 1: Missing required field ----
	print("--- TEST 1: Missing required field (no 'government') ---")
	var bad_data = {"id":"test","name":"Test","population":1000,"gdp":100.0,"military_power":10.0,"stability":0.5}
	var r1 = ContentSchema.validate(bad_data, ContentSchema.SCHEMA_COUNTRY, "test.json")
	print("ok: ", r1.ok)
	for e in r1.errors:
		print("ERROR: ", e)
	for w in r1.warnings:
		print("WARNING: ", w)
	print("")

	# ---- TEST 2: Broken reference ----
	print("--- TEST 2: Broken reference (relation to 'mars') ---")
	var ref_data = {"id":"testland","name":"Testland","population":1000,"gdp":100.0,"military_power":10.0,"stability":0.5,"government":"Republic","relations":["egypt","mars"]}
	var r2 = ContentSchema.validate_references(ref_data, ["egypt","country_b","country_c","france"], "testland.json")
	print("ok: ", r2.ok)
	for e in r2.errors:
		print("ERROR: ", e)
	for w in r2.warnings:
		print("WARNING: ", w)
	print("")

	# ---- TEST 3: Full load ----
	print("--- TEST 3: Full ContentLoader.load_full() ---")
	var r3 = ContentLoader.load_full()
	print("ok: ", r3.ok)
	for e in r3.errors:
		print("ERROR: ", e)
	for w in r3.warnings:
		print("WARNING: ", w)
	print("Total warnings: ", r3.warnings.size())
	print("Total errors: ", r3.errors.size())
	print("")
	print("============================================")
	print("  END OF TEST")
	print("============================================")
	quit()
