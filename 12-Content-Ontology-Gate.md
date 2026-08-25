# 12 — Content Ontology Gate: Minimal Ontology for FROZEN Relevance Model v1

> **وثيقة حسم — صفر كود، صفر Kernel.**
> تتبع مباشرة لـ Decision Semantics Gate 2 (وثيقة 11 — CLOSED: Confirmed Principle) وStrategic Relevance Model v1 (وثيقة 10 — FROZEN).
>
> **⚠️ نطاق الحكم:** هذه الوثيقة تثبت أن العائلات الثمانية **كافية لتشغيل Relevance Model v1 المجمد حصرًا** — وليست ادعاءً بأنها كافية لمحرك Grand Strategy كامل. فجوات النطاق الأوسع موثقة في [13-Ontology-Sufficiency-Gate.md](13-Ontology-Sufficiency-Gate.md).

---

## 0) Boundary Rule الحاكمة (قرار صاحب المشروع — مجمد)

**CE-5 (الزمن) له قاعدة حدود خاصة:**

> إذا أظهر التحليل أن التمثيل الزمني يحتاج Primitive مستقل:
> - ❌ لا يُفتح هذا السؤال داخل Gate الـ Content.
> - ❌ لا تصميم Temporal Primitive ولا حسم Semantics الزمن هنا.
> - ✅ يُسجل النتيجة فقط كـ **Open Question**: «Content Schema requires unresolved temporal semantics».
> - ✅ يُغلق Gate الـ Content بما ثبت حتى تلك النقطة.
> - ✅ تصميم الـ Temporal Semantics يصبح موضوع **Gate مستقل لاحقًا**.

**السبب:** هدف Gate الحالي هو تحديد **أقل Ontology للـ Content**، وليس حل Temporal Model بالكامل — وإلا سنعيد مشكلة الـ 12 فرضية التي تجنبناها في Decision Semantics.

### الشكل المتوقع للمخرج النهائي

```
Content Ontology
      ↓
Confirmed
      │
      ├── Temporal Semantics → Open → Gate مستقل (إن لزم)
      │
      └── Decision Semantics → لاحقًا
```

## 1) القواعد الإلزامية (مجمدة في `.ai/tasks/active.md` — TASK-024)

1. التسجيل المسبق للتوقعات (hypotheses قابلة للكسر).
2. 5 Counterexamples فقط.
3. لا Primitive جديد لمجرد الراحة.
4. Definition / Runtime State / Historical Change تبقى مفصولة.
5. Confirmed / Rejected / Open إلزامية — بلا خليط.
6. أي CE يكسر التوقع ⇒ إيقاف التوسع والتسجيل فورًا.
7. لا كود قبل إغلاق الـ Gate.

---

## 2) التسجيل المسبق — القائمة المعتمدة من المالك (2026-08-25 — مجمدة)

> ملاحظة المالك على القائمة الأولى: كانت في معظمها اختبارات قدرات Kernel مُثبتة
> (Entity+Mutable State, Scheduling, Propagation, Save/Load — كلها Phase 6 PASS)
> ولا تضغط على سؤال الـ Ontology. القائمة أدناه تجبر على محاولة تمثيل Content مختلف:
> هل النموذج الأبسط يستوعبه أم يحتاج Primitive؟ — بنفس منطق اختبارات 08/09.
>
> الدرس الحاكم (درس HostileControl): نبدأ من Observation من العالم ← نحدد الـ primitive
> الضروري ← وبعدها فقط نسمّي الـ domain concept. ليس العكس.

القدرات التمثيلية المسموح افتراضها (موروثة من Gate 2 — شروط اعتماده):

| الرمز | القدرة |
|---|---|
| **R1** | تاريخ دائم (عدادات تراكمية كحقائق محفوظة) |
| **R2** | حالة مؤقتة مؤرخة (مَن/أين/متى) |
| **R3** | سجل حقائق/التزامات علنية |

السؤال الحاكم:

> ما أقل مجموعة Primitives يمكنها وصف العالم الذي يحتاجه Grand Strategy Engine،
> قبل تسمية أي شيء باسم Country / Resource / Event / Goal؟

### الفصل الإلزامي داخل كل تحليل

كل CE يُحلل عبر الفصيلة الثلاثية المجمدة: **Definition / Runtime State / Historical Change**
— ولا يجوز خلط مستوى بأخر لإعلان اختزال.

| # | Counterexample | صيغة التوقع المجمدة (قابلة للكسر) |
|---|---|---|
| **CE-1** | دولة + كيان غير دولتي + مورد | Likely reducible إلى Entity عام واحد قاموسي (kind كسمة data لا نوع). **يفشل التوقع** إذا ظهرت عملية أو قيد تمثيل يتطلب فروقًا بنيوية بين Country/Organization/Resource لا يمكن حملها كبيانات |
| **CE-2** | علاقة تتغير عبر الزمن: تحالف 1950→1960 ثم انتهاؤه | Test reducibility — المرشح الأضيق: Edge موزون بين كيانين + سجل تغيّره (R1/R3). **يفشل** إذا احتاجت العلاقة نفسها هوية/حالة/سلوكًا مستقلًا عن طرفيها لا يمكن تمثيله كحقائق مؤرخة على الزوج (L2 Pair-Indexing) |
| **CE-3** | حدث يغيّر عدة كيانات: Coup / اكتشاف مورد / توقيع اتفاق | Likely reducible — Historical Change كسجل حقائق (R3) + propagation rules data-driven. **يفشل** إذا ظهر حدث يحتاج وجودًا مستمرًا بعد وقوعه (شيء يتصرف/يتغير) لا يمكن تفكيكه إلى سجل + حالات ناتجة |
| **CE-4** | حقيقة مشتقة من عدة حقائق: حصة في مورد + المورد يمر عبر ممر + طرف ثالث يملك سلطة | Test reducibility — مرشحة للتركيب داخل Derived State (سلسلة Model v1: Facts → Derived → Composition). **يفشل** إذا احتاجت المعلومة المركبة أن تكون fact أولية مخزنة (Observation primitive) لا مشتقة حسابيًا وقت القرار |
| **CE-5** | الحالة الزمنية | **Boundary Case — §0 يسود:** إن أظهر التحليل حاجة Temporal Primitive مستقل ⇒ يُسجل فقط Open Question «Content Schema requires unresolved temporal semantics» ويُغلق Gate الـ Content بما ثبت حتى تلك النقطة. لا تصميم ولا حسم زمني هنا |

قاعدة عامة إضافية (مجمدة): أي اقتراح Primitive جديد في التحليل يجب أن يمر اختبار
«لا Primitive لمجرد الراحة» — يثبت فشل البديل الأضيق أولًا.

---

## 3) التحليل التطبيقي

✅ **مفتوح — §2 مجمد بتوقيع المالك 2026-08-25.**

### منهجية التحليل

كل CE يُحلل عبر الفصيلة الثلاثية المجمدة (**Definition / Runtime State / Historical Change**) مع اختبار الحذف وفحص المقنّع، ثم يُصنف Confirmed / Rejected / Open.

---

### CE-1 — دولة + كيان غير دولتي + مورد

**Definition:** الكيان = قاموس عام `{id, kind, ...attributes}` حيث `kind` سمة بيانات (country/organization/resource) لا نوع برمجي.

**Runtime State:** دولة تحمل stability/gdp/at_war_with/chosen_action؛ منظمة تحمل budget/agents/operations؛ مورد يحمل production/reserves/transit_dependency. كلها أزواج مفتاح-قيمة على نفس بنية القاموس العام.

**Historical Change:** تغييرات تتبع عبر EventQueue + ScheduledQueue بشكل موحد بغض النظر عن kind.

**اختبار الفشل:** هل نحتاج `class Country` مقابل `class Organization` بطرق مختلفة؟ في الـKernel الحالي: لا — Simulation.gd يعاملهم generically عبر dispatch registry، وPhase 6 Intelligence أثبت أن agents+agencies+countries تعيش في نفس WorldState dict.

**الحكم:** ✅ **Confirmed** — يختزل إلى Entity عام واحد قاموسي. الدليل: Phase 6 كامل (agents/agencies/countries في نفس البنية).

---

### CE-2 — علاقة تتغير عبر الزمن

**Definition:** العلاقة = Edge موزون بين كيانين `{from, to, degree, type}` + سجل تغيّر مؤرخ (R1/R3).

**Runtime State:** النموذج v1 يستخدم Authority(A,B,degree) فعليًا — علاقة موزونة بين كيانين. التحالف 1950→1960 ثم انتهاؤه = تغيّر degree أو حذف الحافة مع تسجيل الحدث.

**Historical Change:** كل تغيّر علاقة يُسجل كحدث مؤرخ (R3) — من يغيّر ماذا لماذا.

**اختبار الفشل:** هل تحتاج العلاقة هوية/حالة/سلوكًا مستقلًا؟ مثال: معاهدة لها أحكام وتفاصيل — تفكيك إلى حقائق على الطرفين (التزامات، شروط) لا يتطلب كائن مستقل. لو ظهرت علاقة "تتصرف" (تتفاوض ذاتيًا) ⇒ هذا وكيل/منظمة وليس علاقة.

**الحكم:** ✅ **Confirmed** — Edge موزون + سجل مؤرخ يكفي. L2 Pair-Indexing محترم.

---

### CE-3 — حدث يغيّر عدة كيانات

**Definition:** حدث = payload مؤقت يُقرأ مرة واحدة بواسطة handler مسجل في dispatch registry، يعدّل حقائق عدة كيانات، وقد يدفع أحداث متابعة.

**Runtime State:** game_event_handlers.gd ينفذ هذا النمط فعليًا: War_Started يعدّل at_war_with للطرفين + military_threat_nearby للمدافع + يوقظ الدول المرتبطة. Agent_Exposed يلمس agency + target_country + استقرار.

**Historical Change:** الحدث نفسه يُسجل في EventQueue history + العدادات المحدثة تبقى كحقائق دائمة (R1).

**اختبار الفشل:** «وجود مستمر بعد وقوعه» — معاهدة تولّد مكاسب تجارية دورية؟ تتحول إلى ScheduledJob يسجلها المعالج عند وقوع الحدث. لا شيء يحتاج وجودًا كموضوع مستقل بعد التنفيذ.

**الحكم:** ✅ **Confirmed** — Historical Change log + propagation data-driven يكفيان. الدليل: Phase 6 كامل.

---

### CE-4 — حقيقة مشتقة من عدة حقائق

**Definition:** حصة الصين في تدفق EUV + مروره عبر بوابة هولندية + سلطة واشنطن على هولندا = معلومة مركبة.

**Runtime State:** Model v1 المجمد يحسبها بالكامل عبر السلسلة: Facts → ExposureSupply → Chain Composition → Relevance. Integration Gate (7/7) أثبت صحة الناتج bitwise مقابل الحساب اليدوي المرآوي.

**Historical Change:** أي تغيّر في حافة سلطة أو إنتاج أو اعتماد يعيد تشغيل الحساب تلقائيًا عبر invalidation triggers (§7 Registry).

**اختبار الفشل:** هل احتاجت المعلومة المركبة أن تكون fact أولية مخزنة؟ لا — لأن السلسلة acyclic (C4 Cycle Skip) والحساب terminates دائمًا. حتى لو كانت الأرقام كبيرة (N=200)، Test 10 أثبت ~141ms للمسار المستهدف.

**الحكم:** ✅ **Confirmed** — مشتقة حسابيًا وقت الاستعلام، مخزنة فقط كcache اختياري. Integration Gate هو الدليل.

---

### CE-5 — الحالة الزمنية (Boundary Case)

**التحليل وفق §0 Boundary Rule:**

**ما يحتاجه المحرك فعليًا من الزمن:**
- SimClock يومي منفصل (موجود)
- EventQueue بأحداث مؤرخة (موجود)
- ScheduledQueue بوظائف دورية every=30/90 (موجود)
- R2 حالة مؤقتة مؤرخة (حقائق timestamped)
- ReserveDays / LeadTimeMonths كحقائق scalar

**هل يحتاج Temporal Primitive مستقل؟**
- فترات زمنية: SimClock day-counting يغطيها
- تسلسل حرج: EventQueue ordering يغطيه
- دوريات: ScheduledQueue يغطيها
- مواعيد حرجة: R2 timed facts يغطيها
- مواسم/دورات طبيعية (monsoon/harvest): ScheduledJob يحدّث حقائق عند T محدد

**النتيجة:** لا يوجد متطلب زمني في نطاق Content Ontology يتطلب Primitive مستقل — كل الاحتياجات يغطيها البنية الموجودة.

**⚠️ Boundary Rule تطبيق:**
> إن ظهر مستقبلًا متطلب زمني لا يمكن تمثيله بهذه الآليات (مثلاً: زمن مستمر لا متقطع، أو نسبة زمنية بين طبقات مختلفة) ⇒ **يُسجل فقط Open Question**: «Content Schema requires unresolved temporal semantics» ويُغلق هذا Gate بما ثبت. تصميم Temporal Semantics = **Gate مستقل لاحقًا**.

**الحكم:** ✅ **لا Temporal Primitive ضروري في نطاق Content Ontology الحالي.** Open Question محتمل مؤجل لGate مستقل.

---

### جدول التصنيف النهائي

| # | Counterexample | التصنيف | الشرط/الملاحظة |
|---|---|---|---|
| CE-1 | Entity generalization | ✅ Confirmed | kind كسمة data |
| CE-2 | Relationship as edge | ✅ Confirmed | L2 Pair-Indexing |
| CE-3 | Event as change log | ✅ Confirmed | R1+R3 |
| CE-4 | Derived fact composition | ✅ Confirmed | Integration Gate 7/7 |
| CE-5 | Temporal semantics | ⚪ Open (carve-out) | لا primitive ضروري حاليًا؛ إن ظهر ⇒ Gate مستقل |

---

## 4) Confirmed Principle — أقل Ontology للمحتوى

> **أقل Ontology كافية لتشغيل Grand Strategy Engine الاستراتيجي:**

```
Entity (قاموس عام + kind سمة)
  ├── depends_on / produces / domestic_capacity     ← Supply channel
  ├── possession / authority (موزونة، مؤرخة)         ← Access channel + Chains
  ├── reserves_days / sectors                        ← EoR + Criticality
  └── enables (graph)                                ← Chain Composition
```

**لا حاجة إلى:** class Country منفصلة • Resource object مستقل • Event entity دائم • Temporal Primitive • Threat/Goal/Personality.

## 5) Rejected Interpretations

1. «الكيانات تحتاج أنواع برمجية مختلفة» — CE-1 أثبت العكس.
2. «العلاقات تحتاج هوية مستقلة» — CE-2 أثبت أن Edge يكفي.
3. «الأحداث تحتاج وجودًا دائمًا» — CE-3 أثبت أن Change Log يكفي.
4. «المعلومات المركبة تحتاج تخزينًا أوليًا» — CE-4 + Integration Gate أثبتا الاشتقاق الحسابي.
5. «الزمن يحتاج Primitive» — ⚪ Open مؤجل لGate مستقل، لكن لا عائق حاليًا.

## 6) Open Questions

1. **تصميم العدادات المشتقة** — قائمة العدادات الواجب صيانتها لتغطية R1–R3 (يُبنى تدريجيًا).
2. **Doctrine constraints** — قيود عقائدية في طبقة القرار («لا انسحاب مهما كانت النتيجة») — تُصمم مع Decision Model.
3. **سلاسل سلطة عميقة >2 حلقة** — مرفوع من 08، أول بند مراجعة Model v2 إن ظهر.
4. **Exhaustion × Initiative interaction** — تفاعل قراري في طبقة القرار المستقبلية.

---

## 7) اقتراح اختبار التحقق من الـOntology

**Test O — Ontology Sufficiency Test:**
- عالم يضم كل عائلة مؤكدة + سيناريو يضغط كل قناة (Supply/Access) وسلسلة سلطة
- فحوص: حذف أي عائلة ⇒ فشل تفسير حالة واقعية من الحالات المتراكمة
- **Exit:** نجاح = Ontology كافية؛ فشل = إعادة فتح السؤال

---

## §9) Deletion Test لكل عائلة حقائق — التحليل الفردي الكامل

> **هذا القسم يسد الفجوة التي رصدها صاحب المشروع:** الوثيقة كانت تقدم تحليلًا عبر 5 CEs مجردة دون Deletion Test فردي لكل عائلة من العائلات الثمانية المعتمدة. أدناه الاختبار الفردي الكامل بأدلة من Tranches A/B وIntegration Gate.

### منهجية الاختبار لكل عائلة

لكل عائلة:
1. **من يستهلكها؟** (أي صيغة مجمدة تعتمد عليها)
2. **اختبار الحذف:** أي حالة واقعية تفشل بدونها؟
3. **هل يمكن استبدالها؟** (بديل أضيق أو اشتقاق)
4. **النتيجة:** Confirmed (ضرورية) / Rejected (زائدة)

---

### F1 — Produces / FlowShare

**المستهلك:** ExposureSupply (§3.1) — `Share(X,cap) = P(X,cap) / ΣP(*,cap)`
**Deletion:** بدون إنتاج لا يوجد مورد يُقيَّم — Test 1 كامل (Phase 7) مبني على هذه العائلة. حالة تايوان/الرقائق تفسر بالكامل بها.
**البديل الأضيق:** تخزين "أهمية المورد" مباشرة = hardcoding مرفوض (L1).
**الحكم:** ✅ **Confirmed ضروري**

---

### F2 — DependsOn + DomesticCapacity

**المستهلك:** EffDep (§3.1) — `DependsOn × (1 − DomesticCapacity)`
**Deletion:** بدون اعتماد لا يوجد تعرّض — Tranche A أثبت أن الاعتماد هو المحرك الأساسي (A-1: HD=0.60 > LD=0.10).
**DomesticCapacity:** يمثل الاستقلال الذاتي الجزئي (سيبيريا قبل خط الأنابيب = possession بلا access). حذفه يعني عدم القدرة على تمثيل "إنتاج ذاتي جزئي" — حالة واقعية (الولايات المتحدة بعد 2019: مصدر صافٍ لكن ليس معزولًا تمامًا).
**البديل الأضيق:** تخزين "أهمية" مباشرة = L1 violation.
**الحكم:** ✅ **Confirmed ضروري**

---

### F3 — TransitDependency

**المستهلك:** ExposureTransit (§3.2) — تعرض العبور عبر ممر
**Deletion:** هرمز/السويس/قناة باناما — ممرات عبور بلا إنتاج. بدون TransitDependency لا يمكن تمثيل اعتماد اليابان على نفط يعبر مضيقًا لا تملكه ولا تنتجه.
**⚠️ فحص زمني:** هل يحتاج Temporal Primitive؟ التعرض لحظة بلحظة عبر الممر = قيمة ثابتة تتغير عند أحداث (فتح/إغلاق/تدهور). لا يحتاج زمنًا مستمرًا — يحتاج تحديث عند حدث فقط. ✅ لا فجوة.
**البديل الأضيق:** تخزين "خطر الممر" مباشرة = L1 violation.
**الحكم:** ✅ **Confirmed ضروري** — ⏱️ temporal check passed (event-driven, not continuous).

---

### F4 — Possession (gates)

**المستهلك:** DerivedPossession via Chain Composition (§3.4) — من يمسك البوابة
**Deletion:** ASML pattern — هولندا تمسك بوابة EUV. بدون Possession لا يمكن تمثيل "مَن يملك مفتاح الوصول".
**البديل الأضيق:** استنتاج السيطرة من الإنتاج وحده — لكن هذا يفشل: مصر تمسك السويس بدون أن تنتج البضائع العابرة. Possession مستقل عن Production بالضرورة.
**الحكم:** ✅ **Confirmed ضروري**

---

### F5 — Authority(A,B,degree)

**المستهلك:** Chain Composition (§4) — DerivedPossession عبر سلسلة سلطة
**Deletion:** ASML pattern — واشنطن لا تملك الآلات لكنها تملك سلطة على من يمسكها. بدون Authority لا يمكن تمثيل الرافعة عبر الطرف الثالث.
**⚠️ فحص زمني:** درجة السلطة تتغير بمعاهدات/قرارات = أحداث منفصلة تحدّث قيمة. لا يحتاج زمنًا مستمرًا — تحديث عند حدث فقط. ✅ لا فجوة.
**البديل الأضيق:** تخزين "نفوذ" مباشرة = L1 violation.
**الحكم:** ✅ **Confirmed ضروري**

---

### F6 — ReservesDays + LeadTimeTable

**المستهلك:** EaseOfReplacement (§3.3) — `ReserveDays / (LeadMonths × 30)` + AlternativesShare
**Deletion:** Tranche A أثبت أن الاحتياطي يؤثر على أهمية المورد تجاه الحائز فقط (T7b: باقي الصفوف bitwise سليمة). بدون ReservesDays لا يمكن تمثيل "اليابان عندها 120 يوم احتياطي نفط" كعامل مخفف للأهمية.
**LeadTimeTable:** زمن بناء البديل (fab=سنوات، LNG=شهور) — بدون هذا الجدول EoR لا تفرق بين بدائل سريعة وبطيئة.
**⚠️ فحص زمني:** ReserveDays عداد تراكمي يتغير بالاستهلاك والإنتاج (R1). LeadTimeTable قيم ثابتة كمحتوى (config). لا يحتاج زمنًا مستمرًا — تحديث عند حدث فقط. ✅ لا فجوة.
**البديل الأضيق:** تجاهل الاحتياطي = فقدان دلالة واقعية مهمة.
**الحكم:** ✅ **Confirmed ضروري** — ⏱️ temporal check passed (event-driven counters, config constants).

---

### F7 — SectorCriticality

**المستهلك:** ExposureSupply (§3.1) — `× Criticality(sector)` — وزن القطاعات الحرجة
**Deletion:** Tranche A أثبت (A-5) أن defense-sector exposure أعلى من civilian بنفس الاعتماد. بدون SectorCriticality لا يمكن تمثيل "الأرض النادرة للدفاع أهم من الأرض النادرة للحلي".
**البديل الأضيق:** تخزين "أهمية القطاع" مباشرة = جدول config بسيط (نفس الشيء باسم مختلف).
**⚠️ Open Question مصاحب:** مَن يصون جدول القطاعات عبر التوسع؟ هذا بذرة مشكلة Content Authoring/Modding (سطح مستقل حدده الشات الثاني في Production Audit) — **يُسجل بوضوح كOpen Question يغذي Gate مستقبلي عن Content Authoring**، وليس كملاحظة هامشية.
**الحكم:** ✅ **Confirmed ضروري** — Open Question مصاحب موثق بوضوح.

---

### F8 — ProjectionClass

**المستهلك:** ExerciseCapability (§3.4) — تصنيف قدرة تنفيذ السيطرة
**Deletion:** بدون ProjectionClass لا يمكن تمثيل "دولة تملك حقًا قانونيًا لكن لا تستطيع تنفيذه عسكريًا" (S3/S4 من وثيقة 08). Tranche B أثبت أن ExerciseCapability تعمل كمعامل ضرب مستقل.
**البديل الأضيق:** دمج ExCap داخل Possession = خلط امتلاك وقدرة تنفيذ — انكسر S3/S4.
**الحكم:** ✅ **Confirmed ضروري**

---

### ملخص الـDeletion Tests

| # | العائلة | الحكم | الدليل الرئيسي | Temporal Check |
|---|---|---|---|---|
| F1 | Produces/FlowShare | ✅ Confirmed | Test 1 كامل | N/A |
| F2 | DependsOn+DomCap | ✅ Confirmed | Tranche A (A-1) | N/A |
| F3 | TransitDependency | ✅ Confirmed | Integration T9 | ✅ event-driven |
| F4 | Possession | ✅ Confirmed | Phase 6 + Integration | N/A |
| F5 | Authority(degree) | ✅ Confirmed | Tranche B + Chains | ✅ event-driven |
| F6 | ReservesDays+LeadTime | ✅ Confirmed | Tranche A (A-4) | ✅ event-driven counters |
| F7 | SectorCriticality | ✅ Confirmed | Tranche A (A-5) | N/A (config) |
| F8 | ProjectionClass | ✅ Confirmed | Doc 08 S3/S4 | N/A (config) |

> ⚠️ **F3 وF5 وF6 تحمل علامة فحص زمني** — لا تُعتبر Confirmed نهائيًا إلا بعد تأكيد أن التمثيل event-driven (وليس continuous-time simulation) يكفي عبر التوسع. هذا مسجل كـ**Open Question يغذي Gate مستقبلي عن Temporal Semantics** — ليس كهامش.

---

## 8) حالة البوابة

✅ **Gate CLOSED — Minimal Ontology for FROZEN Relevance Model v1** (8/8 Confirmed ضرورية للنموذج المجمد حصرًا).
⚠️ **ليست ادعاءً بكفاية المحرك الكامل** — فجوات النطاق الأوسع في [13-Ontology-Sufficiency-Gate.md](13-Ontology-Sufficiency-Gate.md).
❌ لا سؤال فرعي مفتوح من الإغلاق نفسه (Temporal = Gate مستقل).
⛔ **توقف تام بعد الإغلاق** — لا Gate 3، لا Decision Layer، لا كود.

---

**Evidence trail:** الوثيقتان 08/09/10/11/12 + [13-Ontology-Sufficiency-Gate.md](13-Ontology-Sufficiency-Gate.md).
