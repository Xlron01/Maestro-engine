# T3-Phase 1 — Collision Log

## COLLISION #1 — Single-Script Dispatch

```
COLLISION #1
- Requirement: Economy event/job handlers يتسجلوا في dispatch loop
- Attempted representation: economy_event_handlers.gd كملف مستقل بدون تعديل baseline
- Result: Simulation.gd يدعم handlers_script واحد فقط (L196-204)؛
  لا توجد دالة register_job_handler() أو extension point رسمي.
  الوصول المباشر لـ sim._job_handlers (underscore = private convention)
  رُفض من المراجع كـ"engine touch مقنّع" أخطر من التعديل الصريح.
- Preliminary classification: C1
- Rationale: الاحتياج يُحلّ بـ composition داخل البنية الحالية (delegation pattern)
  بدون تعديل منطق أي ملف baseline. التعديلات المطلوبة هي:
  (1) 4 أسطر delegation في game_event_handlers.gd
  (2) سطر تسجيل واحد في dispatch.json
  كلاهما ENGINE TOUCH مرئي ومُسجَّل، لا يُغيّر أي منطق baseline قائم.
- Evidence: Simulation.gd L196-204, dispatch.json L1-3, game_event_handlers.gd L17-18
- Final classification: C1 (بقرار المراجع — 2026-08-27)
```

### ENGINE TOUCH #1 — game_event_handlers.gd
- **الملف:** `scripts/game_event_handlers.gd`
- **نوع التعديل:** إضافة 4 أسطر delegation نقية (صفر منطق دومين)
- **السطور المضافة:** const preload + var instance + 2 في setup() + دالة delegation لكل handler اقتصادي
- **سبب الضرورة:** dispatch.json يربط job/event names بـ methods على _content_handlers فقط

### ENGINE TOUCH #2 — dispatch.json
- **الملف:** `data/rules/dispatch.json`
- **نوع التعديل:** إضافة entry واحد في job_handlers لتسجيل اسم job_economy_tick
- **سبب الضرورة:** _load_dispatch() يبني _job_handlers من dispatch.json فقط؛
  أي job_name غير مسجل يُسقط صامتاً في _run_scheduled_job()
- **المحتوى قبل:** job_handlers بـ 5 entries
- **المحتوى بعد:** job_handlers بـ 6 entries (+ "economy_tick")

---

## T3-Phase 2 — Collision Log

## COLLISION #2 — Core State Write-Access Boundary

```
COLLISION #2
- Requirement: التفاعل الاقتصادي (shortage) يحتاج إلى تعديل حقل الـ stability في WorldState (Core State).
- Attempted representation: تعديل stability للدولة المتضررة مباشرة من داخل موديول الاقتصاد (economy_event_handlers.gd).
- Result: الكتابة المباشرة في حقول WorldState من موديول خارجي غير مسموحة معماريًا للحفاظ على عزل النواة ومنع التداخل المباشر.
- Preliminary classification: C1 (Architectural Constraint).
- Rationale: حُلّ التعارض بتوجيه الكتابة من خلال Event Queue:
  (1) موديول الاقتصاد يدفع حدث "Economy_Shortage_Occurred" بالبيانات المطلوبة.
  (2) النواة المخوّلة (game_event_handlers.gd) تلتقط الحدث وتعدّل stability للدولة المعنية.
  هذا يحمي عزل الاقتصاد تمامًا ويبقي التعديل خاضعًا لسيطرة المحرك.
- Evidence: economy_event_handlers.gd (_detect_shortages()), game_event_handlers.gd (evt_economy_shortage_occurred())
- Final classification: C1 (معتمد بقرار المراجع — 2026-08-27)
```

### ENGINE TOUCH #3 — game_event_handlers.gd (Phase 2 Additions)
- **الملف:** `scripts/game_event_handlers.gd`
- **نوع التعديل:** إضافة delegation لـ economy_v2 + handler معالجة حدث الـ shortage.
- **سبب الضرورة:**
  1. تمرير `job_economy_v2_tick` للـ Coal Handler المستقل.
  2. استقبال `Economy_Shortage_Occurred` وتعديل stability للدولة بشكل رسمي بدلاً من الكتابة المباشرة من الاقتصاد.

### ENGINE TOUCH #4 — dispatch.json (Phase 2 Additions)
- **الملف:** `data/rules/dispatch.json`
- **نوع التعديل:** إضافة "economy_v2_tick" في job_handlers و "Economy_Shortage_Occurred" في event_handlers.
- **سبب الضرورة:** تسجيل الدوال المقابلة في الـ Registry لتمكين المحاكاة من عمل dispatch لها.

