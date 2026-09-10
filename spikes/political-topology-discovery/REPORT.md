# POLITICAL TOPOLOGY DISCOVERY — REPORT (2026-09-10)

Per CHARTER.md v1.0 (+ amendment A1) — read-only discovery from production code/data.
No engine files touched; no benchmark run; no architectural verdicts.
All numbers below are machine-verified against raw JSONs by `verify_report.py` (log: `logs/verify_report.log`).

---

## 0) Scope recap (what was measured and from where)

Political runtime as it exists TODAY in code (TASK-039/040 Batch-A v0):
`scripts/politics/` (1,052 lines fully audited) + political handlers in
`scripts/game_event_handlers.gd` + institutional rules + 3 political worlds
measured (1 production minimal, 2 TASK-040 fixtures @ 200 countries; t040_c
adds the 120-governed high-density regime; t040_b/t040_d/​t040_a10 share
t040_a's structure at lower governed counts and were skipped as redundant —
same generator, same shell structure).

**Variants measured per world:**
- `aswired` — fixture election wiring verbatim (changes_head=false in fixtures)
- `prodsem` — production election semantics (changes_head=true, head=office_pm,
  auth=office_president, bound per-country)
- `prodsem_scopedE7` — prodsem + E7 quota loop counterfactually restricted to
  same-country parties (isolates the audited global-parties loop)

**Charter amendment A1 (frozen before this report):** every metric is reported
for (a) the FULL semantic graph and (b) the ACTIVE subgraph — edges whose
source state actually has a production writer (`apply_office_fill/vacate`,
`apply_seats`, `apply_government_status`, `apply_support/withdraw`, government
formation). Edges whose source state has NO production writer today
(`electoral_strength`, party `leader`, legislature `dissolved`, static rule
tables) are LATENT: real read-paths, behaviorally dormant — no propagation can
ever travel them today. This distinction emerged from verifying the numbers
and is part of the method, not a result filter.

---

## 1) Node inventory (200-country fixture; production minimal world in parens)

| Node type | Count | Mutable state read in production semantics |
|---|---|---|
| Office | 600 (3) | holder, status |
| Party | 800 (3) | leader, electoral_strength, seats mirror* |
| Legislature | 200 (1) | seats, procedural_state.dissolved |
| Government | 30 (t040_a) (0) | status, head, officeholders[] |
| Character — **excluded (identity-only)** | 1,800 (5) | none read by any production path |
| Histories/Bills/Deadlines — excluded (records) | runtime | append-only |

*party "seats" mirror is fixture-generation data; production code reads
`legislatures[leg].seats` only (audited: political_state.gd:80-95).

**Total mutable-state nodes: 1,630 (t040_a) · 7 (production minimal).**
Node-state audit confirms characters are topologically inert: `load_from`
strips them to `{"character_id"}`, and `party_of_leader`/`head_government`
read `parties[p].leader` / `governments[g].head`, never character records.

---

## 2) Edge inventory (Charter §2 — audited read-paths E1-E10)

### t040_a, full semantic graph (aswired)

| Edge type | Count | Carrier state | Active today? |
|---|---:|---|---|
| E1 appointing_authority (office→office) | 400 | office.holder | ✔ active |
| E2 dismissible_by (office→office) | 600 | office.holder | ✔ active |
| E3 party.seats→leg totals | 800 | legislature.seats | ✔ active |
| E3 leg→gov formation/tallies | 30 | legislature.seats | ✔ active |
| E4 gov.status→support eligibility | 120 | government.status | ✔ active |
| E5 government_support | 0 (no support relations in any world — see A-4) | government_support | n/a |
| E7 strength→seat quota (global loop) | 160,000 | party.electoral_strength | ✖ **latent** |
| E8 term wiring (time-gated) | 30 | legislature rules (static) | ✖ latent (rule, not state) |
| E9 head resigns eligibility | 30 | government.head | ✔ active |
| **Total (aswired)** | **162,010** | | **1,980 active · 160,030 latent** |

With production election semantics (prodsem) two active edge families appear:
E6 electoral_authority gate (leg←office_president, 200) and E6 head_office
succession (leg→office_pm, 200) — both carried by office.holder/leg.seats
(writable). Totals: **prodsem 162,410 (2,380 active) · scopedE7 3,210 (2,380
active, 830 latent).**

### Static-rule vs dynamic-state (Charter field)

| Variant | static-rule | dynamic-state |
|---|---:|---:|
| Full aswired | 1,030 (0.64%) | 160,980 (99.36%) |
| Full prodsem | 1,430 (0.88%) | 160,980 |
| ACTIVE aswired | 1,000 (50.5%) | 980 (49.5%) |
| ACTIVE prodsem | 1,400 (58.8%) | 980 (41.2%) |

The full graph's near-total "dynamic" mass is the latent E7 loop. In the
active subgraph the split is roughly half rule wiring / half live state.

---

## 3) Degree / hub / depth / component profile (Charter fields)

### t040_a — ACTIVE subgraph (what can actually propagate today)

| Metric | aswired | prodsem | prodsem_scopedE7 |
|---|---:|---:|---:|
| Active edges | 1,980 | 2,380 | 2,380 |
| Mean out-degree | 1.57 | 1.66 | 1.66 |
| P95 out-degree | 3 | 4 | 4 |
| **Max out-degree** | **5** | **5** | 5 |
| Mean in-degree | 2.64 | 3.17 | 3.17 |
| **Max in-degree** | **4** | **5** | 5 |
| Hubs (in-degree ≥ 20) | **0** | **0** | 0 |
| **Max causal depth (DAG)** | **2** | **3** | 3 |
| Cyclic SCCs | 0 | 30 (2-node: office↔office pairs via E1/E2 both directions) | 30 |
| Connected components | 400 | 200 | 200 |
| **Largest active component** | **6** | **9** | 9 |
| **Cross-country active edges** | **0** | **0** | **0** |

### Full semantic graph (reference — includes the 160K latent E7 mass)

| Metric | aswired | prodsem | prodsem_scopedE7 |
|---|---:|---:|---:|
| Edges | 162,010 | 162,410 | 3,210 |
| Max out-degree | 201 | 201 | 5 |
| Max in-degree | 805 | 806 | 10 |
| Max causal depth | 2 | 4 | 3 |
| Components | 201 | **1 (giant: 1,630 nodes)** | 200 |
| Largest component | 1,030 | **1,630** | 9 |

### Production minimal world (batch_a_base, aswired)

Nodes 7 · active edges 10 · depth 3 · 1 component (all 7 nodes) · max
in-degree 7 (parliament_H) — a single-country shell, exactly the per-country
structure below at N=1.

### t040_c (120 governed — highest fixture density)

Active edges 2,520 (aswired) / 2,920 (prodsem) · largest active component
6-9 · depth 2-3 · cross-country active **0**. Identical structural profile
to t040_a: adding 90 more governments scales the graph **linearly
(+edges), not structurally** — no new hubs, no deeper chains, no coupling.

### Per-country subgraph (Charter addition)

- Mean 7.0 nodes/country · 9.0 active edges/country (prodsem) — uniform
- **Every active component is exactly one country's political shell**
  (prodsem: 200 components = 200 countries of 9 nodes; aswired: 400 = each
  country split into an office-shell and a leg-gov pair because fixtures
  don't wire composition→government)
- Top active in-degree nodes: legislatures (in 5: 4 seat-writes + head
  succession), office_pm/office_finance (in 3: authority gates),
  office_president (in ≤4)
- **No PROBE-P1-style hub exists** (max active in-degree = 5 vs the 805 of
  the latent E7 mass)

---

## 4) Closures (Charter §3 — measured per production operation)

### HoldElection — one election in one country (production semantics, prodsem)

| Measure | ACTIVE graph (today's reality) | FULL graph (if every read-path could carry) |
|---|---:|---:|
| Direct writes (apply_seats [+ office_fill on succession]) | 1 (median) | 1 |
| Eval closure (level-1: whose eligibility reads changed) | median 2 · max 3 | median 2 · max 4 |
| **Structural closure (PROBE-P1 dirty-marking)** | **median 3 · max 8** | median 3 · **max 750** |

The max-8 chain is the complete causal spine of the domain:
```
election → leg.seats (write) → office_pm.holder (succession write)
→ office_finance eligibility (E1/E2) → gov (E3) → 4 parties (E4)
= {leg, pm, finance, gov, 4 parties} = 8 nodes, depth 3, one country
```
**8 nodes = 0.49% of the 1,630-node political world.** (Median 3 = the common
case where office_pm is vacant: {leg, pm, gov}.)

The full-graph 750 is what a naive structural propagator would visit through
the latent E7 mass (leg→gov→parties→[E7]→all 200 legs→…). It cannot happen
today because nothing writes party strength — but it is the exact number that
becomes live the day a writer for `electoral_strength` appears (see A-1).

### DismissOfficeholder (c000_office_president, prodsem)

Direct writes 1 · eval closure 4 (pm + finance re-appoint/dismiss rights +
leg authority gate) · structural 4.

### WithdrawSupport

0-op in all worlds — no fixture populates `government_support` (see A-4).
Recorded honestly as unexercised; E4 wiring edges (120) are counted but this
path's closure is unmeasured.

### Election → Head chain (PF-2/PF-3 question)

The full production chain exists, is deterministic, and is strictly local:
HoldElection → seats → global-strength winner → succession → office_pm →
downstream authorities — **closure 8 nodes, depth 3, one country.**

---

## 5) Anomaly register (all discoveries, quantified)

### A-1 — `_hold_election` global parties loop (political_actions.gd:357-393): LATENT coupling, not active

The quota/winner loops iterate ALL 800 parties regardless of legislature's
country. Today: **zero cross-country active edges** (measured, all worlds and
variants) because nothing writes `electoral_strength` — party strength is
fixture-constant. The moment ANY writer to party strength ships (campaigns,
polls, ideology drift, coup-reshaped parties), every election everywhere
re-reads every party: the active graph jumps from 2,380 edges / 200 isolated
9-node shells to a **1,630-node giant with max in-degree 806**, and one
election's structural closure becomes 750. The scoped counterfactual
(same-country quota loop) shows the identical semantics today at 3,210 edges
(**50.6× lighter graph**) — but it is a production code change, i.e. the
owner's decision. This discovery documents; it does not decide.

### A-2 — fixture vs production election wiring divergence

Fixtures wire `changes_head=false` + open electoral authority (deadline-chain
controllability); production rules wire `changes_head=true`,
`head_office=office_pm`, `electoral_authority_office=office_president`.
Topology impact: aswired = 400 components / depth 2; prodsem = 200 components
of exactly 9 / depth 3. Any future PF-PROBE must run on prodsem semantics.

### A-3 — "political" events bypass PoliticalState entirely

Coup_Attempt / Minister_Died / Election handlers write
`WorldState.countries[cid].stability` (strategic layer) and never read or
write PoliticalState. The TASK-040 event streams exercise ZERO
political-state propagation. PoliticalState's only live integration points
today: government-term wiring (E8) and the deadline pump — both scheduled,
zero per-tick evaluation. A PF-PROBE must inject changes via
PoliticalActions/deadline payloads (as TASK-040's chain does), not via events.

### A-4 — `government_support` empty in every world

SupportGovernment/WithdrawSupport edges (E5) and support-eligibility gates
(E4) are wired but unexercised: no world populates the support map. Closures
on those paths are unmeasured. A PF-PROBE fixture MUST include support
relations or these paths remain dark.

### A-5 — cyclic SCCs (30 two-node office pairs, prodsem)

E1/E2 wiring creates mutual-read office pairs (pm→finance via appoint,
finance→pm? no — president↔pm via dismissible_by + appointing_authority).
These are 2-node evaluation cycles, harmless for dirty-marking (no state
cycle: holder writes flow one way), but an incremental implementation must
handle them (visit-once semantics), as PROBE-P1's generation-stamping already
does.

---

## 6) Workload evidence (PF-4 pre-work — TASK-040 ticklogs, read-only)

| Scenario | Days | Deadline activations (total / max-day) | PA evals (total / max-day) |
|---|---:|---:|---:|
| A (30 governed) | 90 | 60 / 20 | 30 / 20 |
| B (15 crisis) | 90 | 30 / 9 | 15 / 9 |
| C (120 governed) | 90 | 240 / 64 | 120 / 64 |
| D (45 gov + 15 crisis + 30 bg) | 120 | 75 / 25 | 45 / 25 |

Realistic regime: **tens of political actions per day at N=200 countries**
(peak measured: 64 deadline activations + PA evals in one day in Scenario C).
With per-country 9-node active shells and zero cross-country edges, even the
peak day is 64 disjoint ≤8-node closures ≈ ≤512 node-visits vs 1,630 for a
full recompute. PROBE-P1's saturation regime
(uniform ≥0.1% changes saturating a random DAG's giant component) is
**structurally unreachable here**: the active graph is 200 disconnected
9-node components, so change density accumulates additively, never cascades.

---

## 7) Answers to the owner's five questions (PF-1..PF-5, discovery-grade)

**PF-1 — What is the real political topology?**
Tiny and strictly local. 1,630 mutable-state nodes @200 countries; mean 7
political nodes/country. Active semantic graph: 1,980-2,920 edges; mean
out-degree 1.57-1.66; max out-degree 5; max in-degree 5; **no hub ≥20**;
max causal depth 3; 200-400 disconnected components, largest 9 nodes; zero
cross-country active edges. The 160K-edge E7 mass is latent (read-path only,
no writer).

**PF-2 — What happens on one real political change?**
An election (production semantics) writes 1-2 nodes; structural closure
**median 3, max 8 nodes (0.49% of the world), depth 3, never leaves its
country**. A dismissal: closure 4. The domain is the opposite of
"highly connected": it is 200 mutually-isomorphic 9-node shells.

**PF-3 — What happens on a real chain?**
The Election→Officeholder→Authority→Eligibility chain is live in production
semantics: 3 hops, 8 nodes, deterministic, one country. Indexed propagation
(8 nodes) vs full recompute (1,630) is a **~204× structural work ratio** —
before any runtime measurement. (At today's scale both are trivially fast in
absolute terms; the ratio is what matters for architecture.)

**PF-4 — What happens at higher change density?**
Peak measured density (20 deadline-activations/day) = 20 disjoint closures =
160 node-visits. Because components are disconnected, density scales the work
additively — the break-even (whole-world closure) is unreachable by change
count alone. It would require either (a) a party-strength writer activating
the E7 giant (closure 750 from one election), or (b) future cross-country
features (alliances/unions) that don't exist in the domain yet.

**PF-5 — Does the political topology justify the general abstraction?**
Discovery-grade answer, three honest layers:
1. **Topology-wise, the domain is in C2's ideal regime** — tiny closures
   (3-8), shallow depth (≤3), no hubs, per-country isolation, reverse index
   would cost ~57KB (2,380 edges × 24B). If derived-state caching is ever
   adopted, PROBE-P1's measured mechanism applies directly.
2. **But today the runtime has zero derived state** — everything is on-demand
   (J-acceptance: 0 per-tick political evaluations). There is nothing to
   maintain incrementally; C2 has no current job to do in this domain.
3. **The one real risk found is latent, not active**: the global parties loop
   (A-1) is a 160K-edge giant waiting for its first writer. The domain's
   future topology depends more on that single code-shape decision than on
   anything measured here.

Whether a functional probe is commissioned, and whether the E7 loop is scoped,
are owner decisions. The numbers above are the input, not the decision.

---

## 8) What this discovery does NOT establish (Charter §6)

- No performance numbers (no benchmark ran; runtime never measured).
- No architectural verdict, no adoption recommendation.
- Batch-A v0 only: coalitions, factions, intra-party politics, cross-country
  alliances would materially change the topology. "200 shells of 9 nodes"
  describes the current domain, not its destination.
- The E7 scoping question is documented, not decided.
- Nothing here enters the acceptance chain; zero production files changed.

## 9) Artifacts

- `CHARTER.md` v1.0 + amendment A1 — frozen definitions (commit 198fdd0a)
- `extract_topology.py` — semantic graph extraction + closures (read-only)
- `active_subgraph.py` — active/latent split, dual-graph metrics + closures
- `verify_report.py` — every number in this report re-checked against raw
  JSONs (log: `logs/verify_report.log`)
- `results/*.json` — raw per-world/variant data (full + active views)
- `logs/` — all runs kept, including the buggy tool iterations (runs 1-4
  are superseded; the reported numbers are from the final run — honest
  record of the tool's own discovery process)
