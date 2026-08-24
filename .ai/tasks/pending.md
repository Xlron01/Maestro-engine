# Pending Tasks

قائمة المهام المنتظرة والمعلقة في المشروع.

---

### [TASK-003] Scaling & Stress Test Simulator

- **Status:** PENDING
- **Owner:** None
- **Dependencies:** TASK-002
- **Objective:** قياس كفاءة أداء المحاكي عند تشغيل أعداد كبيرة من الكيانات (الوكلاء والوكالات والدول).
- **Acceptance Criteria:**
  - [ ] تشغيل 1000 عميل و 100 وكالة و 50 دولة متزامنة دون تدهور زمن الخطوة المحسوبة.
  - [ ] قياس واكتشاف عنق الزجاجة (Bottlenecks) في `EventQueue` أو `ScheduledQueue`.
- **Validation Method:**
  Benchmarking script
- **Evidence:** None
