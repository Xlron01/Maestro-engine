#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Political Topology Discovery — ACTIVE subgraph analysis (Charter v1.1).

Key discovery from run5 verification: a large share of semantic edges are
LATENT — they exist as production read-paths but nothing in the current
political runtime ever WRITES the source state, so no propagation can occur
along them. Charter §2 requires edges to be production read-paths (faithful);
the discovery report must therefore separate:

  ACTIVE edges   : src state has at least one production writer
                   (apply_office_fill / apply_seats / apply_government_status /
                    apply_support / apply_withdraw_support / head changes)
  LATENT edges   : src state is read but has NO production writer today
                   (parties[].electoral_strength, parties[].leader,
                    legislatures[].dissolved, ...)
                   => topologically real, behaviorally dormant.

This module recomputes the graph per variant with the ACTIVE/LATENT split
and derives the metrics that depend on it (active degree, active depth,
active components, per-country active subgraphs).

Charter amendment A1 (frozen post-discovery, pre-report): the metric set of
§4 is computed for (a) the FULL semantic graph (as before) and (b) the
ACTIVE subgraph only. Both are reported side by side. No numbers are dropped.
"""
import json
import os
from collections import Counter, defaultdict

import importlib.util

HERE = os.path.dirname(os.path.abspath(__file__))
sys_path_hack = os.path.dirname(HERE)


def _load_extractor():
    spec = importlib.util.spec_from_file_location(
        "extract_topology", os.path.join(HERE, "extract_topology.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


EX = _load_extractor()
OUT = os.path.join(HERE, "results")


# ----------------------------------------------------------------------------
# Production writers (audited from political_state.gd apply_* + actions)
# ----------------------------------------------------------------------------

def writers_by_state():
    """Which political state fields have production writers, and which nodes
    they can touch. Returns {field: writer_fn} and a node-typewriter map."""
    # From political_actions.gd audit:
    #  apply_office_fill / apply_office_vacate  -> offices[oid].holder/.status
    #  apply_government / apply_government_status -> governments[gid].status...
    #  apply_support / apply_withdraw_support    -> government_support
    #  apply_seats                              -> legislatures[lid].seats
    #  (apply_bill / histories are excluded node types per Charter §1)
    return {
        "office.holder": "apply_office_fill/apply_office_vacate (actions 1,2,3,11)",
        "office.status": "apply_office_fill/apply_office_vacate",
        "legislature.seats": "apply_seats (HoldElection changes_composition)",
        "government.status": "apply_government_status (4,7,8)",
        "government.head": "apply_government (1) — fixture sets head at formation",
        "government_support": "apply_support/apply_withdraw_support (9,10)",
    }


def edge_src_state(etype):
    """Which src-side state field the edge reads (maps edge type -> field)."""
    return {
        "E1 appointing_authority": "office.holder",      # holder_of(auth)
        "E2 dismissible_by": "office.holder",            # holder_of(d)
        "E3 party.seats->leg totals": "legislature.seats",  # seats dict is leg state; party-side seats mirror only
        "E3 leg->gov formation/tallies": "legislature.seats",
        "E4 gov.status->support eligibility": "government.status",
        "E5 government_support": "government_support",
        "E6 electoral_authority gate": "office.holder",
        "E6 head_office succession": "legislature.seats",   # winner derived from seats quota
        "E7 strength->seat quota": "party.electoral_strength",
        "E8 term wiring (time-gated)": "legislature.rules",  # static rule, not runtime state
        "E9 head resigns eligibility": "government.head",
    }.get(etype, "?")


def active_edges(edges):
    writers = writers_by_state()
    out = []
    for e in edges:
        field = edge_src_state(e["etype"])
        if field in writers:
            out.append({**e, "src_field": field, "writer": writers[field]})
    return out


# ----------------------------------------------------------------------------
# Analysis
# ----------------------------------------------------------------------------

def analyze(name, variant, world, rules, scoped_e7=False):
    nodes, counts = EX.node_inventory(world)
    edges = EX.extract_edges(world, rules, scoped_e7=scoped_e7)
    act = active_edges(edges)

    m_full, adj_full, _ = EX.metrics(nodes, edges)
    m_act, adj_act, _ = EX.metrics(nodes, act)
    depth_full, sccs_full, cyc_full = EX.max_causal_depth(nodes, adj_full)
    depth_act, sccs_act, cyc_act = EX.max_causal_depth(nodes, adj_act)

    # closures on BOTH graphs: full (E7 latent edges included in reach) and
    # active (E7 latent excluded — what can propagate today)
    cl_full = EX.compute_closures(world, rules, adj_full, nodes)
    cl_act = EX.compute_closures(world, rules, adj_act, nodes)

    split = {
        "edges_total": len(edges),
        "edges_active": len(act),
        "edges_latent": len(edges) - len(act),
        "edges_by_type_active": dict(Counter(e["etype"] for e in act)),
        "edges_by_type_latent": dict(Counter(
            e["etype"] for e in edges if e not in act)),
    }
    return {
        "world": name, "variant": variant,
        "node_counts": counts,
        "node_types": dict(Counter(n["type"] for n in nodes.values())),
        "full": {"metrics": m_full, "max_causal_depth": depth_full,
                 "scc_count": len(sccs_full),
                 "cyclic_sccs": sum(1 for c in sccs_full if len(c) > 1),
                 "cyclic_scc_examples": [c[:6] for c in cyc_full[:2]],
                 "closures": cl_full},
        "active": {"metrics": m_act, "max_causal_depth": depth_act,
                   "scc_count": len(sccs_act),
                   "cyclic_sccs": sum(1 for c in sccs_act if len(c) > 1),
                   "cyclic_scc_examples": [c[:6] for c in cyc_act[:2]],
                   "closures": cl_act},
        "split": split,
    }


def main():
    root = os.path.abspath(os.path.join(HERE, "..", ".."))
    os.chdir(root)
    worlds = [
        ("production_minimal", "data/worlds/politics/batch_a_base.json",
         "data/rules/institutional_rules.json"),
        ("t040_a", "data/scenarios/t040/t040_a/worlds/politics/world.json",
         "data/scenarios/t040/t040_a/rules/institutional_rules.json"),
        ("t040_c", "data/scenarios/t040/t040_c/worlds/politics/world.json",
         "data/scenarios/t040/t040_c/rules/institutional_rules.json"),
    ]
    summary = []
    for name, wpath, rpath in worlds:
        w = json.load(open(wpath, encoding="utf-8"))
        rules = json.load(open(rpath, encoding="utf-8"))
        variants = [("aswired", rules, False)]
        if name != "production_minimal":
            variants.append(("prodsem", EX.prodsem_rules(rules, w), False))
            variants.append(("prodsem_scopedE7", EX.prodsem_rules(rules, w), True))
        for vname, vrules, scoped in variants:
            res = analyze(name, vname, w, vrules, scoped_e7=scoped)
            fp = os.path.join(OUT, f"{name}__{vname}__active.json")
            with open(fp, "w", encoding="utf-8", newline="\n") as f:
                json.dump(res, f, indent=1, ensure_ascii=False)
            fa, ff = res["active"]["metrics"], res["full"]["metrics"]
            row = {
                "world": name, "variant": vname,
                "edges_full": res["split"]["edges_total"],
                "edges_active": res["split"]["edges_active"],
                "edges_latent": res["split"]["edges_latent"],
                "cross_country_active": fa["cross_country_edges"],
                "components_active": fa["components"],
                "largest_comp_active": fa["largest_component"],
                "depth_active": res["active"]["max_causal_depth"],
                "out_max_active": fa["out_degree_max"],
                "in_max_active": fa["in_degree_max"],
            }
            summary.append(row)
            print(f"{name}/{vname}: full={res['split']['edges_total']} "
                  f"active={res['split']['edges_active']} "
                  f"latent={res['split']['edges_latent']} "
                  f"cross_active={fa['cross_country_edges']} "
                  f"comps_active={fa['components']} "
                  f"largest_active={fa['largest_component']} "
                  f"depth_active={res['active']['max_causal_depth']}")
    with open(os.path.join(OUT, "summary_active.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(summary, f, indent=1, ensure_ascii=False)
    print("done")


if __name__ == "__main__":
    main()
