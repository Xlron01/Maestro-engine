# 20 — Planning Coverage Mapping (Stage 3)

> **وثيقة تدقيق تغطية تحليلية — صفر كود، صفر تصميم جديد، صفر تشغيل محرك.**
> الغرض: استكمال جدول الـMapping الذي بدأه المالك بثلاثة صفوف نموذجية، على باقي مشكلات Planning/Utility القياسية، لتحديد هل تقع كلها على آليات **موجودة ومجمدة فعلًا** أم تظهر أول فجوة حقيقية تستحق Gate.
>
> **المدخلات المجمدة:** doc 19 (clone-and-replay = الحد الأدنى الكافي) · doc 18 (Evaluation CONFIRMED) · doc 17 §2.2 (المفردات المغلقة) · doc 15 §3.2 (preconditions) · doc 10 (Model v1) · doc 11 (R1–R3).

## 0) القالب والحكم الإلزامي

أعمدة القالب الخمسة كما جمّدها المالك حرفيًا: Problem · Input · Required Computation · Output · مكانه في الـPipeline الحالي · Generic أم Game-specific؟
كل صف يُختتم بأحد الأحكام الأربعة — والاوليان **باستشهاد حرفي** قابل للتحقق لا إشارة عامة:
`COVERED(citation)` · `COMPOSED(parts+citations)` · `BOUNDARY(layer-name)` · `GAP(needs-gate)`
*(الأرقام والأحكام أدناه مؤشرات تحليلية تُعرض لاعتماد المراجع؛ ليست حقائق مجمّدة قبل ختمه.)*

## 1) الجدول — التسعة صفوف

| # | Problem | Input | Required Computation | Output | مكانه في الـPipeline الحالي | Generic/Game-specific؟ | الحكم |
|---|---|---|---|---|---|---|---|
| 1 | Multi-step planning (P) | World + Goal + candidate actions | تكرار `predict(action, world)` clone-and-replay + gating بين الخطوات | واصف Outcome نهائي بعد N خطوات | **موجود**: doc19 §2.1-(ب) + §CE-P3 (iterated + precondition gating) | Generic بالكامل | `COVERED` — doc19 §CE-P3 |
| 2 | Constraint-aware planning (P) | action preconditions + predicted state | مطابقة `{field, op, value}` على الحالة المتنبأة | توافر/عدم توافر الفعل | **موجود**: آلية Gate15 §3.2 نفسها، أُعيد تشغيلها على النسخة الافتراضية (doc19 §CE-P2) | Generic — الشروط نفسها content | `COVERED` — doc19 §CE-P2 |
| 3 | Situation/Problem Recognition (U) | world حالية أو متنبأة | حساب Relevance بالقنوات المجمدة (`rel_supply`/`access`/`exposure`) | قائمة «ما يستاهل الاهتمام» | **موجود**: هذا هو Model v1 ذاته (doc10) بمفردات doc17 المغلقة | Generic — قنوات مجمدة محايدة الدومين | `COVERED` — doc10 |
| 4 | Resource Allocation (U/P) | world + مدّعون متعددون على قدرة نادرة | كل مدّعي يستقل: predict(ب) + evaluate(doc18) لنفسه — **بلا محكّم عالمي** (متوافق L1/doc19-r6) | قرارات لكل كيان؛ التنازع يطفو عند التنفيذ | `COMPOSED` من الصفين 1+2 + doc18 — لا primitive تخصيص | Generic composition | `COMPOSED` + سؤال حدّي ↓ |
| 5 | Plan Lifecycle / Persistence (P) | سلسلة تفكير سابقة + world جديدة بعد tick | الموجود مجمد: **لا Plan object مخزن** (doc19) — وهذا حرفيًا لا يثبت lifecycle semantics كاملة | قرارات طازجة | `COMPOSED`: لا-Plan-object (doc19) + دورة الحسم المعادة — يُثبت سلوكيًا في Spec tests؛ الكاش/memoization = تحسين Spec (سبق Test-10-v3) | Generic | `COMPOSED` — **تصحيح المالك** |
| 6 | Reactive Replanning (P) | انحراف النتيجة الفعلية عن المتنبأة | **لا نص مجمد يقول «replanning كل tick» ولا «decide() يُعاد كل tick»** — العبارة السابقة استنتاج معماري لا نصًا؛ يُصنف تركيبًا: لا-Plan-object + دورة الحسم | قرار محدث — يُثبت سلوكيًا في Spec tests | `COMPOSED` — **تصحيح المالك**: تقبلها COVERED كان قفزة semantics من نص لا يقولها | Generic | `COMPOSED` — **تصحيح المالك** |
| 7 | Global-vs-Local Coordination (P) | خطط كيانات متفاعلة (نفس بوابة/مورد) | قاعدة تنازل/تحكيم عند تصادم التوقعات — **لا آلية موجودة**، والتفاوض ممنوع بامتداد L1 (doc19 r6) | ؟ | لا يقع على أي مجمد | ؟ | `DEFERRED (خيار ii — قرار مؤقت موثّق)` — **ليس COVERED وليس REJECTED**: غير محسومة كPlanner capability مستقلة؛ الحسم يؤجل حتى تصادم فعلي خلال Spec/tests |
| 8 | Concurrent Goals (U) | goal_table متعددة الأهداف لكيان واحد | تجميع بأنماط F4 المجمدة (weighted/lex/pareto+§7) | score مجمّع حتمي | **موجود ومنفذ bitwise**: doc17 §2.2 + Test E (G_F4W/G_F4L/G_F4P) | Generic | `COVERED` — doc18/Test E |
| 9a | Failure Handling (P) | فشل شرط بخطوة من السلسلة | بوابة التوافر تبطل السلسلة من تلك الخطوة (لا إنقاذ جزئي) | سلسلة غير صالحة | `COMPOSED`: CE-P2 gating + انهيار الصف 6 | Generic | `COMPOSED` — doc19 §CE-P2 |
| 9b | Opportunity Detection (U) | واصفات حالات متنبأة | تطبيق Recognition (صف 3) على الواصف المتنبأ لا الحالي فقط | فرص مرصودة مسبقًا | `COMPOSED`: صف 3 فوق مخرج صف 1 | Generic | `COMPOSED` — صفوف 1+3 |
| 9c | Commitments Tracking (U/R) | وعود/التزامات معلنة | قراءة سجلات R3 ضمن المفردات المغلقة وتغذيتها كfacts | التزامات مؤثرة بالتقييم | **موجود شرطًا**: R3 بشرطه في doc11، والمفردات تقبله doc17 §2.2 | Generic — السجلات نفسها content | `COVERED` — doc11-R3 |
| 9d | Hidden-Info / Deception (U) | معلومة يراها طرف ولا يراها آخر | يتطلب واصفًا لكل-مراقب — يمس التمثيل ذاته | — | يقاطع **فجوة الرؤية غير المتماثلة الموثقة في doc13** (نفس جذر partial-observability المؤجل في doc19 §4-b) | — | `BOUNDARY → doc13-gap` (مؤجل مسمى) |

## 2) الحصيلة

| الحكم | العدد | الصفوف |
|---|---|---|
| COVERED | 4 | 1, 2, 3, 8 (+9c) |
| COMPOSED | 5 | 4, **5**, **6**, 9a, 9b |
| BOUNDARY | 1 | 9d → doc13-gap |
| **DEFERRED (خيار ii)** | **1** | **7 — Global-vs-Local Coordination** |

**الأحكام النهائية بتعديلات المالك:** صفّا 5 و6 نزلا إلى `COMPOSED` — استشهاد «لا Plan object» لا يثبت lifecycle كاملة، وعبارة «replanning كل tick» كانت استنتاجًا معماريًا لا نصًا مجمدًا، وقبولها COVERED كان قفزة دلالية. صف 7: **لا Gate الآن — الخيار (ii)**؛ يُوثَّق كـ**غير محسومة كPlanner capability مستقلة**، وحسمه يؤجل إلى ظهور تصادم فعلي أثناء بناء Planning Spec أو اختباراتها.

**القاعدة المنهجية المسجلة بتوقيع المالك:** *«لا تُفتح Gate جديدة لمجرد احتمال نطري قبل ظهور عجز أو counterexample يثبت أن البنية الحالية لا تكفي»* — متسقة مع خانة Open في doc19 (تُفتح عند عجز مثبت لا وقائيًا). وهذا **ليس رفضًا للمشكلة؛ إنه رفض لاتخاذ قرار معماري قبل وجود دليل.**

**محضر validator الخام (منقول حرفيًا من الإخراج المستر إلى ملف — 2026-08-26؛ بوابة تحليلية بلا تشغيل محرك: هذا إخراج أداة الذاكرة):**

```text
====================================================
  Maestro Memory Validator & Linter
====================================================
Checking project structure...
Checking task files...
Checking link integrity...

----------------------------------------------------
Validation Finished: 0 Errors, 1 Warnings
----------------------------------------------------

Warnings:
  [WARN] Broken file link in .\00-خطة-الطريق.md: c:/tmp/maestro%20engine/acceptance_report.md (Expected file: acceptance_report.md)

[SUCCESS] Memory integrity validation passed successfully!
```

---
---
## 3) حالة الوثيقة

⏸️ **بانتظار اعتماد المراجع** — ولا فتح لأي Gate جديد تلقائيًا.

### سجل المراجعة

| التاريخ | الإجراء | السبب |
|---|---|---|
| 2026-08-26 | إنشاء الوثيقة بقرار المالك: Stage 3 تدريجي — 9 صفوف كاملة بأحكام مصنفة، ومرشح-GAP الوحيد يُرفع مقفول الباب (تصنيف وتوقف، بلا مسودة Gate) | منهجية «أصنف وأتوقف» + فصل واضح: هذه الوثيقة مدخل تغطية لـPlanning Spec v0.1 لا تصميم لها |
| 2026-08-26 | **rev.2 — أحكام المالك الثلاثة منفذة وإغلاق مشروط**: صف5 COVERED→**COMPOSED** · صف6 COVERED→**COMPOSED** (تصحيح استنتاج غير مكتوب) · صف7 **DEFERRED(خيار ii)** بلا Gate الآن، يبقى غير محسوم كcapability مستقلة حتى counterexample/احتياج فعلي خلال Spec/tests | قاعدة المالك: لا Gate لاحتمال نطري قبل عجز مثبت — اتساقًا مع Open-in-doc19 |

---
