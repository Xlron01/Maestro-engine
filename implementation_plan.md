# T3-Phase 2 — Implementation Plan
## Investment, Feedback Loop, and Reusability

---

## 1. الأهداف والنطاق (Scope)

الهدف من Phase 2 هو تعريض المحرك (Engine) لاختبارات أعمق تكشف حدود دلالات الحالة المستمرة (Continuous State) وإعادة استخدام الأنظمة الاقتصادية:

1. **Investment (الاستثمار):**
   - قدرة الدول على استخدام الفوائض (wheat/iron أو النقد) لرفع قدراتها الإنتاجية (أو البنية التحتية) دورياً.
2. **Feedback Loop (التأثير المتبادل):**
   - **من الاقتصاد إلى النواة:** العجز في السلع الأساسية (EC-8 Shortages) يقلل استقرار الدولة (`stability`) ويفعّل استيقاظها الحركي في الـ Activation Set.
   - **من النواة إلى الاقتصاد:** انخفاض الـ `stability` (بسبب Election أو Coup) يقلل الكفاءة الإنتاجية (Production rates) بنسبة مئوية.
3. **Multi-Instance Reusability (إعادة الاستخدام):**
   - إدخال نظام اقتصادي ثانٍ مبسط ومستقل تماماً (مثلاً: `Economy v2` لإدارة سلعة واحدة فقط كـ "coal" وبأرقام مغايرة) للتأكد من أن الـ engine يستطيع تشغيل مثيلين (Instances) معزولين حسابياً وفي نفس الوقت دون تداخل أو تخريب في الـ State.

---

## 2. التصميم المعماري والعزل (Isolation)

تُطبّق نفس ضوابط العزل الصارمة من Phase 1:
- **ملفات النواة الـ 9 المحمية:** ممنوع لمسها نهائياً.
- **ملفات الـ content المسموح تعديلها كـ Engine Touches (تحت بند C1):**
  - [`scripts/game_event_handlers.gd`](file:///c:/tmp/maestro%20engine/scripts/game_event_handlers.gd) (لإضافة delegation للـ v2 وللـ feedback).
  - [`data/rules/dispatch.json`](file:///c:/tmp/maestro%20engine/data/rules/dispatch.json) (لتسجيل الـ ticks الجديدة).
- **مكان كود المنطق الجديد:**
  - `economy/economy_v2_handlers.gd` (للنظام الاقتصادي الثاني).
  - `economy/economy_v2.json` (بيانات النظام الاقتصادي الثاني).
  - إضافات منطق الـ Feedback والـ Investment تعيش بالكامل داخل `economy/economy_event_handlers.gd` (موديول الاقتصاد الأول) أو في موديول مستقل يتبع الـ delegation.

---

## 3. الـ Collision Protocol و الـ Stop Rules

سنلتزم بنفس قالب الـ Collision وتسجيله للتوجيه المعماري:
- **الحد الأقصى للـ Logic LOC الإضافي في Phase 2:** `500` سطر (للمنطق الجديد المضاف في Phase 2 فقط، غير تراكمية مع أسطر Phase 1).
- **الحد الأقصى للتعارضات (Collisions):** `5` تعارضات جديدة.
- **الـ STOP-3:** يتفعل فوراً عند أي احتياج لتعديل النواة.

---

## 4. تصميم الـ Feedback Loop الحركي (قراءة وكتابة)

لضمان أقصى درجات العزل الدوميني والحفاظ على حتمية وموثوقية النواة:
1. **اتجاه القراءة (من النواة للاقتصاد):**
   - موديول الاقتصاد يقرأ حقول النواة مثل `stability` مباشرة عبر `sim.world.countries[id]["stability"]` (اتجاه قراءة فقط محايد ومسموح به تماماً كـ C1).
2. **اتجاه الكتابة (من الاقتصاد للنواة):**
   - **ممنوع منعاً باتاً** قيام موديول الاقتصاد بالكتابة المباشرة في حقول النواة الأساسية.
   - عند حدوث عجز (Shortage)، يقوم موديول الاقتصاد بدفع حدث اقتصادي مخصص `Economy_Shortage_Occurred` للـ EventQueue التابعة للمحرك.
   - يتم التقاط هذا الحدث وتحديث الـ `stability` من داخل طبقة المحتوى المعتمدة للـ engine وهي [`scripts/game_event_handlers.gd`](file:///c:/tmp/maestro%20engine/scripts/game_event_handlers.gd) (عبر delegation بسيط)، مما يحافظ على مبدأ "نقطة تعديل واحدة فقط" لـ Core State.

---

## 5. خطة التحقق والـ Verification Plan

سنقوم بكتابة سكريبت اختبار مخصص للـ Phase 2:
`scripts/test_t3_economy_phase2.gd`

### الاختبارات المؤتمتة المطلوبة:
1. **EC2-1 (Investment):** التحقق من أن الدولة ذات الفائض المالي/السلعي ارتفعت معدلات إنتاجها بعد عدد معين من التيكات مقارنة بالـ baseline.
2. **EC2-2 (Feedback - Economy to Core):** التحقق من أن حدوث عجز (Shortage) يتبعه انخفاض مبرهن وحتمي في الـ `stability` الخاصة بالدولة.
3. **EC2-3 (Feedback - Core to Economy):** التحقق من أن تدهور الـ `stability` لسبب خارجي (مثل Election) يتبعه انخفاض حتمي في معدلات الإنتاج الفعلي.
4. **EC2-4 (Reusability):** تشغيل النظامين الاقتصاديين (v1 و v2) معاً والتحقق من أن مخزونات سلعة الـ coal في v2 معزولة بالكامل، ولا تظهر أو تتداخل مع Wheat/Iron in v1.

---

## 6. مخرجات البوابة المتوقعة

- `economy/economy_v2_handlers.gd` & `economy/economy_v2.json`
- `.ai/evidence/tests/test_t3_economy_phase2_run01.log` (السجل الخام المتوقع)
- `25-Economy-Feedback-Reusability.md` (التقرير المعماري للبوابة الثانية)

