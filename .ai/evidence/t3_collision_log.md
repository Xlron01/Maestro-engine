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
