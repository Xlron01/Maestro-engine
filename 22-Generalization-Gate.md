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
| F4 | **ممتاز محليًا ممنوع تأخريًا** + قيد نشط | B{0.5}·P1·RAIL{precond dmg<=0.4,cost1}×حتى 0.8 · DECOY_COUP_B{cost0} · Goal `{P1.dmg==0.8}` · Forbidden `{B.stab<0.44}` | ثلاث RAILs: 0.5→0.48→0.46→0.44 (لا يخترق) ⇒ صالحة؛ أي سلسلة تحوي DECOY تنزل تحت 0.44 ⇒ ممنوعة | **قيد نشط**: عدّاد سلاسل-الممنوعة-المعدودة >0 والاختيار خارجهما |
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
| G-prune | قيد نشط (F4) | `count(satisfiers containing DECOY) == 0` و`count(enum chains containing DECOY) > 0` | `"G-prune active constraint eliminates locally-tempting chains"` |

**FAIL لأي:** خطة مخالفة · NO-PLAN كاذب · خطة على غير القابل · لاحتمية · تلويث · تسرب حل.

## 5-b) البروتوكول

Fixtures ثوابت §3 داخل العدّاء حرفًا · **runNN.log إلزامي لكل محاولة** · deg/degree · Evidence: `.ai/evidence/tests/test_g_generalization_runNN.log` · عند الإغلاق: transcript + SHA256 كاملة (runner/log/politics/dispatch/fixtures إن فصلت) + سطر commit-scope داخل هذه الوثيقة.

## 6) حالة الوثيقة

⏸️ **PRE-REGISTERED / PROVISIONAL — بانتظار مراجعة المالك قبل بناء Planner+Test G.**

### سجل المراجعة

| التاريخ | الإجراء | السبب/التوكيد |
|---|---|---|
| 2026-08-26 | فتح البوابة بأمر المالك (الالتزام من doc19 §6) وبقراراته: توسعات داخل البوابة (i) · أطيف تاسع NO-PLAN · فحص فرق الجشع | الطيف الثماني يتطلب تعدادًا وتكلفة مؤجلَيْن إلى Spec بحكم rule-11 — رُخصّا هنا بمبررات موثقة |
| 2026-08-26 | تجميد الثوابت التسعة بحساب يدوي مثبت (كل القيم ثنائية-الدقة) + قواعد الـaudit المضادة لتسرب الحلول | «الحل لا يسكن في الـfixture» أصبح فحصًا آليًا لا وعدًا نثريًا |

## 7) Open / مؤجل باقٍ

DEFERRED-7 Coordination (لمسٌ ممنوع هنا أيضًا) · partial-observability/doc13 · Hidden-Info (9d) — جميعها خارج نطاق هذه البوابة وأمام Gate خاصة عند الاقتراب منها.

---

**Evidence trail:** docs 19/20/21 + هذا الملف. صفر كود حتى الآن — Pre-reg ثم توقف.
