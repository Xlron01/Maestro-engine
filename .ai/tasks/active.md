# Active Tasks

قائمة المهام النشطة الجاري العمل عليها حالياً في المشروع.

---

### [TASK-034] Generalization / Behavioral Validation Gate + Test G

- **Status:** IN_PROGRESS — PRE-REGISTERED (doc22) بانتظار مراجعة المالك قبل بناء Planner+عدّاء
- **Owner:** ox-alpha
- **Dependencies:** TASK-033 (Spec v0.1 PASS 11/11), TASK-031 (التزام doc19 §6)
- **Acceptance Criteria:**
  - [ ] doc22 rev.1 معتمدًا: تعديلات A1 (تعداد DFS ≤3 بترتيب §7، سقف 64) + A2 (تكلفة معلنة كسر-تعادل فقط) بمبررات rule-11
  - [ ] الـ9 fixtures بثوابتها المجمدة، **بلا أي حل داخل fixture** (G-audit آلي)
  - [ ] G1..G9 + G-det/G-pure/G-audit/G-greedy/G-cost/G-prune كلها PASS بنصوصها المجمدة
  - [ ] أرشفة runNN إلزامية · deg/degree · transcript+SHA256 مضمّنة عند الإغلاق · PROVISIONAL حتى ختم المالك
- **Evidence:** [`22-Generalization-Gate.md`](file:///c:/tmp/maestro%20engine/22-Generalization-Gate.md)
