# 13 — Ontology Sufficiency Gate: هل تكفي الـOntology الحالية للعبة كاملة؟

> **وثيقة اختبار حدود — صفر تعديل على Model v1 المجمد.**
> تتبع مباشرة لـ Content Ontology Gate (12) وStrategic Relevance Model v1 (10 — FROZEN).
>
> **السؤال:** هل العائلات الثمانية المؤكدة (F1–F8) كافية لبناء لعبة Grand Strategy كاملة، أم أنها فقط كافية لتشغيل Relevance Model v1؟
>
> **المنهج:** 5 counterexamples من أنظمة اللعبة **خارج Relevance** — نحاول تمثيل كل واحد بالـOntology الحالية ونصنف: Expressible / Gap / Open-carve-out.

---

## 1) المنهجية

لكل counterexample:
1. **وصف السيناريو الواقعي** بالكلام العادي
2. **محاولة التمثيل** بالحقائق الثماني الموجودة حصرًا
3. **تصنيف**: ✅ Expressible / ❌ Gap (عائلة ناقصة) / ⚪ Open (carve-out مؤجل)
4. **العائلة الناقصة** إن وجدت

---

## 2) Counterexamples الخمسة

### OS-1 — الموقع الجغرافي/المسافة

**السيناريو الواقعي:** مصر (القاهرة) تغزو إثيوبيا (أديس أبابا). المسافة ~2000 كم. اللوجستيات العسكرية تتدهور مع المسافة، والوقت المستغرق يعتمد على الطبيعة الجغرافية (صحراء/جبال/أنهار).

**محاولة التمثيل بالـOntology الحالي:**
- Entity قاموسي: يمكن إضافة `location` كسمة بيانات؟ نعم كحقل نصي أو زوج إحداثيات.
- لكن: **المسافة بين كيانين** علاقة ثنائية تحتاج حساب جغرافي (Haversine مثلاً). لا صيغة في Model v1 تحسب المسافة.
- Access channel يقيس "من يملك البوابة" — لكن **لا يعرف أين هي البوابة** ولا كم تبعد عن المهاجم.

**التصنيف:** ❌ **Gap**
**العائلة الناقصة:** Geographic position + Distance computation
**التأثير على النموذج:** Access channel بدون جغرافيا = رافعة بلا مسافة. غزو جار مجاور ≠ غزو دولة عبر قارة.

---

### OS-2 — الرؤية غير المتماثلة (Asymmetric Information)

**السيناريو الواقعي:** إسرائيل تعرف عبر الاستخبارات أن إيران تبني منشأة نووية في نطاز. مصر **لا تعرف** بهذه المنشأة. نفس المنشأة الفيزيائية — مستويان مختلفان تمامًا من المعرفة.

**محاولة التمثيل بالـOntology الحالي:**
- الـKernel يخزن نسخة واحدة من WorldState يشاهدها الجميع.
- لا يوجد مفهوم "per-observer visibility" أو "known_facts" منفصلة لكل دولة.
- Phase 6 Intelligence اقترب (Agent_Exposed = حدث يكشف معلومة)، لكن لم يبنِ نظام معرفة منفصل لكل دولة.

**التصنيف:** ❌ **Gap**
**العائلة الناقصة:** Per-observer known-facts layer (Intelligence/Information asymmetry)
**التأثير على النموذج:** بدونها، كل الدول ترى نفس العالم = استخبارات بلا معنى. أهم مبرر وجود لطبقة Intelligence.

---

### OS-3 — تحالف ثلاثي متعدد الأطراف

**السيناريو الواقعي:** NATO المادة 5: هجوم على أي عضو = هجوم على الجميع. ثلاث دول A, B, C ملزمة دفاعًا جماعيًا.

**محاولة التمثيل بالـOntology الحالي:**
- Authority(A,B,degree) زوجي موجه.
- يمكن تفكيك إلى: Authority(A,C), Authority(B,C), Authority(C,A)... لكن هذا يفقد **الشرط الجماعي**: "هجوم على C يستدعي A وB معًا".
- التفكيك الزوجي ينتج N×(N−1) حواف بدلاً من علاقة مجموعة واحدة.

**التصنيف:** ⚠️ **Partially Expressible (lossy decomposition)**
**العائلة الناقصة:** Multi-party agreement/group semantics
**التأثير:** يمكن العمل بالتفكيك الزوجي في v1، لكن الدلالة الجماعية (trigger مشترك) تضيع.

---

### OS-4 — ملكية جزئية 40%

**السيناريو الواقعي:** الصين تمتلك 40% من حصة ميناء بيرايوس اليوناني. ليست سيطرة كاملة، لكن نفوذ مؤثر على قرارات الوصول.

**محاولة التمثيل بالـOntology الحالي:**
- Possession(entity, gate) يدعم `degree ∈ [0,1]` ✓
- `Possession(China, Piraeus_gate, degree=0.4)` يمثل الملكية الجزئية مباشرة.

**التصنيف:** ✅ **Expressible**
**ملاحظة:** سلوك النموذج عند درجات جزئية غير مُختبر بعد (Test 1′ اختبر 0.0 و0.8 فقط). يُقترح إضافة حالة partial-ownership في Test 1″.

---

### OS-5 — دورة موسمية (Temporal carve-out)

**السيناريو الواقعي:** ممرات الهيمالايا تغلق نوفمبر-مارس (ثلوج) وتفتح أبريل-مايو. التجارة والحركة العسكرية تتبع دورة سنوية.

**محاولة التمثيل بالـOntology الحالي:**
- ScheduledQueue يمكنه تسجيل job سنوي يغير `transit_dependency` عند T محدد.
- لكن: هذا يتطلب آلية "seasonal modifier" على حقائق العبور — نمط زمني دوري غير مدعوم حاليًا كبنية schema.

**التصنيف:** ⚪ **Open — Temporal Carve-out**
**المرجع:** §0 Boundary Rule من doc 12 — أي دلالة زمنية غير قابلة للاختزال ⇒ Open Question فقط.
**Open Question:** «Content Schema requires unresolved temporal semantics» — موثق سابقًا.

---

## 3) جدول التصنيف النهائي

| # | Counterexample | التصنيف | العائلة الناقصة | الأولوية |
|---|---|---|---|---|
| OS-1 | جغرافيا/مسافة | ❌ Gap | Geographic Position + Distance | عالية (Military/Access) |
| OS-2 | رؤية غير متماثلة | ❌ Gap | Per-Observer Known-Facts | عالية (Intelligence) |
| OS-3 | تحالف ثلاثي | ⚠️ Partial lossy | Multi-party Agreement | متوسطة (Diplomacy) |
| OS-4 | ملكية جزئية 40% | ✅ Expressible | — | — |
| OS-5 | دورة موسمية | ⚪ Open carve-out | Temporal Semantics (Gate مستقل) | مؤجلة |

## 4) الخلاصة

> **الـOntology الحالية (8 عائلات): كافية لتشغيل Relevance Model v1 المجمد حصرًا.**
>
> **غير كافية لعبة GS كاملة بسبب 2 Gaps حقيقيان (جغرافيا + رؤية) و1 Partial (تحالف ثلاثي) و1 Open (temporal).**

### الخطوة التالية المقترحة (بترتيب الأولوية)

| الأولوية | الإجراء | الأسباب |
|---|---|---|
| 1 | تصميم Geographic fact family | Military/Access بدون جغرافيا ناقصان هيكليًا |
| 2 | تصميم Per-Observer Visibility | Intelligence بلا معرفة منفصلة = بلا معنى |
| 3 | Multi-party Agreement | Diplomacy تحتاج تجميع غير زوجي |
| 4 | Temporal Semantics | Gate مستقل (مؤجل) |

## 5) ما الذي لا يتغير

Model v1 FROZEN • Tranches A/B results • Integration Gate results • Test 1′/Test 2 results — كلها صحيحة في نطاقها ولا تتأثر بهذه الفجوات.

---

⛔ **توقف تام** — لا Decision Layer، لا كود، لا Gate جديد.
