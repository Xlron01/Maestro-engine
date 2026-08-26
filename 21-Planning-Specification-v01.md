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

### 4.4 نتائج Test P الفعلية ([run01 raw](file:///.ai/evidence/tests/test_p_run01.log))

| المجموعة | النتيجة |
|---|---|
| L0 | الأحداث المرخصة الحتمية فقط في الـfixture |
| TP1 | views bitwise متطابقة عبر نسختين مستقلتين |
| TP2 | world_real + rules لم يُلمَسا bitwise |
| TP3 | `invalid_at_step == 3` بالضبط |
| TP4 | threat=5.0 · at_war=[A]/[B] · chosen=security · gdp=99.0 · power=11.0 · A سليمة 1.0 · طابور=1×Military_Spending_Increase |
| TP5 | تركيب تسلسلي bitwise-associative |
| TP6 | صفر مفاتيح خارج المغلق، صفر هوية فعل |
| TP7 | `horizon-exceeded` بأسبقية على فشل الشرط |
| TP8 | تقاطع مفاتيح التغير = ∅ (الزناد لم يُطلق) |
| TP9 | 0.7 / 0.95 بالضبط |
| TP10 | 0.4 / 0.7 / 0.48 بالضبط + activations=2 |

**RESULT: PASS (11 checks) — EXIT=0** *(محاولة سابقة علتها parse أُرشفت run01_attempt1 وفق rev.4d)*

## 5) البروتوكول التنفيذي

Fixtures تُبنى داخل العدّاء مطابقةً لـ4.1 حرفًا · **أرشفة إلزامية**: كل تشغيل وسيط `runNN.log` · deg/degree على أي bug · Evidence: `.ai/evidence/tests/test_p_planning_spec_run01.log…`

## 6) حالة الوثيقة

⏸️ **PROVISIONAL — Test E-P: PASS 11/11 (run01, EXIT=0)** · الأدلة التشغيلية الخام منقولة حرفيًا في §7 بانتظار ختم المراجع (الحالة CONFIRMED بيده لا بيد الوثيقة)

### سجل المراجعة

| التاريخ | الإجراء | السبب/التوكيد |
|---|---|---|
| 2026-08-26 | إنشاء الوثيقة بعد قرار المالك: Planning قبل D3، وبعد إجابات التأسيس الأربعة: خطي N=3 · أفعال حقيقية عبر dispatch · كتالوج الـ20 بالإحالة المرجعية · Pre-reg ثم توقف | ضبط الطبقات والأفق مسبقًا |
| 2026-08-26 | **توقف تقني مشروع أثناء الاستكشاف** → قرارا المالك: F-1 (هدف الreplay = العالم القديم، خيار A) + حجية المفردات التوسعية بحجية doc12-CE1 — كُتبا تصريحًا في §0/§1 | اكتشاف انفصال العالمين؛ اختلاق handlers جديدة كان توسيعًا خفيًا |
| 2026-08-26 | استبعاد `Election` من الأحداث المرخصة (استخدام rng) وتجميد أرقام §4 بعد التحقق الحسابي المباشر (0.7/0.95/0.48/0.8/99.0 كلها bitwise-true) | P7 الحتمية + معيار «الأرقام تحقق الصيغة» |
| 2026-08-26 | **rev.2 — التنفيذ المنفذ**: HypotheticalSim stub (extends Node لقبول handlers.setup) + العدّاء عبر dispatch.json الحقيقي ⇒ محاولة R1 علها parse (setup-type + اسم دالة) **أُرشفت** run01_attempt1 ⇒ الإصلاحان ⇒ run01 كامل **PASS 11/11 EXIT=0**؛ النتيجتان العدديتان الحرستان (gdp=99.0/power=11.0) طابقتا الشلال المفروض رياضيًا في §4.2 حرفيًا | deg/degree: R1 لم يكمل أي دورة فأعيد كل شيء؛ الأرشفة بنظام runNN طبقت من أول لحظة |

---

---

## 7) ملحق الأدلة التشغيلية الخام (rev.2 — قبل الختم)

### 7.1 اللوج الكامل run01 — منقول حرفيًا

```text
﻿Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org


============================================================
  TEST P - PLANNING SPECIFICATION v0.1 ACCEPTANCE
  Reference predictor: HypotheticalSim + real dispatch
  Horizon N=3 | run01 archived
============================================================

-- L0: deterministic-event allowlist honored
[PASS] L0 fixture contains only deterministic allowlisted events

-- TP1: prediction determinism
   views identical=true
[PASS] TP1 prediction is bitwise-deterministic across independent clones

-- TP2: thought never mutates the real world
[PASS] TP2 thought never mutates the real world (P6 forward)

-- TP3: precondition gate invalidates at exact failing step
   status=invalid invalid_at_step=3
[PASS] TP3 precondition gate invalidates chain at exact failing step

-- TP4: emergent war cascade
   threat=5.0 chosen=security gdp=99.0 power=11.0 queued=1
[PASS] TP4 replay captures emergent cascade absent from any declared delta

-- TP5: sequential composition bitwise-associative
   equal=true damage=0.8 supply=0.4
[PASS] TP5 sequential composition is bitwise-associative

-- TP6: closed vocabulary scan
[PASS] TP6 predicted descriptors stay inside the closed vocabulary - no action identity

-- TP7: hard horizon precedes everything
   status=rejected reason=horizon-exceeded
[PASS] TP7 hard horizon precedes all other checks

-- TP8: DEFERRED-7 isolation tripwire
   |changed(WAR)|=8 |changed(RAIL)|=3 |intersection|=0
[PASS] TP8 entities predict independently - DEFERRED-7 trigger not fired

-- TP9: single-event arithmetic exacts
   coup(C)=0.70 minister(D)=0.95
[PASS] TP9 deterministic single-event effects match frozen arithmetic exactly

-- TP10: multi-target side-effects with owner coupling
   damage=0.4 supply=0.7 ownerStab=0.48 activations=2
[PASS] TP10 multi-target side-effects captured exactly (owner coupling included)

============================================================
  TEST P RESULT: PASS (11 checks)
============================================================
[Dispatch] Registry loaded: 8 event handlers, 5 job handlers
Godot_v4.7.2-stable_win64_console.exe : WARNING: 86 ObjectDB instances were leaked at exit (run with `--verbose` for 
details).
At line:1 char:114
+ ... og" -Force; & "C:\Users\ahmed\Downloads\Godot_v4.7.2-stable_win64.exe ...
+                 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (WARNING: 86 Obj...` for details).:String) [], RemoteException
    + FullyQualifiedErrorId : NativeCommandError
 
   at: cleanup (core/object/object.cpp:2536)
```

### 7.2 SHA256 كاملة غير مقتطعة

| الملف | SHA256 |
|---|---|| scripts/test_p_planning_spec.gd | `87634fb2322eaca723564c56f0849344c0d576162d4d46e2608af3fdfb80ea13` |
| .ai/evidence/tests/test_p_run01.log | `8096de85840513d464a07343aa880f72df7e5490ea62b57e04cccbb60a61fe40` |
| .ai/evidence/tests/test_p_run01_attempt1_parsefail.log | `066c4b14e40ddd96e38bae0c67a4d16cd8b02aed9abe367c215ae6e61c5183c9` |
| data/rules/politics.json | `8ba94c6fc1aa5e3304265dab0895a55cdaa03052fa6a00e2241c62f5c058d878` |
| data/rules/dispatch.json | `0beeb605cb96cba6dfcfea12f2a17cbb190296f5004586e9bba373f95f57e440` |

### 7.3 تصريح نطاق الـcommits (نمط rev.4e)

- commit التنفيذ الحالي = runner + لوجا runNN + تعديل هذه الوثيقة + دورة الذاكرة — يُذكر هاشه في رسالة التسليم.
- لا يوجد أي commit آخر مساس بهذه الأدلة بعد `f4f1423` (التسجيل المسبق).

### 7.4 محضر validator الخام (إخراج أداة الذاكرة لا لوج محاكاة)

```text
====================================================
  Maestro Memory Validator & Linter
====================================================
Checking project structure...
Checking task files...
Checking link integrity...

----------------------------------------------------
Validation Finished: 0 Errors, 1 Warnings
----------------------------------------------------

Warnings:
  [WARN] Broken file link in .\00-خطة-الطريق.md: c:/tmp/maestro%20engine/acceptance_report.md (Expected file: acceptance_report.md)

[SUCCESS] Memory integrity validation passed successfully!
```

---
---

**Evidence trail:** docs 11/15/16/17/18/19/20 + هذا الملف. صفر كود حتى الآن — التزامًا بإيقاع Pre-reg ثم توقف.
