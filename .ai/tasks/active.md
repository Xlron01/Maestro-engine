# Active Tasks

قائمة المهام النشطة الجاري العمل عليها حالياً في المشروع.

---

### [TASK-028] D1 — Decision Boundary Test

- **Status:** IN_PROGRESS
- **Owner:** ox-alpha
- **Dependencies:** TASK-027 (Gate 15 CLOSED بعد تصحيحَي المالك), TASK-024 (Ontology), TASK-020 (Model v1 FROZEN)
- **Objective:** إثبات أن طبقة القرار تحترم حدود Decision Semantics (حدود/مدخلات/مخرجات) عبر 7 خصائص مجمدة — **بلا أي ادعاء بصحة معادلة تقييم** (ذلك D2 لاحقًا).
- **Acceptance Criteria:**
  - [ ] تسجيل مسبق مجمد في `16-Decision-Boundary-Test.md` قبل التشغيل.
  - [ ] P1..P7: Goal/Relevance Dependence، Capability Constraint، Option Sensitivity، Identity Blindness، Read-only bitwise، Determinism.
  - [ ] شروط FAIL الستة مغطاة كنفي مباشر للخصائص.
  - [ ] Action Registry = fixture بيانات فقط؛ سؤال أنطولوجيا مصدر الأفعال Open Question مسجل ولا يُفتح.
  - [ ] صفر Kernel code — decide() داخل العدّاء حصرًا reference-only.
  - [ ] deg/degree: أي bug ⇒ إعادة كل الفحوصات من الصفر.
- **Validation Method:** تشغيل headless واحد + raw log في `.ai/evidence/tests/d1_decision_boundary.log` + مراجعة المالك.
- **Evidence:** [`16-Decision-Boundary-Test.md`](file:///c:/tmp/maestro%20engine/16-Decision-Boundary-Test.md)

---

> ✅ TASK-027 (Decision Layer Design Gate) أُغلق نهائيًا بعد تصحيحين بتوجيه المالك: إعادة صياغة §3.11 كمبدأ بلا معادلة (التزامًا بالبند 7)، وإضافة ربط Goal↔Channel بأسماء doc 10 الحرفية (`exposure`/`access`/`rel_supply`). التفاصيل في completed.md وسجل مراجعة doc 15 §4.
