# PROBE-P1 — Incremental Propagation Performance & Expressiveness Feasibility

> **هذا الملف أرشيف حرفي لمواصفة المالك (المُسلَّمة 2026-09-09) — مجمّدة كـsource of truth
> قبل أول تشغيل. لا تُعدَّل هنا أبدًا؛ التعديلات التشغيلية تعيش في DESIGN.md وسجل تعديلاته.**

## 1. Purpose

PROBE-P1 هو feasibility probe معزول، هدفه تحديد ما إذا كان نموذج حساب يعتمد على:

`State → Dependency → Change → Affected Propagation → Effects`

يمتلك خصائص كافية من حيث:

1. التعبير عن dependency-driven consequences.
2. الأداء عند اختلاف حجم العالم.
3. الأداء عند اختلاف حجم التغيير.
4. الأداء تحت أشكال مختلفة من dependency topology.
5. الحفاظ على deterministic execution.
6. عدم فرض تكلفة مرتبطة بحجم العالم عندما يكون الجزء المتغير صغيرًا.

PROBE-P1 ليس implementation للمحرك، وليس TASK production، ولا يدخل في acceptance chain الخاصة بـGSG Engine.

---

# 2. Hard Scope Boundary

PROBE-P1:

* لا يعدل أي ملف production في GSG Engine.
* لا يضيف subsystem جديد إلى `Simulation.gd`.
* لا يغير `EventQueue.gd`.
* لا يغير `ScheduledQueue.gd`.
* لا يغير `ActivationSet.gd`.
* لا يربط أي candidate بالـproduction runtime.
* لا يستخدم parallel execution.
* لا يستخدم multithreading.
* لا يدخل Actor Runtime.
* لا يدخل Political Runtime.
* لا يدخل Economy Runtime.
* لا يقرر architecture النهائية.
* لا يحول candidate إلى production code حتى لو نجح.

كل الكود الخاص بالـprobe يجب أن يكون معزولًا تحت مساحة تجربة مستقلة.

---

# 3. Research Questions

## R1 — Expressiveness

هل يمكن لـdependency-driven propagation تمثيل الحالات الأساسية التي نحتاجها على مستوى مجرد:

`change → affected state → consequence`

بدون إضافة game-specific logic؟

## R2 — Locality

عندما يتغير عدد صغير من الـnodes داخل عالم كبير، هل يمكن للنظام تنفيذ work على الجزء المتأثر فقط؟

## R3 — Scaling

هل ترتبط تكلفة التنفيذ أساسًا بـ:

`Δ = number of changes`

و:

`A = affected closure`

و:

`T = graph topology`

بدلًا من حجم العالم `N` وحده؟

## R4 — Boundary

متى يصبح incremental propagation أقل فائدة أو أكثر تكلفة من full recomputation؟

## R5 — Resource Trade-off

ما تكلفة dependency indexing أو tracking من ناحية الذاكرة والعمل الإضافي؟

---

# 4. Conceptual Model

الـprobe يستخدم نموذجًا مجردًا صغيرًا.

## Node

يحمل:

* deterministic ID
* scalar state
* dependency links
* derived value

## Dependency

العلاقة:

`A → B`

تعني:

> state of B depends on state of A.

## Change

عملية تغيّر state في Node أو مجموعة Nodes.

## Propagation

إعادة تقييم كل Node قد تكون نتيجته تغيرت بسبب change مباشر أو غير مباشر.

## Effect

تغير derived state الناتج عن propagated change.

لا توجد game-specific semantics داخل الـprobe.

---

# 5. Implementations Under Test

## Candidate 0 — Full Recompute Baseline

بعد كل change:

> evaluate جميع الـnodes وفق graph الحالي.

هذا baseline مرجعي لقياس تكلفة الحساب الكامل.

لا يستخدم baseline لإثبات أن full recomputation هو architecture المرغوبة.

## Candidate 1 — Affected-Set Propagation

عند حدوث change:

1. تسجيل الـchanged node.
2. استخراج الـdependent nodes.
3. زيارة dependency closure.
4. إعادة حساب nodes الموجودة داخل affected set فقط.
5. عدم لمس nodes خارج affected set.

Candidate 1 يعتمد على dependency structure مسبقة.

## Candidate 2 — Indexed Propagation

Candidate 2 يستخدم reverse dependency index:

`source → dependents`

بحيث يمكن الوصول مباشرة إلى dependent nodes دون discovery traversal كامل.

يتم قياس:

* index build cost
* index query/use cost
* index update cost إن وجدت
* index memory footprint

Candidate 2 ليس architecture مقترحة؛ هو candidate للمقارنة.

---

# 6. Execution Model

كل benchmark run يتكون من:

1. deterministic world generation.
2. deterministic dependency graph generation.
3. initial state evaluation.
4. fixed sequence of state changes.
5. propagation/evaluation.
6. final state hash.
7. metrics collection.

لا يوجد random branching أثناء التنفيذ.

كل scenario يستخدم seed ثابتًا ومعلنًا.

يجب فصل:

* graph construction time
* initial build time
* propagation runtime

حتى لا تختلط تكاليف مختلفة في metric واحدة.

---

# 7. World Sizes

الإصدارات الأولى تستخدم:

| ID |   Nodes |
| -- | ------: |
| N1 |   1,000 |
| N2 |  10,000 |
| N3 |  40,000 |
| N4 | 100,000 |

`N3 = 40,000` هو الـanchor scale.

`N4 = 100,000` يستخدم فقط لاختبار اتجاه scaling، وليس لإعلان أن 100K هو target رسمي للمحرك.

---

# 8. Topology Definitions

الـtopologies يتم تعريفها عدديًا وليست مجرد labels.

## T1 — Sparse

* target average out-degree = 4
* maximum out-degree = 8
* no intentional super-hub
* معظم العقد تقع في degree range منخفض

الهدف: قياس incremental behavior في شبكة sparse.

## T2 — Long Chain

* average out-degree ≈ 1
* maximum out-degree = 1
* chain depth = 1,000
* no intentional wide fan-out

الهدف: قياس cost of propagation depth.

## T3 — Hub

* 1% من العقد Hubs.
* كل Hub يمتلك direct fan-out مستهدفًا قدره 5% من العالم.
* بقية الشبكة تحافظ على sparse structure.

الهدف: قياس wide fan-out concentrated topology.

## T4 — Dense

* target average out-degree = 20
* maximum out-degree = 40

الهدف: قياس أثر relationship density.

## T5 — Mixed

* 80% sparse nodes
* 15% medium-degree nodes
* 5% hubs
* يحتوي على chains قصيرة وclusters وhub connections

الهدف: تقريب heterogeneous topology التي قد تظهر في world strategy.

### Topology Qualification

الأرقام السابقة هي **probe definitions** وليست ادعاءً بأن GSG الحقيقي لديه هذه الكثافات.

قبل اعتماد أي workload لاحق داخل production architecture، يجب مقارنة كثافة topology التجريبية مع العلاقات الفعلية في domains الموجودة.

---

# 9. Change Density

| C-ID | Change Count |
| ---- | -----------: |
| C0   |            0 |
| C1   |            1 |
| C2   |   0.01% of N |
| C3   |    0.1% of N |
| C4   |      1% of N |
| C5   |    5% of N |
| C6   |     20% of N |
| C7   |     50% of N |

القيم تمثل عدد الـchanged nodes بالنسبة إلى N.

---

# 10. Affected-Work Levels

عدد الـchanged nodes وحده لا يكفي.

كل run يسجل: `Affected Closure Size`

ويصنف:

| Level | Affected nodes |
| ----- | -------------: |
| A0    |              0 |
| A1    |           1–10 |
| A2    |         11–100 |
| A3    |      101–1,000 |
| A4    |   1,001–10,000 |
| A5    |        >10,000 |

هذه classification تستخدم characterization والتحليل، وليس كل level يجب أن يظهر في كل topology.

---

# 11. Required Scenario Matrix

لا يتم تشغيل Cartesian product كامل لكل N × T × C إلا إذا ثبتت فائدته.

الـminimum locked matrix:

## S1 — Idle
* N = 40,000, Topology = T1, Changes = C0
* الغرض: إثبات عدم وجود unconditional propagation work.

## S2 — Single Local Change
* N = 40,000, Topology = T1, Changes = C1, Target affected closure = A1
* الغرض: أفضل حالة متوقعة للـincremental approach.

## S3 — Single Change / Large Cascade
* N = 40,000, Topology = T3, Changes = C1, Target affected closure = A4
* الغرض: اختبار concentrated fan-out.

## S4 — Sparse 1% Changes
* N = 40,000, Topology = T1, Changes = C4
* الغرض: قياس incremental behavior عند low global change density.

## S5 — Dense 1% Changes
* N = 40,000, Topology = T4, Changes = C4
* الغرض: قياس أثر graph density.

## S6 — Wide Cascade
* N = 40,000, Topology = T3, Changes = C2, Target affected closure = A4/A5
* الغرض: قياس wide propagation.

## S7 — Long Dependency Chain
* N = 40,000, Topology = T2, Changes = C1, Depth = 1,000
* الغرض: قياس propagation depth.

## S8 — High Change Density
* N = 40,000, Topology = T5, Changes = C6
* الغرض: اختبار regime يصبح فيه incremental computation قريبًا من full recompute.

## S9 — World Scaling / Local Work Fixed
* Topology = T1, Changes = C1, affected closure يجب أن يظل ضمن A1
* N: `1K → 10K → 40K → 100K`
* الغرض المركزي: هل تكلفة local change ترتفع مع N، أم تبقى مرتبطة تقريبًا بالجزء المتأثر؟

## S10 — World Scaling / Work Scaling
* Topology = T1, N يتزايد، affected closure يتزايد proportionally
* الغرض: تمييز scaling مع world size عن scaling مع actual affected work.

---

# 12. Benchmark Metrics

## Runtime
* total runtime, mean propagation latency, p95 propagation latency, peak propagation latency

## Work
* nodes evaluated, dependencies traversed, propagation visits, recomputations, skipped nodes

## Memory
* peak process memory / working set, dependency storage, reverse-index storage, temporary allocations إن أمكن

## Correctness
* final state hash, per-run deterministic hash, propagated node count, effect count

## Scaling
يجب تسجيل: `Runtime / N` و `Runtime / affected_nodes` و `Memory / N` و `Memory / dependency` حتى لا يتم الحكم من runtime الخام وحده.

---

# 13. Correctness Criteria

## P1-COR-1
Final state hash للـCandidate 1 يجب أن يطابق Candidate 0 bitwise في كل scenario.

## P1-COR-2
Final state hash للـCandidate 2 يجب أن يطابق Candidate 0 bitwise في كل scenario.

## P1-COR-3
تشغيلان مستقلان بنفس seed/fixture/graph/state/change sequence يجب أن ينتجا نفس hash.

## P1-COR-4
عدد الـeffects النهائية يجب أن يكون متطابقًا.

أي mismatch = FAIL.

---

# 14. Performance Acceptance

## Status of Numeric Thresholds

القيم الرقمية التالية هي **PROBE-LEVEL WORKING GATES** وليست **GSG-wide production performance budgets**. لا يجوز استخدام هذه الأرقام وحدها لاتخاذ قرار architecture نهائي للمحرك.

## P1-PERF-1 — Idle
عند C0: Candidate 1/2 يجب ألا يقوم بـpropagation أو world evaluation. أي full-world recomputation في idle path = FAIL.

## P1-PERF-2 — Local Change Advantage
في S2 وS9، عندما `affected closure ≤ 0.1% of N`، يجب أن يحقق أفضل candidate **≥ 50% lower runtime** من full recompute عند N ≥ 40,000.

## P1-PERF-3 — 1% Change Advantage
في S4، عندما `changes = 1% of N` و`affected closure ≤ 10% of N`، يجب أن يحقق أفضل candidate **≥ 25% lower runtime** من baseline.

## P1-PERF-4 — Scaling Locality
في S9، عندما يبقى affected closure ثابتًا تقريبًا أثناء زيادة N من 1K إلى 100K: يجب أن يكون `Runtime(100K) / Runtime(1K) ≤ 3×` مع ثبات تقريبًا للـaffected work.

## P1-PERF-5 — Dense / Hub
في S3/S5/S6: لا يشترط التفوق على baseline. لكن: لا crash، لا OOM، peak memory ≤ 2× baseline، ويتم تسجيل actual affected closure. هذه scenarios boundary characterization أكثر من كونها speedup gates.

## P1-PERF-6 — High Change Density
عند `changes ≥ 20%`: يسمح للـincremental candidate أن يكون أسوأ من baseline. لكن `runtime(candidate) ≤ 3 × runtime(baseline)` وإلا تعتبر هناك performance pathology تستحق التحقيق.

## P1-PERF-7 — Memory
في scenarios التي يكون فيها incremental approach متوقعًا أن يستفيد منها: `Peak memory(candidate) ≤ 1.5 × Peak memory(baseline)`. أما scenarios التي يتحول فيها graph إلى dense/highly connected فيستخدم P1-PERF-5 كـupper safety bound. أي memory result يتجاوز ذلك يسجل كـFAIL أو diagnostic exception موثق.

---

# 15. Break-Even Characterization

هذا القسم إلزامي حتى لو نجح candidate في كل performance gates. يجب تحديد:

## B1 — Change-density break-even
أقل/أقرب نقطة يصبح عندها `Incremental runtime ≥ Full recompute runtime` مع زيادة C.

## B2 — Affected-work break-even
النسبة التقريبية من N التي عندها يصبح incremental approach مساويًا أو أسوأ من baseline.

## B3 — Topology break-even
تحديد topology أو density regime الذي تتراجع عنده ميزة incremental approach.

## B4 — Memory break-even
تحديد النقطة التي تصبح فيها تكلفة dependency/index storage ذات أثر مادي.

الـbreak-even numbers تكون **نتائج benchmark** وليست thresholds مفروضة مسبقًا.

---

# 16. Candidate Comparison

بعد اجتياز correctness gates، إذا كان Candidate 1 وCandidate 2 كلاهما يحقق performance acceptance:

## P1-COMP-1
إذا كان هناك فرق أداء materially significant: يفضل الأسرع.

## P1-COMP-2
إذا كان الأداء متقاربًا ضمن ±10%: يفضل الأقل peak memory.

## P1-COMP-3
إذا كان runtime وmemory متقاربين: يفضل الأقل structural/implementation complexity.

لا يتم تحويل complexity إلى score رقمي مصطنع.

## P1-COMP-4
وجود reverse index لا يعتبر ميزة بحد ذاته. يجب تبرير تكلفته بالـruntime/memory results.

---

# 17. Benchmark Integrity

كل benchmark run يجب أن:

* يستخدم نفس seed.
* يستخدم نفس initial state.
* يستخدم نفس dependency graph.
* يستخدم نفس change sequence.
* يستخدم نفس الجهاز.
* يستخدم نفس build configuration.
* يشغل scenarios مرتين مستقلتين على الأقل.
* يسجل warm-up إن وجد.
* لا يخلط build time بالـruntime.
* لا يخلط graph-generation time بالـpropagation time.
* لا يستخدم benchmark-specific shortcut غير متاح للمفهوم المقاس.

---

# 18. Required Output

PROBE-P1 يجب أن ينتج:

1. correctness report.
2. performance table لكل scenario.
3. memory table.
4. topology summary.
5. scaling measurements.
6. deterministic hashes.
7. Candidate 1 vs Candidate 2 comparison.
8. break-even characterization.
9. failure/boundary analysis.

ويجب أن تكون النتيجة الخام متاحة حتى لو فشل verdict النهائي.

---

# 19. Verdict Categories

## FULL PASS
Correctness بالكامل ناجح، وP1-PERF-1 ناجح، وP1-PERF-2 ناجح، وP1-PERF-3 ناجح، وP1-PERF-4 ناجح، ولا integrity failures، ولا crash/OOM، وتوجد regime واضحة يكون فيها incremental approach أفضل ماديًا من baseline، وbreak-even يمكن تحديده من النتائج.

## PARTIAL PASS
Correctness ناجح، لكن: performance benefit محدود، أو memory trade-off كبير، أو فائدته تظهر فقط في regime ضيق. وفي هذه الحالة يمنع اعتبار النتيجة adoption recommendation تلقائيًا.

## FAIL
أي من التالي: correctness mismatch، nondeterminism، crash/OOM، full-world work في idle، فشل واضح في local scaling، memory pathology، أو عدم وجود workload مفيد يتحسن فيه incremental approach بصورة ذات معنى.

---

# 20. What PROBE-P1 Does Not Decide

حتى FULL PASS لا يعني: اعتماد dependency propagation داخل GSG، ولا اعتماد graph architecture محددة، ولا إضافة provenance، ولا إضافة Observation، ولا تعديل Relevance، ولا ربط Political/Economy/Military، ولا اختيار static أو dynamic dependency model production، ولا parallelization، ولا تغيير scheduler، ولا تحديد production performance budget للمحرك.

FULL PASS يعني فقط: توجد evidence تجريبية كافية أن هذا النوع من mechanism يستحق الانتقال إلى مرحلة design/functional feasibility التالية، ضمن حدود الأداء التي قاستها التجربة.

---

# 21. Production Adoption Gate

أي انتقال من PROBE-P1 إلى production يحتاج مشروعًا منفصلًا. لا يجوز استخدام نتيجة PROBE-P1 لتنفيذ integration مباشر. الترتيب المستهدف هو:

`PROBE-P1 → evidence review → functional domain probe → production integration design → production implementation → real workload benchmark`

---

# 22. Non-Goals

PROBE-P1 لا يحاول إثبات أن "dependency graphs هي البنية الصحيحة لمحرك GSG" ولا أن "incremental propagation هي الحل النهائي" ولا أن "significance يمكن اختزالها إلى propagation" ولا أن "كل domains يمكن توحيدها".

الغرض الوحيد: **اختبار ما إذا كان change-driven dependency propagation يمكنه تحقيق correctness وuseful locality وacceptable resource behavior عند scale قريب من GSG، وتحديد حدوده التجريبية قبل أي adoption معماري.**
