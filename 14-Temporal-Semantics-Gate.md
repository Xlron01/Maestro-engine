# 14 — Temporal Semantics Gate

> **وثيقة تسجيل مسبق — صفر كود، صفر Kernel، بلا تحليل تطبيقي بعد.**
> البوابة مفتوحة بتوقيع صاحب المشروع. التحليل التطبيقي لا يبدأ إلا بإشارته.
>
> **السؤال الأنطولوجي المجمد:**
>
> **هل الزمن Primitive مستقل (Temporal State object) ولا هو بُعد إضافي على الـ Entities/Relationships الموجودة (timestamps + duration fields)؟**
>
> **المنهجية:** نفس منهج Gates 08/09/11 — تسجيل مسبق ⇒ تحليل تطبيقي ⇒ Confirmed/Rejected/Open.
>
> **قاعدة الحدود:** إن ظهر متطلب زمني غير قابل للتمثيل بهذه الآليات ⇒ **Open Question فقط**: «Content Schema requires unresolved temporal semantics» ⇒ إغلاق البوابة بما ثبت ⇒ تصميم Temporal Semantics = Gate مستقل لاحقًا.

---

## 1) السياق — لماذا هذه البوابة الآن؟

- **Gate 2** أثبت أن القرارات المتسلسلة محتاجة حالة زمنية (Initiative من سجل نتائج).
- **TransitDependency** تستخدم مدة عبور (duration field) — تعمل event-driven ✓.
- **ReservesDays/LeadTimeTable** عدادات تراكمية عبر الزمن — تعمل event-driven ✓.
- **OS-5 Seasonal Cycle**: ممرات تغلق موسميًا — ScheduledJob يمكنه تحديث حقائق عند T محدد ✓.
- **لكن**: هذه الحالات اختبرت فرديًا. السؤال: هل هناك نمط زمني جماعي/مستمر يتطلب بنية جديدة؟

---

## 2) Counterexamples المسجلة (5 — قابلة للتعديل قبل التحليل)

| # | السيناريو | السمة الزمنية المطلوبة | مصدر واقعي |
|---|---|---|---|
| TS-1 | TransitDependency — مدة نقل شحنة عبر ممر | Duration فقط | قوافل الأطلسي: مدة العبور تحدد التعرض |
| TS-2 | ReservesDays + LeadTimeTable — تراكمي عبر الوقت | History + accumulation | احتياطي النفط ينقص بالاستهلاك ويزيد بالإنتاج |
| TS-3 | Initiative/Momentum — معدل تغيّر نسبي عبر آخر N أحداث | Rolling window metric | هجوم الربيع 1918: الزخم انعكس عند الاستنزاف |
| TS-4 | Seasonal cycle — ممرات تغلق وتفتح سنويًا | Periodic modifier | ممرات الهيمالايا / مواسم الإعصار |
| TS-5 | Decay function — أثر حدث يضعف بمرور الوقت | Time-decay on derived value | أثر Agent_Exposed على الاستقرار يقل مع مرور الشهور |

## 3) القواعد

1. التوقعات المسجلة قبل التحليل (hypotheses قابلة للكسر).
2. لا Primitive جديد لمجرد الراحة — يثبت فشل البديل الأضيق أولًا.
3. Definition / Runtime State / Historical Change تبقى مفصولة.
4. أي سيناريو كسر توقع ⇒ توقف وتسجيل فوري.
5. لا كود قبل إغلاق البوابة.

## 4) حالة البوابة

⏸️ **OPEN — بانتظار إشارة صاحب المشروع لبدء التحليل التطبيقي.**

⛔ **توقف هنا — لا تحليل، لا كود، لا تنفيذ.**

---

**Evidence trail:** Gate 2 (11) + Content Ontology (12) + Model v1 FROZEN (10) + هذا الملف.
