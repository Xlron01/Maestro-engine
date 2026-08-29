# -*- coding: utf-8 -*-
# T5-P0 World Generator — deterministic 10,000-country world under data/scenarios/t5_p0/
# Owner-ordered scope: data-only generation, zero engine changes.
import io, json, os, shutil

ROOT = os.path.join("data", "scenarios", "t5_p0")
SRC_RULES = os.path.join("data", "rules", "politics.json")
SRC_EVENTS = os.path.join("data", "scenarios", "default", "events.json")

N = 10000
os.makedirs(os.path.join(ROOT, "countries"), exist_ok=True)
os.makedirs(os.path.join(ROOT, "rules"), exist_ok=True)
os.makedirs(os.path.join(ROOT, "scenarios", "default"), exist_ok=True)

shutil.copyfile(SRC_RULES, os.path.join(ROOT, "rules", "politics.json"))
shutil.copyfile(SRC_EVENTS, os.path.join(ROOT, "scenarios", "default", "events.json"))

for i in range(N):
    cid = "c%05d" % i
    d = os.path.join(ROOT, "countries", cid)
    os.makedirs(d, exist_ok=True)
    # deterministic variation: no rng
    country = {
        "id": cid,
        "name": cid,
        "population": 1000000 + (i * 137 % 9000000),
        "gdp": 1000.0 + (i * 37 % 9000),
        "military_power": 1.0 + (i * 7 % 490),
        "stability": 0.5 + ((i * 13 % 50) / 100.0),
        "government": "Republic",
        "growth": 0.005 + ((i * 11 % 30) / 1000.0),
        "relations": []
    }
    io.open(os.path.join(d, "country.json"), "w", encoding="utf-8").write(
        json.dumps(country, indent=1, ensure_ascii=False))

print("generated %d countries under %s" % (N, ROOT))
