# 16 — D1: Decision Boundary Test

> **وثيقة تسجيل مسبق مجمد — قبل أي تشغيل.**
> تنفيذ مباشر لقرار صاحب المشروع بعد إغلاق Gate 15 المصحح (doc 15).
>
> **المبدأ الحاكم (توجيه المالك الحرفي):**
>
> **D1 لا يختبر صحة Evaluation Formula — يختبر أن Decision Layer يحترم حدود ومدخلات ومخرجات الـDecision Semantics.**
>
> الفصل المرحلي المجمد:
> - **D1** = هل Decision Architecture صحيحة؟ (هذه الوثيقة)
> - **D2** = هل Evaluation Semantics التي ستقود القرار صحيحة؟ (وثيقة مستقلة لاحقة)

---

## 0) حدود التنفيذ المجمدة

1. **صفر Kernel code** — طبقة القرار المرجعية `decide()` تعيش داخل العدّاء حصرًا (reference-only)، بنمط Test 2 B.
2. **Action Registry ليس نظامًا معماريًا هنا** — الخيارات الأربعة بيانات fixture في JSON فقط. السؤال الأنطولوجي «من أين تأتي الأفعال أصلًا؟» (Content / Capability / Simulation / توليد ذاتي) **Open Question مسجل أدناه ولا يُفتح داخل D1**.
3. أسماء القنوات الحرفية من doc 10/Gate 15: `exposure` / `access` / `rel_supply`. لا اختصارات جديدة.
4. goal_table بصيغة Gate 15 المصححة: `{"goal_name": {"channels": [...], "weight": w}}`.
5. deg/degree: أي bug ⇒ إعادة كل الفحوصات من الصفر.

---

## 1) خصائص PASS السبع (نص المالك المجمد)

| # | الخاصية | التعريف المجمد |
|---|---|---|
| P1 | Goal Dependence | نفس World/Relevance/Options + تغيير Goal ⇒ القرار يتغير عندما يكون تغيير الهدف كافيًا لتغيير الأفضلية |
| P2 | Relevance Dependence | نفس Goal/Options + تغيير Fact حقيقي يغير Relevance ⇒ القرار قد يتغير لأن تقييم الخيارات تغير |
| P3 | Capability Constraint | Action غير ممكن للكيان لا يجوز اختياره مهما كان الهدف مغريًا (Goal لا يولّد Capability من العدم) |
| P4 | Option Sensitivity | إضافة Action جديد أفضل من الموجود ⇒ القرار قادر على الانتقال إليه (Decision = Goal+Relevance+Options، وليس mapping ثابت Goal→Action) |
| P5 | Identity Blindness | تبديل أسماء الكيانات مع ثبات المدخلات الدلالية ⇒ القرار لا يتغير (لا `if country == X` من الباب الخلفي) |
| P6 | Read-only Inputs | WorldState_before == WorldState_after و Relevance_before == Relevance_after bitwise؛ الوحيد المتغير هو مخرج القرار (Relevance → Decision لا Relevance ↔ Decision) |
| P7 | Determinism | نفس المدخلات ⇒ نفس القرار |

## 1-b) شروط FAIL الستة (نص المالك المجمد)

1. Decision يعتمد على اسم كيان.
2. Decision يكتب في WorldState.
3. Decision يغير Relevance.
4. Goal يستطيع اختيار Action غير ممكن.
5. إزالة/إضافة Option لا تؤثر رغم أنها الوحيدة التي أصبحت أفضل.
6. نفس المدخلات تنتج قرارات مختلفة بدون مصدر randomness معلن.

> كل شرط FAIL هو نفي مباشر لخاصية P — يتحقق آليًا عبر فحوص §4.

---

## 2) الـFixtures المجمدة (قبل التشغيل)

### 2.1 العالم `data/worlds/model_v1/d1_base.json`
مشتق من test2_base مع التعديلات الجوهرية:
- `Decision_Actor`: depends_on EUV_flow=0.70، **transit_dependency على EUV_gate (EUV_flow: 0.5)** — تفعيل حد العبور §3.2 لقناة access، sectors defense، reserves 90، **projection_class="limited"** (شرط انكماش P3)، goal_table بالصيغة الجديدة (resource_security→rel_supply وزن 0.8 / prestige→[] وزن 0.2).
- `Second_Actor`: depends_on 0.20، civilian، reserves 30، goal_table معكوس الأوزان (0.2/0.8).
- البقية مطابقة بنيويًا لـtest2_base (Maker_Prime 0.70، Fab_Secondary 0.30، Gate_Holder، Washington authority 0.8، Anchor_Null).

### 2.2 الخيارات `data/worlds/model_v1/d1_options.json`
| option_id | channels | target_ref | requires | available_by_default |
|---|---|---|---|---|
| opt_secure | [rel_supply] | Maker_Prime | — | true |
| opt_disengage | [] | — | — | true |
| opt_gate_play | [access] | Washington | projection_class=full | true |
| opt_dominant | [rel_supply, access] | Maker_Prime | — | **false** (يُضاف فقط في variant P4) |

### 2.3 Variants
| state | التعديل عن base | الغرض |
|---|---|---|
| v_goal_swap | تبديل goal_table بين الفاعلين | P1 |
| v_fact_change | Maker_Prime.produces.EUV_flow: 0.70 → **0.02** | P2 (دلتا محسومة تعبر حد الأفضلية) |
| v_capped_actor | goal_table للفاعل = gate_leverage(access,1.0) والفاعل limited | P3a (منع الاختيار رغم أقصى إغراء) |
| v_capped_full | نفس أهداف P3a لكن projection_class=full | P3b (ضبط سالب: القيد هو الحاجب الوحيد) |
| v_option_add | تفعيل opt_dominant | P4 |
| v_renamed | خريطة إعادة تسمية كاملة (الكيانات + relations keys + authority.to + options.target_ref) | P5 |

### 2.4 عقد `decide()` المرجعي (مجمد)
```
decide(actor_facts, goal_table, options, rel_row) -> {"decision": id, "eligible": {...}, "scores": {...}}
```
- استبعاد غير المؤهل أولًا (requires ضد actor_facts) — قبل أي حساب نقاط.
- raw(option) = Σ قيم القنوات المعلنة من rel_row[option.target].
- boost_channeled = Σ أوزان الأهداف ذات قنوات غير فارغة المتقاطعة مع قنوات الخيار.
- boost_empty = Σ أوزان الأهداف بلا قنوات، يُحتسب فقط حين تكون قنوات الخيار فارغة.
- **final = raw × boost_channeled + boost_empty** — الخيار عديم القنوات يقف على تفضيله الثابت بدل أن يُصفَّر بضرب صدر.
- كسر التعادل: option_id تصاعديًا (حتمية).
- التجميع أعلاه **reference-only**: D1 لا تدّعي صحته (ذلك D2). الخاصيات P تثبت تحت أي تجميع رتيب يحافظ على المساهمتين.

---

## 3) التوقعات المسجلة قبل التشغيل (قابلة للكسر)

| فحص | التوقع المجمد |
|---|---|
| P1 | decision(A-goals) = opt_secure (0.5292×0.8=0.4234 > 0.2) ≠ decision(B-goals على نفس المصفوفات) = opt_disengage (0.1058 < 0.8) |
| P2a | rel_supply(A→Maker) في v_fact_change **أقل قطعيًا** من base (سبق T4a: التخفيف يخفض القناة قطعيًا) |
| P2b | decision ينقلب secure → disengage (0.0177 < 0.2) مع هامش > 0.01 في الحالتين |
| P3a | في v_capped_actor: eligible[opt_gate_play]=false والقرار ≠ opt_gate_play مهما بلغ وزنه 1.0 |
| P3b | في v_capped_full: eligible=true ويُختار opt_gate_play بفضل access(A→Washington)>0 عبر transit_dependency (القيد هو الحاجب الوحيد) |
| P4 | decision(v_option_add) = opt_dominant (final ≥ incumbent دائمًا، والتعادل يحسمه ترتيب المعرفات لمصلحته) |
| P5a | قرارات الفاعلين في v_renamed == قرارات base bitwise بعد تطبيع الأسماء |
| P5b | مصفوفات supply/access في v_renamed == base بعد عكس خريطة التسمية على المفاتيح |
| P6 | لقطات world + supply/access/chains قبل/بعد كل استداءات decide ⇒ bitwise متطابقة |
| P7 | تحميل مستقل ثانٍ لـbase ⇒ قرارات ومصفوفات bitwise متطابقة |
| J | L2-joint (لا مفاتيح تجميعية) + L3-joint (floats خالصة) على كل حالة |

## 4) النتائج

✅ **D1 RESULT: PASS (28 checks) — EXIT=0** — [raw log](file:///.ai/evidence/tests/d1_decision_boundary.log)

| فحص | النتيجة الفعلية |
|---|---|
| A-BOUNDARY | matrices bitwise == base بعد goal_swap ✓ |
| P1 | own-goals ⇒ opt_secure · swapped-goals ⇒ opt_disengage (نفس المصفوفات) |
| P2 | rel_supply(A→Maker): 0.5292000000 → 0.0221484375 قطعيًا · انقلاب secure→disengage · هوامش 0.223360 / 0.182281 |
| P3 | limited+هدف أقصى ⇒ gate_play ineligible وغير مختار · full بنفس الأهداف ⇒ **يُختار opt_gate_play** |
| P4 | بإضافة opt_dominant ⇒ القرار ينتقل إليه (final مساوٍ للحاضن والتعادل حسمه ترتيب المعرفات المجمد — موثق بلا تجميل) |
| P5 | Act_One/Act_Two يعيدان قراري base bitwise بعد عكس خريطة التسمية على المصفوفات أيضًا |
| P6 | world + relevance قبل/بعد decide ⇒ bitwise متطابقة (كائنًا وإعادة حساب) |
| P7 | تحميل مستقل ⇒ مصفوفات وقرارات bitwise متطابقة |
| J | L2/L3-joint خضراء على الحالات السبع (14 فحصًا) |

## 5) حالة البوابة

✅ **D1 CLOSED — Decision Architecture Boundary CONFIRMED (rev.2, PASS 28/28).**

الخصائص السبع مثبتة تنفيذيًا؛ شروط FAIL الستة مستحيلة بنيويًا تحت العقد المجمد. طبقة القرار استهلكت World/Relevance/Goals/Options وأنتجت Decision دون سرقة مسؤولية أي طبقة — **صفر Kernel code**.

### سجل المراجعة

| التاريخ | الإجراء | السبب |
|---|---|---|
| 2026-08-26 | rev.1 → تشغيل أول ⇒ FAIL 3/28 (P1, P2b, P3b) ⇒ **deg/degree: توقف كامل** | علتان جذريتان مكتشفتان تنفيذيًا |
| 2026-08-26 | rev.2: تعديل عقد §2.4 (`+ boost_empty`) + توصيل `transit_dependency` في الـfixture + تحديث توقعات §3 بأرقام صريحة | (أ) الصيغة القديمة `raw×boost` تُصفّر كل خيار عديم القنوات بنيويًا — وزن prestige لا يمكن أن يعبّر أبدًا؛ (ب) قناة access كانت معدومة لأن حد العبور يتطلب transit_dependency غائبًا عن الـfixture — P3b كان مستحيلًا بنيويًا لا رقميًا. العلة في المرجع/fixture لا في Model v1 ولا Kernel (لم يُمَس أي منهما) |
| 2026-08-26 | إعادة تشغيل كاملة من الصفر ⇒ **PASS 28/28، EXIT=0** — الإغلاق | تنفيذ deg/degree حرفيًا |

## 6) الخطوة التالية المفتوحة

**D2 — Evaluation Semantics** (وثيقة مستقلة): كيف تتفاعل Goal + Relevance + Preference + World/Outcome في التقييم فعليًا. D1 أثبت الحدود فقط ولا يغني عنها.

## 6) Open Questions (خارج نطاق D1 — مسجلة ولا تُفتح هنا)

1. **أنطولوجيا مصدر الأفعال**: Content definitions vs Capability-derived vs Simulation operations vs توليد من Decision Layer ذاتها — Gate مستقل عند الحاجة.
2. **D2 — Evaluation Semantics**: كيف تتفاعل Goal + Relevance + Preference + World/Outcome في التقييم فعليًا — الوثيقة التالية بعد ثبوت D1.

---

**Evidence trail:** docs 10/11/12/13/14/15 + هذا الملف.
