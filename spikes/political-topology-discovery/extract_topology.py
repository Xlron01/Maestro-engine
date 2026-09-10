#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Political Topology Discovery — read-only extraction per CHARTER.md v1.0.

Builds the semantic political graph (edges E1-E10) from a political world JSON
+ institutional rules JSON, exactly as the production GDScript code reads them.
No production file is modified; no Godot is run — the reader mirrors the read
paths audited in the Charter (can_appoint/can_dismiss/seat_share/support/
holder_of/party leader/electoral_strength), so edge extraction is faithful to
production semantics, not to data shapes.

Variants per world:
  - aswired      : fixture rules verbatim
  - prodsem      : production election semantics calibrated per country
                   (changes_head=true, head_office=<cid>_office_pm,
                   electoral_authority_office=<cid>_office_president)
  - prodsem+scopedE7 : prodsem AND E7 quota loop restricted to same-country
                   parties (counterfactual isolating the E7 global-loop anomaly)

Outputs results/<world>__<variant>.json with nodes/edges/metrics/closures.
"""
import json
import os
import re
import sys
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results")
LOG = os.path.join(HERE, "logs")


def load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


# ----------------------------------------------------------------------------
# Node inventory (Charter §1)
# ----------------------------------------------------------------------------

def node_inventory(world):
    nodes = {}
    counts = {}
    for ntype, key in (("Office", "offices"), ("Party", "parties"),
                       ("Legislature", "legislatures"), ("Government", "governments")):
        for nid, rec in world.get(key, {}).items():
            nodes[nid] = {"type": ntype, "id": nid}
        counts[ntype] = len(world.get(key, {}))
    counts["Character (identity-only, excluded)"] = len(world.get("characters", {}))
    return nodes, counts


# ----------------------------------------------------------------------------
# Edge extraction (Charter §2, E1-E10)
# ----------------------------------------------------------------------------

_CID_RE = re.compile(r"^(?:leg_|gov_)?(c\d{3})")


def country_of(nid):
    m = _CID_RE.match(nid or "")
    if m:
        return m.group(1)
    return "single"


def extract_edges(world, rules, scoped_e7=False):
    edges = []

    def add(src, dst, etype, prov):
        if src is None or dst is None:
            return
        if scoped_e7 and etype.startswith("E7"):
            if country_of(src) != country_of(dst):
                return
        edges.append((src, dst, etype, prov))

    insts = rules.get("institutions", {})
    elections = rules.get("elections", {})

    # E1/E2 office->office authority wiring
    for inst in insts.values():
        if inst.get("kind") != "office":
            continue
        office_id = inst.get("office_id")
        r = inst.get("rules", {})
        auth = r.get("appointing_authority", "")
        if auth:
            add(auth, office_id, "E1 appointing_authority", "static-rule")
        for d in r.get("dismissible_by", []):
            add(d, office_id, "E2 dismissible_by", "static-rule")

    # E3 party.seats -> leg totals ; leg -> gov formation/tallies
    for gov_id, gov in world.get("governments", {}).items():
        leg_id = gov.get("legislature_id")
        if leg_id:
            add(leg_id, gov_id, "E3 leg->gov formation/tallies", "dynamic-state")
    for leg_id, leg in world.get("legislatures", {}).items():
        for pid in leg.get("seats", {}):
            add(pid, leg_id, "E3 party.seats->leg totals", "dynamic-state")

    # E4 gov.status -> support eligibility (parties seated in gov's legislature)
    leg_parties = {l: sorted(leg.get("seats", {}).keys())
                  for l, leg in world.get("legislatures", {}).items()}
    for gov_id, gov in world.get("governments", {}).items():
        leg_id = gov.get("legislature_id")
        if not leg_id:
            continue
        for pid in leg_parties.get(leg_id, []):
            add(gov_id, pid, "E4 gov.status->support eligibility", "dynamic-state")

    # E5 government_support party->gov
    for pid, gov_id in world.get("government_support", {}).items():
        add(pid, gov_id, "E5 government_support", "dynamic-state")

    # E6/E7 election wiring per election type, per legislature.
    # head_office / electoral_authority_office may carry a country prefix
    # (e.g. "c000_office_pm") — in that case they are PER-COUNTRY templates:
    # bind each legislature to ITS OWN country's offices (no cross-country
    # edges from the binding itself).
    for etype, e in elections.items():
        er = e.get("rules", {})
        auth_tpl = er.get("electoral_authority_office", "")
        head_tpl = er.get("head_office", "")
        changes_head = bool(er.get("changes_head", False))
        for leg_id in world.get("legislatures", {}):
            lc = country_of(leg_id)

            def bind(tpl, leg_country):
                """Bind an office template to the legislature's country.
                Production naming ('office_pm') and country-prefixed templates
                ('c005_office_pm') both bind to the leg's own scoped office."""
                if not tpl:
                    return None
                if tpl in world.get("offices", {}):
                    # exact id (production single-country world) — accept only
                    # if it belongs to this leg's country or is unscoped
                    tc = country_of(tpl)
                    if tc == "single" or tc == leg_country:
                        return tpl
                    return None
                # try the leg's country-prefixed variant (fixture naming)
                bound = leg_country + "_" + tpl
                return bound if bound in world.get("offices", {}) else None

            auth = bind(auth_tpl, lc)
            head = bind(head_tpl, lc)
            for pid in world.get("parties", {}):
                add(pid, leg_id, "E7 strength->seat quota", "dynamic-state")
            if auth:
                add(auth, leg_id, "E6 electoral_authority gate", "static-rule")
            if changes_head and head:
                add(leg_id, head, "E6 head_office succession", "static-rule")

    # E8 term wiring (time-gated rule edges, self-loop marker)
    for inst in insts.values():
        if inst.get("kind") != "legislature":
            continue
        lid = inst.get("legislature_id")
        if int(inst.get("rules", {}).get("government_term_days", 0)) > 0:
            add(lid, lid, "E8 term wiring (time-gated)", "static-rule")

    # E9 gov.head -> own resignation eligibility
    for gov_id in world.get("governments", {}):
        add(gov_id, gov_id, "E9 head resigns eligibility", "dynamic-state")

    seen = {}
    for e in edges:
        seen.setdefault((e[0], e[1], e[2]), e)
    return [dict(src=s, dst=d, etype=t, provenance=p) for (s, d, t), (s, d, t, p) in seen.items()]


# ----------------------------------------------------------------------------
# Metrics (Charter §4)
# ----------------------------------------------------------------------------

def metrics(nodes, edges):
    m = {}
    m["nodes_total"] = len(nodes)
    m["edges_total"] = len(edges)
    outdeg, indeg = Counter(), Counter()
    adj, radj = defaultdict(list), defaultdict(list)
    for e in edges:
        adj[e["src"]].append(e["dst"])
        radj[e["dst"]].append(e["src"])
        outdeg[e["src"]] += 1
        indeg[e["dst"]] += 1
    outs = sorted(outdeg.values())
    ins = sorted(indeg.values())
    m["out_degree_mean"] = sum(outs) / len(outs) if outs else 0
    m["out_degree_max"] = outs[-1] if outs else 0
    m["out_degree_p50"] = outs[len(outs) // 2] if outs else 0
    m["out_degree_p95"] = outs[int(len(outs) * .95)] if outs else 0
    m["in_degree_mean"] = sum(ins) / len(ins) if ins else 0
    m["in_degree_max"] = ins[-1] if ins else 0
    m["top_out"] = outdeg.most_common(10)
    m["top_in"] = indeg.most_common(10)

    # components (undirected)
    parent = {n: n for n in nodes}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for e in edges:
        if e["src"] in parent and e["dst"] in parent:
            ra, rb = find(e["src"]), find(e["dst"])
            if ra != rb:
                parent[ra] = rb
    comps = defaultdict(int)
    for n in nodes:
        comps[find(n)] += 1
    sizes = sorted(comps.values(), reverse=True)
    m["components"] = len(comps)
    m["largest_component"] = sizes[0] if sizes else 0
    m["mean_component"] = sum(sizes) / len(sizes) if sizes else 0
    m["component_sizes_top5"] = sizes[:5]
    cross = []
    for e in edges:
        ca, cb = country_of(e["src"]), country_of(e["dst"])
        if ca != cb:
            cross.append({**e, "src_country": ca, "dst_country": cb})
    m["cross_country_edges"] = len(cross)
    m["cross_country_examples"] = cross[:6]

    per = defaultdict(lambda: {"nodes": 0, "edges": 0})
    for n in nodes:
        per[country_of(n)]["nodes"] += 1
    for e in edges:
        per[country_of(e["src"])]["edges"] += 1
    per.pop("single", None)
    if per:
        pes = sorted(v["edges"] for v in per.values())
        m["per_country_count"] = len(per)
        m["per_country_nodes_mean"] = sum(v["nodes"] for v in per.values()) / len(per)
        m["per_country_edges_mean"] = sum(pes) / len(pes)
        m["per_country_edges_max"] = pes[-1]

    prov = Counter(e["provenance"] for e in edges)
    m["edges_static_rule"] = prov.get("static-rule", 0)
    m["edges_dynamic_state"] = prov.get("dynamic-state", 0)
    m["edges_by_type"] = dict(Counter(e["etype"] for e in edges))
    m["hubs_in_ge20"] = {n: d for n, d in indeg.items() if d >= 20}
    return m, adj, radj


# ----------------------------------------------------------------------------
# Max causal depth — SCC condensation + longest path in the condensed DAG
# ----------------------------------------------------------------------------

def max_causal_depth(nodes, adj):
    # Tarjan SCC (iterative)
    index = {}
    low = {}
    onstack = set()
    stack = []
    scc_of = {}
    sccs = []
    counter = [0]

    for root in nodes:
        if root in index:
            continue
        work = [(root, iter(adj.get(root, [])))]
        index[root] = low[root] = counter[0]
        counter[0] += 1
        stack.append(root)
        onstack.add(root)
        while work:
            v, it = work[-1]
            advanced = False
            for w in it:
                if w not in index:
                    index[w] = low[w] = counter[0]
                    counter[0] += 1
                    stack.append(w)
                    onstack.add(w)
                    work.append((w, iter(adj.get(w, []))))
                    advanced = True
                    break
                elif w in onstack:
                    low[v] = min(low[v], index[w])
            if advanced:
                continue
            work.pop()
            if work:
                pv = work[-1][0]
                low[pv] = min(low[pv], low[v])
            if low[v] == index[v]:
                comp = []
                while True:
                    w = stack.pop()
                    onstack.discard(w)
                    comp.append(w)
                    if w == v:
                        break
                for w in comp:
                    scc_of[w] = len(sccs)
                sccs.append(comp)

    # condensed DAG longest path
    cadj = defaultdict(set)
    for s, dsts in adj.items():
        cs = scc_of.get(s)
        if cs is None:
            continue
        for d in dsts:
            cd = scc_of.get(d)
            if cd is not None and cd != cs:
                cadj[cs].add(cd)
    indeg_c = Counter()
    for cs, cds in cadj.items():
        for cd in cds:
            indeg_c[cd] += 1
    # topological order (Kahn)
    from collections import deque
    q = deque([i for i in range(len(sccs)) if indeg_c[i] == 0])
    order = []
    while q:
        c = q.popleft()
        order.append(c)
        for cd in cadj[c]:
            indeg_c[cd] -= 1
            if indeg_c[cd] == 0:
                q.append(cd)
    dist = {i: 0 for i in range(len(sccs))}
    for c in order:
        for cd in cadj[c]:
            if dist[cd] < dist[c] + 1:
                dist[cd] = dist[c] + 1
    best = max(dist.values()) if dist else 0
    # nodes in the deepest SCC with >1 member = cycle info
    deepest = [c for c in dist if dist[c] == best]
    cyclic = [sccs[c] for c in deepest if len(sccs[c]) > 1]
    return best, sccs, cyclic


# ----------------------------------------------------------------------------
# Closure computation (Charter §3)
# ----------------------------------------------------------------------------

def build_world_state(world):
    return {
        "offices": {k: {"holder": v.get("holder"), "status": v.get("status")}
                    for k, v in world.get("offices", {}).items()},
        "parties": {k: {"leader": v.get("leader"),
                        "electoral_strength": v.get("political_profile", {}).get("electoral_strength")}
                    for k, v in world.get("parties", {}).items()},
        "legislatures": {k: {"seats": dict(v.get("seats", {}))}
                         for k, v in world.get("legislatures", {}).items()},
        "governments": {k: {"status": v.get("status"), "head": v.get("head")}
                        for k, v in world.get("governments", {}).items()},
        "government_support": dict(world.get("government_support", {})),
    }


def largest_remainder(strengths, total):
    quotas = {p: strengths[p] * total for p in strengths}
    seats = {p: int(q // 1) for p, q in quotas.items()}
    used = sum(seats.values())
    fracs = sorted([{"p": p, "frac": quotas[p] - seats[p]} for p in strengths],
                   key=lambda x: (-x["frac"], x["p"]))
    rem = total - used
    i = 0
    while rem > 0 and fracs:
        seats[fracs[i % len(fracs)]["p"]] += 1
        rem -= 1
        i += 1
    return seats


def hold_election_writes(st, rules, leg_id, etype="general"):
    """Mirror of _hold_election (political_actions.gd:343-422). Production
    writes: apply_seats writes ONLY legislatures[leg_id].seats (one node);
    apply_office_fill writes head office on succession (one node). The
    party-side 'seats' mirror is fixture-generation data that production
    code never reads (audited: political_state reads leg['seats'] only)."""
    er = rules.get("elections", {}).get(etype, {}).get("rules", {})
    pids = sorted(st["parties"].keys())          # AUDITED global loop (reads)
    total = sum(st["legislatures"].get(leg_id, {}).get("seats", {}).values())
    seats = largest_remainder({p: st["parties"][p]["electoral_strength"] for p in pids}, total)
    winner = ""
    best = -1.0
    for p in pids:
        s = st["parties"][p]["electoral_strength"]
        if s > best:
            best, winner = s, p
    writes = set()
    head_written = None
    if er.get("changes_composition", False):
        writes.add(leg_id)                        # apply_seats: one node
    if er.get("changes_head", False):
        head_office = er.get("head_office", "")
        if head_office in st["offices"]:
            out_holder = st["offices"][head_office]["holder"]
            in_holder = st["parties"][winner]["leader"] if winner in st["parties"] else ""
            if out_holder not in ("", None) and out_holder != in_holder:
                writes.add(head_office)
                head_written = head_office
    return writes, head_written


def forward_closure(adj, seeds, stop_at=None):
    seen = set(seeds)
    stack = list(seeds)
    while stack:
        cur = stack.pop()
        if stop_at and len(seen) >= stop_at:
            break
        for nxt in adj.get(cur, []):
            if nxt not in seen:
                seen.add(nxt)
                stack.append(nxt)
    return seen


def eval_closure(adj, seeds):
    """One level: nodes whose evaluations read the changed state."""
    out = set()
    for s in seeds:
        out.update(adj.get(s, []))
    return out


def compute_closures(world, rules, adj, nodes):
    """For each exercised production action: direct writes + eval-closure
    (level-1 semantic: nodes whose evaluations read the changed state) +
    full forward closure (structural, PROBE-P1 style)."""
    results = []
    legs = sorted(world.get("legislatures", {}).keys())

    # HoldElection per legislature
    per_direct, per_eval, per_struct = [], [], []
    for leg_id in legs:
        st = build_world_state(world)
        writes, _ = hold_election_writes(st, rules, leg_id)
        if not writes:
            continue
        evals = eval_closure(adj, writes)
        struct = forward_closure(adj, writes) | writes
        per_direct.append(len(writes))
        per_eval.append(len(evals) + len(writes))
        per_struct.append(len(struct))
    if per_eval:
        sv, ss, sd = sorted(per_eval), sorted(per_struct), sorted(per_direct)
        results.append({
            "op": "HoldElection (per legislature, all legs)",
            "n": len(per_eval),
            "direct_writes_median": sd[len(sd) // 2],
            "direct_writes_max": sd[-1],
            "eval_closure_median": sv[len(sv) // 2],
            "eval_closure_max": sv[-1],
            "structural_closure_median": ss[len(ss) // 2],
            "structural_closure_max": ss[-1],
        })

    # DismissOfficeholder on an occupied office (deterministic: first sorted)
    oc = sorted(o for o, v in world.get("offices", {}).items() if v.get("holder"))
    if oc:
        o0 = oc[0]
        evals = eval_closure(adj, {o0})
        struct = forward_closure(adj, {o0}) | {o0}
        results.append({
            "op": "DismissOfficeholder", "target": o0, "n": 1,
            "eval_closure": len(evals) + 1,
            "eval_nodes": sorted(evals)[:30],
            "structural_closure": len(struct),
        })

    # WithdrawSupport on first support relation
    sup = world.get("government_support", {})
    if sup:
        pid = sorted(sup)[0]
        gov_id = sup[pid]
        evals = eval_closure(adj, {pid, gov_id})
        struct = forward_closure(adj, {pid}) | {pid}
        results.append({
            "op": "WithdrawSupport", "target": pid, "n": 1,
            "eval_closure": len(evals) + 2,
            "structural_closure": len(struct),
        })
    return results


# ----------------------------------------------------------------------------
# Rules variants
# ----------------------------------------------------------------------------

def prodsem_rules(rules, world):
    """Production election semantics (data/rules/institutional_rules.json):
    changes_head=true, head_office=office_pm, electoral_authority_office=
    office_president. In fixture worlds offices are country-scoped
    (c000_office_pm), so the binding is applied per-legislature at edge
    extraction time (bind() in extract_edges) — no template coupling here."""
    r = json.loads(json.dumps(rules))
    gr = r.get("elections", {}).get("general", {}).get("rules", {})
    gr["changes_composition"] = True
    gr["changes_head"] = True
    gr["head_office"] = "office_pm"
    gr["electoral_authority_office"] = "office_president"
    r["elections"]["general"]["rules"] = gr
    r["_prodsem_note"] = ("production election semantics (changes_head=true, "
                          "office_pm/office_president); per-country binding at "
                          "extraction; see REPORT")
    return r


# ----------------------------------------------------------------------------
# Workload evidence (PF-4 pre-work — TASK-040 ticklogs, read-only)
# ----------------------------------------------------------------------------

def workload_evidence():
    out = {}
    pat = re.compile(
        r"day=(\d+) tick_us=\d+ events=(\d+) event_act=(\d+) dl_act=(\d+) queue=\d+ pa_evals=(\d+)")
    for scen in ("a", "b", "c", "d"):
        fp = os.path.join(".ai", "evidence", "tests", f"t040_scenario_{scen}_ticklog.txt")
        if not os.path.exists(fp):
            continue
        days, dl, pa, ev = [], [], [], []
        with open(fp, encoding="utf-8") as f:
            for line in f:
                m = pat.search(line)
                if m:
                    days.append(int(m.group(1)))
                    ev.append(int(m.group(2)))
                    dl.append(int(m.group(4)))
                    pa.append(int(m.group(5)))
        if days:
            out[f"scenario_{scen.upper()}"] = {
                "days": len(days),
                "deadline_activations_total": sum(dl),
                "deadline_activations_max_day": max(dl),
                "pa_evals_total": sum(pa),
                "pa_evals_max_day": max(pa),
                "events_max_day": max(ev),
            }
    return out


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

WORLDS = [
    ("production_minimal", "data/worlds/politics/batch_a_base.json",
     "data/rules/institutional_rules.json"),
    ("t040_a", "data/scenarios/t040/t040_a/worlds/politics/world.json",
     "data/scenarios/t040/t040_a/rules/institutional_rules.json"),
    ("t040_c", "data/scenarios/t040/t040_c/worlds/politics/world.json",
     "data/scenarios/t040/t040_c/rules/institutional_rules.json"),
]


def analyze(name, variant, world, rules, scoped_e7=False):
    nodes, counts = node_inventory(world)
    edges = extract_edges(world, rules, scoped_e7=scoped_e7)
    m, adj, radj = metrics(nodes, edges)
    depth, sccs, cyclic = max_causal_depth(nodes, adj)
    m["max_causal_depth"] = depth
    m["scc_count"] = len(sccs)
    m["cyclic_sccs"] = sum(1 for c in sccs if len(c) > 1)
    m["cyclic_scc_examples"] = [c[:8] for c in cyclic[:3]]
    closures = compute_closures(world, rules, adj, nodes)
    return {
        "world": name, "variant": variant,
        "node_counts": counts,
        "node_types": dict(Counter(n["type"] for n in nodes.values())),
        "metrics": m,
        "closures": closures,
        "edges_dump": (edges if len(edges) <= 2000 else
                       f"[{len(edges)} edges — first 300 in edges_sample]"),
        **({"edges_sample": edges[:300]} if len(edges) > 2000 else {}),
    }


def main():
    root = os.path.abspath(os.path.join(HERE, "..", ".."))
    os.chdir(root)
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(LOG, exist_ok=True)

    summary = []
    for name, wpath, rpath in WORLDS:
        if not os.path.exists(wpath):
            print(f"skip {name}: missing {wpath}")
            continue
        w = load_json(wpath)
        rules = load_json(rpath)

        variants = [("aswired", rules, False)]
        if name != "production_minimal":
            variants.append(("prodsem", prodsem_rules(rules, w), False))
            variants.append(("prodsem_scopedE7", prodsem_rules(rules, w), True))
        for vname, vrules, scoped in variants:
            res = analyze(name, vname, w, vrules, scoped_e7=scoped)
            fp = os.path.join(OUT, f"{name}__{vname}.json")
            with open(fp, "w", encoding="utf-8", newline="\n") as f:
                json.dump(res, f, indent=1, ensure_ascii=False)
            m = res["metrics"]
            row = {
                "world": name, "variant": vname,
                "nodes": m["nodes_total"] if "nodes_total" in m else res["node_counts"],
                "edges": m["edges_total"],
                "cross_country": m["cross_country_edges"],
                "components": m["components"], "largest": m["largest_component"],
                "depth": m["max_causal_depth"],
                "out_max": m["out_degree_max"], "in_max": m["in_degree_max"],
                "static": m["edges_static_rule"], "dyn": m["edges_dynamic_state"],
            }
            summary.append(row)
            print(f"{name}/{vname}: edges={m['edges_total']} "
                  f"cross={m['cross_country_edges']} comps={m['components']} "
                  f"largest={m['largest_component']} depth={m['max_causal_depth']} "
                  f"cycSCC={m['cyclic_sccs']} out_max={m['out_degree_max']} "
                  f"in_max={m['in_degree_max']}")

    wl = workload_evidence()
    with open(os.path.join(OUT, "workload_evidence.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(wl, f, indent=1, ensure_ascii=False)
    with open(os.path.join(OUT, "summary.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(summary, f, indent=1, ensure_ascii=False)
    print("\nworkload:", json.dumps(wl)[:300])
    print("done — results in", OUT)


if __name__ == "__main__":
    main()
