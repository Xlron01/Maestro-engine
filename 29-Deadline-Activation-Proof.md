# 29 — TASK-040-pre: Minimal Deadline Activation Proof

> **الحالة:** COMPLETE (PROVISIONAL — بانتظار مراجعة المالك قبل TASK-040) · **Owner:** ox-alpha
> **النطاق:** أدنى بنية إنتاجية لإثبات deadline-driven political activation — إعادة استخدام SimClock/ScheduledQueue/pipeline القائمة، لا مجدول ثاني، لا T5-D، لا periodic reassessment.

## 1) Implementation Summary
- **التمثيل الإنتاجي** (`scripts/politics/political_deadlines.gd` + حقول في `political_state.gd`): سجل دائم `{deadline_id, deadline_type, owner, due_at, scheduled_at, status, actual_activation_at, resolved_at, lateness_days, activation_count, payload, resolution}` — الـdeadline المستحق **لا يختفي بصمت** (status lifecycle: scheduled → due → activated → resolved).
- **الأهلية**: `current_simulation_day >= due_at` عبر **instance من ScheduledQueue النواة نفسه** (`state.deadline_queue` — قبول A7 يتحقق `is ScheduledQueue`)؛ لا آلية جدولة ثانية.
- **التنشيط**: `pump(state, day, rules, actions, ctx)` — يُستدعى بعد كل tick محاكى (نقطة الدمج الموثقة في الـorchestrator؛ لم يُمسّ production run_step). تصريف حتى الاستقرار داخل اليوم (حد 8 جولات حتمي) حتى تكتمل السلسلة السببية المشتقة في ضخّة واحدة.
- **الملكية (A6)**: التنفيذ عبر `PoliticalActions.execute` القائم (HoldElection) — صفر كتابة حالة مباشرة من الـdeadline path.
- **السببية عبر القواعد فقط (A4)**: `government_term_days` ⇒ جدولة dl_term عند FormGovernment (hook مشروط بالقاعدة — لا تغيير دلالي حيث لا قاعدة)؛ عند الاستحقاق: `term_expiration_causes_election` ⇒ إنشاء `election_due` + تنفيذه عند استحقاقه، وإلا `no_election_required_per_rules` بلا اختلاق.
- **النوع الثاني v1**: `election_due` يُجدول مستقلًا أيضًا (مثبت T3 — ليس hardwired لانتهاء المدة).

## 2) الملفات
- إنتاجية: `scripts/politics/political_deadlines.gd` (جديد) · `political_state.gd` (+deadlines/queue/stats +serialization) · `political_actions.gd` (hook مشروط في FormGovernment فقط) · `data/worlds/politics/deadline_proof.json` (fixture معلن: **test fixture value — not production game-balance**: term=30d, due=30, call=0, horizon=45).
- اختبار: `scripts/test_politics_deadlines.gd` (tests-first).
- **صفر تعديل نواة** (التسعة + Simulation/EventQueue لم تُمس).

## 3) القبول A1–A7 — **PASS 17/17** (`test_t040pre_deadlines_run01.log`)
| البند | الفحص | النتيجة |
|---|---|---|
| A1 | لا تنشيط قبل يوم 29؛ التنشيط يوم 30 بالضبط (lateness=0) | PASS |
| A2 | كل الـdeadlines المطلوبة resolved عند الأفق؛ صفر تعليق صامت | PASS |
| A3 | activation_count=1 لكل deadline؛ duplicates=0 (منع بنيوي: unregister بعد المعالجة) | PASS |
| A4 | term→election أنشأ deadline الانتخابات (due=30)؛ بدون القاعدة: `no_election_required` بلا اختلاق | PASS |
| A5 | canonical SHA-256 ×2 متطابق: `29841b42…67cb2f4` | PASS |
| A6 | التنشيط عبر pipeline (تقييم HoldElection واحد) + أحداث DeadlineActivated/Resolved | PASS |
| A7 | `deadline_queue is ScheduledQueue` + audit مصدري (لا polling/rng/engine-coupling) | PASS |
| مستقل | election_due مجدول بمعزل عن المدة فعّل يوم 10 ونفّذ انتخابًا | PASS |

## 4) البذرة/التكوين والأوراكل
- Workload حتمي صفر-RNG (seed: N/A — التثبيت يعلن انعدام العشوائية صراحة)؛ تكوين من `deadline_proof.json`.
- Canonical snapshot: حالة سياسية دلالية فقط (بلا عناوين ذاكرة/عدادات تشخيص) — **`29841b4297c7b9ffe8f0591ff37b3e8f2545b6221669360ab74b7e25b67cb2f4`** متطابق عبر التشغيلات.

## 5) التشخيصات المسجلة (§11)
scheduled=2 · due=2 · activated=2 · resolved=2 · duplicates=0 · lateness_max=0 · queue_size=0 عند الأفق · 45 يوم محاكاة عبر SimClock الإنتاجي · تقييمات سياسية داخل الإنتاج run_step = 0 (التنشيط من pump الخارجي فقط).

## 6) Regression — تشغيل ما بعد التعديلات
(مرفقة في تقرير التسليم: 8 أجنحة EXIT=0 + t5c ببوابات bitwise.)

## 7) الفجوات المعمارية المكتشفة
1. **نقطة الدمج**: pump خارجي للـorchestrator في الإثبات؛ الإدماج الدائم في run_step سيكون قرار TASK-040 (لا يزال صحيحًا دون تغيير).
2. قيم العرض (عرض/تعديل lateness كsemantic) مؤجلة — تشخيصية هنا كما نصت المواصفة.
3. `government_term_days` غير موجودة في قواعد batch-a الافتراضية (عن قصد — عدم تغيير دلالة TASK-039)؛ التمكين عبر القاعدة فقط.

## 8) التوصية
المالك يراجع الإثبات ثم يقرر فتح TASK-040 (Actor Runtime validation) — **لا انتقال تلقائي**.
