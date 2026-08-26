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
| 5 | Plan Lifecycle / Persistence (P) | سلسلة تفكير سابقة + world جديدة بعد tick | **لا شيء مطلوب** — الخطط كائنات تفكير عابرة بحسم doc19 (لا Plan object)؛ `decide()` يعاد كل tick حتميًا | قرارات طازجة | `COVERED` بالتصميم — الكاش/memoization تحسين Spec (سبق Test-10-v3) | Generic | `COVERED` — doc19 §CE-P3 ruling |
| 6 | Reactive Replanning (P) | انحراف النتيجة الفعلية عن المتنبأة | ينهد إلى `decide()` العادي على حالة الـtick الجديدة — لا شيء مخزَّن يُصلَح | قرار محدث | `COVERED` بنيويًا — انهيار المشكلة نتيجة غياب التخزين (صف 5) | Generic | `COVERED` — نتيجة بنائية لقرار doc19 |
| 7 | Global-vs-Local Coordination (P) | خطط كيانات متفاعلة (نفس بوابة/مورد) | قاعدة تنازل/تحكيم عند تصادم توقعات — **لا آلية موجودة**، وأسلوب التفاوض ممنوع بامتداد L1 (doc19 r6) | ؟ | ⚠️ لا يقع على أي مجمد | ؟ | ⚠️ **GAP-candidate — مرفوع لقرار المالك (§3)، مصنف وتوقف** |
| 8 | Concurrent Goals (U) | goal_table متعددة الأهداف لكيان واحد | تجميع بأنماط F4 المجمدة (weighted/lex/pareto+§7) | score مجمّع حتمي | **موجود ومنفذ bitwise**: doc17 §2.2 + Test E (G_F4W/G_F4L/G_F4P) | Generic | `COVERED` — doc18/Test E |
| 9a | Failure Handling (P) | فشل شرط بخطوة من السلسلة | بوابة التوافر تبطل السلسلة من تلك الخطوة (لا إنقاذ جزئي) | سلسلة غير صالحة | `COMPOSED`: CE-P2 gating + انهيار الصف 6 | Generic | `COMPOSED` — doc19 §CE-P2 |
| 9b | Opportunity Detection (U) | واصفات حالات متنبأة | تطبيق Recognition (صف 3) على الواصف المتنبأ لا الحالي فقط | فرص مرصودة مسبقًا | `COMPOSED`: صف 3 فوق مخرج صف 1 | Generic | `COMPOSED` — صفوف 1+3 |
| 9c | Commitments Tracking (U/R) | وعود/التزامات معلنة | قراءة سجلات R3 ضمن المفردات المغلقة وتغذيتها كfacts | التزامات مؤثرة بالتقييم | **موجود شرطًا**: R3 بشرطه في doc11، والمفردات تقبله doc17 §2.2 | Generic — السجلات نفسها content | `COVERED` — doc11-R3 |
| 9d | Hidden-Info / Deception (U) | معلومة يراها طرف ولا يراها آخر | يتطلب واصفًا لكل-مراقب — يمس التمثيل ذاته | — | يقاطع **فجوة الرؤية غير المتماثلة الموثقة في doc13** (نفس جذر partial-observability المؤجل في doc19 §4-b) | — | `BOUNDARY → doc13-gap` (مؤجل مسمى) |

## 2) الحصيلة

| الحكم | العدد | الصفوف |
|---|---|---|
| COVERED | 6 | 1, 2, 3, 5, 6, 8 (+9c) |
| COMPOSED | 3 | 4, 9a, 9b |
| BOUNDARY | 1 | 9d → doc13-gap |
| **GAP-candidate** | **1** | **7 — Global-vs-Local Coordination** |

**مؤشر مبدئي (ليس نهائيًا):** 9 من 10 تقع على مجمد موجود أو تركيبه — الـPipeline أوسع تغطية من المتوقع. الفجوة المرشحة الوحيدة: **قاعدة التنازل عند التصادم (Coordination Semantics)** — وهي قد تكون (i) Gate دلالي جديد، أو (ii) تُترك للطوارئ عبر أحداث المحاكاة دون آلية — **التصنيف هنا وقفُ إعلانٍ لا حسم؛ القرار للمالك وحدّه.**

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

---
