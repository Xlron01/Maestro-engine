# 22 — Planning Generalization / Behavioral Validation Gate

> **ثالث وثيقة تنفيذية — Gate-Style بإغلاق تنفيذي (Test G)، دستور doc18 كاملًا:**
> توقعات القبول مجمّدة قبل أي كود · أرشفة `runNN.log` إلزامية · transcript + SHA256 كاملة تُضمَّن عند الإغلاق · سطر commit-scope تصريحي · **CONFIRMED بيد المراجع لا الوثيقة**.
>
> **السؤال القابل للقياس (نص الالتزام من doc19 §6):**
>
> **هل يستطيع الـPlanner إنتاج قرارات/خطط صحيحة في مجموعة سيناريوهات مستقلة تختلف في بنية المشكلة لا في القيم فقط؟**

**موقع الطبقة:** Behavioral adequacy حصرًا — فشل الـPlanner لا يفنّد Semantics صحيحة (doc19/doc21)، ونجاحه لا يكتمل بها. الكائن المُختبر: **Planner مرجعي harness-local** مبني من `predict()` (doc21 §1) + تعديلات §1 أدناه + مسند هدف §2. **كيان واحد فقط** — DEFERRED-7 باقٍ غير ممسّ.

---

## 0) الدستور

1. **قاعدة الـfixture الحاكمة (نص المالك):** الاختبار يحدد {العالم + الهدف + الأفعال + القيود + معيار النجاح} **ولا يتضمن الحل أبدًا** — كتابة «المفروض A→B→C» داخل الـfixture تحوّله لاختبار implementation.
2. **قاعدة عدم-الـGate-الوقائي (توقيع المالك):** لا Gate جديدة لاحتمال نظري قبل عجز مثبت/counterexample — صف7 البنية (Coordination) مؤجل بهذه الصفة بالذات.
3. الأحداث المرخصة: الخمسة الحتمية فقط (doc21 §2)؛ `Election` مستبعد (rng).
4. الحتمية والقراءة-فقط والغلق المعجمي: باقية نصًا (وراثة TP1/TP2/TP6).
5. deg/degree + أرشفة runNN + PROVISIONAL حتى الختم.

## 1) تعديلات الميكانيزم المرخصة (Mechanism-Amendments — قرار المالك i)

### A1 — تعداد مُقيّد (DFS)
```text
plan(w, goal, forbidden, actions):
  chains := DFS عمق 1..N(=3)، ترتيب العقد في كل مستوى = option_id تصاعديًا (§7)
            تقليم فوري لأي عقدة تفشل بوابة شروطها (Gate15 §3.2 على العرض الحالي)
  إذا تجاوز العددُ الكلي للمسارات المولَّدة 64 ⇒ FIXTURE_INVALID (خطأ تصميم fixture، يُرفض قبل التشغيل)
  satisfiers := السلاسل التي يحقق واصفُها النهائي كلَ الشروط ∧ لا انتهاكًا واحدًا
  إن كان satisfiers فارغًا ⇒ NO-PLAN
  وإلا ⇒ min(total_cost, ties → ترتيب §7 على نص السلسلة)
```
**التبرير مقابل rule-11:** بدون تعداد يصبحان الأطيفان 4 و6 غير قابلين للاختبار أصلًا — الضرورة مثبتة بالطيف المجمد نفسه؛ **صفر مفردات دلالية جديدة** (التعداد آلية استكشاف، والتكلفة بيانات مقارنة).

### A2 — تكلفة معلنة
حقل `cost` اختياري (عدد ≥0) على نسخة الفعل في المحتوى؛ `total_cost = Σ`؛ توظفها **حصرًا كسر تعادل بين المُحقِّقات** — لا تدخل الواصفات ولا الدلالة.

## 2) مسند الهدف والممنوعات (IF-form)

```text
satisfies(view, goal_list, forbidden_list):
  لكل g في goal_list:   يجب تحقق {field,op,value} على view   (وإلا false)
  لكل f في forbidden_list: يجب عدم تحقق {field,op,value}      (أي تحقق ⇒ false)
  true
```

## 3) المصفوفة — التسعة fixtures المجمدة

عالم مشترك مشتق من Test P (doc21 §4.1) مع إضافات مصغّرة لكل حالة؛ كل الثوابت ثنائية-الدقة ومحققة حسابيًا (0.4+0.4=0.8 · 1.0−0.3=0.7 · 0.5−0.02=0.48 · 0.9−0.2=0.7 · 1.0−0.05=0.95).

| # | الأطياف | العالم/الأفعال/الهدف/الممنوع (مجمد) | الحكم المتوقع | بنيويًا مميز |
|---|---|---|---|---|
| F1 | هدف مباشر بفعل واحد | D{stab:1.0} · MIN_D(cost 2) · Goal `{D.stab==0.95}` | خطة `[MIN_D]` cost2 | خطوة واحدة |
| F2 | سلسلة بترتيب مفروض | B{0.5}·P1{dmg0,sup1}·RAIL1{precond dmg<0.4,cost1}·RAIL2{precond dmg==0.4,cost1}·Goal `{P1.dmg==0.8}` | `[RAIL1,RAIL2]` cost2 — RAIL2 أولًا يُقص عند الخطوة1 | بوابة تفرض الترتيب |
| F3 | **سيئ-ظاهريًا إلزامي أولًا** + فرق أفق | B{0.5}·COUP_B{precond stab>=0.5,cost1}·MIN_B{precond stab>=0.28,cost1}·Goal `{B.stab==0.25}` | `[COUP_B,MIN_B]` وحدها صالحة (0.5→0.3→0.25)؛ [MIN أولًا] يُقص لأن 0.45<0.5 | **G-greedy**: بحث عمق-1 يعجز، عمق-3 يحل |
| F4 | **بطّاع مجاني التكلفة تُستبعده الممنوعات وحدها** + قيد نشط | B{0.5}·P1{dmg0} · RAIL_F4{event Railway_Damaged(P1)، precond dmg<=0.8، cost1} · DECOY_COUP_B{Coup_Attempt(B)، cost0} · Goal `{P1.dmg==0.8}` · Forbidden `{B.stab<0.44}` | المطيع `[RAIL,RAIL]`: dmg 0→0.4→0.8 · stab 0.5→0.48→0.46 (آمنة) · cost2. الطّعم `[DECOY,RAIL,RAIL]`: dmg 0.8 **محقّق نفسه** وبنفس التكلفة 2، لكن stab 0.3→0.26 < 0.44 ⇒ ممنوع | **قيد نشط حقيًا**: الممنوعات هي الفاصل الوحيد بين محقّقتين متساويي التكلفة |
| F5 | قيود تمنع أقصر طريق | B{0.5}·P1{dmg0}·P2{dmg0,sup1}·RAIL_P1{precond dmg<=0.4}·RAIL_P2{precond **P1.dmg>=0.4**}·Goal `{P1.dmg==0.8 AND P2.dmg==0.4}` | `[P1,P2,P1]` (0→.4؛ P2 تُفتح؛ →.8) — أي ترتيب يبدأ بP2 يُقص خطوة1 | اعتمادية تفتح البديل الوحيد |
| F6 | خطط متعددة بتكاليف مختلفة | كما F2 لكن بإضافتين: RAIL1_cost=1 · RAIL2_cost=1 · **RAIL2X** نسخة مطابقة لRAIL2 بـcost=7 (فعلاً مكرر المفعول) · Goal `{P1.dmg==0.8}` | مُحقِّقات متعددة؛ المختار `[RAIL1,RAIL2]` cost2 (الأدنى) لا `[RAIL1,RAIL2X]` cost8 | اختبار minimality + تكرارات المفعول |
| F7 | تغيير العالم بثبات Goal | كصف5 لكن `B.stab:0.52` ⇒ بعد ريلين 0.50/0.48 ≠ 0.46 | **NO-PLAN** (الهدف غير قابل للتحقق في هذا العالم) | حساسية العالم |
| F8 | تغيير Goal بثبات العالم | عالم صف2 نفسه، Goal `{P1.dmg==0.4}` فقط | `[RAIL1]` cost1 — خطة أقصر لهدف مختلف | حساسية الهدف |
| F9 | **غير قابل للحل** | C{0.9}·COUP_C{cost1}·MIN_C{cost1}·Goal `{C.stab==0.55}` | من 0.9 ضمن عمق3: مجموعات {−0.2,−0.05} لا تصل 0.55 ⇒ **NO-PLAN صادق** | صدق الإنكار |

## 4) خوارزمية الـPlanner المرجعي (حرفية)

كما §1-A1 حرفًا. **ممنوع على مصدر الـPlanner:** احتواء أي `action_id` خاص بأي fixture (فحص آلي)، أو أي فرع شرطي على اسم fixture/سيناريو.

## 5) PASS/FAIL — Test G

| # | الفحص | الشرط التنفيذي | assertion المجمد |
|---|---|---|---|
| G1..G8 | لكل fixture قابل للحل (1–8) | الخطة المعادة: تمر ببواباتها عند إعادة تشغيل replay مستقل bitwise + `satisfies(view_final)` true + تكلفة مسجلة مطابقة مجموع المعلن | `"G<n> returns a valid minimal-cost plan for structurally-distinct problem"` |
| G9 | F9 | الناتج `NO-PLAN` وليس سلسلة | `"G9 honestly reports NO-PLAN on unsolvable problem"` |
| G-det | حتمية | تشغيل كامل مرتين ⇒ canonical(output) متطابق | `"G-det planner is bitwise-deterministic across runs"` |
| G-pure | نقاء | لقطات العالم الحقيقي قبل/بعد ⇒ bitwise | `"G-pure planning never mutates the real world"` |
| G-audit | **منع الحل-داخل-fixture** | فحص آلي: ملفات fixtures بلا مفاتيح `expected/solution/plan_` (case-insensitive) + مصدر الـPlanner بلا أي `action_id` من الـfixtures | `"G-audit fixtures contain no solutions and planner contains no fixture-specific ids"` |
| G-greedy | فرق الأفق (F3) | بحث عمق-1 ⇒ لا مُحقِّق؛ عمق-3 ⇒ خطة صالحة | `"G-greedy depth-1 fails where depth-3 succeeds - lookahead value proven"` |
| G-cost | أدنى تكلفة (F6) | `cost(chosen) == min(cost(satisfiers))` بالضبط | `"G-cost chooses minimum total declared cost among satisfiers"` |
| G-prune | قيد نشط (F4) | (a) count(مخزّنة تحوي DECOY وتحقّق dmg==0.8) >= 1 — الطّعم معدّود ومحقّق للهدف · (b) count(satisfiers containing DECOY) == 0 — الممنوعات استبعدته · (c) chosen بلا DECOY وstab_final == 0.46 | `"G-prune forbidden-constraint alone separates two equal-cost goal-satisfiers"` |

**FAIL لأي:** خطة مخالفة · NO-PLAN كاذب · خطة على غير القابل · لاحتمية · تلويث · تسرب حل.

### 5-a) نتائج Test G الفعلية ([run03 raw](file:///.ai/evidence/tests/test_g_run03.log))

| المجموعة | النتيجة |
|---|---|
| G1–G8 | خطط صالحة bitwise-replay لكل البنى الثماني المختلفة |
| G9 | NO-PLAN صادق على غير القابل |
| G-det / G-pure | حتمية كاملة · صفر تلويث |
| **G-audit** | صفر مفاتيح حل في الfixtures · صفر action-id في نواة الـPlanner |
| G-greedy | عمق-1 يعجز حيث عمق-3 ينجح (قيمة الـLookahead مثبتة سلوكيًا) |
| G-cost | الأدنى معلنًا (2 مقابل 8) بين المُحقِّقات |
| **G-prune** | (a) طُعم مُحقِّق معدود ≥1 · (b) صفر مُحقِّق يحوي DECOY · (c) المختار stab_final==0.46 |

**RESULT: PASS (15 checks) — EXIT=0**

## 5-b) البروتوكول

Fixtures ثوابت §3 داخل العدّاء حرفًا · **runNN.log إلزامي لكل محاولة** · deg/degree · Evidence: `.ai/evidence/tests/test_g_generalization_runNN.log` · عند الإغلاق: transcript + SHA256 كاملة (runner/log/politics/dispatch/fixtures إن فصلت) + سطر commit-scope داخل هذه الوثيقة.

## 6) حالة الوثيقة

⏸️ **PROVISIONAL — Test G: PASS 15/15 (run03, EXIT=0)** · اللوج الخام وSHA256 الكاملة منقولة حرفيًا في §8 · بانتظار ختم المراجع (الحالة CONFIRMED بيده لا بيد الوثيقة)

### سجل المراجعة

| التاريخ | الإجراء | السبب/التوكيد |
|---|---|---|
| 2026-08-26 | فتح البوابة بأمر المالك (الالتزام من doc19 §6) وبقراراته: توسعات داخل البوابة (i) · أطيف تاسع NO-PLAN · فحص فرق الجشع | الطيف الثماني يتطلب تعدادًا وتكلفة مؤجلَيْن إلى Spec بحكم rule-11 — رُخصّا هنا بمبررات موثقة |
| 2026-08-26 | تجميد الثوابت التسعة بحساب يدوي مثبت (كل القيم ثنائية-الدقة) + قواعد الـaudit المضادة لتسرب الحلول | «الحل لا يسكن في الـfixture» أصبح فحصًا آليًا لا وعدًا نثريًا |
| 2026-08-26 | **rev.3 — تصحيح حسابي لF4 بقبع المالك قبل البناء**: النسخة المجمدة ادّعت «ثلاث RAILs تلمس 0.44 بدون اختراق» وهي خاطئة — الهدف dmg==0.8 يُحقق بتطبيقين (cost2، stab0.46 بعيدة عن الحد) فيقع G-prune ديكوريًا. التصحيح: precond الريل في F4 فقط رُفع إلى <=0.8 ليسمح لطّعم DECOY(cost0) بدخول سلاسل محقّقة-للهدف بنفس التكلفة، فتكون الممنوعات <0.44 هي الفاصل الوحيد: (a)وجود طّعم-محقّق معدّود (ب)صفر محقّق-محتوٍ عليه (ج)المطيع 0.46 بلا طّعم. دور DECOY أُيضّح نصًا: طّعام مجاني التكلفة لا يفصله إلا الممنوعات — ليس مسارًا أرخص | درس المرحلة: المراجعة الحسابية للثوابت قبل البناء أمان المشروع من فجوة منطقية لا يكشفها التنفيذ بعد |
| 2026-08-26 | **rev.4 — التنفيذ الكامل للمرحلة B**: خمس محاولات مؤرشفة بالكامل وفق rev.4d — R1 parse-abort(attempt1) · R2 تشغيل كامل انقطع داخل G-prune(attempt2_partial) · R3 أول دورة كاملة 14/15: **كل الfixtures فارغة** ⇒ DIAG أرشفت وأثبتت الجذر: عوالم fixture مسطّحة مقابل قارئ مقسّم بالأقسام ⇒ R4 بعد sectionalize: 14/15 وbait_hits=0 ⇒ اكتشاف break-مبكر يمنع عدّ الطُعم العميق ⇒ إزالته ⇒ R5 **PASS 15/15 EXIT=0** بكل نصوص assertion المجمدة، بما فيها فصل الممنوعات-وحدها بين متساويي التكلفة (F4) | deg/degree بنسخته الصارمة: كل المحاولات الخمس مؤرشفة بأسمائها رغم انحراف تسميتها عن runNN الموحد — مذكور هنا اعترافًا |

## 7) Open / مؤجل باقٍ

DEFERRED-7 Coordination (لمسٌ ممنوع هنا أيضًا) · partial-observability/doc13 · Hidden-Info (9d) — جميعها خارج نطاق هذه البوابة وأمام Gate خاصة عند الاقتراب منها.

---

---

## 8) ملحق الأدلة التشغيلية الخام (rev.4 — قبل الختم)

### 8.1 اللوج الكامل run03 (النهائي PASS) — منقول حرفيًا

```text
﻿Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org


============================================================
  TEST G - PLANNING GENERALIZATION / BEHAVIORAL VALIDATION
  Reference planner harness-local | doc22 rev.3 frozen
============================================================

-- G1..G8: per-fixture behavioral validity
[PASS] G1 F1 returns a valid minimal-cost plan for structurally-distinct problem
[PASS] G2 F2 returns a valid minimal-cost plan for structurally-distinct problem
[PASS] G3 F3 returns a valid minimal-cost plan for structurally-distinct problem
[PASS] G4 F4 returns a valid minimal-cost plan for structurally-distinct problem
[PASS] G5 F5 returns a valid minimal-cost plan for structurally-distinct problem
[PASS] G6 F6 returns a valid minimal-cost plan for structurally-distinct problem
[PASS] G7 F7 returns a valid minimal-cost plan for structurally-distinct problem
[PASS] G8 F8 returns a valid minimal-cost plan for structurally-distinct problem

-- G9: unsolvable honesty
[PASS] G9 honestly reports NO-PLAN on unsolvable problem
[PASS] G-det planner is bitwise-deterministic across runs
[PASS] G-pure planning never mutates the real world

-- G-audit: solution absence
[PASS] G-audit fixtures contain no solutions and planner contains no fixture-specific ids

-- G-greedy: lookahead differential on trap F3
[PASS] G-greedy depth-1 fails where depth-3 succeeds - lookahead value proven

-- G-cost: minimum declared cost among satisfiers (F6)
[PASS] G-cost chooses minimum total declared cost among satisfiers

-- G-prune: active constraint separates equal-cost satisfiers (F4)
[PASS] G-prune forbidden-constraint alone separates two equal-cost goal-satisfiers

============================================================
  TEST G RESULT: PASS (15 checks)
============================================================
[Dispatch] Registry loaded: 8 event handlers, 5 job handlers
Godot_v4.7.2-stable_win64_console.exe : WARNING: 886 ObjectDB instances were leaked at exit (run with `--verbose` for 
details).
At line:1 char:1
+ & "C:\Users\ahmed\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7. ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (WARNING: 886 Ob...` for details).:String) [], RemoteException
    + FullyQualifiedErrorId : NativeCommandError
 
   at: cleanup (core/object/object.cpp:2536)
```

### 8.2 سلسلة المحاولات المؤرشفة (قاعدة rev.4d منفذة)

| # | الملف | النتيجة |
|---|---|---|
| R1 | test_g_run01_attempt1_parsefail.log | parse-abort (صفر فحص) |
| R2 | test_g_run01_attempt2_partial.log | انقطاع داخل G-prune |
| R3 | test_g_run03_diag_rootcause.log *(النسخة المنقذة قبل استبدالها بـR5 — تشمل خطوط DIAG)* | 14/15 — كل fixtures فارغة (جذر: عوالم مسطّحة) + انقطاع G-prune |
| R4 | test_g_run02.log | 14/15 — bait=0 بعد sectionalize (break مبكر) |
| R5 | test_g_run03.log | **PASS 15/15 EXIT=0** |

### 8.3 SHA256 كاملة غير مقتطعة

| الملف | SHA256 |
|---|---|| scripts/test_g_generalization.gd | `c7ab7d7365563dae444c038a245056370613be1e89ab037183605a45b4ecbc9e` |
| evidence test_g_run01_attempt1_parsefail.log | `361213ae97efce504baed03d4e21f67c3e802afb449382c9097ac2b33573d2d3` |
| evidence test_g_run01_attempt2_partial.log | `0089de8f2f62b6bb969a1ddcae691a0e19f05e5984745d38bca6bd7b95699eba` |
| evidence test_g_run03_diag_rootcause.log (**R3 الحقيقي المأرشف**) | `5063f2582885e9338f7021b76b9b5403d74b21c4eaa8e1864c760a69b9577197` |
| evidence test_g_run02.log (R4: 14/15 post-sectionalize) | `75ca61d98adf376122fe9903eb479b663d83bbf7c861e429ab4b8afe2daad286` |
| evidence test_g_run03.log (R5: FINAL PASS 15/15) | `246798058fe929418819812874079f837b4158932996d2063371c40f0763ecc8` |
| data/rules/politics.json | `8ba94c6fc1aa5e3304265dab0895a55cdaa03052fa6a00e2241c62f5c058d878` |
| data/rules/dispatch.json | `0beeb605cb96cba6dfcfea12f2a17cbb190296f5004586e9bba373f95f57e440` |

### 8.4 محضر validator الخام

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

### 8.5 تصريح نطاق commits

- commit التسجيل المسبق: `7619cce` (doc22 فقط).
- commit التنفيذ والإغلاق: runner + خمسة لوجات مؤرشفة + تعديل هذه الوثيقة + دورة الذاكرة — هاشه في رسالة التسليم؛ لا أي commit آخر يمس هذه الأدلة.

---
---

**Evidence trail:** docs 19/20/21 + هذا الملف. صفر كود حتى الآن — Pre-reg ثم توقف.
