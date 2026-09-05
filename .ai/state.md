# CURRENT STATE

## Metadata
- **Last Updated:** 2026-09-05
- **Current Phase:** T5-C Storm Root-Cause — **DONE (الجذر: EventQueue.push_event = 99.2-99.5% من العاصفة؛ C1=PASS بـ−99.8%؛ بانتظار الختم)**
- **Current Step:** توقف — قرار الترحيل (T5-D مقترح لـEventQueue) قرار المالك حصريًا

## Current Objective
تفكيك عاصفة mass-synchronous workload (T5-P0) على الحمل الحقيقي بلا تعديل نواة، وإصلاح المكوّن المقاس فقط. النتيجة: الجذر = إعادة الفرز الكامل داخل EventQueue.push_event (99.2-99.5% من زمن العاصفة) وليس المجدول (≤0.3%). المرشّح C1 (BatchedEventQueue تجريبي) حقق −99.8% عواصف مع بوابات bitwise PASS. أرقام T5-B العاصفية أُعيد تأسيسها بأساس رسمي منزوع القياس (OSB=191/180/176s).

## Active Tasks
- `T5-C`: Storm Root-Cause & Measured-Bottleneck-Only Fix. (Status: COMPLETE, Evidence Saved, PROVISIONAL)
- `T4.5`: Scale Optimisation (Neighborhood Caching). (Status: COMPLETE, Evidence Saved, PROVISIONAL)
- `T3-Phase 2`: Economy Feedback & Reusability. (Status: COMPLETE, Evidence Saved, PROVISIONAL)
- `T3-Phase 1`: Economy Representability Gate. (Status: COMPLETE, Evidence Saved, PROVISIONAL)
- `T4`: Instrumentation Breakdown. (Status: COMPLETE, Evidence Saved, CONFIRMED)
- `T2`: Simulation Scale Stress Test. (Status: COMPLETE, Evidence Saved, PROVISIONAL)
- `TASK-034`: Generalization Gate. (Status: COMPLETE)
- `TASK-030`: Evaluation Specification v0.1 + Test E. (Status: COMPLETE)
- `TASK-004..029`: السلسلة السابقة. (موثقة)

## Blockers & Known Risks
- لا يوجد معوقات. الـ DI يمثل عنق زجاجة عند N >= 10K وتم تحذير المطورين المعماريين لتجنب دمجه في tick الساخن دون جدولة.
- بيئة التشغيل: Godot الفعلي داخل مجلد اسمه exe: `C:\Users\ahmed\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`.

## Next Recommended Actions
1. قرار المالك: ترحيل نمط BatchedEventQueue إلى EventQueue.gd (T5-D مقترح — ملف نواة واحد) مع حسم سياسة روابط الأحداث المتساوية الزمن ودراسة الذاكرة.
2. إعادة تقييم حكم T5-B على Bucket (فوز quiet حقيقي 77×؛ فائدة العاصفة غير متكوّرة على الأساس المصحح).
3. اعتماد `test_t5c_storm_lab.gd --phase=e0 --probe=off` كمرجع regression دائم للعاصفة.

## Known Bugs & Temporary Hacks
- **لا يوجد دين تقني متبقٍ في النواة:** جرد TASK-013 صُفّر؛ D1/D2 لم يلمسا Kernel إطلاقًا.
- **درس D1 الموثق (rev.1→rev.2):** عقد تجميع يُصفّر الخيارات عديمة القنوات بنيويًا (`raw×boost`) + قناة access تتطلب transit_dependency على الفاعل — موثق في سجل مراجعة doc 16.
- **تحذيرات الخروج في Godot:** تسريب بعض كائنات ObjectDB عند خروج السكريبتات المستقلة `SceneTree.quit()` (سلوك موروث pre-existing baseline).
