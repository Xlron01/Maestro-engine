# Memory Protocol Specification — بروتوكول الذاكرة

يحدد هذا المستند الـ Contracts والهياكل الإلزامية لجميع مستندات "ذاكرة المشروع" لضمان إمكانية قراءتها والتحقق منها آلياً بواسطة الـ Memory Validator.

---

## 1) State Document Contract (`.ai/state.md`)

يجب أن يحتوي ملف الحالة الحالية حصراً على الأقسام التالية:
- `# CURRENT STATE`
- `## Metadata`: (تاريخ التحديث، المرحلة الحالية، الخطوة الحالية).
- `## Current Objective`: الهدف النشط الذي يتم العمل عليه.
- `## Active Tasks`: قائمة بالمهام الجارية مع معرفاتها (Task IDs).
- `## Blockers & Known Risks`: المعوقات والمخاطر المعمارية الحالية.
- `## Next Recommended Actions`: الخطوات القادمة المقترحة.
- `## Known Bugs & Temporary Hacks`: العيوب التقنية والحلول المؤقتة النشطة.

---

## 2) Task Document Contract (`.ai/tasks/*.md`)

يجب كتابة المهام بـ Task IDs فريدة بصيغة `TASK-[0-9]{3}`. هيكل المهمة الإلزامي:

```markdown
### [TASK-XXX] Title

- **Status:** [Allowed: PENDING, IN_PROGRESS, BLOCKED, REVIEW, COMPLETE, CANCELLED]
- **Owner:** [Model name / Agent name]
- **Dependencies:** [None / Other Task IDs]
- **Objective:** [Brief goal]
- **Acceptance Criteria:**
  - [ ] Criterion 1
  - [ ] Criterion 2
- **Validation Method:** [Test command / Manual process]
- **Evidence:** [File link to raw output / Git commit hash]
```

---

## 3) Handoff Document Contract (`.ai/handoffs/latest.md`)

مستند التسليم والتسلم الإلزامي عند انتهاء النوبة وتغيير الموديل:

```markdown
# Handoff

- **Date:** [YYYY-MM-DD]
- **From Agent:** [Model/Agent Name]
- **Current Task:** [Task ID]

## 1. Summary of Completed Work
- Detail 1
- Detail 2

## 2. Changed Files & Modifications
- [File Name](file:///path/to/file)

## 3. Test & Validation Evidence
- **Test Command:** `command`
- **Exit Code:** `[0 / 1]`
- **Result:** [PASS / FAIL]
- **Raw Evidence Link:** [Link to log in evidence/tests/]

## 4. Known Blocker / Problems Encountered
- Detail

## 5. Decisions Made
- Detail (reference to decisions/ if any)

## 6. Next Recommended Actions
- Detail
```

---

## 4) Decision Document Contract (`.ai/decisions/*.md`)

ملفات القرارات المعمارية يجب تسميتها بصيغة `[0-9]{3}-[slug].md` وهيكلها:

```markdown
# Decision [XXX]: [Title]

- **Date:** [YYYY-MM-DD]
- **Status:** [PROPOSED / ACCEPTED / REJECTED / SUPERSEDED]

## Context
سياق ودوافع المشكلة والخيارات المتاحة.

## Decision
القرار الفني المتخذ بالتفصيل.

## Consequences
الآثار المعمارية والتقنية المترتبة على القرار.

## Rejected Alternatives
البدائل التي تم دراستها ورفضها وأسباب الرفض.
```
