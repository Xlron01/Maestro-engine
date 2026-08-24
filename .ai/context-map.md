# Project Context Map

خريطة الربط الذكي لتوجيه النماذج إلى الملفات البرمجية ومستندات العمارة والقرارات ذات الصلة بكل نطاق.

---

## 1) Core Kernel (النواة الأساسية)

المسؤول عن توقيت المحاكاة، حالة العالم، جدولة الوظائف، وطوابير الأحداث والـ Activation Set.

- **الملفات البرمجية ذات الصلة:**
  - [`scripts/SimClock.gd`](file:///c:/tmp/maestro%20engine/scripts/SimClock.gd)
  - [`scripts/WorldState.gd`](file:///c:/tmp/maestro%20engine/scripts/WorldState.gd)
  - [`scripts/EventQueue.gd`](file:///c:/tmp/maestro%20engine/scripts/EventQueue.gd)
  - [`scripts/ScheduledQueue.gd`](file:///c:/tmp/maestro%20engine/scripts/ScheduledQueue.gd)
  - [`scripts/ActivationSet.gd`](file:///c:/tmp/maestro%20engine/scripts/ActivationSet.gd)
- **قرارات ومستندات للقراءة:**
  - `.ai/architecture.md`
  - `.ai/decisions/001-dictionary-based-entities.md`

---

## 2) Content Loader & Verification (نظام تحميل وتحقق البيانات)

المسؤول عن تحميل ملفات الـ JSON الخارجية، والتحقق من صحتها وتوافقها مع الـ Schema المحددة.

- **الملفات البرمجية ذات الصلة:**
  - [`scripts/ContentLoader.gd`](file:///c:/tmp/maestro%20engine/scripts/ContentLoader.gd)
  - [`scripts/ContentSchema.gd`](file:///c:/tmp/maestro%20engine/scripts/ContentSchema.gd)
- **ملفات البيانات ذات الصلة:**
  - [`data/rules/politics.json`](file:///c:/tmp/maestro%20engine/data/rules/politics.json)
  - [`data/countries/`](file:///c:/tmp/maestro%20engine/data/countries/)
  - [`data/provinces/`](file:///c:/tmp/maestro%20engine/data/provinces/)
- **قرارات ومستندات للقراءة:**
  - `.ai/decisions/002-data-driven-rules.md`

---

## 3) Decision System (نظام التقييم والقرارات)

المسؤول عن الحسابات الرياضية الموزونة لفرص الانقلابات وقرارات الدول واستخبارات العمليات.

- **الملفات البرمجية ذات الصلة:**
  - [`scripts/DecisionSystem.gd`](file:///c:/tmp/maestro%20engine/scripts/DecisionSystem.gd)
- **قرارات ومستندات للقراءة:**
  - `.ai/decisions/002-data-driven-rules.md`

---

## 4) Simulation Orchestration (أوركيسترا المحاكاة والـ Lifecycle)

المسؤول عن ربط كافة الأنظمة ببعضها، تمرير البيانات، معالجة خطوة المحاكاة، الحفظ والاستعادة.

- **الملفات البرمجية ذات الصلة:**
  - [`scripts/Simulation.gd`](file:///c:/tmp/maestro%20engine/scripts/Simulation.gd)
- **قرارات ومستندات للقراءة:**
  - `.ai/decisions/003-domain-coupling-debt.md`

---

## 5) Test Suite & Verification (جناح الاختبارات والـ Linting)

- **الملفات البرمجية ذات الصلة:**
  - [`scripts/ScenarioTest.gd`](file:///c:/tmp/maestro%20engine/scripts/ScenarioTest.gd)
  - [`scripts/validate_memory.py`](file:///c:/tmp/maestro%20engine/scripts/validate_memory.py)
  - [`scripts/test_phase6_step4.gd`](file:///c:/tmp/maestro%20engine/scripts/test_phase6_step4.gd)
  - [`scripts/test_phase6_step5.gd`](file:///c:/tmp/maestro%20engine/scripts/test_phase6_step5.gd)
