# Maestro Engine

## English

**Maestro Engine** is a data-driven game engine specialized for **Grand Strategy** games (in the style of Paradox titles like HoI4 / Victoria series), built on **Godot 4** (GDScript).

### Core Vision

This project started as a mod for HoI4 (Millennium Dawn). After long discussions, the real goal emerged: **build a specialized engine for Grand Strategy games** — not a general engine like Unity/Unreal (impossible for a small team), but like **Paradox's Clausewitz**: an engine built for one game genre, reusable across multiple different games.

The goal is **not real AI (LLM/ML)** — the goal is a smarter layer than currently exists, using simple weighted equations (Utility AI) instead of random decisions, without sacrificing performance, but **improving** it.

### Current Status (as of TASK-039 Batch A, 2026-09-07)

- **"First Working Engine" milestone: PASSED** — all 5 acceptance criteria verified and sealed in `acceptance_report.md` (external-data game, two rules through one weighted-equation mechanism, save/load, zero domain names in engine core, full determinism).
- **10 roadmap phases complete** (`00-خطة-الطريق.md`): kernel prototype → content contract → simulation lifecycle + scenario tests → second decision rule (Coup Risk) → engine/content audit → acceptance → intelligence capability → derived importance (21/21) → world-sensitivity Test B (14/14) → structural emergence Test C (14/14) → core purification (all domain logic moved out of `Simulation.gd` into data + content handlers, behavior-equivalent to the checksum anchor).
- **Latest milestone: TASK-039 Political Institutional Core — Batch A** (COMPLETE PROVISIONAL, awaiting owner seal): 5 political models, 12 actions through a unified action pipeline, history contracts, data-driven institutional rules — 31/31 acceptance tests PASS, benchmark N=100 countries / 1100 actions / 330µs per action / **zero per-tick political evaluations**.
- **Full regression suite K green** across every suite (see below).
- Recent major tasks before that: TASK-038 Compliance Runtime Layer (25/25), T5-C scheduler storm root-cause fix, T4.5 scale optimization, T3 economy representability + feedback.

### What's Inside

| Layer | What it does |
|---|---|
| **Simulation Core** | `SimClock`, `EventQueue`, `ScheduledQueue`, `ActivationSet`, `WorldState` — event-driven, selectively-activating (idle entities cost nothing), deterministic (seeded RNG, bitwise-reproducible) |
| **Content Contract** | `ContentSchema` + `ContentLoader` — JSON content with schema validation, typed fields, clear errors; adding content requires zero code changes |
| **Decision Layer** | Utility-AI weighted equations (`evaluate_weighted_score`) shared by all decision rules — every numeric parameter lives in `data/rules/*.json`, never in code |
| **Derived Importance** | Entity importance derived from world state + dependency network alone (no hand-written values) — identity-blind (proven bitwise by name-swap tests) |
| **Economy Layer** | Representability gate + feedback economy (`economy/`) |
| **Compliance Runtime** | On-demand feasibility / resistance / influence / legitimacy queries over `control_chains` + `social_relations` (no per-tick polling) |
| **Political Layer** | PoliticalOffice / PoliticalParty / Legislature / Government / Election models + 12 institutional actions + election/succession/regime history contracts |
| **Dispatch Registry** | `data/rules/dispatch.json` + content-handler scripts — the engine core stays a generic dispatch machine with zero domain names |
| **Serialization** | Unified save/load (games, scenarios, tests) with `SAVE_VERSION` guard and RNG-state-safe JSON round-trip |

### Quick Start

Requirements: **Godot 4.7+** (on Windows, the console binary is recommended). No other dependencies — content is plain JSON.

From the repo root, run the regression suites headless:

```
godot --headless --script scripts/ScenarioTest.gd
```

| Suite | Script | Last result |
|---|---|---|
| Scenario tests (determinism, save/load, checksum anchor) | `scripts/ScenarioTest.gd` | 5/5 PASS |
| Decision boundary (Model v1) | `scripts/test_d1_decision_boundary.gd` | 28/28 PASS |
| Model v1 integration | `scripts/test_model_v1_integration.gd` | 7/7 PASS |
| Economy Phase 2 | `scripts/test_t3_economy_phase2.gd` | 14/14 PASS |
| Compliance runtime | `scripts/test_compliance_runtime.gd` | 25/25 PASS |
| Politics Batch A (TASK-039) | `scripts/test_politics_batch_a.gd` | 31/31 PASS |
| Politics benchmark | `scripts/test_politics_benchmark.gd` | PASS |

Raw outputs for every run are archived under `.ai/evidence/tests/`.

Project memory integrity is validated with:

```
python scripts/validate_memory.py
```

### Project Layout

```
project.godot            Godot project
scripts/                 Engine core (9 files) + domain content layers (politics/, experimental/)
data/                    countries/ provinces/ rules/ scenarios/ worlds/ agents/ agencies/
economy/                 Economy layer content + handlers
addons/maestro/          Godot editor plugin
scenes/                  Debug UI scene
.ai/                     Project memory (state, tasks, handoffs, decisions, evidence)
00-خطة-الطريق.md … 27-*  Numbered design/gate/spec documents (see below)
```

### Documentation

- **`00-خطة-الطريق.md`** (Roadmap) — single source of truth for step ordering and phase status.
- **`01-مبادئ-المحرك.md`** (Engine Principles) — immutable constitution of the project.
- **`02-المعمارية.md`** (Architecture) — technical details, subject to evolution.
- **`03-اطار-اللعب.md`** (Gameplay Framework) — game content (not engine code).
- **`04-اسئلة-تصميم-مفتوحة.md`** (Open Design Questions) — deliberately deferred decisions.
- **`05-…`–`27-…`** — numbered series of gates, stress tests, and specifications (Derived Importance, Strategic Relevance Model, Decision/Evaluation/Planning semantics, Ontology, Scale, Economy, Scheduler, Compliance).
- **`acceptance_report.md`** / **`audit_report.md`** — acceptance and engine/content audit evidence.
- **`CHANGELOG.md`** — chronological log of all significant changes.

### Project Memory (`.ai/`)

This repository runs on a strict memory protocol (see `AGENTS.md` and `.ai/memory-protocol.md`): `.ai/state.md` holds the current phase, `.ai/tasks/` the task ledger, `.ai/handoffs/latest.md` the agent-to-agent handoff, `.ai/decisions/` frozen architecture decisions, and `.ai/evidence/tests/` raw test outputs. Any agent session must read these before working and update them before committing.

---

## العربية

**محرك Maestro** هو محرك ألعاب متخصص مبني على Godot 4، مخصص لألعاب **Grand Strategy** (بنمط ألعاب Paradox زي HoI4 / Victoria).

### الرؤية الأساسية

بدأ المشروع كمود لـ HoI4 (Millennium Dawn). بعد نقاش طويل، اتضح إن الهدف الحقيقي أكبر: **بناء محرك متخصص لألعاب Grand Strategy** — مش محرك عام زي Unity/Unreal (مستحيل لفريق صغير)، لكن زي **Clausewitz بتاع Paradox**: محرك مبني لنوع لعبة واحد، قابل لإعادة الاستخدام عبر ألعاب مختلفة.

الهدف **مش AI حقيقي (LLM/ML)** — الهدف طبقة أذكى من الموجود حاليًا باستخدام معادلات وزن بسيطة (Utility AI) بدل قرارات عشوائية، من غير أي تضحية في الأداء، بل **تحسينه**.

### الحالة الحالية (حتى TASK-039 Batch A — 2026-09-07)

- **معيار "أول محرك شغال": محقق** — النقاط الخمس كلها اتثبتت واتقفلت في `acceptance_report.md` (لعبة من بيانات خارجية، قاعدتين بنفس آلية التقييم، Save/Load، صفر أسماء دومين في النواة، Determinism كامل).
- **10 مراحل من خطة الطريق مكتملة** (`00-خطة-الطريق.md`) — من الـKernel Prototype لحد تطهير النواة (كل منطق الدومين خرج من `Simulation.gd` لبيانات + طبقات محتوى، بتكافؤ Checksum حرفي).
- **آخر إنجاز: TASK-039 — النواة المؤسسية السياسية Batch A** (مكتمل PROVISIONAL، بانتظار ختم المالك): 5 نماذج سياسية، 12 action عبر pipeline موحد، history contracts، قواعد مؤسسية data-driven — قبول 31/31 PASS، وbenchmark بـ N=100 دولة / 1100 action / 330µs لكل action / **صفر تقييمات سياسية لكل tick**.
- **الـ Regression الكامل أخضر** في كل الجناحات (جدول الاختبارات فوق).
- قبلها: TASK-038 طبقة الـCompliance (25/25) · T5-C إصلاح storm الجدولة · T4.5 تحسين الأداء · T3 الاقتصاد.

### مكونات المحرك

| الطبقة | الوظيفة |
|---|---|
| **نواة المحاكاة** | SimClock · EventQueue · ScheduledQueue · ActivationSet · WorldState — event-driven، تفعيل انتقائي (الكيان النايم تكلفته صفر)، حتمي (RNG بـseed، قابل لإعادة الإنتاج bitwise) |
| **عقد المحتوى** | ContentSchema + ContentLoader — محتوى JSON بتحقق schema وأخطاء واضحة؛ إضافة محتوى بدون أي كود |
| **طبقة القرار** | معادلات وزن موحدة (`evaluate_weighted_score`) لكل قواعد القرار — كل معامل رقمي في `data/rules/*.json` وليس الكود أبدًا |
| **الأهمية المشتقة** | أهمية الكيان تُشتق من حالة العالم وشبكة الاعتماديات وحدها — عمياء عن الهوية (مثبت bitwise باختبارات تبديل الأسماء) |
| **طبقة الاقتصاد** | بوابة التمثيل + اقتصاد التغذية الراجعة (`economy/`) |
| **الـ Compliance Runtime** | استعلامات on-demand للجدوى/المقاومة/النفوذ/الشرعية فوق control_chains وsocial_relations — بلا per-tick polling |
| **الطبقة السياسية** | نماذج Office/Party/Legislature/Government/Election + 12 action مؤسسي + عقود تاريخ الانتخابات/التولية/الأنظمة |
| **سجل الـ Dispatch** | `data/rules/dispatch.json` + معالجات محتوى — النواة آلة dispatch عامة بصفر أسماء دومين |
| **الـ Serialization** | حفظ/تحميل موحد (ألعاب، سيناريوهات، اختبارات) بحارس إصدار وRNG آمن عبر JSON |

### البدء السريع

المتطلبات: **Godot 4.7+** (على Windows يُنصح بالنسخة الـconsole). لا تبعيات أخرى — المحتوى JSON خام.

من جذر المستودع:

```
godot --headless --script scripts/ScenarioTest.gd
```

النواتج الخام لكل تشغيل مؤرشفة في `.ai/evidence/tests/`، وسلامة ذاكرة المشروع بتتأكد بـ:

```
python scripts/validate_memory.py
```

### هيكل المشروع

```
project.godot            مشروع Godot
scripts/                 نواة المحرك (9 ملفات) + طبقات محتوى الدومين (politics/ · experimental/)
data/                    countries/ provinces/ rules/ scenarios/ worlds/ agents/ agencies/
economy/                 محتوى ومعالجات طبقة الاقتصاد
addons/maestro/          إضافة محرر Godot
scenes/                  مشهد Debug UI
.ai/                     ذاكرة المشروع (state · tasks · handoffs · decisions · evidence)
00-خطة-الطريق.md … 27-*  سلسلة الوثائق المرقمة (تصميم/بوابات/مواصفات)
```

### الوثائق

- **`00-خطة-الطريق.md`** (خطة الطريق) — مصدر الحقيقة الوحيد لترتيب الخطوات وحالة المراحل.
- **`01-مبادئ-المحرك.md`** (مبادئ المحرك) — دستور المشروع الثابت.
- **`02-المعمارية.md`** (المعمارية) — التفاصيل التقنية، قابلة للتطور.
- **`03-اطار-اللعب.md`** (إطار اللعب) — محتوى اللعبة (مش كود المحرك).
- **`04-اسئلة-تصميم-مفتوحة.md`** — القرارات المؤجلة عمدًا.
- **`05-…`–`27-…`** — السلسلة المرقمة للبوابات واختبارات الإجهاد والمواصفات (الأهمية المشتقة، نموذج الصلة الاستراتيجية، دلالات القرار/التقييم/التخطيط، الأونتولوجيا، الحجم، الاقتصاد، الجدولة، الـCompliance).
- **`acceptance_report.md`** / **`audit_report.md`** — تقرير القبول والتدقيق المعماري.
- **`CHANGELOG.md`** — سجل زمني لكل التعديلات الهامة.

### ذاكرة المشروع (`.ai/`)

المستودع يعمل ببروتوكول ذاكرة صارم (انظر `AGENTS.md` و`.ai/memory-protocol.md`): `.ai/state.md` للحالة الحالية، `.ai/tasks/` لسجل المهام، `.ai/handoffs/latest.md` للتسليم بين الوكلاء، `.ai/decisions/` للقرارات المعمارية المجمّدة، و`.ai/evidence/tests/` للنواتج الخام. أي جلسة عمل يجب أن تقرأها قبل التنفيذ وتحدّثها قبل الـcommit.
