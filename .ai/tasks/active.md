# Active Tasks

قائمة المهام النشطة الجاري العمل عليها حالياً في المشروع.

---

### [TASK-024] Content Ontology Gate

- **Status:** IN_PROGRESS
- **Owner:** ox-alpha (openrouter)
- **Dependencies:** TASK-023 (Decision Semantics Gate 2 — CLOSED)
- **Objective:** تحديد أقل Ontology ممكنة لمخطط المحتوى (Content Schema) عبر بروتوكول Gates التحليلي — صفر كود، صفر Kernel.
- **Acceptance Criteria:**
  - [ ] تسجيل مسبق مجمد (Pre-registration) للـ 5 Counterexamples بتوقعات قابلة للكسر قبل أي تحليل تطبيقي.
  - [ ] كل نتيجة مصنفة إلزاميًا: Confirmed / Rejected / Open — بلا خليط.
  - [ ] فصل تام بين Definition / Runtime State / Historical Change.
  - [ ] CE-5 (الزمن): إن أظهر التحليل حاجة إلى Primitive زمني مستقل ⇒ يُسجل فقط Open Question باسم «Content Schema requires unresolved temporal semantics» ويُغلق الـ Gate بما ثبت حتى تلك النقطة — دون تصميم Temporal Primitive أو حسم Semantics الزمن داخل هذا الـ Gate (موضوع Gate مستقل لاحقًا).
  - [ ] لا كود قبل إغلاق الـ Gate.
- **Validation Method:** مراجعة صاحب المشروع لوثيقة الحسم `12-Content-Ontology-Gate.md`
- **Evidence:** None

## القواعد الحاكمة المجمدة لـ TASK-024 (قرار صاحب المشروع — 2026-08-25)

1. **التسجيل المسبق للتوقعات** — hypotheses قابلة للكسر، لا حلول مسبقة.
2. **5 CEs** — تُقبل كما هي بمجرد تجميدها.
3. **لا Primitive جديد لمجرد الراحة** — كل افتراض بنية جديدة يحتاج إثبات فشل البديل الأضيق.
4. **Definition / Runtime State / Historical Change مفصولة دائمًا.**
5. **Confirmed / Rejected / Open إلزامية** لكل مخرج.
6. **أي Counterexample يكسر التوقع يوقف التوسع ويُسجل** — لا تجاوز ولا ترقيع فوري.
7. **لا كود قبل إغلاق الـ Gate.**
8. **Boundary Rule خاصة بـ CE-5 (الزمن)** كما في معيار القبول أعلاه — الهدف هو أقل Ontology للمحتوى وليس حل Temporal Model بالكامل؛ وإلا سنعيد مشكلة الـ 12 فرضية التي تجنبناها في Decision Semantics.

> ⚠️ قائمة الـ 5 Counterexamples نفسها **غير مسجلة بعد** في ذاكرة المستودع (الـ Chat غير معتمد حسمًا). مسودة مقترحة في الوثيقة `12-Content-Ontology-Gate.md` بانتظار تجميد المالك قبل بدء التحليل التطبيقي.
