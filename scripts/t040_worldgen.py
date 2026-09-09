#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ============================================================
# TASK-040 — Deterministic World/Workload Fixture Generator
# ------------------------------------------------------------
# Generates 5 self-contained fixture trees under data/scenarios/t040/:
#   t040_a10 (A10 minimal, 1 government) · t040_a (Normal, 30 active)
#   t040_b (Regional Crisis, 15 affected) · t040_c (Global Crisis, 120 active)
#   t040_d (Stacked Contention: 15 crisis + 30 background + 170 quiet)
#
# TEST FIXTURE ONLY — values are NOT production game-balance content.
# Deterministic: every random draw goes through random.Random(TREE_SEED).
# Political seat allocation mirrors PoliticalActions._hold_election
# (largest remainder, ties by party id) so fixture seats are consistent
# with what an election would produce.
# Zero engine changes here — data generation only.
# ============================================================
import io
import json
import os
import random
import sys

ROOT = os.path.join("data", "scenarios", "t040")

SRC_RULES = os.path.join("data", "rules", "politics.json")

N_COUNTRIES = 200
SEATS_TOTAL = 200          # per legislature (fixture value)
PARTY_STRENGTH_TEMPLATE = [0.45, 0.30, 0.15, 0.10]  # k=4 parties (fixture)

# Tree seeds — logged in manifest; same seed => byte-identical fixture.
TREE_SEEDS = {
    "t040_a10": 101040,
    "t040_a": 40140,
    "t040_b": 40240,
    "t040_c": 40340,
    "t040_d": 40440,
}

# Scenario activity specs (owner-frozen v1):
#   A10: 1 government, election-wired, term=30, call_days=0 (minimal full-chain proof)
#   A  : 30/200 politically active — governed, ALL election-wired (normal
#        democracies), mild political events, no coups
#   B  : 15 crisis-affected — governed + election-wired + coup/minister events
#   C  : 120/200 activation pressure — all governed crisis-wired + events
#   D  : 15 crisis-active + 30 independent background-active + quiet remainder.
#        NOTE: owner text says "15+30+170" which sums to 215; the frozen N=200
#        world constraint wins, so quiet = 200-45 = 155 (flagged in report).
# "election_wired" = crisis countries (B/C/D) or all governed (A/a10):
# government_term_days>0 + term_expiration_causes_election=true.
SCENARIO_SPECS = {
    "t040_a10": {"governed": 1, "crisis": 1, "background": 0,
                 "horizon": 60, "election_call_days": 0,
                 "all_election_wired": True},
    "t040_a": {"governed": 30, "crisis": 0, "background": 0,
               "horizon": 90, "election_call_days": 5,
               "all_election_wired": True},
    "t040_b": {"governed": 15, "crisis": 15, "background": 0,
               "horizon": 90, "election_call_days": 5},
    "t040_c": {"governed": 120, "crisis": 120, "background": 0,
               "horizon": 90, "election_call_days": 5},
    "t040_d": {"governed": 45, "crisis": 15, "background": 30,
               "horizon": 120, "election_call_days": 5},
}


def jdump(obj, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with io.open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(obj, f, indent=1, ensure_ascii=False)
        f.write("\n")


def largest_remainder_seats(strengths, total):
    """Mirror of PoliticalActions._hold_election seat allocation."""
    quotas = {p: strengths[p] * total for p in strengths}
    seats = {p: int(q // 1) for p, q in quotas.items()}
    used = sum(seats.values())
    fracs = sorted(
        [{"p": p, "frac": quotas[p] - seats[p]} for p in strengths],
        key=lambda x: (-x["frac"], x["p"]),
    )
    rem = total - used
    i = 0
    while rem > 0 and fracs:
        seats[fracs[i % len(fracs)]["p"]] += 1
        rem -= 1
        i += 1
    return seats


def gen_str_tree(rng, base, jitter):
    """k=4 electoral strengths summing to 1.0 — deterministic per country."""
    raw = [max(0.02, base[i] * (1.0 + rng.uniform(-jitter, jitter))) for i in range(4)]
    s = sum(raw)
    return [v / s for v in raw]


def make_country_ids(rng):
    """Deterministic stable country id list: c000..c199 in id order."""
    return ["c%03d" % i for i in range(N_COUNTRIES)]


def pick(rng, pool, k):
    return rng.sample(pool, k)


def build_tree(tree_name, spec):
    seed = TREE_SEEDS[tree_name]
    rng = random.Random(seed)
    tdir = os.path.join(ROOT, tree_name)

    # ---------- deterministic role assignment ----------
    ids = make_country_ids(rng)
    governed = pick(rng, ids, spec["governed"])
    crisis = pick(rng, governed, spec["crisis"]) if spec["crisis"] <= len(governed) else governed[:]
    # background countries are NOT governed (independent background activity)
    rest = [c for c in ids if c not in governed]
    background = pick(rng, rest, spec["background"])

    governed_set = set(governed)
    crisis_set = set(crisis)
    background_set = set(background)
    # election-wired legislatures: in Normal/A10 worlds every governed country
    # is a democracy (election on term expiry); in crisis worlds only the
    # crisis-governed subset carries election causality.
    if spec.get("all_election_wired", False):
        election_set = set(governed_set)
    else:
        election_set = set(crisis_set)

    # ---------- strategic-layer countries ----------
    for cid in ids:
        cdir = os.path.join(tdir, "countries", cid)
        os.makedirs(cdir, exist_ok=True)
        is_crisis = cid in crisis_set
        is_background = cid in background_set
        stability = rng.uniform(0.25, 0.55) if is_crisis else (
            rng.uniform(0.50, 0.90) if is_background else rng.uniform(0.60, 0.95))
        country = {
            "id": cid,
            "name": cid,
            "population": 1_000_000 + rng.randint(0, 9_000_000),
            "gdp": 1000.0 + rng.uniform(0.0, 9000.0),
            "military_power": 1.0 + rng.uniform(0.0, 490.0),
            "stability": round(stability, 3),
            "government": "Republic",
            "growth": 0.005 + rng.uniform(0.0, 0.03),
            "relations": [],
        }
        jdump(country, os.path.join(cdir, "country.json"))

    # ---------- political world (governments as data) ----------
    characters = {}
    parties = {}
    legislatures = {}
    offices = {}
    governments = {}
    government_support = {}

    for idx, cid in enumerate(ids):
        # every country gets full institutions (200 legislatures), but only
        # governed countries get a government + term rule wiring.
        strengths = gen_str_tree(rng, PARTY_STRENGTH_TEMPLATE, 0.15)
        leg_id = "leg_%s" % cid
        pids = ["%s_P%d" % (cid, k) for k in range(4)]
        for k, pid in enumerate(pids):
            leader = "%s_c_l%d" % (cid, k)
            mp = "%s_c_m%d" % (cid, k)
            characters[leader] = {"name": "Leader %d %s" % (k, cid)}
            characters[mp] = {"name": "MP %d %s" % (k, cid)}
            parties[pid] = {
                "party_id": pid,
                "leader": leader,
                "membership": [leader, mp],
                "political_profile": {
                    "electoral_strength": strengths[k],
                    "ideology": "v%d" % (k + 1),
                },
                "seats": {},
            }
        king = "%s_c_king" % cid
        characters[king] = {"name": "Head of State %s" % cid}
        seats = largest_remainder_seats(
            {pids[k]: strengths[k] for k in range(4)}, SEATS_TOTAL)
        for k, pid in enumerate(pids):
            parties[pid]["seats"][leg_id] = seats[pid]
        legislatures[leg_id] = {
            "legislature_id": leg_id,
            "chambers": ["lower"],
            "seats": {pids[k]: seats[pids[k]] for k in range(4)},
            "procedural_state": {"dissolved": False, "term": 1},
            "active_bills": [],
            "active_motions": [],
        }
        offices["%s_office_president" % cid] = {
            "office_id": "%s_office_president" % cid,
            "institution_id": "inst_state_%s" % cid,
            "role": "head_of_state",
            "holder": king,
            "status": "appointed",
        }
        offices["%s_office_pm" % cid] = {
            "office_id": "%s_office_pm" % cid,
            "institution_id": "inst_government_%s" % cid,
            "role": "head_of_government",
            "holder": None,
            "status": "vacant",
        }
        offices["%s_office_finance" % cid] = {
            "office_id": "%s_office_finance" % cid,
            "institution_id": "inst_government_%s" % cid,
            "role": "minister",
            "holder": None,
            "status": "vacant",
        }

        if cid in governed_set:
            gov_id = "gov_%s" % cid
            # deterministic: strongest party's leader is head
            head = characters and "%s_c_l0" % cid
            governments[gov_id] = {
                "government_id": gov_id,
                "head": head,
                "officeholders": [],
                "status": "active",
                "legislature_id": leg_id,
                # fixture metadata (TEST FIXTURE value, not production balance)
                "fixture_crisis_active": cid in crisis_set,
                "fixture_background_active": cid in background_set,
            }

    world = {
        "world_id": "t040_%s_political_fixture" % tree_name,
        "description": (
            "TASK-040 benchmark political fixture — TEST FIXTURE ONLY, "
            "not game-balance content. %s scenario." % tree_name),
        "fixture_metadata": {
            "seed": seed,
            "num_countries": N_COUNTRIES,
            "test_horizon_days": spec["horizon"],
            "governed": len(governed_set),
            "crisis_active": len(crisis_set),
            "background_active": len(background_set),
            "note": "TEST FIXTURE VALUE — not production game-balance value",
        },
        "characters": characters,
        "parties": parties,
        "legislatures": legislatures,
        "offices": offices,
        "governments": governments,
        "government_support": government_support,
    }
    jdump(world, os.path.join(tdir, "worlds", "politics", "world.json"))

    # ---------- institutional rules (generated; data-driven injection) ----------
    institutions = {}
    for cid in ids:
        leg_id = "leg_%s" % cid
        is_governed = cid in governed_set
        institutions["legislature_%s" % leg_id] = {
            "kind": "legislature",
            "legislature_id": leg_id,
            "rules": {
                "confidence_required_to_form": True,
                "formation_support_threshold": 0.5,
                "bill_pass_threshold": 0.5,
                "confidence_pass_threshold": 0.5,
                "no_confidence_removes_government": True,
                "confidence_fail_removes_government": False,
                "proposer_requires_seats": True,
                # term wiring: governed countries get terms; election-wiring
                # (causes_election) per election_set (all governed in Normal/A10,
                # crisis subset in crisis worlds)
                "government_term_days": rng.choice([30, 60]) if is_governed else 0,
                "term_expiration_causes_election": cid in election_set,
                "election_call_days": spec["election_call_days"] if cid in election_set else 0,
            },
        }
        institutions["office_%s_office_president" % cid] = {
            "kind": "office",
            "office_id": "%s_office_president" % cid,
            "role": "head_of_state",
            "rules": {
                "appointing_authority": "",
                "dismissible_by": [],
                "succession_on_vacancy": "none",
            },
        }
        institutions["office_%s_office_pm" % cid] = {
            "kind": "office",
            "office_id": "%s_office_pm" % cid,
            "role": "head_of_government",
            "rules": {
                "appointing_authority": "%s_office_president" % cid,
                "dismissible_by": ["%s_office_president" % cid],
                "succession_on_vacancy": "none",
            },
        }
        institutions["office_%s_office_finance" % cid] = {
            "kind": "office",
            "office_id": "%s_office_finance" % cid,
            "role": "minister",
            "rules": {
                "appointing_authority": "%s_office_pm" % cid,
                "dismissible_by": ["%s_office_president" % cid, "%s_office_pm" % cid],
                "succession_on_vacancy": "none",
            },
        }
    rules = {
        "_non_final": "TASK-040 benchmark-generated institutional rules — TEST FIXTURE",
        "institutions": institutions,
        "elections": {
            "general": {
                "type": "general",
                "scope": "national",
                "rules": {
                    "changes_composition": True,
                    "changes_head": False,
                    # wide-open electoral authority so HoldElection executed from
                    # the deadline path can run under the fixture offices wiring
                    "electoral_authority_office": "",
                },
            }
        },
    }
    jdump(rules, os.path.join(tdir, "rules", "institutional_rules.json"))

    # ---------- rules copy (production semantics unchanged) ----------
    with io.open(SRC_RULES, "r", encoding="utf-8") as f:
        prod_rules = json.load(f)
    jdump(prod_rules, os.path.join(tdir, "rules", "politics.json"))

    # ---------- deterministic event stream ----------
    events = []
    horizon = spec["horizon"]
    # crisis events on crisis countries: bursts in the first half of horizon
    for cid in sorted(crisis_set):
        t = rng.randint(5, horizon // 2)
        events.append({"time": t, "type": "Coup_Attempt", "source": cid})
        t2 = rng.randint(horizon // 2, horizon)
        events.append({"time": t2, "type": "Minister_Died", "source": cid})
    # background events on background countries (Scenario D semantics:
    # independent background activity)
    for cid in sorted(background_set):
        t = rng.randint(1, horizon)
        events.append({"time": t, "type": "Minister_Died", "source": cid})
        t2 = rng.randint(1, horizon)
        events.append({"time": t2, "type": "Election", "source": cid})
    # normal-world mild political events on governed non-crisis countries
    # (Scenario A semantics: meaningful activity without coups)
    normal_gov = sorted(governed_set - crisis_set)
    for cid in normal_gov:
        t = rng.randint(1, horizon)
        events.append({"time": t, "type": "Minister_Died", "source": cid})
    # quiet majority: no events at all (mostly quiet)
    events.sort(key=lambda e: (e["time"], e["type"], e["source"]))
    jdump(events, os.path.join(tdir, "scenarios", "default", "events.json"))

    # ---------- manifest ----------
    manifest = {
        "tree": tree_name,
        "seed": seed,
        "scenario_spec": spec,
        "governed": sorted(governed_set),
        "crisis_active": sorted(crisis_set),
        "background_active": sorted(background_set),
        "n_countries": N_COUNTRIES,
        "horizon": horizon,
        "events": {
            "total": len(events),
            "by_type": _count_by(events, "type"),
        },
        "note": "TEST FIXTURE — deterministic workload; same seed => identical tree",
    }
    jdump(manifest, os.path.join(tdir, "manifest.json"))
    return manifest


def _count_by(events, key):
    out = {}
    for e in events:
        out[e[key]] = out.get(e[key], 0) + 1
    return out


def main():
    os.makedirs(ROOT, exist_ok=True)
    manifests = {}
    for tree_name in ["t040_a10", "t040_a", "t040_b", "t040_c", "t040_d"]:
        m = build_tree(tree_name, SCENARIO_SPECS[tree_name])
        manifests[tree_name] = m
        print("generated %s: governed=%d crisis=%d background=%d events=%d" % (
            tree_name, len(m["governed"]), len(m["crisis_active"]),
            len(m["background_active"]), m["events"]["total"]))
    jdump(manifests, os.path.join(ROOT, "manifest.json"))
    print("all trees generated under %s" % ROOT)


if __name__ == "__main__":
    sys.exit(main())
