# 15 — Decision Layer Design Gate

> **وثيقة حسم — صفر كود، صفر Kernel، صفر تعديل على Model v1 المجمد.**
> تتبع مباشرة لـ Content Ontology Gate (12) وDecision Semantics Gate 2 (11) وStrategic Relevance Model v1 (10 — FROZEN).
>
> **السؤال الأنطولوجي المجمد:**
>
> **ما الحد الأدنى من البنية التي تجعل المحرك قادرًا على تحويل حالة العالم + أهداف الدولة + تفضيلاتها + الخيارات المتاحة إلى قرار، دون أن يصبح الـDecisionSystem معرفة بالدومين — وما مصدر الـPreference نفسه في هذا التحويل؟**

---

## 0) المبدأ الحاكم المجمد (Gate 1 — قرار صاحب المشروع)

```
Decision ≠ direct Action scoring
```

- التفضيل الأساسي يقع على **الحالات/النتائج المستقبلية**.
- الأفعال **وسائل** لتغيير الحالة.
- القرارات متعددة الخطوات تتطلب النظر في **المسار/السياسة** للوصول إلى النتائج.

## 0-b) Boundary Rules

### CE-5 Temporal Carve-out (من doc 12)
إن ظهر متطلب زمني غير قابل للاختزال ⇒ Open Question فقط: «Content Schema requires unresolved temporal semantics» ⇒ إغلاق بما ثبت ⇒ Gate مستقل لاحقًا.

### deg/degree Rule
أي bug أثناء الاختبار ⇒ إعادة كل الفحوصات من الصفر، وليس فقط assertions المتأثرة.

---

## 1) القواعد الإلزامية (11 بند)

1. تحديد الـAction ontology بدون افتراض Domain Types.
2. تحديد مصدر Candidate Actions.
3. تحديد مدخلات Decision بالضبط.
4. تحديد حدود Decision مقابل Simulation/Relevance/Content.
5. إثبات أن Goal وPreference وCapability لا تتحول إلى hardcoded domain behavior.
6. Counterexamples تضرب التصميم.
7. لا معادلة Evaluation نهائية في هذه المرحلة.
8. أي primitive جديد يحتاج Deletion Test.
9. أي سؤال أوسع من الـGate يتحول Open Question ولا يتم حله داخله.
10. صفر كود قبل إغلاق الـGate.
11. تحديد صراحة مصدر الـPreference/Utility نفسه — هل هو Relevance Model v1 وحده، ولا محتاج تمثيل "أهداف/أوزان" إضافي في Content Schema؟ (مرتبط بسؤال 2: مصدر Options).

---

## 2) التصنيف الثلاثي الحاكم

```
FACT          — ما حدث/ما هو موجود في العالم (يقرأه النموذج)
DERIVED STATE — ما تعنيه البنية ميكانيكيًا (Relevance المجمدة)
DECISION      — ماذا تفعل الدولة بهذه الحقيقة (خارج النموذج؛ يُصمم هنا كتصميم حدود لا كتنفيذ)
```

> **ملاحظة صاحب المشروع المسبقة:** Relevance المجمدة **نصف الطريق فقط، ليست الوجهة النهائية** — طبقة القرار هي الاختبار الحقيقي لمتانة القوانين الثلاثة عليها.

---

## 3) التحليل التطبيقي

✅ **مفتوح — التصميم المسبق مكتمل، النتائج أدناه لكل بند من الـ11.**

### منهجية التحليل

كل بند يُحلل عبر: **ما هو؟ / ما مصدره؟ / ما حدوده؟ / اختبار فشل** ثم تصنيف Confirmed/Rejected/Open.

---

### 3.1 — Action Ontology (بدون Domain Types)

**ما هو:** Action = قاموس عام `{action_id, actor, target, parameters}` — نفس نمط EventQueue payloads.

**المصدر:** تعريفات في content JSON (`data/actions/`) تقرأها طبقة القرار عند init.

**الحدود:** Action ليس كائنًا دائمًا — قرار لحظي ينتج `chosen_action` field + قد يدفع event.

**اختبار الفشل:** هل ظهرت عملية تحتاج class مستقل؟ لا — كل الفروق بين "تحالف" و"غزو" هي parameters لا بنية.

**الحكم:** ✅ **Confirmed**

---

### 3.2 — مصدر Candidate Actions

**ما هو:** قائمة الأفعال المتاحة لكل كيان ليختار منها.

**المصدر المقترح:** `data/actions/available_actions.json` يحمل لكل action preconditions بصيغة `{field, op, value}` تُقارن ضد entity facts (نفس نمط CE-4 stress test P1).

**الحدود:** Precondition matching = مطابقة حقائق ضد شروط JSON. لا evaluator معقد.

**اختبار الفشل:** هل ظهر precondition لا يمكن تمثيله كـ{field, op, value}؟ لا.

**الحكم:** ✅ **Confirmed** — Content-driven registry + precondition matching.

---

### 3.3 — مدخلات Decision بالضبط

| المدخل | المصدر | النوع |
|---|---|---|
| Relevance values | Model v1 المجمد | float per pair |
| Entity facts | WorldState dict | depends_on, produces, stability... |
| Goal weights | entity.goal_table (content) | dict goal→weight |
| Available actions | action registry (content) | list with preconditions |
| ProjectionClass | entity field | config string |

**ما ليس مدخلًا (L1):**
- Intent/stance/relation sentiment
- Threat assessment
- Personality traits
- Other entities' goals

**اختبار الفشل:** هل ظهر مدخل من طبقة القرار دخل في صيغة الاشتقاق؟ لا — L1 المجمدة تمنع ذلك بنيويًا.

**الحكم:** ✅ **Confirmed** — القائمة محددة ومغلقة.

---

### 3.4 — حدود Decision مقابل Simulation/Relevance/Content

| الطبقة | Decision يقرأ | Decision يكتب |
|---|---|---|
| Simulation Kernel | عبر WorldState | chosen_action field فقط |
| Relevance Model v1 | pair-indexed floats | read-only |
| Content Data | definitions, weights, tables | read-only |

**القاعدة:** Decision Layer = **مستهلك نهائي** — أي تأثير عكسي يعود عبر أحداث جديدة تدخل EventQueue.

**اختبار الفشل:** هل ظهرت حاجة لكتابة في بنية أخرى؟ لا — chosen_action موجود منذ Phase 1.

**الحكم:** ✅ **Confirmed**

---

### 3.5 — Goals ≠ Hardcoded Behavior

**الإثبات التنفيذي:** Test 2 B-D1 أثبت أن نفس Relevance + تبديل goal_tables ⇒ قراران مختلفان — القرار المرجعي كان **دالة نقية داخل العدّاء** (reference-only)، بلا أي hardcoding في النواة.

**التعميم:** أي هدف جديد = إضافة `{goal_name: weight}` في goal_table. لا كود جديد.

**اختبار الفشل:** هل ظهر هدف لا يمكن التعبير عنه كـ{weight × relevance_channel}؟ لا.

**الحكم:** ✅ **Confirmed** — Goals are data, not behavior.

---

### 3.6 — Counterexamples المهاجمة للتصميم

| CE | السيناريو | الحكم |
|---|---|---|
| D1 | Circular dependency (فعل يتطلب نتيجته) | ⚪ Open — Planning layer مؤجل؛ v1 يقيّم أفعالًا مستقلة |
| D2 | Equal-weight conflicting goals | ⚪ Open — deterministic tie-break (key sort) مقبول لv1 |
| D3 | Action requires missing capability | ✅ Precondition rejection يعالجها |

### 3.7 — لا معادلة Evaluation نهائية

Model v1 يحدد **البنية** وليس **معادلة scoring**. الصيغة الرقمية الدقيقة تُصمم عند بناء طبقة القرار التنفيذية بعد اعتماد هذا التصميم.

---

### 3.8 — أي Primitive جديد يحتاج Deletion Test

المفردات الجديدة الوحيدة في هذا التصميم:
- **Action Registry** (content JSON) — ليس primitive، إنه config data
- **Goal Table** (على الكيان) — موجود فعليًا منذ Test 2
- **Precondition Format** ({field, op, value}) — نفس نمط CE-4 stress test

**لا Primitive جديد اقترح.**

---

### 3.9 — أسئلة أوسع من الـGate → Open

1. Multi-step planning (GOAP-like) — مؤجل لطبقة متقدمة
2. Negotiation between entities — مؤجل
3. Learning/adaptation from outcomes — مؤجل

---

### 3.10 — صفر كود

هذه الوثيقة تصميم حدود فقط. لا implementation في هذه المرحلة.

---

### 3.11 — مصدر Preference/Utility (البند 11)

**السؤال:** هل Preference = Relevance وحدها أم تحتاج تمثيل إضافي؟

**التحليل:**

Relevance تقول "X مهم لY بقدر Z" لكنها لا تقول "Y يريد فعل شيئ بشأن X".

الجسر = **goal_table** على الكيان (محتوى config):
```json
{"resource_security": 0.8, "prestige": 0.2}
```

- goal_table = محتوى على الكيان (بيانات)
- Relevance = Derived State من Model v1
- Decision score = goal_weight × relevance_channel → argmax

**هل goal_table يكفي بدون primitive جديد؟** نعم — dict موجود فعليًا منذ Test 2، ويُقرأ بواسطة decision stub فقط.

**هل Relevance وحدها تكفي بدون goal_table؟** لا — لأن نفس Relevance مع أهداف مختلفة تعطي قرارات مختلفة (B-D1 مثبت). إذن Preference = تفاعل الاثنين.

**الحكم:** ✅ **Preference source = goal_table (content) × relevance_profile (derived)** — كلاهما موجود ولا يحتاج primitive إضافي.

---

## 4) حالة البوابة

✅ **Gate CLOSED — Decision Layer Design Confirmed** (11/11 بنود محلولة).
⚪ 2 Open Questions مؤجلة (Planning layer + tie-break refinement).
⛔ **توقف تام بعد الإغلاق.**

---

**Evidence trail:** الوثائق 08/09/10/11/12/13/14 + هذا الملف.
