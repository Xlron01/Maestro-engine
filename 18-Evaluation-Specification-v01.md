# 18 — Evaluation Specification v0.1

> **أول وثيقة تنفيذية في سلسلة القرار — تترجم مباشرة إلى كود.**
> تنفذ حرفيًا دلالة doc 17 المؤكدة، تحت حدوده الثلاثة في §7 وحرفيًا.
>
> **الشكل المؤسسي (بتوجيه صاحب المشروع):** هذه الوثيقة **Gate-Style ذات إغلاق تنفيذي** — لا ترفع حالتها إلى CONFIRMED إلا بعد **PASS لـTest E** المجمد داخلها (§5)، وتوقعات Test E مكتوبة هنا **قبل أي سطر كود**. بعد الإغلاق تعمل دورًا مزدوجًا: سجل إغلاق **و**مرجع مراجعة دائم تُقاس عليه تنفيذات D3/D4.

---

## 0) النطاق والقيود الموروثة

1. **صفر Kernel code**: المقيّم المرجعي (reference evaluator) يعيش في عدّاء Test E حصرًا — نمط D1. موضع الإنتاج النهائي قرار ترانش لاحق.
2. **حدود §7 الثلاثة حرفًا بحرف** (doc 17): هوية الخيار بعد التقييم فقط وبين المتعادلين · الضمانة «عنصر أعلى حتميًا» لا «الأفضل» · F4-lex/F4-weighted أساسيان وباريتو بالافتراضي المجمد.
3. **L1/L2/L3 موروثة حيث تنطبق**: التقييم يستهلك derived-state ولا يعدله (قراءات خالصة)؛ المخرجات حتمية؛ لا تجميع مخفي.
4. **Temporal carve-out باقٍ**: لا ديناميكا زمنية داخل المقيّم — R1/R2 تدخل كسجلات حالة جاهزة فقط.
5. **قاعدة عدم امتياز D1 باقية**: عقد `decide()` في doc 16 ليس مرجعًا لهذه المواصفة — المقيّم هنا يُبنى من الصفر فوق دلالة doc 17.

---

## 1) أنواع الواصفات — من المفردات المغلقة حصرًا (doc 17 §2.2)

### 1.1 Schema الواصف

```text
descriptor := {
  "channels": { "rel_supply"?: {target: float}, "access"?: {target: float},
                "exposure"?: {target: float} },          # قراءات Model v1 عند الحالة المتنبأة
  "facts":    { "reserves_days"?: {cap: num}, "depends_on"?: {cap: num},
                "possession"?: { <capability_or_gate_id>: degree }, ... },
                # possession: المفاتيح معرفات قدرات/بوابات موجودة في المحتوى، والقيم degrees ∈ [0,1]
                # بنفس دلالة Model v1 حرفيًا (نمط fixtures: {"EUV_gate": 1.0}) — لا مفهوم جديد هنا إطلاقًا
  "records"?: { "counters"?: {...}, "timed"?: [...], "commitments"?: [...] }  # R1–R3 (اختياري)
}
```

### 1.2 قواعد الغلق (ممنوعات صريحة)

- ⛔ أي مفتاح يحمل هوية الفعل أو المسار: `action_id`, `path_id`, ... — **باستثناء موقع واحد**: اختيار ما بعد التقييم بين المتعادلين (حد §7-1)، خارج الواصف تمامًا.
- ⛔ أي حقل محسوب خارج المفردات (لا مقاييس جديدة، لا نسب مصنوعة يدويًا).
- ⛔ أي إشارة لحالة كيانات غير متعلقة بالهدف (لا تجميع بيئي).

### 1.3 حدود صدق v0.1 (موثقة لا مخفاية — بلا أي التزام معماري)

الحالة «المتنبأة» في هذه النسخة تُبنى من **deltas معلنة في الـfixture** (إعلانات نتائج الأفعال). لا يوجد محرك تنبؤ في هذه النسخة، **ولا تصمم هنا، ولا تُجدول هنا، ولا تُسند هنا إلى أي طبقة**. أي ربط مستقبلي بين الواصف وحالة متنبأة حقيقية مسألة جديدة كاملة تتطلب Gate خاصًا بها وفق المنهجية — هذا البند إعلان فجوة نطاق حصرًا، وليس إشارة تصميم أو جدولة.

---

## 2) عائلة الأشكال F1–F5 بصيغ Content JSON

كل هدف قد يعلن كتلة `evaluation` واحدة؛ الشكل المجهول ⇒ خطأ تحميل قاطع. الأشكال:

```jsonc
// F1 خطي-فتري — يتطلب إعلان المقياس صراحة (doc 17 CE-1)
{ "form": "F1", "channels": ["rel_supply"], "target_ref": "Maker_Prime",
  "scale": "interval", "direction": "maximize" }

// F2 إشباعي-معتبي — العتبة والانحدار معاملات محتوى
{ "form": "F2", "fact": "reserves_days.EUV_flow", "floor": 90,
  "below_penalty_per_day": 0.05, "above_saturation": true }

// F3 نسبي — فوق تركيب موجود في Model v1 حصرًا؛ معامل المخالفة معلن إلزاميًا
{ "form": "F3", "composite": "supply_share", "cap": "EUV_flow",
  "of": "Maker_Prime", "ceiling": 0.375, "violation_multiplier": 10.0 }

// F4 متعدد-الأبعاد — ثلاثة أنماط
{ "form": "F4", "mode": "weighted",
  "terms": [ {"term": <F1|F2|F3-block>, "weight": 0.7, "scale_decl": "interval"}, ... ] }
{ "form": "F4", "mode": "lexicographic",
  "priority": [ <condition-block>, <condition-block>, ... ] }   // الأسبق أشد
{ "form": "F4", "mode": "pareto",
  "terms": [ <condition-block>, <condition-block>, ... ],        // شروط عارية بلا غلاف — توازي priority لا weighted
  "tie_extension": { "by": "option_id", "order": "asc" } }       // افتراضي §7 — غير قابل للتجاوز في v0.1
```

### 2.1 قواعد الأعضاء + صيغ المساهمة الحرفية

**الصيغ المعيارية أولًا** (هي المصدر؛ أرقام E في §5 تحقّق لها لا بديل عنها):

**F2 — إشباعي-معتبي** (القيمة `value` تُقرأ من مسار `fact` في الواصف):

```text
if value < floor:    contribution = -(floor - value) * below_penalty_per_day
if value >= floor:   contribution = 0.0                      # above_saturation = true (الوحيد المنفذ في v0.1)
```

**F3 — نسبي** (القيمة `ratio` من تركيب موجود — V5):

```text
if ratio <= ceiling: contribution = (ceiling - ratio)                 # headroom، المضاعف = 1 ثابت
if ratio > ceiling:  contribution = -(ratio - ceiling) * violation_multiplier
```

**ثم القواعد:**

- **F1** بلا `"scale": "interval"` ⇒ رفض تحميل (الافتراض يجب أن يكون معلنًا — درس CE-1).
- **F2** فوق الأرضية: مساهمة ثابتة/مشبعة إذا `above_saturation=true`.
- **F3** يجوز فقط `composite` من الموجود فعليًا في [`scripts/relevance_supply.gd`](file:///c:/tmp/maestro%20engine/scripts/relevance_supply.gd) (`supply_share` اليوم). يجب أن يعلن `violation_multiplier` (عدد > 1). **صيغة المساهمة المجمدة**: `c = (ceiling − share) × (share > ceiling ? violation_multiplier : 1.0)`.
- **F4-weighted** كل term يجب أن يحمل `scale_decl` متوافقًا (لا خلط ordinal مع interval).
- **F4-lex**: المدخل الأول غير المحقق يحسم؛ المساواة الكلية تنزل لتعادل عادي (يدخل §7 إن كانت باريتو).
- **F5** ليس شكلًا يُعلن — انظر قاعدة الرفض الحرفية V3 أدناه.

### 2.2 التجميع عبر أهداف الكيان = مثيل F4 آخر (لا primitive جديد)

`goal_table` متعدد الأهداف يُجمَّع بنفس أنماط F4 (weighted بشرط توافق المقاييس المعلنة | lex بأولوية أهداف معلنة | pareto+§7). بهذا يبقى كل التجميع داخل العائلة نفسها — صفر آليات موازية.

### 2.3 قواعد تحميل حرفية (Loader Validation — نص تنفيذي ملزم)

المقيّم عند قراءة كتلة `evaluation` ينفذ هذه الفحوصات بالترتيب؛ أي فشل ⇒ **رفض تحميل قاطع** (لا تحمّل متسامح):

```text
V0:  if not block.has("form")                        -> REJECT("missing form")

# ---- فحصا الهوية: الترتيب V1a قبل V1b مقصود صراحة ----
# V1a يفحص F5 تحديدًا "قبل" القائمة البيضاء حتى يكون تشخيصه قابلًا للوصول؛
# بالتقسيم القديم (V1 قائمة ثم V3 مستقل) كانت V3 ستكون كودًا ميتًا never-reached —
# عيب الترتيب ذاك سُجل بمراجعة المالك وصُحح هنا. النتيجة REJECT في الحالتين،
# والفارق الوظيفي الوحيد = رسالة تشخيص أدق لمؤلف المحتوى.
V1a: if block.form == "F5"                           -> REJECT("F5 is structural, not declarable")
V1b: if block.form not in {"F1","F2","F3","F4"}      -> REJECT("unknown form")

V2:  if block.form == "F1" and block.get("scale") != "interval"
                                                     -> REJECT("F1 requires declared interval scale")
V4:  if block.form == "F4":
       if block.mode == "pareto" and block.get("tie_extension") != {"by":"option_id","order":"asc"}
                                                     -> REJECT("tie_extension immutable in v0.1")
       if block.mode == "weighted" and any(term lacks "scale_decl" compatible with its term's scale)
                                                     -> REJECT("scale_decl required per weighted term")
V5:  if block.form == "F3" and block.composite != "supply_share"
                                                     -> REJECT("composite outside existing Model v1 set")
V6:  if block.form == "F1" and block.get("direction") not in {"maximize","minimize"}
                                                     -> REJECT("direction must be declared: maximize|minimize")
V7:  if block.form == "F2" and block.get("above_saturation") != true
                                                     -> REJECT("only saturated variant implemented in v0.1")
```

ملاحظات:
- **V2/V6 فلسفة واحدة**: كل افتراض قياس/اتجاه يجب أن يكون **معلنًا** — لا قيم افتراضية ضمنية (درس CE-1).
- ترقيم V3 تُرك فارغًا **عمدًا** توثيقًا لدمجه في V1a بعد ملاحظة الكود الميت — لا يعاد استخدام الرقم حتى لا يوحي بوجود فحص سادس مستقل.
- `"form": "F5"` غير موجود في اللغة الإعلانية أصلًا؛ ثبات F5 البنيوي مصدره توقيع المقيّم (لا هوية فعل في التسجيل)، وV1a مجرد إنذار مبكر لخطأ محتوى.

---

## 3) تطبيق اتفاقية §7

1. حساب الترتيب/الحد الأعلى **كاملًا أولًا** — الاختيار بين عناصر عليا غير قابلة للمقارنة يتم **بعده فقط** بـ`option_id` تصاعديًا.
2. مخرَج المقيّم يوصف رسميًا: *«اختيار حتمي لعنصر أعلى»* — ممنوع في أي نص/اختبار وصفه بـ«الأفضل».
3. أي اتفاقية أغنى مستقبلاً = حقل محتوى جديد خارج v0.1.

---

## 4) البروتوكول التنفيذي

- **Fixtures جديدة**: `e_base.json` (عالم مشتق مصغر) + `e_actions.json` (أفعال بواصفات deltas معلنة، منها **توأمان** بواصف متطابق bitwise لأجل E6) — تُكتب قبل العدّاء وتُجمد أرقامها أدناه.
- **deg/degree منطبقة**: أي bug ⇒ إعادة Test E كاملًا من الصفر.
- **Evidence**: `.ai/evidence/tests/test_e_evaluation_spec.log`

## 5) Test E — معيار القبول المجمد (قبل أي كود)

**ثوابت الـfixtures مجمّدة هنا بالأرقام** — اختيرت جميعها ثنائية-الدقة (binary-exact) حتى تكون المقارنات bitwise بلا فخوف عشري. العدّاء والـfixtures ملزمون بها حرفيًا:

```text
F1-probe : weight=1.0, scale=interval, direction=maximize, target=Maker_Prime
           ACT_D1A: Δrel_supply = +0.25   |   ACT_D1B: Δrel_supply = +0.50
F2-probe : floor=90, below_penalty_per_day=0.0625, above_saturation=true
           probes: reserves ∈ {75, 90, 120}
F3-probe : ceiling=0.375, violation_multiplier=10.0
           probes: share ∈ {0.75, 0.3125, 0.25}
F4-probe : dims A(supply Δ+0.25, interval/maximize), B(exposure worsens: access Δ+0.05
           under direction=minimize => contribution −0.05), interval
           weighted weights {A:0.75, B:0.25}  |  lex priority [B-first(no-worsen), A]
           options OPT_TRADE (يحمل Deltas) / OPT_BASE (صفر deltas)
E5-pair  : OPT_P1/OPT_P2 incomparable maxima   E6-twins: ACT_TWIN_X/ACT_TWIN_Y + D_TWIN واحد
```

| # | الفحص | الشرط التنفيذي الحرفي + نص assertion المجمد |
|---|---|---|
| E1 | F1 رتابة | `score(D1B) − score(D1A) == 0.25` **بالضبط** (فرق الدلتا ثنائي-دقة؛ لا سماحية). assertion: `"E1 monotonicity holds under declared interval scale"` |
| E2 | F2 الكينك | `contrib(75) == −(90−75)×0.0625 == −0.9375` بالضبط · `contrib(90) == 0.0` · `contrib(120) == 0.0` (تشبع). assertion: `"E2 satisficing kink: below-floor deficit penalized at declared rate; at/above floor contributes zero"` |
| E3 | F3 السقف | `c(0.75) == −3.75` · `c(0.3125) == +0.0625` · `c(0.25) == +0.125` بالضبط، و`c(0.25) − c(0.3125) == 0.0625` (ميل تحت السقف = مضاعف 1: سقفٌ لا سباق). assertion: `"E3 ratio ceiling: above-ceiling share penalized by declared multiplier; headroom linear without bonus"` |
| E4 | F4-lex مقابل weighted | weighted: `net = 0.75×(+0.25) + 0.25×(−0.05) == +0.175 > 0` ⇒ يقبل ⇒ `decision_weighted == "OPT_TRADE"` · lex: الشرط الأول [B no-worsen] مخفوق (ΔB=−0.05<0) ⇒ يرفض ⇒ `decision_lex == "OPT_BASE"`. assertion: `"E4 lexicographic refuses trade-off that weighted accepts - both forms earn membership"` |
| E5 | F4-pareto + §7 | بمجموعة العناصر العليا `M` (≥2 غير قابلين للمقارنة): `chosen == min(M, by=option_id)`. assertion نصه المجمد: `"E5 selects a maximal element deterministically via option_id ascending (doc17 §7)"` — ممنوع أي صياغة بديلة |
| E6 | **CE-5 توأمان (شرط قبول إلزامي)** | `ACT_TWIN_X.action_id != ACT_TWIN_Y.action_id` و`canonical(D_TWIN_X) == canonical(D_TWIN_Y)` ⇒ `canonical(scores_X) == canonical(scores_Y)` bitwise. أي اختلاف = كسر F5 مباشرة. assertion: `"E6 twin actions with identical descriptors yield bitwise-identical scores (Gate-2 path-neutrality)"` |
| E7 | عمى الهوية | تطبيق خريطة تسمية على كيانات e_base ثم التقييم: `canonical(scores_base) == canonical(inverse_map(scores_renamed))` مساواة سلسلة حرفية. assertion: `"E7 evaluation identity-blind: scores invariant under entity renaming (inverse-mapped)"` |
| E8 | قراءة-فقط + حتمية | `canonical(world_before) == canonical(world_after)` و`canonical(descriptors_before) == canonical(descriptors_after)`، وتشغيلان مستقلان ⇒ تطابق كامل المخرجات. assertion: `"E8 read-only evaluation, deterministic across independent loads"` |

**شرط إغلاق الوثيقة:** PASS لكل الثمانية بصيغها الحرفية أعلاه ⇒ الحالة تنتقل PROVISIONAL → **CONFIRMED**، وتصبح المرجع الدائم لتدقيق تنفيذات D3/D4.

| 2026-08-26 | **rev.4 بمراجعة المالك**: أُضيفت صيغتا المساهمة الحرفيتان لـF2/F3 في §2.1 بنمط الشرط التنفيذي (IF-form) — فصارت الأرقام في §5 تحقّقًا للصيغة لا بديلًا عنها؛ وأُضيفت V7 (رفض `above_saturation != true` — الوحيد المنفذ في v0.1) | طلب المالك: «الصيغة مكتوبة حرفيًا في §2 وإلا فهي أرقام بديلة عن المعادلة لا تحقق لها» — وبعد ذلك **إذن صريح ببدء fixtures + عدّاء Test E** |

| 2026-08-26 | **rev.4b (أثناء التنفيذ المصرح به — قبل CONFIRMED)**: تشغيل TestE أول كشف علتين fixture/spec ⇒ deg/degree توقف كامل ⇒ (1) صيغة terms الباريتو لم كانت محددة في §2 — حُسمت **شروطًا عارية** توازي priority لا weighted، وكتبت في §2 صراحة؛ (2) إشارة OPT_TRADE في e_actions كانت `access Δ−0.05` بينما "التدهور" تحت direction=minimize يعني `Δ+0.05` (المساهمة −0.05 كما يجمدها صف E4 نفسه) — صح الـfixture وضبط سطر الثوابت §5؛ (3) خطأ تحميل canonical في العدّاء أصلحه قبل أي دورة | تنفيذ بروتوكول deg/degree حرفيًا داخل مرحلة التنفيذ أيضًا؛ الوثيقة لم تُغلق بعد فالتعديل المشروع قبل الإغلاق بشرط التوثيق |

| 2026-08-26 | **rev.4c — إفصاح وإثبات (بطلب المالك قبل قبول CONFIRMED)**: (أ) **إفصاح pareto-terms**: الفجوة كانت في rev.3 نفسه (جمدنا weighted المغلف وlex العاري وأغفلنا pareto — خطؤنا التوثيقي)؛ القرار أثناء التنفيذ: *شروط عارية* = كتل F1/F2/F3 نفسها بلا غلاف ولا أوزان — **ليس primitive جديد** (لا قدرة حسابية/دلالية خارج ما كسبه lex عضويته عبر CE-4؛ إعادة استخدام صياغة قائمة) ⇒ لا Deletion Test مطلوب، لكن كان الصواب التوقف للسؤال قبل التنفيذ ويُسجل ذلك إخلالًا إجرائيًا منقحًا؛ (ب) **دليل deg/degree**: R1 parse-abort (0 فحص) → R2 محاولة كاملة FAIL 13/3 انقطعت داخل E5 → R3 إعادة كاملة **PASS 16/16**؛ لوجات R1/R2 استُبدلت بخطوة التنظيف قبل R3 (**غير مؤرشفة — إقرار صريح**)؛ الدليل الملزم: المجموعة المجمدة سلفًا في rev.4 (commit `13bd605` قبل أي تشغيل) = E1–E8، واللوج النهائي يحيويها 8/8 بنصوصها + 8 L إضافية تحصينًا — [PASS]=16 [FAIL]=0 بعد آلي؛ (ج) **تطابق حرفي code↔spec**: عدّ آلي لتسع رسائل V + صيغتا F2/F3 + assertion-labels الحساسة في مصدر العدّاء ⇒ كلها موجودة (count≥1)؛ SHA256 للملفات الخمسة مسجل بمحضر الجلسة | مبدأ «تم بلا دليل» — النتيجة كانت PASS لكن المطلوب raw+checksum+تصنيف وقد سُلم بالحرف |
| 2026-08-26 | **rev.4d — نقل الأدلة الخام داخل الوثيقة (بطلب المالك الثاني)**: لا يوجد أي قيد واجهة يمنع النقل الحرفي — يُصرح بذلك صريحًا فلا حاجة لآلية بديلة؛ أُضيف §7: اللوج كاملًا (60 سطرًا/2800 حرفًا) بلا تحرير، SHA256 كاملة للخمسة ملفات، سطر التشغيل ونسخة المحرك، ومرساة الإثبات ``12a8e15``؛ وأُعيدت حالة §6 إلى PROVISIONAL واقعيًا؛ وقاعدة إجرائية جديدة: **ممنوع حذف/استبدال لوجات التشغيلات الوسيطة** — تُأرشف runNN.log وdeg/degree تُوثق عليها جميعًا | مبدأ «الدليل يتنقل لا يُشار إليه» — المسار file:// ليس دليلًا لأي مراجع خارج الجهاز |
| 2026-08-26 | **rev.4e — تصريح بنطاق الـcommits (بطلب المالك الثالث — السطر المطلوب للإغلاق)**: **``12a8e15``** = commit التنفيذ — يحيي fixtures الثلاثة (e_base/e_actions/e_goals) + عداد test_e_evaluation_spec.gd (508 سطرًا) + اللوج الخام test_e_evaluation_spec.log الذي نُقل حرفيًا في §7.1 وتنطبق عليه hashes §7.2 — 11 ملفاً (+765/−23)؛ **``57c2591``** = commit توثيقي حرفًا (rev.4d) — يمس ملف doc18 الوحيد (279 سطرًا: إضافة §7 + إعادة PROVISIONAL + صف rev.4d) ولا يمس أي كود أو fixture أو لوج — تأكيد من ``git show --stat`` لكليهما في محضر الجلسة. ولشفافية السلسلة: هذا التعديل rev.4e ذاته سيسجل في commit ثالث توثيكي يمس doc18 الوحيد أيضًا | القاعدة: لا استنتاج ضمني بدل السطر الصريح — نصنا من وضعها |

## 6) حالة الوثيقة

⏸️ **PROVISIONAL — الأدلة الخام منقولة حرفيًا في §7 بانتظار اعتماد المراجع (المالك)**
> تصحيح تجاوز سابق: حالة CONFIRMED بيد المراجع لا بيد الوثيقة؛ عنوان CONFIRMED السابق في هذا الموقع كان غير صالح. عند الاعتماد تنقل الوثيقة إلى CONFIRMED وتؤدي دورها المزدوج المجمد (سجل إغلاق + مرجع دائم لـD3/D4).

---

## 0) النطاق والقيود الموروثة

1. **صفر Kernel code**: المقيّم المرجعي (reference evaluator) يعيش في عدّاء Test E حصرًا — نمط D1. موضع الإنتاج النهائي قرار ترانش لاحق.
2. **حدود §7 الثلاثة حرفًا بحرف** (doc 17): هوية الخيار بعد التقييم فقط وبين المتعادلين · الضمانة «عنصر أعلى حتميًا» لا «الأفضل» · F4-lex/F4-weighted أساسيان وباريتو بالافتراضي المجمد.
3. **L1/L2/L3 موروثة حيث تنطبق**: التقييم يستهلك derived-state ولا يعدله (قراءات خالصة)؛ المخرجات حتمية؛ لا تجميع مخفي.
4. **Temporal carve-out باقٍ**: لا ديناميكا زمنية داخل المقيّم — R1/R2 تدخل كسجلات حالة جاهزة فقط.
5. **قاعدة عدم امتياز D1 باقية**: عقد `decide()` في doc 16 ليس مرجعًا لهذه المواصفة — المقيّم هنا يُبنى من الصفر فوق دلالة doc 17.

---

## 1) أنواع الواصفات — من المفردات المغلقة حصرًا (doc 17 §2.2)

### 1.1 Schema الواصف

```text
descriptor := {
  "channels": { "rel_supply"?: {target: float}, "access"?: {target: float},
                "exposure"?: {target: float} },          # قراءات Model v1 عند الحالة المتنبأة
  "facts":    { "reserves_days"?: {cap: num}, "depends_on"?: {cap: num},
                "possession"?: { <capability_or_gate_id>: degree }, ... },
                # possession: المفاتيح معرفات قدرات/بوابات موجودة في المحتوى، والقيم degrees ∈ [0,1]
                # بنفس دلالة Model v1 حرفيًا (نمط fixtures: {"EUV_gate": 1.0}) — لا مفهوم جديد هنا إطلاقًا
  "records"?: { "counters"?: {...}, "timed"?: [...], "commitments"?: [...] }  # R1–R3 (اختياري)
}
```

### 1.2 قواعد الغلق (ممنوعات صريحة)

- ⛔ أي مفتاح يحمل هوية الفعل أو المسار: `action_id`, `path_id`, ... — **باستثناء موقع واحد**: اختيار ما بعد التقييم بين المتعادلين (حد §7-1)، خارج الواصف تمامًا.
- ⛔ أي حقل محسوب خارج المفردات (لا مقاييس جديدة، لا نسب مصنوعة يدويًا).
- ⛔ أي إشارة لحالة كيانات غير متعلقة بالهدف (لا تجميع بيئي).

### 1.3 حدود صدق v0.1 (موثقة لا مخفاية — بلا أي التزام معماري)

الحالة «المتنبأة» في هذه النسخة تُبنى من **deltas معلنة في الـfixture** (إعلانات نتائج الأفعال). لا يوجد محرك تنبؤ في هذه النسخة، **ولا تصمم هنا، ولا تُجدول هنا، ولا تُسند هنا إلى أي طبقة**. أي ربط مستقبلي بين الواصف وحالة متنبأة حقيقية مسألة جديدة كاملة تتطلب Gate خاصًا بها وفق المنهجية — هذا البند إعلان فجوة نطاق حصرًا، وليس إشارة تصميم أو جدولة.

---

## 2) عائلة الأشكال F1–F5 بصيغ Content JSON

كل هدف قد يعلن كتلة `evaluation` واحدة؛ الشكل المجهول ⇒ خطأ تحميل قاطع. الأشكال:

```jsonc
// F1 خطي-فتري — يتطلب إعلان المقياس صراحة (doc 17 CE-1)
{ "form": "F1", "channels": ["rel_supply"], "target_ref": "Maker_Prime",
  "scale": "interval", "direction": "maximize" }

// F2 إشباعي-معتبي — العتبة والانحدار معاملات محتوى
{ "form": "F2", "fact": "reserves_days.EUV_flow", "floor": 90,
  "below_penalty_per_day": 0.05, "above_saturation": true }

// F3 نسبي — فوق تركيب موجود في Model v1 حصرًا؛ معامل المخالفة معلن إلزاميًا
{ "form": "F3", "composite": "supply_share", "cap": "EUV_flow",
  "of": "Maker_Prime", "ceiling": 0.375, "violation_multiplier": 10.0 }

// F4 متعدد-الأبعاد — ثلاثة أنماط
{ "form": "F4", "mode": "weighted",
  "terms": [ {"term": <F1|F2|F3-block>, "weight": 0.7, "scale_decl": "interval"}, ... ] }
{ "form": "F4", "mode": "lexicographic",
  "priority": [ <condition-block>, <condition-block>, ... ] }   // الأسبق أشد
{ "form": "F4", "mode": "pareto",
  "terms": [ <condition-block>, <condition-block>, ... ],        // شروط عارية بلا غلاف — توازي priority لا weighted
  "tie_extension": { "by": "option_id", "order": "asc" } }       // افتراضي §7 — غير قابل للتجاوز في v0.1
```

### 2.1 قواعد الأعضاء + صيغ المساهمة الحرفية

**الصيغ المعيارية أولًا** (هي المصدر؛ أرقام E في §5 تحقّق لها لا بديل عنها):

**F2 — إشباعي-معتبي** (القيمة `value` تُقرأ من مسار `fact` في الواصف):

```text
if value < floor:    contribution = -(floor - value) * below_penalty_per_day
if value >= floor:   contribution = 0.0                      # above_saturation = true (الوحيد المنفذ في v0.1)
```

**F3 — نسبي** (القيمة `ratio` من تركيب موجود — V5):

```text
if ratio <= ceiling: contribution = (ceiling - ratio)                 # headroom، المضاعف = 1 ثابت
if ratio > ceiling:  contribution = -(ratio - ceiling) * violation_multiplier
```

**ثم القواعد:**

- **F1** بلا `"scale": "interval"` ⇒ رفض تحميل (الافتراض يجب أن يكون معلنًا — درس CE-1).
- **F2** فوق الأرضية: مساهمة ثابتة/مشبعة إذا `above_saturation=true`.
- **F3** يجوز فقط `composite` من الموجود فعليًا في [`scripts/relevance_supply.gd`](file:///c:/tmp/maestro%20engine/scripts/relevance_supply.gd) (`supply_share` اليوم). يجب أن يعلن `violation_multiplier` (عدد > 1). **صيغة المساهمة المجمدة**: `c = (ceiling − share) × (share > ceiling ? violation_multiplier : 1.0)`.
- **F4-weighted** كل term يجب أن يحمل `scale_decl` متوافقًا (لا خلط ordinal مع interval).
- **F4-lex**: المدخل الأول غير المحقق يحسم؛ المساواة الكلية تنزل لتعادل عادي (يدخل §7 إن كانت باريتو).
- **F5** ليس شكلًا يُعلن — انظر قاعدة الرفض الحرفية V3 أدناه.

### 2.2 التجميع عبر أهداف الكيان = مثيل F4 آخر (لا primitive جديد)

`goal_table` متعدد الأهداف يُجمَّع بنفس أنماط F4 (weighted بشرط توافق المقاييس المعلنة | lex بأولوية أهداف معلنة | pareto+§7). بهذا يبقى كل التجميع داخل العائلة نفسها — صفر آليات موازية.

### 2.3 قواعد تحميل حرفية (Loader Validation — نص تنفيذي ملزم)

المقيّم عند قراءة كتلة `evaluation` ينفذ هذه الفحوصات بالترتيب؛ أي فشل ⇒ **رفض تحميل قاطع** (لا تحمّل متسامح):

```text
V0:  if not block.has("form")                        -> REJECT("missing form")

# ---- فحصا الهوية: الترتيب V1a قبل V1b مقصود صراحة ----
# V1a يفحص F5 تحديدًا "قبل" القائمة البيضاء حتى يكون تشخيصه قابلًا للوصول؛
# بالتقسيم القديم (V1 قائمة ثم V3 مستقل) كانت V3 ستكون كودًا ميتًا never-reached —
# عيب الترتيب ذاك سُجل بمراجعة المالك وصُحح هنا. النتيجة REJECT في الحالتين،
# والفارق الوظيفي الوحيد = رسالة تشخيص أدق لمؤلف المحتوى.
V1a: if block.form == "F5"                           -> REJECT("F5 is structural, not declarable")
V1b: if block.form not in {"F1","F2","F3","F4"}      -> REJECT("unknown form")

V2:  if block.form == "F1" and block.get("scale") != "interval"
                                                     -> REJECT("F1 requires declared interval scale")
V4:  if block.form == "F4":
       if block.mode == "pareto" and block.get("tie_extension") != {"by":"option_id","order":"asc"}
                                                     -> REJECT("tie_extension immutable in v0.1")
       if block.mode == "weighted" and any(term lacks "scale_decl" compatible with its term's scale)
                                                     -> REJECT("scale_decl required per weighted term")
V5:  if block.form == "F3" and block.composite != "supply_share"
                                                     -> REJECT("composite outside existing Model v1 set")
V6:  if block.form == "F1" and block.get("direction") not in {"maximize","minimize"}
                                                     -> REJECT("direction must be declared: maximize|minimize")
V7:  if block.form == "F2" and block.get("above_saturation") != true
                                                     -> REJECT("only saturated variant implemented in v0.1")
```

ملاحظات:
- **V2/V6 فلسفة واحدة**: كل افتراض قياس/اتجاه يجب أن يكون **معلنًا** — لا قيم افتراضية ضمنية (درس CE-1).
- ترقيم V3 تُرك فارغًا **عمدًا** توثيقًا لدمجه في V1a بعد ملاحظة الكود الميت — لا يعاد استخدام الرقم حتى لا يوحي بوجود فحص سادس مستقل.
- `"form": "F5"` غير موجود في اللغة الإعلانية أصلًا؛ ثبات F5 البنيوي مصدره توقيع المقيّم (لا هوية فعل في التسجيل)، وV1a مجرد إنذار مبكر لخطأ محتوى.

---

## 3) تطبيق اتفاقية §7

1. حساب الترتيب/الحد الأعلى **كاملًا أولًا** — الاختيار بين عناصر عليا غير قابلة للمقارنة يتم **بعده فقط** بـ`option_id` تصاعديًا.
2. مخرَج المقيّم يوصف رسميًا: *«اختيار حتمي لعنصر أعلى»* — ممنوع في أي نص/اختبار وصفه بـ«الأفضل».
3. أي اتفاقية أغنى مستقبلاً = حقل محتوى جديد خارج v0.1.

---

## 4) البروتوكول التنفيذي

- **Fixtures جديدة**: `e_base.json` (عالم مشتق مصغر) + `e_actions.json` (أفعال بواصفات deltas معلنة، منها **توأمان** بواصف متطابق bitwise لأجل E6) — تُكتب قبل العدّاء وتُجمد أرقامها أدناه.
- **deg/degree منطبقة**: أي bug ⇒ إعادة Test E كاملًا من الصفر.
- **Evidence**: `.ai/evidence/tests/test_e_evaluation_spec.log`

## 5) Test E — معيار القبول المجمد (قبل أي كود)

**ثوابت الـfixtures مجمّدة هنا بالأرقام** — اختيرت جميعها ثنائية-الدقة (binary-exact) حتى تكون المقارنات bitwise بلا فخوف عشري. العدّاء والـfixtures ملزمون بها حرفيًا:

```text
F1-probe : weight=1.0, scale=interval, direction=maximize, target=Maker_Prime
           ACT_D1A: Δrel_supply = +0.25   |   ACT_D1B: Δrel_supply = +0.50
F2-probe : floor=90, below_penalty_per_day=0.0625, above_saturation=true
           probes: reserves ∈ {75, 90, 120}
F3-probe : ceiling=0.375, violation_multiplier=10.0
           probes: share ∈ {0.75, 0.3125, 0.25}
F4-probe : dims A(supply Δ+0.25, interval/maximize), B(exposure worsens: access Δ+0.05
           under direction=minimize => contribution −0.05), interval
           weighted weights {A:0.75, B:0.25}  |  lex priority [B-first(no-worsen), A]
           options OPT_TRADE (يحمل Deltas) / OPT_BASE (صفر deltas)
E5-pair  : OPT_P1/OPT_P2 incomparable maxima   E6-twins: ACT_TWIN_X/ACT_TWIN_Y + D_TWIN واحد
```

| # | الفحص | الشرط التنفيذي الحرفي + نص assertion المجمد |
|---|---|---|
| E1 | F1 رتابة | `score(D1B) − score(D1A) == 0.25` **بالضبط** (فرق الدلتا ثنائي-دقة؛ لا سماحية). assertion: `"E1 monotonicity holds under declared interval scale"` |
| E2 | F2 الكينك | `contrib(75) == −(90−75)×0.0625 == −0.9375` بالضبط · `contrib(90) == 0.0` · `contrib(120) == 0.0` (تشبع). assertion: `"E2 satisficing kink: below-floor deficit penalized at declared rate; at/above floor contributes zero"` |
| E3 | F3 السقف | `c(0.75) == −3.75` · `c(0.3125) == +0.0625` · `c(0.25) == +0.125` بالضبط، و`c(0.25) − c(0.3125) == 0.0625` (ميل تحت السقف = مضاعف 1: سقفٌ لا سباق). assertion: `"E3 ratio ceiling: above-ceiling share penalized by declared multiplier; headroom linear without bonus"` |
| E4 | F4-lex مقابل weighted | weighted: `net = 0.75×(+0.25) + 0.25×(−0.05) == +0.175 > 0` ⇒ يقبل ⇒ `decision_weighted == "OPT_TRADE"` · lex: الشرط الأول [B no-worsen] مخفوق (ΔB=−0.05<0) ⇒ يرفض ⇒ `decision_lex == "OPT_BASE"`. assertion: `"E4 lexicographic refuses trade-off that weighted accepts - both forms earn membership"` |
| E5 | F4-pareto + §7 | بمجموعة العناصر العليا `M` (≥2 غير قابلين للمقارنة): `chosen == min(M, by=option_id)`. assertion نصه المجمد: `"E5 selects a maximal element deterministically via option_id ascending (doc17 §7)"` — ممنوع أي صياغة بديلة |
| E6 | **CE-5 توأمان (شرط قبول إلزامي)** | `ACT_TWIN_X.action_id != ACT_TWIN_Y.action_id` و`canonical(D_TWIN_X) == canonical(D_TWIN_Y)` ⇒ `canonical(scores_X) == canonical(scores_Y)` bitwise. أي اختلاف = كسر F5 مباشرة. assertion: `"E6 twin actions with identical descriptors yield bitwise-identical scores (Gate-2 path-neutrality)"` |
| E7 | عمى الهوية | تطبيق خريطة تسمية على كيانات e_base ثم التقييم: `canonical(scores_base) == canonical(inverse_map(scores_renamed))` مساواة سلسلة حرفية. assertion: `"E7 evaluation identity-blind: scores invariant under entity renaming (inverse-mapped)"` |
| E8 | قراءة-فقط + حتمية | `canonical(world_before) == canonical(world_after)` و`canonical(descriptors_before) == canonical(descriptors_after)`، وتشغيلان مستقلان ⇒ تطابق كامل المخرجات. assertion: `"E8 read-only evaluation, deterministic across independent loads"` |

**شرط إغلاق الوثيقة:** PASS لكل الثمانية بصيغها الحرفية أعلاه ⇒ الحالة تنتقل PROVISIONAL → **CONFIRMED**، وتصبح المرجع الدائم لتدقيق تنفيذات D3/D4.

| 2026-08-26 | **rev.4 بمراجعة المالك**: أُضيفت صيغتا المساهمة الحرفيتان لـF2/F3 في §2.1 بنمط الشرط التنفيذي (IF-form) — فصارت الأرقام في §5 تحقّقًا للصيغة لا بديلًا عنها؛ وأُضيفت V7 (رفض `above_saturation != true` — الوحيد المنفذ في v0.1) | طلب المالك: «الصيغة مكتوبة حرفيًا في §2 وإلا فهي أرقام بديلة عن المعادلة لا تحقق لها» — وبعد ذلك **إذن صريح ببدء fixtures + عدّاء Test E** |

| 2026-08-26 | **rev.4b (أثناء التنفيذ المصرح به — قبل CONFIRMED)**: تشغيل TestE أول كشف علتين fixture/spec ⇒ deg/degree توقف كامل ⇒ (1) صيغة terms الباريتو لم كانت محددة في §2 — حُسمت **شروطًا عارية** توازي priority لا weighted، وكتبت في §2 صراحة؛ (2) إشارة OPT_TRADE في e_actions كانت `access Δ−0.05` بينما "التدهور" تحت direction=minimize يعني `Δ+0.05` (المساهمة −0.05 كما يجمدها صف E4 نفسه) — صح الـfixture وضبط سطر الثوابت §5؛ (3) خطأ تحميل canonical في العدّاء أصلحه قبل أي دورة | تنفيذ بروتوكول deg/degree حرفيًا داخل مرحلة التنفيذ أيضًا؛ الوثيقة لم تُغلق بعد فالتعديل المشروع قبل الإغلاق بشرط التوثيق |

| 2026-08-26 | **rev.4c — إفصاح وإثبات (بطلب المالك قبل قبول CONFIRMED)**: (أ) **إفصاح pareto-terms**: الفجوة كانت في rev.3 نفسه (جمدنا weighted المغلف وlex العاري وأغفلنا pareto — خطؤنا التوثيقي)؛ القرار أثناء التنفيذ: *شروط عارية* = كتل F1/F2/F3 نفسها بلا غلاف ولا أوزان — **ليس primitive جديد** (لا قدرة حسابية/دلالية خارج ما كسبه lex عضويته عبر CE-4؛ إعادة استخدام صياغة قائمة) ⇒ لا Deletion Test مطلوب، لكن كان الصواب التوقف للسؤال قبل التنفيذ ويُسجل ذلك إخلالًا إجرائيًا منقحًا؛ (ب) **دليل deg/degree**: R1 parse-abort (0 فحص) → R2 محاولة كاملة FAIL 13/3 انقطعت داخل E5 → R3 إعادة كاملة **PASS 16/16**؛ لوجات R1/R2 استُبدلت بخطوة التنظيف قبل R3 (**غير مؤرشفة — إقرار صريح**)؛ الدليل الملزم: المجموعة المجمدة سلفًا في rev.4 (commit `13bd605` قبل أي تشغيل) = E1–E8، واللوج النهائي يحيويها 8/8 بنصوصها + 8 L إضافية تحصينًا — [PASS]=16 [FAIL]=0 بعد آلي؛ (ج) **تطابق حرفي code↔spec**: عدّ آلي لتسع رسائل V + صيغتا F2/F3 + assertion-labels الحساسة في مصدر العدّاء ⇒ كلها موجودة (count≥1)؛ SHA256 للملفات الخمسة مسجل بمحضر الجلسة | مبدأ «تم بلا دليل» — النتيجة كانت PASS لكن المطلوب raw+checksum+تصنيف وقد سُلم بالحرف |

## 6) حالة الوثيقة

✅ **CONFIRMED — Evaluation Specification v0.1 (Test E PASS 16/16، EXIT=0)**

الوثيقة الآن تؤدي دورها المزدوج المجمد: سجل إغلاق **و**مرجع مراجعة دائم تُقاس عليه تنفيذات D3/D4.

### نتائج Test E الفعلية ([raw log](file:///.ai/evidence/tests/test_e_evaluation_spec.log))

| المجموعة | النتيجة |
|---|---|
| Loader L0–L7 | القوائم الست تحمّل نظيفة · الرفوض السبعة برسائلها الحرفية بالضبط (منها F5-structural وtie_extension-immutable) |
| E1 | diff == 0.25 بالضبط |
| E2 | −0.9375 / 0 / 0 بالضبط |
| E3 | −3.75 / +0.0625 / +0.125 بالضبط والميل 0.0625 بلا مكافأة |
| E4 | weighted=OPT_TRADE (net +0.175) · lex=OPT_BASE (متجه [false,true]) — مختلفان |
| E5 | M={P1,P2} ⇒ chosen=OPT_P1 بنص assertion §7 الحرفي |
| E6 | توأمان: descriptors وscores bitwise متطابقة والقرار حتمي |
| E7/E8 | عمى الهوية بعد عكس الخريطة · قراءة-فقط + حتمية إعادة التشغيل |

### سجل المراجعة

| التاريخ | الإجراء | السبب |
|---|---|---|
| 2026-08-26 | إنشاء الوثيقة بالشكل المؤسسي الذي قرره المالك: Gate-Style بإغلاق تنفيذي (Test E) + دور مرجعي دائم بعده — وكلا الدورين لا أحدهما | سؤال المالك الصريح عن الشكل قبل الكتابة؛ خيار «نثرية مرجعية فقط» رُفض لأنه يؤجل كشف أخطاء F1–F5 طبقة كاملة |
| 2026-08-26 | **rev.2 بمراجعة المالك**: (أ) §1.3 أعيدت صياغته — حُذف ذكر «طبقة Planning» كوجه ربط، واستُبدل بإعلان فجوة صرف بلا أي التزام معماري أو جدولة؛ (ب) أُضيف §2.3 قواعد تحميل حرفية V0–V5 تجيب نصيًا: إلزامية `"scale": "interval"` في F1 (V2)، ورفض `"form": "F5"` صراحة (V1/V3)، وقفل `tie_extension` (V4)، وقصر F3 على composites الموجودة (V5)؛ (ج) E5 صار شرطًا تنفيذيًا حرفيًا `chosen == min(M, by=option_id)` بنص assertion مجمد | ملاحظة المالك: الملخص الوصفي ليس دليلًا حرفيًا — والسطر السابق في §1.3 كان يلمّح لربط Planning داخل مستند لا يملك بوابة تبرره (خيط Gate 15 المؤجل). النوع نفسه من الانزلاق الذي وقع في Gate 15 §3.11 وفي D1 boost_empty — يُعالج قبل التجميد لا بعده |
| 2026-08-26 | **rev.3 بمراجعة المالك** — أربعة إصلاحات: (1) **V3 كانت كودًا ميتًا**: بالترتيب القديم V1(القائمة) قبل V3(F5) لم تكن V3 تُصل أبدًا؛ أُعيدت الهيكلة V1a(F5 أولًا)/V1b(القائمة) مع توثيق أن التفريق مقصود تشخيصيًا فقط (نفس REJECT، رسالة أدق)، والرقم V3 تُرك فارغًا عمدًا؛ (2) **`{gate: num}` كان خطأ تسمية**: صُحح إلى `{<capability_or_gate_id>: degree}` — درجات الملكية الموجودة في المحتوى بنفس دلالة Model v1، لا مفهوم جديد ⇒ لا deletion test مطالب؛ (3) **`direction` بلا قيم معرفة**: أُضيفت V6 بمجموعة مغلقة {maximize, minimize} إلزامية — نفس فلسفة V2 (كل افتراض معلن)؛ (4) **E1–E4/E7–E8 رُقّيت للحرفية الكاملة**: ثوابت fixtures مجمّدة بالأرقام (ثنائية-الدقة كلها: 0.25/0.50/0.0625/0.375/10.0/0.75/0.25...) + شرط تنفيذي + نص assertion مجمد لكل فحص، وأُضيف `violation_multiplier` معلنًا إلزاميًا لـF3 بصيغة المساهمة المجمدة | مراجعة المالك الرابعة: استمرار نفس معيار «الحرفي لا الوصفي» بلا استثناء حتى داخل جدول القبول نفسه |

---

---

## 7) ملحق الأدلة الخام المنقولة (Raw Evidence Transcript — rev.4d)

**سطر التشغيل:** `& "Godot_v4.7.2-stable_win64_console.exe" --headless --path "C:\tmp\maestro engine" --script res://scripts/test_e_evaluation_spec.gd` · **EXIT=0**
**مرساة الإثبات:** commit `12a8e15` (fixtures + runner + هذا اللوج كما هو)

### 7.1 اللوج الكامل — منقول حرفيًا (60 سطرًا، بلا أي تحرير)

```text
﻿Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org


============================================================
  TEST E - EVALUATION SPECIFICATION v0.1 ACCEPTANCE
  Reference evaluator harness-local | doc18 rev.4 frozen
============================================================

---------------- RAW: weighted scores ----------------
  G_F4W OPT_TRADE => 0.1750000000 | OPT_BASE => 0.0000000000
----------------------------------------------

-- L0: all six fixture goals load clean under V0-V7
[PASS] L0 fixture goals all pass loader validation

-- L: loader rejection probes (V-rules executable)
[PASS] L1 unknown form rejected with exact reason
[PASS] L2 form F5 rejected as structural-not-declarable
[PASS] L3 F1 without scale=interval rejected
[PASS] L4 F1 direction outside closed set rejected
[PASS] L5 tampered tie_extension rejected (immutable)
[PASS] L6 composite outside Model v1 set rejected
[PASS] L7 non-saturated F2 variant rejected in v0.1

-- E1: F1 monotonicity (declared interval scale)
   D1A=0.2500000000 D1B=0.5000000000 diff=0.2500000000
[PASS] E1 monotonicity holds under declared interval scale

-- E2: F2 satisficing kink (floor=90 penalty=0.0625)
   c(75)=-0.9375000000 c(90)=0.0000000000 c(120)=0.0000000000
[PASS] E2 satisficing kink: below-floor deficit penalized at declared rate; at/above floor contributes zero

-- E3: F3 ratio ceiling (ceiling=0.375 multiplier=10)
   shares 0.7500/0.3125/0.2500 => c=-3.7500/0.0625/0.1250
[PASS] E3 ratio ceiling: above-ceiling share penalized by declared multiplier; headroom linear without bonus

-- E4: lexicographic vs weighted divergence
   weighted=>OPT_TRADE net_TRADE=0.1750000000 | lex=>OPT_BASE sat_VECTOR_TRADE=[false, true]
[PASS] E4 lexicographic refuses trade-off that weighted accepts - both forms earn membership

-- E5: pareto maxima + section-7 extension
   maxima={OPT_P1, OPT_P2} chosen=OPT_P1
[PASS] E5 selects a maximal element deterministically via option_id ascending (doc17 section 7)

-- E6: CE-5 twin actions (mandated acceptance)
   descriptors identical=true scores identical=true decisions X/Y=ACT_TWIN_X/ACT_TWIN_X
[PASS] E6 twin actions with identical descriptors yield bitwise-identical scores (Gate-2 path-neutrality)

-- E7: evaluation identity blindness
   base==renamed(after inverse map): true
[PASS] E7 evaluation identity-blind: scores invariant under entity renaming (inverse-mapped)

-- E8: read-only + determinism
[PASS] E8 read-only evaluation, deterministic across independent loads

============================================================
  TEST E RESULT: PASS (16 checks)
============================================================
[Dispatch] Registry loaded: 8 event handlers, 5 job handlers
```

### 7.2 SHA256 كاملة غير مقتطعة

| الملف | SHA256 |
|---|---|
| .ai/evidence/tests/test_e_evaluation_spec.log | `E98221C7B47A394E278CF2AEC2BF59D3F6FA72D635582D6436252DA1C9071733` |
| scripts/test_e_evaluation_spec.gd | `9C66E7A65CBD29A9741DF9CFA199E1C6C4205FCF989873932D89E76D90C9A900` |
| data/worlds/model_v1/e_base.json | `315C4EEAE43EF0A027504A63CDF0B75DC3A94BB727C51718139DFC1A80CC18DC` |
| data/worlds/model_v1/e_actions.json | `4D6D9DB903B795976FADA1FCA732407113A2887DBE505D3D0AAB0BA68CD5C34B` |
| data/worlds/model_v1/e_goals.json | `593BB12FB962BA40182175465C6FA278A7016644E1268EB26F8196CBFEA2C432` |

### 7.3 فجوة R1/R2 والقاعدة الإجرائية الجديدة

R1 (parse-abort، صفر فحص) وR2 (محاولة كاملة FAIL 13/3 انقطعت داخل E5) لم تُؤرشفا — استُبدلتا بخطوة تنظيف قبل R3، ويُقر بذلك أن رقم R2 غير قابل للتحقق المستقل. التعويض الموثق: مجموعة القبول المجمدة E1–E8 كانت في commit `13bd605` قبل أي تشغيل، وتظهر 8/8 بنصوصها الحرفية في لوج R3 أعلاه (+8 فحوص L إضافية تحصينًا) — لا حذف ولا تخفيف. **من تاريخ rev.4d: كل تشغيل وسيط يُؤرشف إلزاميًا باسم runNN.log ويُدرج في محضر deg/degree — الحذف أو الاستبدال ممنوع.**

---

**Evidence trail:** docs 11/15/16/17 + هذا الملف. صفر كود حتى الآن — التزامًا بشروط الإذن.
