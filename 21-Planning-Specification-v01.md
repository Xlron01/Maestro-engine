# 21 — Planning Specification v0.1

> **ثاني وثيقة تنفيذية — Gate-Style بإغلاق تنفيذي (Test P)، بنفس دستور doc 18 الناجح وكل دروسه:**
> توقعات القبول مجمّدة هنا **قبل أي سطر كود** · لوجات التشغيلات الوسيطة تُؤرشف `runNN.log` إلزاميًا · transcript + SHA256 كاملة تُضمَّن في الوثيقة عند الإغلاق · سطر commit-scope تصريحي مطلوب عند الإقفال · **الحالة CONFIRMED بيد المراجع لا الوثيقة**.
>
> طبقة الادعاء: **Architecture/Mechanism فقط** — Correctness لاختباراته، Behavioral adequacy لـGeneralization Gate اللاحق (سلّم doc19 §6).

---

## 0) الاكتشاف المؤسِّس F-1 والعالم المستهدف (بتصريح المالك)

**F-1 — عالمان منفصلان:** معالجات `dispatch.json` الثمانية تحرك عالم اللعب (`countries`/`provinces`/`agents`)، بينما عالم Model v1 الاستراتيجي (`entities`: possession/produces) لا يملك أي handler اليوم.

**القرار المجمد (خيار A):** هدف الـreplay في v0.1 = **العالم القديم حصرًا** بأفعال من الأحداث الحتمية الخمسة الموجودة — صفر ملفات جديدة، وأقوى برهان T4 (شلال War_Started المتسلسل).
**حجية المفردات (قرار المالك):** أي مفتاح على كيان داخل النسخة الافتراضية بعد replay = **fact مشروع بحجية doc12-CE1** (Entity قاموسي عام) — يُكتب هذا التفسير هنا تصريحًا لا استنتاجًا.
*(تسجيل مؤجل: replay يمس قنوات Model v1 نفسها يتطلب محتوى جديدًا — بند مستقبلي §6.)*

## 1) عقد التنبؤ المرجعي (IF-form ملزم)

```text
predict(action a, world w_real, depth d):
  if d > N(=3):            REJECT("horizon-exceeded")          # فحص أول — الأسبقية له
  h := deep_copy(w_real);  h.hypothetical = true               # وسم إجرائي (doc19 ق3)
  GameEventHandlers.dispatch(a.event, a.payload, h)             # المعالجات الموجودة حصرًا
  return hypothetical_view(h)                                   # قراءة facts عامة (doc12-CE1)

chain([a1..ak], w):  # k ≤ N
  S0 := w_real
  لكل i: إن فشلت شروط ai على Si-1 (مطابقة {field,op,value} نمط Gate15 §3.2) ⇒ invalid_at_step=i
         Si := predict(ai, Si-1, i)
  outcome_descriptor := hypothetical_view(Sk)
```

**HypotheticalSim (واجهة العدّاء):** stub يكشف `rules` (politics.json كما هو) + `world` (النسخة) + `events` طابور + `activation` سجل + `rng` مجمد غير مستخدم — يستقبل `GameEventHandlers.setup()` فتعمل المعالجات الحقيقية دون تعديل.

## 2) الآلية الدنيا المجمدة

| البعد | v0.1 | ممنوع |
|---|---|---|
| Horizon | N=3 سقف صلب، تجاوز ⇒ رفض `horizon-exceeded` **بأسبقية** على أي فحص آخر | قطع صامت |
| Branching | معدوم — سلاسل خطية فقط | تفريع/cap |
| Search | معدوم — تقييم سلاسل مرشحة معلنة فقط | best-first/أي استراتيجية |
| Cost | غير معرَّف (لا مفردات تكلفة موجودة) | أوزان ضمنية |
| Pruning | بوابة الشروط وحدها (§1) | أي pruning آخر |

**الأحداث المرخصة (حتمية الخمسة):** `War_Started` · `Railway_Damaged` · `Coup_Attempt` · `Minister_Died` · `Agent_Exposed`.
**مستبعد:** `Election` — يستخدم `sim.rng.randf_range` ⇒ مخالف للحتمية (P7).

## 3) الممنوعات

1. **DEFERRED-7 tripwire:** كل كيان يتنبأ على نسخته **باستقلال تام**؛ أي مسار تنسيق/قراءة نوايا الآخرين داخل predict = FAIL تصميمي (يُفعِّل إعادة فتح مسألة Coordination).
2. partial-observability · عشوائية · هوية فعل في أي واصف — باقية نصًا.
3. لا تعديل على Kernel/handlers قائمة — المحتوى الجديد (إن لزم لاحقًا) Gate/إذن مستقل.

## 4) Test P — التسجيل المسبق المجمد (قبل أي كود)

### 4.1 ثوابت العالم `p_base` (تُبنى في العدّاء مطابقةً لحرفها)

```text
A: {stability:1.0, threat:0.0, border:0.0, econ_stab:1.0, growth:0.5, gdp:100.0, power:10.0, at_war:[]}
B: {stability:0.5, threat:0.0, border:0.0, econ_stab:1.0, growth:0.5, gdp:100.0, power:10.0, at_war:[]}
C: {stability:0.9}   D: {stability:1.0}
P1: {owner:B, damage:0.0, supply:1.0}
rules = politics.json الفعلية (war_threat_increase=5.0 · railway_damage=0.4 · railway_supply_loss=0.3 ·
        railway_stability_loss=0.02 · minister_death_loss=0.05 · coup_loss=0.2 · exposure_penalty=0.03 ·
        threshold=0.0 · weights كلها 1.0 · military_power_gain=1.0 · spending_cost=0.01)
```

### 4.2 الشلال المحسوب يدويًا لـWar_Started(A→B) — المسار مفروض رياضيًا

```text
sec(B) = 5.0×1 + 0×1 = 5.0   >   prosp(B) = 1.0×1 + 0.5×1 = 1.5 (+threshold 0.0)
⇒ chosen="security" ⇒ power += 1.0 ; gdp −= 100×0.01
```

### 4.3 فحوص Test P

| # | الشرط التنفيذي الحرفي | assertion المجمد |
|---|---|---|
| TP1 | predict(WAR) مرتان من نسختين مستقلتين ⇒ canonical(hypothetical_view) متطابقة bitwise | `"TP1 prediction is bitwise-deterministic across independent clones"` |
| TP2 | لقطات world_real + relevance matrices قبل/بعد كل التنبؤات ⇒ bitwise متطابقة | `"TP2 thought never mutates the real world (P6 forward)"` |
| TP3 | سلسلة [RAIL(P1), RAIL(P1), RAIL(P1)] بشرط `{P1.damage < 0.8}` لكل تطبيق ⇒ `invalid_at_step == 3` بالضبط | `"TP3 precondition gate invalidates chain at exact failing step"` |
| TP4 | بعد predict(WAR): `B.threat==5.0` · `B.at_war==[A]` و`A.at_war==[B]` · `B.chosen=="security"` · `B.gdp==99.0` بالضبط · `B.power==11.0` · `A.stability==1.0` لم تُلمس · طابور أحداث h يحوي **بالضبط واحدًا** نوعه `Military_Spending_Increase` | `"TP4 replay captures emergent cascade absent from any declared delta"` |
| TP5 | `descriptor(chain([RAIL,RAIL],w)) == descriptor(predict(RAIL, predict(RAIL, w)))` bitwise | `"TP5 sequential composition is bitwise-associative"` |
| TP6 | مسح آلي لواصف كل التنبؤات: المفاتيح ⊆ (مفاتيح الكيانات المستنسخة ∪ قنوات doc17) ولا ظهور لأي `action_id/path_id` | `"TP6 predicted descriptors stay inside the closed vocabulary - no action identity"` |
| TP7 | سلسلة [RAIL×4] ⇒ REJECT `"horizon-exceeded"` **رغم** أن شرط الخطوة الثالثة كان سيفشل — إثبات أسبقية السقف | `"TP7 hard horizon precedes all other checks"` |
| TP8 | تنبؤ متوازٍ معزول: WAR على نسخة A-محور وRAIL على نسخة B-محور ⇒ مجموعات المفاتيح المتغيرة منفصلة تمامًا (تقاطع = ∅) | `"TP8 entities predict independently - DEFERRED-7 trigger not fired"` |
| TP9 | COUP(C) ⇒ `stability == 0.7` بالضبط · MINISTER(D) ⇒ `stability == 0.95` بالضبط | `"TP9 deterministic single-event effects match frozen arithmetic exactly"` |
| TP10 | RAIL(P1): `damage==0.4` · `supply==0.7` بالضبط · `B.stability==0.48` بالضبط · عدّاد activations == 2 | `"TP10 multi-target side-effects captured exactly (owner coupling included)"` |

**شرط الإغلاق:** PASS للعشرة بنصوصها ⇒ PROVISIONAL→CONFIRMED (بختم المراجع) + transcript/SHA256 مضمّنة + سطر commit-scope.

## 5) البروتوكول التنفيذي

Fixtures تُبنى داخل العدّاء مطابقةً لـ4.1 حرفًا · **أرشفة إلزامية**: كل تشغيل وسيط `runNN.log` · deg/degree على أي bug · Evidence: `.ai/evidence/tests/test_p_planning_spec_run01.log…`

## 6) حالة الوثيقة

⏸️ **PRE-REGISTERED / PROVISIONAL — بانتظار مراجعة المالك قبل fixtures+عدّاء.**

### سجل المراجعة

| التاريخ | الإجراء | السبب/التوكيد |
|---|---|---|
| 2026-08-26 | إنشاء الوثيقة بعد قرار المالك: Planning قبل D3، وبعد إجابات التأسيس الأربعة: خطي N=3 · أفعال حقيقية عبر dispatch · كتالوج الـ20 بالإحالة المرجعية · Pre-reg ثم توقف | ضبط الطبقات والأفق مسبقًا |
| 2026-08-26 | **توقف تقني مشروع أثناء الاستكشاف** → قرارا المالك: F-1 (هدف الreplay = العالم القديم، خيار A) + حجية المفردات التوسعية بحجية doc12-CE1 — كُتبا تصريحًا في §0/§1 | اكتشاف انفصال العالمين؛ اختلاق handlers جديدة كان توسيعًا خفيًا |
| 2026-08-26 | استبعاد `Election` من الأحداث المرخصة (استخدام rng) وتجميد أرقام §4 بعد التحقق الحسابي المباشر (0.7/0.95/0.48/0.8/99.0 كلها bitwise-true) | P7 الحتمية + معيار «الأرقام تحقق الصيغة» |

---

**Evidence trail:** docs 11/15/16/17/18/19/20 + هذا الملف. صفر كود حتى الآن — التزامًا بإيقاع Pre-reg ثم توقف.
