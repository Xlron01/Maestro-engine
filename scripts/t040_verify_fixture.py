#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ============================================================
# TASK-040 — Fixture Tree Static Verifier
# ------------------------------------------------------------
# Verifies every t040 fixture tree for internal integrity BEFORE the
# benchmark runs. Exit code 1 on any failure. Pure static checks —
# no engine, no Godot. TEST FIXTURE verification only.
# ============================================================
import io
import json
import os
import sys

ROOT = os.path.join("data", "scenarios", "t040")

EXPECTED = {
    "t040_a10": {"governed": 1, "crisis": 1, "background": 0, "horizon": 60,
                 "election_wired": 1},
    "t040_a": {"governed": 30, "crisis": 0, "background": 0, "horizon": 90,
               "election_wired": 30},
    "t040_b": {"governed": 15, "crisis": 15, "background": 0, "horizon": 90,
               "election_wired": 15},
    "t040_c": {"governed": 120, "crisis": 120, "background": 0, "horizon": 90,
               "election_wired": 120},
    "t040_d": {"governed": 45, "crisis": 15, "background": 30, "horizon": 120,
               "election_wired": 15},
}

N_COUNTRIES = 200

errors = []
warnings = []


def err(msg):
    errors.append(msg)


def warn(msg):
    warnings.append(msg)


def load(path):
    with io.open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def verify_tree(tree):
    tdir = os.path.join(ROOT, tree)
    exp = EXPECTED[tree]

    # --- files present ---
    for rel in ["worlds/politics/world.json", "rules/institutional_rules.json",
                "rules/politics.json", "scenarios/default/events.json",
                "manifest.json"]:
        if not os.path.exists(os.path.join(tdir, rel)):
            err("%s: missing %s" % (tree, rel))
            return
    for i in range(N_COUNTRIES):
        cid = "c%03d" % i
        if not os.path.exists(os.path.join(tdir, "countries", cid, "country.json")):
            err("%s: missing country %s" % (tree, cid))
            return

    world = load(os.path.join(tdir, "worlds/politics/world.json"))
    rules = load(os.path.join(tdir, "rules/institutional_rules.json"))
    events = load(os.path.join(tdir, "scenarios/default/events.json"))
    manifest = load(os.path.join(tdir, "manifest.json"))

    # --- fixture labelling ---
    if "TEST FIXTURE" not in world.get("description", ""):
        err("%s: world description not labelled as TEST FIXTURE" % tree)
    meta = world.get("fixture_metadata", {})
    if "TEST FIXTURE VALUE" not in meta.get("note", ""):
        err("%s: fixture_metadata note not labelled" % tree)

    # --- 200 countries everywhere ---
    chars = world["characters"]
    parties = world["parties"]
    legs = world["legislatures"]
    offices = world["offices"]
    govs = world["governments"]
    if len(legs) != N_COUNTRIES:
        err("%s: legislatures=%d expected %d" % (tree, len(legs), N_COUNTRIES))
    if len(offices) != N_COUNTRIES * 3:
        err("%s: offices=%d expected %d" % (tree, len(offices), N_COUNTRIES * 3))
    if len(govs) != exp["governed"]:
        err("%s: governments=%d expected %d" % (tree, len(govs), exp["governed"]))

    # --- cross-reference integrity ---
    for pid, p in parties.items():
        if p["leader"] not in chars:
            err("%s: party %s leader %s not a character" % (tree, pid, p["leader"]))
        for m in p["membership"]:
            if m not in chars:
                err("%s: party %s member %s not a character" % (tree, pid, m))
        for leg_id, seats in p["seats"].items():
            if leg_id not in legs:
                err("%s: party %s references unknown legislature %s" % (tree, pid, leg_id))
    for leg_id, leg in legs.items():
        total = sum(leg["seats"].values())
        if total != 200:
            err("%s: legislature %s seats total=%d expected 200" % (tree, leg_id, total))
        for pid in leg["seats"]:
            if pid not in parties:
                err("%s: legislature %s references unknown party %s" % (tree, leg_id, pid))
    for oid, o in offices.items():
        h = o.get("holder")
        if h is not None and h not in chars:
            err("%s: office %s holder %s not a character" % (tree, oid, h))
    for gid, g in govs.items():
        if g["head"] not in chars:
            err("%s: government %s head %s not a character" % (tree, gid, g["head"]))
        if g["legislature_id"] not in legs:
            err("%s: government %s references unknown legislature %s"
                % (tree, gid, g["legislature_id"]))

    # --- institutional rules coverage + term wiring ---
    inst = rules["institutions"]
    term_legs = set()
    causes_election = set()
    for key, val in inst.items():
        if key.startswith("legislature_"):
            leg_id = val["legislature_id"]
            if leg_id not in legs:
                err("%s: rules reference unknown legislature %s" % (tree, leg_id))
            r = val["rules"]
            if r.get("government_term_days", 0) > 0:
                term_legs.add(leg_id)
            if r.get("term_expiration_causes_election", False):
                causes_election.add(leg_id)
    # every government's legislature must be term-wired
    for gid, g in govs.items():
        if g["legislature_id"] not in term_legs:
            err("%s: government %s legislature %s has no term wiring"
                % (tree, gid, g["legislature_id"]))
    # crisis count must equal causes_election count (election wiring)
    if len(causes_election) != exp["election_wired"]:
        err("%s: causes_election=%d expected %d"
            % (tree, len(causes_election), exp["election_wired"]))

    # --- events: target + type validity, within horizon ---
    valid_types = {"Coup_Attempt", "Minister_Died", "Election"}
    country_ids = set("c%03d" % i for i in range(N_COUNTRIES))
    manifest_crisis = set(manifest["crisis_active"])
    manifest_background = set(manifest["background_active"])
    n_crisis_events = 0
    n_background_events = 0
    for e in events:
        if e["type"] not in valid_types:
            err("%s: event type %s not in dispatch fixture set" % (tree, e["type"]))
        if e["source"] not in country_ids:
            err("%s: event source %s not a country" % (tree, e["source"]))
        if e["time"] < 1 or e["time"] > exp["horizon"]:
            err("%s: event time %d outside horizon 1..%d" % (tree, e["time"], exp["horizon"]))
        if e["source"] in manifest_crisis:
            n_crisis_events += 1
        elif e["source"] in manifest_background:
            n_background_events += 1
    if exp["crisis"] > 0 and n_crisis_events == 0:
        err("%s: crisis countries have no events" % tree)
    if exp["background"] > 0 and n_background_events == 0:
        err("%s: background countries have no events" % tree)
    # quiet majority: countries with no events must exist in D
    event_targets = set(e["source"] for e in events)
    quiet = country_ids - event_targets
    if tree == "t040_d" and len(quiet) < 100:
        err("%s: expected >=100 quiet countries, got %d" % (tree, len(quiet)))

    # --- manifest consistency ---
    if len(manifest["governed"]) != exp["governed"]:
        err("%s: manifest governed=%d expected %d" % (tree, len(manifest["governed"]), exp["governed"]))
    if len(manifest["crisis_active"]) != exp["crisis"]:
        err("%s: manifest crisis=%d expected %d" % (tree, len(manifest["crisis_active"]), exp["crisis"]))
    if len(manifest["background_active"]) != exp["background"]:
        err("%s: manifest background=%d expected %d"
            % (tree, len(manifest["background_active"]), exp["background"]))
    if set(manifest["governed"]) != set(gid.replace("gov_", "") for gid in govs):
        err("%s: manifest governed set != world governments" % tree)
    if not set(manifest["crisis_active"]).issubset(set(manifest["governed"])):
        err("%s: crisis countries not subset of governed" % tree)
    if set(manifest["background_active"]) & set(manifest["governed"]):
        err("%s: background countries overlap governed (must be independent)" % tree)

    print("  %-9s OK  govs=%3d crisis=%3d background=%3d events=%3d quiet=%3d"
          % (tree, len(govs), len(manifest["crisis_active"]),
             len(manifest["background_active"]), len(events), len(quiet)))


def main():
    print("============================================================")
    print("  TASK-040 fixture tree verification")
    print("============================================================")
    for tree in ["t040_a10", "t040_a", "t040_b", "t040_c", "t040_d"]:
        verify_tree(tree)
    print("------------------------------------------------------------")
    if warnings:
        print("WARNINGS (%d):" % len(warnings))
        for w in warnings:
            print("  [WARN] %s" % w)
    if errors:
        print("ERRORS (%d):" % len(errors))
        for e in errors:
            print("  [ERROR] %s" % e)
        print("[FAIL] fixture verification failed")
        sys.exit(1)
    print("[SUCCESS] all 5 fixture trees verified (0 errors)")
    sys.exit(0)


if __name__ == "__main__":
    main()
