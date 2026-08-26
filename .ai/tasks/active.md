# Active Tasks

قائمة المهام النشطة الجاري العمل عليها حالياً في المشروع.

---

### [TASK-033] Planning Specification v0.1 + Test P

- **Status:** IN_PROGRESS — PRE-REGISTERED (doc21) بانتظار مراجعة المالك قبل fixtures+عدّاء
- **Owner:** ox-alpha
- **Dependencies:** TASK-032 (Coverage Mapping CONFIRMED), TASK-031 (Planning Gate 1)
- **Acceptance Criteria:**
  - [ ] doc21 rev.1 معتمدًا حرفيًا (§1 عقد predict · §2 N=3 خطي بلا branching/search/cost · §3 tripwire DEFERRED-7 · §4 TP1..TP10 بأرقام bitwise مثبتة حسابيًا)
  - [ ] fixtures مطابقة لـ4.1 حرفًا + HypotheticalSim stub بلا تعديل kernel/handlers
  - [ ] أرشفة runNN.log إلزامية لكل تشغيل وسيط
  - [ ] PASS 10/10 ⇒ transcript+SHA256 مضمّنة + سطر commit-scope ⇒ PROVISIONAL→CONFIRMED بختم المالك
- **Evidence:** [`21-Planning-Specification-v01.md`](file:///c:/tmp/maestro%20engine/21-Planning-Specification-v01.md)
