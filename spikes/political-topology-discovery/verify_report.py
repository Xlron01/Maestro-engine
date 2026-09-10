#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Verify REPORT.md numbers against raw results JSONs (discovery-grade)."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
R = lambda f: os.path.join(HERE, "results", f)

fails = []


def check(label, ok, detail=""):
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  [{detail}]" if detail else ""))
    if not ok:
        fails.append(label)


def load(f):
    with open(R(f), encoding="utf-8") as fp:
        return json.load(fp)


# ---- §2 edge inventory (t040_a aswired, full) ----
a = load("t040_a__aswired.json")["metrics"]
ebt = a["edges_by_type"]
check("E1=400", ebt.get("E1 appointing_authority") == 400)
check("E2=600", ebt.get("E2 dismissible_by") == 600)
check("E3 seats=800", ebt.get("E3 party.seats->leg totals") == 800)
check("E3 leg->gov=30", ebt.get("E3 leg->gov formation/tallies") == 30)
check("E4=120", ebt.get("E4 gov.status->support eligibility") == 120)
check("E7=160000", ebt.get("E7 strength->seat quota") == 160000)
check("E8=30", ebt.get("E8 term wiring (time-gated)") == 30)
check("E9=30", ebt.get("E9 head resigns eligibility") == 30)
check("aswired full total=162010", a["edges_total"] == 162010)

aa = load("t040_a__aswired__active.json")
check("aswired active=1980 / latent=160030",
      aa["split"]["edges_active"] == 1980 and aa["split"]["edges_latent"] == 160030)

ap = load("t040_a__prodsem.json")["metrics"]
check("prodsem full total=162410", ap["edges_total"] == 162410)
apa = load("t040_a__prodsem__active.json")
check("prodsem active=2380", apa["split"]["edges_active"] == 2380)

sc = load("t040_a__prodsem_scopedE7.json")["metrics"]
check("scopedE7 full total=3210", sc["edges_total"] == 3210)
sca = load("t040_a__prodsem_scopedE7__active.json")
check("scopedE7 active=2380 / latent=830",
      sca["split"]["edges_active"] == 2380 and sca["split"]["edges_latent"] == 830)

# static/dynamic split (§2 table)
check("full aswired static=1030", a["edges_static_rule"] == 1030, str(a["edges_static_rule"]))
check("full prodsem static=1430", ap["edges_static_rule"] == 1430, str(ap["edges_static_rule"]))
faa = aa["active"]["metrics"]
check("active aswired: static=1000 / dyn=980",
      faa["edges_static_rule"] == 1000 and faa["edges_dynamic_state"] == 980)
fap = apa["active"]["metrics"]
check("active prodsem: static=1400 / dyn=980",
      fap["edges_static_rule"] == 1400 and fap["edges_dynamic_state"] == 980)

# ---- §3 degree/hub/depth/components ----
check("active aswired: out_mean=1.57 p95=3 max=5",
      abs(faa["out_degree_mean"] - 1.57) < 0.01 and faa["out_degree_p95"] == 3
      and faa["out_degree_max"] == 5,
      f"mean={faa['out_degree_mean']:.3f} p95={faa['out_degree_p95']} max={faa['out_degree_max']}")
check("active aswired: in_max=4", faa["in_degree_max"] == 4, str(faa["in_degree_max"]))
check("active aswired: hubs>=20 = 0", not faa["hubs_in_ge20"])
check("active aswired: comps=400 largest=6",
      faa["components"] == 400 and faa["largest_component"] == 6)
check("active aswired: depth=2", aa["active"]["max_causal_depth"] == 2)
check("active aswired: cross-country=0", faa["cross_country_edges"] == 0)

check("active prodsem: out_mean=1.66 p95=4 max=5",
      abs(fap["out_degree_mean"] - 1.66) < 0.01 and fap["out_degree_p95"] == 4
      and fap["out_degree_max"] == 5)
check("active prodsem: in_max=5", fap["in_degree_max"] == 5, str(fap["in_degree_max"]))
check("active prodsem: comps=200 largest=9",
      fap["components"] == 200 and fap["largest_component"] == 9)
check("active prodsem: depth=3", apa["active"]["max_causal_depth"] == 3)
check("active prodsem: cross-country=0", fap["cross_country_edges"] == 0)
check("active prodsem: cyclic SCCs=30", apa["active"]["cyclic_sccs"] == 30,
      str(apa["active"]["cyclic_sccs"]))

check("full aswired: out_max=201 in_max=805 largest=1030",
      a["out_degree_max"] == 201 and a["in_degree_max"] == 805
      and a["largest_component"] == 1030)
check("full prodsem: largest=1630 (giant)", ap["largest_component"] == 1630)
check("full prodsem: depth=4", load("t040_a__prodsem.json")["metrics"]
      and json.load(open(R("t040_a__prodsem.json"), encoding="utf-8"))
      ["full"]["max_causal_depth"] if "full" in load("t040_a__prodsem.json") else
      load("t040_a__prodsem.json")["metrics"]["max_causal_depth"] == 4)
check("full scopedE7: in_max=10", sc["in_degree_max"] == 10)

# ---- §4 closures ----
# HoldElection on ACTIVE graph (prodsem): median 3, max 8
he_act = [c for c in apa["active"]["closures"]
          if c["op"].startswith("HoldElection")][0]
check("HoldElection ACTIVE: direct median=1, eval median=2/max=3, struct median=3/max=8",
      he_act["direct_writes_median"] == 1 and he_act["eval_closure_median"] == 2
      and he_act["eval_closure_max"] == 3 and he_act["structural_closure_median"] == 3
      and he_act["structural_closure_max"] == 8,
      json.dumps(he_act))
# HoldElection on FULL graph (prodsem): struct max=750
he_full = [c for c in apa["full"]["closures"]
           if c["op"].startswith("HoldElection")][0]
check("HoldElection FULL: struct max=750",
      he_full["structural_closure_max"] == 750, str(he_full["structural_closure_max"]))
# Dismiss (prodsem): eval=4 struct=4
dm = [c for c in apa["active"]["closures"] if c["op"] == "DismissOfficeholder"][0]
check("Dismiss prodsem: eval=4 struct=4",
      dm["eval_closure"] == 4 and dm["structural_closure"] == 4)

# production minimal
pm = load("production_minimal__aswired.json")["metrics"]
pma = load("production_minimal__aswired__active.json")
check("minimal: nodes=7 active_edges=10 in_max=7 depth=3 comps=1",
      pm["nodes_total"] == 7 and pma["split"]["edges_active"] == 10
      and pm["in_degree_max"] == 7
      and load("production_minimal__aswired.json")["metrics"]["max_causal_depth"] == 3
      and pm["components"] == 1)

# t040_c
c_a = load("t040_c__aswired__active.json")
c_p = load("t040_c__prodsem__active.json")
check("t040_c: active 2520 aswired / 2920 prodsem",
      c_a["split"]["edges_active"] == 2520 and c_p["split"]["edges_active"] == 2920)
check("t040_c: cross-country active=0 in both",
      c_a["active"]["metrics"]["cross_country_edges"] == 0 and
      c_p["active"]["metrics"]["cross_country_edges"] == 0)
check("t040_c: largest active 6/9, depth 2/3",
      c_a["active"]["metrics"]["largest_component"] == 6 and
      c_p["active"]["metrics"]["largest_component"] == 9 and
      c_a["active"]["max_causal_depth"] == 2 and
      c_p["active"]["max_causal_depth"] == 3)

# ---- §6 workload ----
wl = load("workload_evidence.json")
check("scenario A: 60 dl / max 20; C: 240 dl / max 64",
      wl["scenario_A"]["deadline_activations_total"] == 60 and
      wl["scenario_A"]["deadline_activations_max_day"] == 20 and
      wl["scenario_C"]["deadline_activations_total"] == 240 and
      wl["scenario_C"]["deadline_activations_max_day"] == 64)

print("\n" + ("ALL CHECKS PASSED" if not fails else f"{len(fails)} FAILURES: {fails}"))
sys.exit(1 if fails else 0)
