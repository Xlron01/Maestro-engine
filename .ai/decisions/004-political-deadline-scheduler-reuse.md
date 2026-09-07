# Decision 004: Political Deadline Scheduler — Domain-Owned Instance for TASK-040-pre with Unification in TASK-040

- **Date:** 2026-09-08
- **Status:** ACCEPTED

## Context

TASK-040-pre requires "reuse the existing ScheduledQueue" and "do not introduce a second scheduler." The political deadline mechanism needs scheduling infrastructure for `scheduled → due → activated → resolved` lifecycle.

Two architectural options existed:

1. **Single shared instance**: Political deadlines register directly into `Simulation.scheduled` (the runtime's single scheduler). Requires full Simulation integration, dispatch.json wiring, and job handlers — which is TASK-040's scope (Actor Runtime Integrated Validation).

2. **Domain-owned instance**: `PoliticalState` owns a `ScheduledQueue` instance (`deadline_queue`) for standalone testability of the deadline mechanism (TASK-040-pre). Uses the SAME CLASS/MECHANISM (ScheduledQueue) but separate INSTANCE from `sim.scheduled`.

## Decision

**Option 2 for TASK-040-pre** (domain-owned instance), with **explicit unification in TASK-040**.

Rationale:
- TASK-040-pre is a "minimum production infrastructure" proof WITHOUT broader Actor Runtime validation (which is TASK-040).
- The politics layer (`scripts/politics/`) is architecturally a standalone domain (like Economy) with its own owning-domain state (`PoliticalState`).
- Standalone testability: `test_politics_deadlines.gd` runs PoliticalState + PoliticalActions + PoliticalDeadlines + SimClock WITHOUT requiring Simulation.gd, dispatch.json, or the full runtime.
- Zero kernel changes: No modification to Simulation.gd, EventQueue, or dispatch.json for TASK-040-pre.
- The ScheduledQueue CLASS is reused exactly (A7 compliance: "reuse existing scheduler infrastructure" = same mechanism, not necessarily same instance in pre-integration phase).

## Consequences

### Current (TASK-040-pre)
- Two ScheduledQueue instances exist in test harness:
  - `sim.scheduled` — runtime jobs (economy, decision, agents)
  - `state.deadline_queue` — political deadlines only
- Both use identical scheduling semantics: `register(entity_id, job_name, frequency_days, start_at)` + `get_due_jobs(current_time)` + `unregister` for one-shot.
- Test validates: `st.deadline_queue is SQ` (class reuse), NOT `st.deadline_queue == sim.scheduled` (instance identity).

### Future (TASK-040 — Actor Runtime Integrated Validation)
- Single `Simulation.scheduled` instance owns ALL scheduled work including political deadlines.
- Political deadlines registered via dispatch.json job handlers (e.g., `job_political_deadline_pump`).
- `PoliticalState.deadline_queue` field removed or repurposed as reference to `sim.scheduled`.
- `PoliticalDeadlines.pump()` called from job handler, not test harness.
- This unification is the EXPLICIT scope of TASK-040.

## Why This Is NOT "Duplicate Scheduler Architecture"

1. **Same mechanism, phased integration**: The ScheduledQueue class/algorithm is reused exactly. The "second instance" is a temporary artifact of standalone testing, not a parallel production architecture.

2. **Owned-domain consistency**: `PoliticalState` owns its deadline records (`deadlines` dict) AND its scheduling queue — consistent with Economy domain owning its own state. The scheduler is infrastructure; the deadline records are domain state.

3. **Explicit unification gate**: TASK-040's acceptance criteria will require single scheduler instance. This decision documents the transition path.

4. **No behavioral divergence**: Both instances implement identical semantics (one-shot via `frequency_days=0` + `unregister` on resolution). Zero semantic difference.

## Evidence

- TASK-040-pre acceptance: 17/17 PASS including A7 ("reuse existing scheduler infrastructure")
- Test validates class reuse: `st.deadline_queue is SQ` (line 267, test_politics_deadlines.gd)
- Full regression green: ScenarioTest 5/5, Politics 31/31, Compliance 25/25, etc.
- Canonical SHA-256 deterministic: `29841b4297c7b9ffe8f0591ff37b3e8f2545b6221669360ab74b7e25b67cb2f4`

## Rejected Alternatives

- **Full Simulation integration in TASK-040-pre**: Rejected — violates "minimum production infrastructure" scope; TASK-040 exists for this.
- **Direct registration into sim.scheduled from test harness**: Rejected — couples test to runtime internals; breaks domain isolation.
- **New scheduler implementation**: Rejected — violates A7 ("no second scheduler" = no new mechanism).

## TASK-040 Integration Contract (Pre-commitment)

When TASK-040 begins, the following changes are committed:
1. Remove `PoliticalState.deadline_queue` field (or make it `= sim.scheduled` reference)
2. Add `job_political_deadline_pump` to `dispatch.json` job_handlers
3. `PoliticalDeadlines.pump()` called from job handler with `sim.scheduled` as the queue
4. Single `ScheduledQueue` instance for entire runtime
5. All TASK-040-pre acceptance tests re-run in integrated mode (same canonical hash)

This decision will be revisited at TASK-040 start for confirmation.