# TASK-040 — Actor Runtime Integrated Validation Benchmark — Design (v1, pre-implementation)

- **Date:** 2026-09-09
- **Status:** PROPOSED (awaiting owner ratification alongside results — evidence-first delivery)
- **Baseline commit:** `bf2ea5b4` (A10 integration accepted; rejected successor `ee98f568` is out of scope)
- **Worktree:** `C:/Users/ahmed/orca/workspaces/maestro engine/siren` @ branch `t040-full-benchmark`

## 0. Objective (frozen from owner spec)

Validate the integrated Actor Runtime (production `Simulation.run_step()` → `sim.scheduled`
→ `job_political_deadline_pump` → `PD.pump_integrated` → `PoliticalActions.execute` →
Owning Domain) under deterministic mixed event/deadline workloads at N=200 countries,
and determine whether the architecture survives contention, preserves correctness,
avoids starvation/hidden polling. NOT a redesign of Runtime/Scheduler/EventQueue.
Political periodic reassessment remains deferred (out of scope).

## 1. Fixture architecture (data-only, zero engine semantics)

Five independent fixture trees under `data/scenarios/t040/`, each a COMPLETE world
(N=200 countries, k=4 parties/country, 1 legislature, 3 offices, 8 characters) plus
per-scenario political activity injected at load:

| Tree | Scenario | Political spec (governments are always static-in-fixture) |
|------|----------|----------------|
| t040_a10 | A10 minimal | 1 government (proof of full production chain) |
| t040_a | A Normal | 30/200 (15%) politically active (30 governments with terms) |
| t040_b | B Regional | 15 affected by crisis events (15 governments + crisis events on them) |
| t040_c | C Global | 120/200 (60%) activation pressure (120 governments + global events) |
| t040_d | D Stacked | 15 crisis-active + 30 independent background-active + 170 quiet + deadline activity |

Each tree contains:
- `rules/politics.json` — production copy (unchanged semantics)
- `rules/institutional_rules.json` — GENERATED (all 200 legislatures term-limited; only
  the legislatures of politically-active countries get `term_expiration_causes_election: true`)
- `scenarios/default/events.json` — deterministic seeded crisis/background event stream
- `worlds/politics/world.json` — political world file with 200 countries' entities;
  governments INCLUDED AS DATA (so `schedule_term_integrated` registers on `sim.scheduled`
  at init — no runtime composition needed)
- `countries/<id>/country.json` — 200 strategic-layer countries
- `provinces/` — EMPTY (no provinces in benchmark world; produces zero provinces —
  Railway_Damaged event type will simply not be used)

Generation: `scripts/t040_worldgen.py` (deterministic, seeded, no RNG beyond one
explicitly-seeded `random.Random(TREE_SEED)`); the political world file with the
deterministic seat allocation computed by Python largest-remainder (same algorithm as
`_hold_election`); **all fixture content clearly labelled TEST FIXTURE — not game-balance.**

**Seeding model (v1):** `TREE_SEED` differs per tree (A10=101040, A=40140, B=40240,
C=40340, D=40440); sim RNG seed = 12345 (production default). The tree seed controls
which countries are active, event timing/targeting, term lengths, crisis severity —
all via Python `random.Random(TREE_SEED)` with all draws logged in the manifest for
reproducibility. Same tree seed → byte-identical fixtures → identical benchmark run.

**Why static governments (design note):** Governments are placed as data in the
political world file, not formed at runtime via FormGovernment, because at baseline
`bf2ea5b4`, `FormGovernment` registers the term deadline on `state.deadline_queue`
(domain queue), while the integrated pump reads `sim.scheduled` — an A10 wiring gap
for runtime-formed governments. Static-in-fixture governments route through
`_schedule_existing_political_terms()` → `PD.schedule_term_integrated(sim.scheduled, …)`
which is the production path. This is an **evidence report item**, not a design change.

**Institutional rules injection:** `InstitutionalRules.load()` reads a hard-coded
`res://` path; the fixture trees are therefore self-contained (each tree carries its
own generated `rules/institutional_rules.json`), loaded at runtime by the harness
pattern already established at baseline (`rules.raw = parsed` injection after
`IR.load()`, as done by `test_politics_benchmark.gd` and `test_politics_deadlines.gd`).
No production file is touched.

## 2. Engine touch (single content-layer touch, Decision-004-compliant)

`scripts/game_event_handlers.gd` — ENGINE TOUCH #5 (same additive, delegation-only
pattern as touches #1/#3/#4):
- `_load_political_state()`: when `data_root_override` points to a fixture TREE
  (directory containing `worlds/politics/world.json`), load the political world from
  `<root>/worlds/politics/world.json` and the institutional rules from
  `<root>/rules/institutional_rules.json`. Default production behaviour unchanged.
- `PD._activate` currently calls `PD.schedule()` (standalone) for the derived
  `election_due` deadline → registers on `state.deadline_queue`, INVISIBLE to
  `pump_integrated` (which reads the passed scheduler only) → **derived election
  deadlines would be silently missed in the integrated path (A4 violation)**.
  Fix per Decision 004 pre-commitment ("single `Simulation.scheduled` instance owns
  ALL scheduled work"): pass the scheduler through `_pump_internal → _activate` and
  use `schedule_integrated` for the derived deadline. Standalone tests unaffected
  (they pass `state.deadline_queue` as the scheduler, so their queue semantics are
  identical). This is the documented TASK-040 Integration Contract item 1/3 of
  Decision 004, not a redesign.

No other engine files are touched. `Simulation.gd`, `ScheduledQueue.gd`,
`EventQueue.gd`, `ActivationSet.gd`, `SimClock.gd`, politics modules other than
the `_activate` scheduler parameter, compliance modules: untouched.

## 3. Harness — `scripts/test_t040_benchmark.gd`

Order (owner-mandated): **A10 gate first**, then A → B → C → D.

- **P0 Fixture integrity** (per tree, static): 200 countries everywhere; entities
  self-consistent (every party leader/office holder/character referenced exists;
  seats sum = declared total; governments reference existing legislatures; events
  reference existing countries; activation-class mix matches scenario spec; seed
  labels present; tree manifest matches.
- **P1 A10 gate (t040_a10)**: single government, term=30 days, term→election rule on.
  Must observe, via the PRODUCTION PATH ONLY (a single `sim.run_step()` loop, no
  manual `get_due_jobs`/`pump` calls from the harness): pump fires every day;
  term deadline due at day 30; derived election deadline created through rule
  evaluation; `HoldElection` executed via pipeline; deadline resolved;
  election result recorded. All counters from `political_counters`. **A10 FAIL
  blocks everything (report STOP).**
- **P2 Scenarios A→B→C→D**, each: init with tree as data root → injection of
  institutional rules → run horizon (D: 120 days) → collect all metrics:
  - Runtime: total us, mean/peak tick us, activation latency (day-of-activation −
    day-of-trigger)
  - Activation: event activations, deadline activations, completed, deferred,
    missed — per activation class (deadline vs event)
  - Evaluation: evaluations/tick, total evaluations (PA.eval_count, CQ.eval_count),
    active/total actors ratio
  - Events: generated, consumed, relevant, filtered (via activation_log)
  - **Fairness (Scenario D especially)**: maximum observed wait (per activation
    class), deadline lateness (max/mean), deadline misses (count), per-class
    completion counts
  - Resources: static memory before/after, scheduled queue size/pressure peak
  - **Per-tick raw log**: day, events due/processed, activations by class,
    deadlines due/activated/resolved, queue sizes, PA/CQ eval deltas — written to
    `.ai/evidence/tests/` as raw text.
- **P3 Determinism oracle**: for each scenario, run twice from fresh init; canonical
  snapshot (semantic state only: clock, world countries/provinces/agencies/agents,
  political state to_dict, scheduled jobs, events remaining) via `CT.canonical`
  (sorted keys) → SHA-256. Assert `hash1 == hash2`, assert 64-hex length,
  `is_valid_hex` format check. **Hash length AND format are checked before display.**
- **P4 Performance characterization (diagnostic only)**: report the numbers above,
  plus derived diagnostics (evaluations/tick, active/total ratio, queue pressure,
  nonlinear burst scaling vs scenario scale). NO pass/fail thresholds on timing.

Acceptance mapping (A1–A10 → checks): A1 canonical mismatch (P3), A2 determinism
mismatch (P3), A3 required event activation lost/incorrect (P2 event activations
must equal events due, with per-event-target activation), A4 required deadline
missed (P2 deadline completion), A5 duplicate/lost activation (P2 dedupe counters),
A6 deterministic ordering violation (P3 hash equality across runs, plus event-log
seq monotonicity), A7 starvation under defined semantics (P2 fairness: deadline
work must complete by horizon; event work within horizon or explicitly
deferred/cancelled with semantics; per-class completion), A8 hidden per-tick
political polling (PA.eval_count delta over quiet ticks must be 0 in the
non-deadline quiet segment; documented), A9 crash/OOM/runtime integrity (P2
completion + explicit error scan), A10 political deadlines through
`Simulation.scheduled` production path (P1 gate).

Starvation semantics (owner-frozen v1): deadline work = FAIL if still due but
unactivated at horizon. Event work = must execute within horizon or be
deferred/cancelled with explicit semantics (v1: all events scheduled within
horizon, so none may be silently dropped). Political periodic = no criterion
(deferred).

## 4. Regression suite (post-benchmark)

TASK-040-pre deadlines (17/17), Politics Batch A (31/31), ScenarioTest (5/5),
D1 (28/28), Model v1 (7/7), Economy phase1+2, Compliance (25/25),
`python scripts/validate_memory.py`. All logs saved under `.ai/evidence/tests/`.

## 5. Deliverables

1. `scripts/t040_worldgen.py` + generated trees + `manifest.json` per tree
2. `scripts/t040_verify_fixture.py` (static verification, CI-able)
3. `scripts/test_t040_benchmark.gd` (the harness)
4. Raw per-tick logs + benchmark report under `.ai/evidence/tests/`
5. Memory docs update (state.md, tasks/active.md, handoffs/latest.md, CHANGELOG)
6. NO COMMIT until Ahmed reviews and explicitly approves (per handoff instructions;
   the local handoff says "متعملش commit نهائي ولا تنتقل لأي حاجة تانية قبل ما أحمد يراجع ويوافق صراحة")
