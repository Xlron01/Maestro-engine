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

> **⚠️ Cross-reference:** P3 (Limited-Lifetime Rule) من CE-4 Stress Test مصنف "Confirmed provisionally — pending Temporal Gate outcome" — يعاد اختباره بعد إغلاق هذه البوابة.

⛔ **توقف هنا — لا تحليل، لا كود، لا تنفيذ.**

---

## 3) التحليل التطبيقي

✅ **مفتوح بتوقيع صاحب المشروع.**

### منهجية التحليل

كل TS يُحلل عبر السؤال الأنطولوجي: **هل يحتاج Temporal State object مستقل، أم يكفي timestamp/duration field على البنى الموجودة؟** مع اختبار الحذف وفحص المقنّع.

---

### TS-1 — TransitDependency Duration

**السيناريو:** شحنة تحتاج N يومًا للعبور عبر ممر.

**التمثيل بالحقائق الموجودة:**
- `transit_dependency` يخزن حصة الاعتماد (scalar)
- مدة العبور = `leadtime_months` في config أو `duration_days` على الحافة
- SimClock يعدّ الأيام؛ الوصول = حدث عند T+duration

**هل يحتاج Temporal State object؟** لا — المدة رقم ثابت على العلاقة، والوصول حدث مؤرخ. لا تتبع لحظي لـ"أين الشحنة الآن" في نطاق Relevance.

**الحكم:** ✅ **Timestamp/duration field يكفي** — لا Primitive.

---

### TS-2 — Reserves Accumulation

**السيناريو:** احتياطي النفط ينقص بالاستهلاك اليومي ويزيد بالإنتاج.

**التمثيل:**
- `reserves_days` scalar يتحدث كل tick: `-consumption_rate +production_rate`
- التاريخ الكامل موجود في EventQueue log إذا احتجت مراجعة

**هل يحتاج Temporal State object؟** لا — عدّاد تراكمي (R1) يتحدث event-driven/tick-driven. لا حاجة لتاريخ زمني منفصل.

**الحكم:** ✅ **Scalar counter + tick updates تكفي** — لا Primitive.

---

### TS-3 — Initiative/Momentum

**السيناريو:** معدل تغيّر نسبي محسوب من آخر N نتائج معارك.

**التمثيل:**
- سجل النتائج موجود في EventQueue history (موجود)
- المقياس المشتق: دالة على آخر N أحداث — يُحسب عند الاستعلام لا يُخزَّن

**هل يحتاج Temporal State object؟** لا — Derived metric من سجل أحداث موجود. النافذة الزمنية (آخر N) بارامتر config.

**الحكم:** ✅ **Derived rolling metric from existing event history** — لا Primitive.

---

### TS-4 — Seasonal Cycle

**السيناريو:** ممرات تغلق موسميًا (نوفمبر-مارس).

**التمثيل:**
- ScheduledJob سنوي يغير `transit_dependency[route][cap]` عند T=Nov وT=Apr
- SimClock يوفر day/month/year للمقارنة

**هل يحتاج Temporal State object؟** لا — ScheduledQueue + حقائق تتحدث عند T. لا حاجة لكائن "فصل/موسم" مستقل.

**الحكم:** ✅ **ScheduledJob + SimClock يغطيان الدورة** — لا Primitive.

---

### TS-5 — Decay Function

**السيناريو:** أثر Agent_Exposed على الاستقرار يضعف بمرور الشهور.

**التمثيل بالحقائق الموجودة:**
- Option 1: ScheduledJob شهري يخصم مقدارًا متناقصًا من الاستقرار حتى يصل صفر
- Option 2: عند أي استعلام، احسب decay من `current_day − exposure_day`

**هل يحتاج Temporal State object؟**
- Option 1: لا — مجدول job يحدّث حقfact موجودة
- Option 2: لا — حساب من timestamp delta يستخدم SimClock الموجود

**الحكم:** ✅ **Event-driven updates OR timestamp-delta computation** — كلاهما يعمل بلا Primitive.

---

### جدول التصنيف النهائي

| # | Counterexample | التصنيف | الآلية المستخدمة |
|---|---|---|---|
| TS-1 | Transit duration | ✅ Timestamp/duration field | SimClock + EventQueue |
| TS-2 | Reserves accumulation | ✅ Scalar counter + tick | R1 عدادات تراكمية |
| TS-3 | Initiative rolling metric | ✅ Derived from event history | EventQueue + config window |
| TS-4 | Seasonal cycle | ✅ ScheduledJob toggle | SimClock month/year |
| TS-5 | Decay function | ✅ Event-driven OR timestamp delta | SimClock delta |

---

## 4) الحكم النهائي

> **الزمن ليس Primitive مستقل في نطاق Content Ontology.**
>
> كل الاحتياجات الزمنية الخمسة تُلبى بآليات موجودة (SimClock + EventQueue + ScheduledQueue + scalar fields + R1 counters) دون بنية جديدة.
>
> **Gate CLOSED — No temporal primitive required at Content Schema level.**

**⚠️ Cross-reference:** P3 من CE-4 Stress Test (Confirmed provisionally — pending this gate) **يُعاد تأكيده**: النتيجة صامتة لأن P3 يستخدم scalar fields (start_day/end_day) وليس Temporal Primitive ⇒ P3 يبقى Confirmed نهائيًا.

---

---

**Evidence trail:** Gate 2 (11) + Content Ontology (12) + Model v1 FROZEN (10) + هذا الملف.
