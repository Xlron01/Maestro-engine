# Completed Tasks

قائمة المهام المكتملة والمغلقة بنجاح في المشروع.

---

### [TASK-031] Planning Semantics Gate 1

- **Status:** COMPLETE (CLOSED Confirmed — 5/5 CEs، صفر primitive، صفر كسر)
- **Owner:** ox-alpha
- **Dependencies:** TASK-030 (Spec v0.1 CONFIRMED), TASK-029 (D2), TASK-023 (Gate 2)
- **Objective:** حسم السؤال الانتقالي بقرار المالك (Planning قبل D3): ما أقل تمثيل تنبؤي يتيح مقارنة الأفعال بنتائج مستقبلية دون primitive مسار؟
- **Acceptance Criteria:**
  - [x] العقد الثلاثي المجمد: Planner يتنبأ · Evaluation يقيّم · Decision يختار — «التفكير لا يلوث المحاكاة» (رفع P6 إلى عقد أمامي).
  - [x] سلم مرشحين مجمد حرفيًا: (أ) declared-deltas → (ب) clone-and-replay → (ج) forward-models.
  - [x] تصنيفات متوقعة مجمدة — **طابقت النتيجة 5/5 بلا كسر**.
  - [x] P1=(أ) محليًا · P2/P4 تُعدم (أ) بنيويًا (الاكتمال + الآثار الشبكية) · P3=تكرار(ب)+gating بلا Plan object (وراثة Gate 2) · P5=حتمية بلا حرق Open.
  - [x] النتيجة: **clone-and-replay للقواعد الموجودة على نسخة موسومة = الحد الأدنى الكافي** — صفر مفردات جديدة؛ (ج) رُفض بdeletion test (مصدر حقيقة ثانٍ).
  - [x] §6 يحمل التزام Generalization/Behavioral Validation المستقبلي بنصه المجمد + قاعدة fixture-بلا-حل + سلّم الطبقات الرباعي.
  - [x] صفر كود/Planner/integration — الإغلاق يتوقف توقفًا كاملًا؛ Spec v0.1 للتخطيط بأمر منفصل.
- **Validation Method:**
  مراجعة المالك للوثيقة التحليلية (بوابة بلا تشغيل)
- **Evidence:** [`19-Planning-Semantics-Gate.md`](file:///c:/tmp/maestro%20engine/19-Planning-Semantics-Gate.md)

---

### [TASK-030] Evaluation Specification v0.1 + Test E

- **Status:** COMPLETE (CONFIRMED — Test E PASS 16/16)
- **Owner:** ox-alpha
- **Dependencies:** TASK-029 (D2 Confirmed + §7 محسومة), TASK-028 (D1)
- **Objective:** أول وثيقة تنفيذية Gate-Style: مواصفة معيارية بمفردات مغلقة وأشكال F1–F4 بصيغ JSON حرفية، تُغلق بـTest E التنفيذي وتصير مرجع مراجعة دائمًا لـD3/D4.
- **Acceptance Criteria:**
  - [x] rev.1→rev.3 بمراجعات المالك: نص حرفي للschema وقواعد V0–V7 (إلزامية scale/direction، رفض F5 صراحة، قفل tie_extension، حسم terms الباريتو شروطًا عارية، V7 رفض غير المشبع) — وإزالة أي تلميح Planning (إعلان فجوة صرف).
  - [x] rev.4: صيغتا المساهمة الحرفيتان لـF2/F3 كمصدر معياري والأرقام تحقّق لهما.
  - [x] Fixtures مجمّدة ثنائية-الدقة (e_base/e_actions/e_goals) منها توأمان CE-5.
  - [x] Test E: L0–L7 loader حرفي · E1 diff==0.25 بالضبط · E2 −0.9375/0/0 · E3 −3.75/+0.0625/+0.125 وميل بلا مكافأة · E4 lex يرفض ما يقوله weighted · E5 بنص assertion §7 الحرفي · E6 توأمان bitwise · E7 عمى الهوية · E8 قراءة-فقط+حتمية.
  - [x] deg/degree داخل التنفيذ: تشغيل أول علته canonical-parse (قبل أي دورة) ثم علية fixture/spec (إشارة تدهور + غموض terms الباريتو) ⇒ rev.4b موثق ⇒ إعادة كاملة ⇒ **PASS 16/16 EXIT=0**.
  - [x] صفر Kernel code — المقيّم المرجعي harness-local حصرًا.
- **Validation Method:**
  Godot headless run + raw log + مراجعات المالك rev.1–rev.4
- **Evidence:**
  [`18-Evaluation-Specification-v01.md`](file:///c:/tmp/maestro%20engine/18-Evaluation-Specification-v01.md)
  [.ai/evidence/tests/test_e_evaluation_spec.log](file:///.ai/evidence/tests/test_e_evaluation_spec.log)

---

### [TASK-029] D2 — Evaluation Semantics Gate

- **Status:** COMPLETE (CLOSED Confirmed — 5/5 CEs، صفر primitive نوع-Goal، Open واحد)
- **Owner:** ox-alpha
- **Dependencies:** TASK-028 (D1 CLOSED), TASK-027 (Gate 15), TASK-023 (Gate 2)
- **Objective:** حسم السؤال الأنطولوجي الأعمق بصياغة المالك: هل توجد دلالة Evaluation عامة على Goal + Candidate Outcome + Preference تكفي كل أنواع الأهداف، أم تحتاج بعض الأهداف Primitive دلالية خاصة؟ — سابقًا لأي حديث عن شكل معادلة.
- **Acceptance Criteria:**
  - [x] قاعدة عدم امتياز D1 مجمدة نصًا (§0.2) — نجاح `goal × channel` بلا أي دلالة.
  - [x] الإطار العام المجمد + **مفردات واصف Outcome مغلقة** (Model v1 + schema + R1–R3) + منع هوية الفعل في الواصف (ضاد التهريب).
  - [x] عائلة أشكال Preference F1–F5 مجمدة، عضوية كل شكل بdeletion test.
  - [x] تصنيفات متوقعة مجمّدة قبل التحليل — **طابقت النتيجة 5/5 بلا كسر واحد**.
  - [x] CE-1: المقياس الفتري إعلان محتوى مرئي لا افتراض مدفون · CE-2: الكينك شكل عام والزمن carve-out · CE-3: الحصة primitive مجمدة سابقًا (supply_share) · CE-4: المعجمي يكسب عضويته + ⚪ OQ-D2-1 وحيد · CE-5: امتثال Gate 2 بنيوي + شرط قبول آلي مسجل.
  - [x] صفر كود — Specification v0.1 مؤجلة بأمر المالك صراحة.
- **Validation Method:**
  مراجعة المالك للوثيقة التحليلية (بوابة بلا تشغيل)
- **Evidence:** [`17-Evaluation-Semantics-Gate.md`](file:///c:/tmp/maestro%20engine/17-Evaluation-Semantics-Gate.md)

---

### [TASK-028] D1 — Decision Boundary Test

- **Status:** COMPLETE (PASS 28/28)
- **Owner:** ox-alpha
- **Dependencies:** TASK-027
- **Objective:** إثبات أن طبقة القرار تحترم حدود Decision Semantics عبر 7 خصائص مجمدة من المالك — بلا أي ادعاء بصحة معادلة تقييم (ذلك D2).
- **Acceptance Criteria:**
  - [x] تسجيل مسبق مجمد `16-Decision-Boundary-Test.md` قبل التشغيل.
  - [x] P1 Goal Dependence: أهداف مبادلة ⇒ opt_secure ↔ opt_disengage فوق نفس المصفوفات bitwise.
  - [x] P2 Relevance Dependence: fact حقيقي يُنزل rel_supply قطعيًا (0.5292→0.02215) ويعبر حد الأفضلية ⇒ انقلاب القرار (هوامش 0.223/0.182).
  - [x] P3 Capability Constraint: خيار gate_play محجوب عن limited رغم هدف وزنه 1.0؛ الضابط السالب full يختاره — القيد هو الحاجب الوحيد.
  - [x] P4 Option Sensitivity: opt_dominant المضاف يلتقط القرار (تعادل final حُسم بترتيب المعرفات المجمد — موثق بلا تجميل).
  - [x] P5 Identity Blindness: إعادة تسمية شاملة ⇒ قرارات ومصفوفات مطابقة bitwise بعد عكس الخريطة.
  - [x] P6 Read-only: world+relevance قبل/بعد decide ⇒ bitwise (كائنًا وإعادة حساب).
  - [x] P7 Determinism: تحميل مستقل ⇒ bitwise كامل.
  - [x] deg/degree منفذة حرفيًا: تشغيل rev.1 فشل 3/28 ⇒ توقف كامل ⇒ rev.2 (عقد `+boost_empty` + transit_dependency في الـfixture) ⇒ إعادة تشغيل كل الفحوصات من الصفر ⇒ PASS 28/28.
  - [x] صفر Kernel code — decide() داخل العدّاء reference-only؛ Model v1 وKernel لم يُمَسا.
- **Validation Method:**
  Godot headless run واحد + raw log
- **Evidence:**
  [`16-Decision-Boundary-Test.md`](file:///c:/tmp/maestro%20engine/16-Decision-Boundary-Test.md)
  [.ai/evidence/tests/d1_decision_boundary.log](file:///.ai/evidence/tests/d1_decision_boundary.log)

---

### [TASK-027] Decision Layer Design Gate

- **Status:** COMPLETE (CLOSED بعد تصحيحَي مراجعة المالك)
- **Owner:** ox-alpha
- **Dependencies:** TASK-024, TASK-023, TASK-020
- **Objective:** تصميم حدود Decision Layer: Action ontology، مصدر Candidate Actions، مصدر Preference، حدود Decision مقابل Simulation/Relevance/Content.
- **Acceptance Criteria:**
  - [x] §2 تسجيل مسبق مجود + §3 تحليل البنود الـ11 (11/11 Confirmed + 2 Open مؤجلة: Planning/tie-break).
  - [x] **تصحيح المالك 1**: §3.11 أعيد صياغته كمبدأ بلا معادلة — الصيغة `goal_weight × relevance_channel → argmax` كانت خالفًا للبند 7 (سبق TS-3: وجود metric ≠ معادلة جديدة).
  - [x] **تصحيح المالك 2**: ربط Goal↔Channel صريح في §3.3 بأسماء doc 10 الحرفية (`exposure`/`access`/`rel_supply`) — goal_table = `{channels:[...], weight}`، لا fallback ضمني إلى total.
  - [x] سجل مراجعة في §4 يوثق دورة PENDING→CLOSED كاملة.
- **Validation Method:**
  مراجعة المالك + validator
- **Evidence:** [`15-Decision-Layer-Design-Gate.md`](file:///c:/tmp/maestro%20engine/15-Decision-Layer-Design-Gate.md)

---

### [TASK-017] Strategic Relevance Model v1 — Design Document

- **Status:** REVIEW
- **Owner:** ox-alpha
- **Dependencies:** TASK-016
- **Objective:** كتابة وثيقة التصميم المرجعية التي تجمع مفردات السلسلة كلها في نموذج واحد بأربع طبقات (World Facts → Primitive Derived State → Chain Composition → Relevance)، مع محور فحص إلزامي: **الامتثال المشترك للقوانين L1/L2/L3 على التجميع الكامل** لا كل قانون منفردًا.
- **Acceptance Criteria:**
  - [x] جرد World Facts الكامل (بما فيه البنى الجديدة: TransitDependency / Possession / Authority).
  - [x] سجل قيم مشتقة كامل بفهرس/محفز/تحديث تدريجي لكل قيمة + مرساة أسوأ حالة من Test 10 v2.
  - [x] Relevance بقناتين بنيويتين (Supply / Access) بصيغ مرجعية رتيبة محدودة، وأوزانها محتوى politics.json.
  - [x] **§6 الامتثال المشترك**: خريطة خنادق القوانين + مسيرة ASML موحدة عبر الطبقات الأربعة تتحقق من L1/L2/L3 في كل تسليم + الإغراءات الثلاثة + تفاعلات الزوجي (الامتثال المتزامن نتيجة هيكلية).
  - [x] حدود الامتثال مصرّحة (تصميمي الآن؛ تنفيذي عند Test 1′ بassertions bitwise).
  - [x] المؤجل صراحة (Intent/Threat/Personality/Betweenness...) + بروتوكول التجمد + Test 1′ المقترح الوحيد.
- **Validation Method:**
  مراجعة صاحب المشروع والمراجع؛ ثم تجميد الصيغ وبناء Test 1′ عند الإشارة
- **Evidence:** [`10-Strategic-Relevance-Model-v1.md`](file:///c:/tmp/maestro%20engine/10-Strategic-Relevance-Model-v1.md)

---

### [TASK-016] Control Chain Stress Test — Composition vs New Primitive

- **Status:** COMPLETE
- **Owner:** ox-alpha
- **Dependencies:** TASK-015
- **Objective:** حسم سؤال Model v1 المعلق (ASML): هل السيطرة متعددة الطبقات مجرد Composition لعلاقات موجودة أم تحتاج primitive جديد؟ — وثيقة قصيرة بمعيار حسم ثنائي (A/B) و7 سيناريوهات بتسجيل مسبق.
- **Acceptance Criteria:**
  - [x] السيناريوهات السبعة المطلوبة كلها (مباشر/وسيط/مكسور/جزئي/متعدد/نية/ASML) بأعمدة ثابت-يتغير-ممنوع لكل واحد.
  - [x] الحكم: **الخيار A** — التركيب كافٍ؛ يُضاف عائلة علاقة موزونة واحدة `Authority(A,B,degree)` كبيانات ربط (ليست primitive حالة) + قواعد تركيب C1–C4 (Path Product / Per-Path / Max-Not-Sum / Cycle Skip).
  - [x] اختبار الحذف للحكم B فشل بالمعنى الصحيح: لا معلومة سببية جديدة ظهرت — النموذج **تقلص** لا تكبر (لا ChainControl مخزن).
  - [x] الحكم الواقعي لكل سيناريو (بريكست، حق النقض المزدوج، ASML 2023، حصص جزئية...).
  - [x] بوابة Model v1 مفتوحة رسميًا كسلسلة Facts→Primitives→Composition→Relevance.
- **Validation Method:**
  مراجعة صاحب المشروع والمراجع للوثيقة
- **Evidence:** [`09-Control-Chain-Stress-Test.md`](file:///c:/tmp/maestro%20engine/09-Control-Chain-Stress-Test.md)

---

### [TASK-015] Control Semantics Stress Test — Separability of Control from Intent

- **Status:** COMPLETE
- **Owner:** ox-alpha
- **Dependencies:** TASK-014
- **Objective:** بديل Test E المجمّد بقرار صاحب المشروع: اختبار ضغط مفاهيمي (صفر كود) يحسم هل يمكن تمثيل السيطرة الاستراتيجية كحالة مشتقة بنيوية مستقلة عن النية — عبر 8 سيناريوهات بتوقعات مسجلة مسبقًا + حكم واقعي لكل سيناريو.
- **Acceptance Criteria:**
  - [x] تعريف مرشح مجمد قبل التحليل + قانون Zero-Intent-Input الحاكم.
  - [x] جداول ما يثبت/يتغير/يُمنع استنتاجُه لكل سيناريو من الثمانية.
  - [x] حكم واقعي بدولة/حالة حقيقية لكل سيناريو (أستراليا-اليابان، روسيا-ألمانيا 2022، البحر الأحمر، سيبيريا قبل خط الأنابيب، النرويج، الأرض النادرة مقابل الليثيوم، حظر 1973).
  - [x] النتيجة: **قابل للفصل كليًا** — بشرطين مكتشفين: انقسام Possession/ExerciseCapability (S3+S4) وتثبيت قوانين L1/L2/L3.
  - [x] رفض مفردة HostileControl بالدليل (S1/S5) + توصية Strategic Control مؤجلة الاعتماد لـ Model v1.
- **Validation Method:**
  مراجعة صاحب المشروع والمراجع للوثيقة
- **Evidence:** [`08-Control-Semantics-Stress-Test.md`](file:///c:/tmp/maestro%20engine/08-Control-Semantics-Stress-Test.md)

---

### [TASK-014] Model Discovery — Strategic Relevance Research Document

- **Status:** COMPLETE
- **Owner:** ox-alpha
- **Dependencies:** TASK-012
- **Objective:** بلا أي كود — وثيقة بحثية واحدة `07-Strategic-Relevance-Model-Discovery.md`: 6 حالات واقعية متنوعة، Evidence Matrix بعلامات ✓/؟/✗، تقليم بالحذف، نموذج أدنى من 3 مفاهيم (Exposure / EaseOfReplacement / HostileControl)، Reality→Rule لكل قيمة، شكل حسابي محصور بالجوار، قائمة المجهولات، واقتراح Test E واحد فقط.
- **Acceptance Criteria:**
  - [x] الحالات الست تغطي الأنواع المطلوبة كلها (مورد صناعي/تكنولوجيا/mمر/سلسلة ببدائل/ظاهريًا-مهم-لكن-ليس/تغير زمني).
  - [x] جدول Evidence Matrix بعلامة ؟ صريحة (منع "منطقي إذن يدخل المحرك").
  - [x] التقليم بالاختبار الحذفي: دمج Substitutability+Adaptation+Buffers في EaseOfReplacement؛ سقوط Network-position للحسابي وسقوط Power-asymmetry كمؤجل.
  - [x] النموذج الأدنى = 3 مفاهيم فقط + صيغة الدمج متروكة عمدًا لوثيقة v1 بعد المراجعة الثلاثية.
  - [x] اقتراح Test E واحد غير منفذ + توقف تام عند التقرير.
- **Validation Method:**
  مراجعة صاحب المشروع والمراجع للوثيقة
- **Evidence:** [`07-Strategic-Relevance-Model-Discovery.md`](file:///c:/tmp/maestro%20engine/07-Strategic-Relevance-Model-Discovery.md)

---

### [TASK-013] Purify DecisionSystem.gd & WorldState.gd Residual Inventory

- **Status:** COMPLETE
- **Owner:** ox-alpha
- **Dependencies:** TASK-002
- **Objective:** تصفير الجرد المؤجل من تدقيق Phase 10 (15 ملاحظة) مع الحفاظ الحرفي على الـ Checksum.
- **Acceptance Criteria:**
  - [x] أوزان fallback حُذفت من خرائط `DecisionSystem` (خرائط ثنائية العمود؛ الأوزان صارت بيانات خالصة: politics.json + ContentSchema استقبلت sec/prosp_weight_* بقيمة 1.0 المطابقة للقديم).
  - [x] `evaluate_coup_risk` أصبحت نقية؛ تخزين `coup_risk_score` انتقل لطبقة المحتوى (`game_event_handlers.gd`) محافظًا على Selective Activation (المستقرة لا تحصل على المفتاح — TEST 5 يفحص ذلك وحافظ عليه).
  - [x] `apply_consequence` محايدة الدومين (ترجّع path فقط) وتحويل نوع الحدث انتقل للمحتوى بنفس payload القديم حرفيًا.
  - [x] `WorldState.make_country`: growth بارامتر مطلوب (factory قديم بلا مستدعين).
  - [x] **اكتشاف جانبي موثق:** خطأ إملائي كامن `border_insecureity` في sec_map منذ الإنشاء — عولج للإملاء الصحيح؛ خامل سلوكيًا اليوم (لا بيانات تملأ الحقل) لكنه كان سيصبح فخًا مستقبليًا.
  - [x] التدقيق بعد الإصلاح: **Gate=0 وInventory=0** (من 15) + ScenarioTest **5/5 + Checksum مطابق حرفيًا**.
- **Validation Method:**
  `test_phase10_purification_audit.gd` + `ScenarioTest.gd`
- **Evidence:** [task013_audit_post.log](file:///.ai/evidence/tests/task013_audit_post.log) | [task013_scenariotest.log](file:///.ai/evidence/tests/task013_scenariotest.log)

> **إقفال بالإيصالات (قرار المالك بعد تأكيد الأدلة):** `Inventory complete = Debt resolved` — الإصلاحات نُفذت فعلًا وثبتها: [task013_audit_post.log](file:///.ai/evidence/tests/task013_audit_post.log) (**Gate=0 / Inventory=0**) + [task013_scenariotest.log](file:///.ai/evidence/tests/task013_scenariotest.log) (**5/5 + Checksum مطابق حرفيًا**) ⇒ الدين مغلق نهائيًا لا معلق.

---

### [TASK-018] Model v1 Tranche A — Supply Channel (ExposureSupply + EaseOfReplacement)

- **Status:** COMPLETE (بعد تصحيح الـassertions المعتمد من المالك — **PASS 13/13**)
- **Owner:** ox-alpha
- **Dependencies:** TASK-017
- **Objective:** بناء وتشغيل الترانش الأول وفق §9.1: قناة الإمداد الموروثة (ExposureSupply + EaseOfReplacement بصيغ مجمّدة وعامل ReplacementFactor = 1 − EoR).
- **Acceptance Criteria:**
  - [x] الكود: `scripts/relevance_supply.gd` (primitives) + `data/rules/relevance_config.json` (أوزان/حرجة/leadtime كمحتوى) + عالم `data/worlds/model_v1/tranche_a.json` بحقول reserves/sectors + عدّاء `scripts/test_model_v1_tranche_a.gd`.
  - [x] تشغيل أول: 10 PASS / 2 FAIL (A-3c/A-4b) — شخّص بمجس مؤقت: قيدا ثبات أضيق من دلالة النموذج (مرآة درس Run 1)؛ رُفع للمالك وفق تعليمات التوقف الصريحة.
  - [x] المالك اعتمد التصحيح مع شرط توثيقي: توضيح سبب كفاية المعيار الاتجاهي في A-3c′ (نسبة الحركة = سوقي موحد × استجابة RF خاصة بالمستهلك عبر slack — ليست قاعدة عامة للتطابق bitwise بين المعتمدين) + تأكيد A-3d كخاصية مؤكدة لحساسية المخزون (نسب متفاوتة فعليًا: .5952 مقابل .6053).
  - [x] إعادة التشغيل بعد التصحيح (العدّاء فقط، النموذج لم يُلمس): **PASS 13/13**.
- **Validation Method:**
  `Godot_console --headless --script scripts/test_model_v1_tranche_a.gd`
- **Evidence:** [model_v1_tranche_a.log](file:///.ai/evidence/tests/model_v1_tranche_a.log) | [model_v1_tranche_a_diag.log](file:///.ai/evidence/tests/model_v1_tranche_a_diag.log) | [model_v1_tranche_a_v2.log](file:///.ai/evidence/tests/model_v1_tranche_a_v2.log)

> **الفشلان بالأرقام (سجل Run الأول):** A-3c طالب بثبات مراقبين مرتبطين فعليًا بسوق مشتركة عند دخول منتج (تحركوا جميعًا بمعامل موحد بين من يتشابه احتياطه)؛ A-4b طالب بأن احتياطي الحائز يؤثر نحو مورد واحد فقط (وهو يحمي من كل موردِي القدرة). كلاهما قيد أضيق من الدلالة المجمدة.

---

### [TASK-025] Ontology Sufficiency Gate — Coverage Gap Analysis

- **Status:** COMPLETE
- **Owner:** ox-alpha
- **Dependencies:** TASK-024, TASK-020 (Model v1 FROZEN)
- **Objective:** اختبار هل العائلات الثماني المؤكدة كافية للعبة Grand Strategy كاملة أم فقط لـRelevance Model v1 — عبر 5 counterexamples من أنظمة خارج Relevance.
- **Acceptance Criteria:**
  - [x] OS-1 جغرافيا/مسافة: ❌ Gap (لا موقع جغرافي في الـschema)
  - [x] OS-2 رؤية غير متماثلة: ❌ Gap (نسخة واحدة من الحقائق للجميع)
  - [x] OS-3 تحالف ثلاثي: ⚠️ Partial lossy (تفكيك زوجي يفقد الشرط الجماعي)
  - [x] OS-4 ملكية جزئية 40%: ✅ Expressible (degree field)
  - [x] OS-5 دورة موسمية: ⚪ Open carve-out (Temporal Semantics Gate مستقل)
- **Validation Method:**
  مراجعة صاحب المشروع والمراجع للوثيقة
- **Evidence:** [`13-Ontology-Sufficiency-Gate.md`](file:///c:/tmp/maestro%20engine/13-Ontology-Sufficiency-Gate.md)

---

### [TASK-023] Decision Semantics Gate 2 — Trajectory Necessity

- **Status:** COMPLETE
- **Owner:** ox-alpha
- **Dependencies:** TASK-022, TASK-017 (Model v1 FROZEN)
- **Objective:** وثيقة تحليلية بلا كود: حسم هل يحتاج المسار/Trajectory قيمة مستقلة في Derived State أم يختزل بالكامل إلى Outcome-State Preference مع القدرات التمثيلية R1–R3 — عبر 5 عدادات مسجلة مسبقًا بصيغ hypotheses قابلة للكسر.
- **Acceptance Criteria:**
  - [x] الحالات الخمس المجمدة بصيغة صاحب المشروع المعدلة: A Likely-reducible، B/C Test-reducibility دون افتراض آلية/حل، D Likely-via-facts مع فحص المقنّع، E adversarial بلا توقع حاسم.
  - [x] R1–R3 مصاغة كقدرات تمثيلية مسموحة لا نتائج مثبتة مسبقًا.
  - [x] التحليل تطبيقيًا لكل حالة + مرساة واقعية (فيينا 1683، الأطلسي 1941-43، الربيع 1918، خرق التزامات موثقة، المارن الثانية).
  - [x] أقسام مصنفة: Confirmed Principle / Rejected Interpretations / Open Questions.
  - [x] **النتيجة: Gate 2 CLOSED — Confirmed Principle** (الاختزال نجح في الخمسة دون primitive مسار) + تسجيل ملاحظة صاحب المشروع: Relevance نصف الطريق، طبقة القرار هي الاختبار الحقيقي للقوانين.
- **Validation Method:**
  مراجعة صاحب المشروع والمراجع للوثيقة
- **Evidence:** [`11-Decision-Semantics-Gate2.md`](file:///c:/tmp/maestro%20engine/11-Decision-Semantics-Gate2.md)

---

### [TASK-026] CE-4 Stress Test + Temporal Semantics Gate Registration

- **Status:** COMPLETE
- **Owner:** ox-alpha
- **Dependencies:** TASK-024
- **Objective:** فحص سريع لقواعد الشرطية الثلاثة (compound/meta/lifetime) لحسم CE-4، ثم تسجيل Temporal Semantics Gate (doc 14).
- **Acceptance Criteria:**
  - [x] **CE-4 CONFIRMED**: قواعد الشرطية تمثل كـconfig خالص — P1 Compound condition من JSON ✓، P2 meta-rule تعدل base rule ✓، P3 limited-lifetime window صحيح ⚠️ **Confirmed provisionally — pending Temporal Gate outcome** (النافذة الزمنية تفترض timestamps كscalar fields؛ لو Temporal Gate قرر Primitive مستقل، P3 يعاد اختباره).
  - [x] Temporal Semantics Gate مسجل: السؤال الأنطولوجي المجمد + 5 counterexamples (TS-1..5) في `14-Temporal-Semantics-Gate.md` بلا تحليل تطبيقي (بانتظار إشارة).
  - [x] Temporal Semantics Gate مسجل: السؤال الأنطولوجي المجمد + 5 counterexamples (TS-1..5) في `14-Temporal-Semantics-Gate.md` بلا تحليل تطبيقي (بانتظار إشارة).
- **Validation Method:**
  تشغيل probe مباشر + مراجعة الوثيقة
- **Evidence:** [model_v1_test2_boundary.log](file:///.ai/evidence/tests/model_v1_test2_boundary.log) (يشمل نتائج البروبات)

---

### [TASK-022] Test 2 — Relevance Boundary / Decision Non-Equivalence

- **Status:** COMPLETE
- **Owner:** ox-alpha
- **Dependencies:** TASK-021, TASK-013 closure receipts
- **Objective:** إثبات أن Relevance لا تتحول تلقائيًا إلى Decision: الحالات غير المادية (stance/relations/goal_tables) تترك المخرجات bitwise، بينما الأهداف وحدها تكفي لقلب القرار عند نفس الـRelevance (Non-Equivalence معماريًا ودلاليًا).
- **Acceptance Criteria:**
  - [x] عالم `data/worlds/model_v1/test2_base.json` يجمع القناتين + حقول غير بنيوية موجودة من البداية (stance/relations/goal_table على الكيانات) وتتبدل قيمها فقط عبر 7 حالات.
  - [x] **A-BOUNDARY**: الحالات الخمس غير المادية ⇒ supply+access+chains **bitwise == base** (صفر فروق، شامل طبقة السلاسل).
  - [x] **PC**: تغيير fact حقيقي يحرك القيم (إثبات حساسية الهارنس ضد النجاح الفارغ).
  - [x] **B-D1**: نفس Relevance + تبديل goal_tables ⇒ قراران مختلفان (binary argmax مرجعي داخل العدّاء حصرًا).
  - [x] **B-D2**: حساب القرارات يترك world object وrelevance bitwise كما هما (لا تلويث عكسي).
  - [x] **B-D3**: relevance=0 + أقصى هدف ⇒ secure score = 0.0 بالضبط (الأهداف لا تولّد قدرة من عدم).
  - [x] **J-L1/L2/L3** أعيدت على كل حالة من السبع.
- **Validation Method:**
  `Godot_console --headless --script scripts/test_model_v1_test2_boundary.gd`
- **Evidence:** [model_v1_test2_boundary.log](file:///.ai/evidence/tests/model_v1_test2_boundary.log) — Exit Code: 0

---

### [TASK-021] Test 1′ — Relevance Pipeline Test over FROZEN Model v1

- **Status:** COMPLETE
- **Owner:** ox-alpha
- **Dependencies:** TASK-020
- **Objective:** إعادة بناء روح Test 1 فوق Model v1 المجمد بالكامل: عالمان (ASML-pattern سلسلة سلطة + هرمز-style ممر عبور مع net-exporter) يختبران القناتين والقوانين الثلاثة تنفيذيًا، مع خاصيتين جديدتين: ظهور Relevance عبر قناة الوصول بلا إنتاج/اعتماد مباشر، وجمود البنية تحت انقلاب نية خارجي.
- **Acceptance Criteria:**
  - [x] عوالم `data/worlds/model_v1/test1p_w1.json` / `test1p_w2.json` + عدّاء `scripts/test_model_v1_test1prime.gd` بتوقعات مسجلة في الهيدر.
  - [x] **إكمال فجوة تنفيذ موثقة**: `ExposureTransit` (§3.2 المجمدة حرفيًا) لم تكن مبنية — بُنيت كما نصّت الوثيقة وأُضيف حد العبور إلى relevance_access (تنفيذ تصميم لا تعديله؛ موثق في هيدر الكود).
  - [x] **النتيجة النهائية: PASS 20/20** — أبرزها: T2 ظهور وصول عبر السلسلة فقط، T5a إغلاق البوابة ⇒ 0.0 بالضبط مع ثبات الإمداد bitwise، T6 كسر السلطة نفس النمط، T9 رافعة عبور للمستورد (1.125 عبر energy-crit)، T10 الـ net-exporter صفر كليًا (الحالة "يبدو مهمًا وليس كذلك" منفذة).
  - [x] شفافية انحرافات التشغيل موثقة: خطأ مفتاح طباعة، تعليقان سببهما نسيان `--script` في الأمر (بيئي)، وخطأ runtime أجهض `_init` تاركًا الشجرة حية — كلها شُخصت من اللوجات وحُلّت دون أي تعديل على الصيغ المجمدة.
- **Validation Method:**
  `Godot_console --headless --script scripts/test_model_v1_test1prime.gd`
- **Evidence:** [model_v1_test1prime_v2.log](file:///.ai/evidence/tests/model_v1_test1prime_v2.log) (+ لوجات المحاولات السابقة محفوظة بنفس المجلد) — Exit Code: 0

---

### [TASK-020] Model v1 Integration Gate & Freeze

- **Status:** COMPLETE
- **Owner:** ox-alpha
- **Dependencies:** TASK-019
- **Objective:** تنفيذ §9.3: بوابة الدمج — القناتان (Supply/Access) + السلاسل على عالم موحد، والقوانين الثلاثة L1/L2/L3 تُختبر **معًا** على خط الإنتاج الكامل، ثم ScenarioTest regression وإعلان التجميد.
- **Acceptance Criteria:**
  - [x] `scripts/test_model_v1_integration.gd` + `data/worlds/model_v1/integration.json` (ASML-pattern: Washington authority 0.8 → NL_Policy possesses EUV_gate + produces EUV_flow ← China defense/90d).
  - [x] **PASS 7/7**: I-1 Supply mirror exact | I-2 dp==0.8 بالضبط | I-3 Access channel mirror exact | **I-4 L1-joint** (انقلاب stance + إضافة hostile_relation ⇒ الطبقات الثلاث bitwise) | **I-5 L2-joint** (صفر مفاتيح تجميعية) | **I-6 L3-joint** (كل مخرج float خالص) | I-7 حتمية مزدوجة.
  - [x] قيم مرجعية: exposure=1.05، dp=0.8، access=0.84، rel_supply=0.945، total=1.785.
  - [x] ScenarioTest regression: **5/5 + Checksum ثابت** بعد كل شيء.
  - [x] الوثيقة 10 محدثة: MODEL v1 **FROZEN** بجدول البوابات كاملًا.
- **Validation Method:**
  `Godot_console --headless --script scripts/test_model_v1_integration.gd` + `ScenarioTest.gd`
- **Evidence:** [model_v1_integration.log](file:///.ai/evidence/tests/model_v1_integration.log) | [model_v1_freeze_scenariotest.log](file:///.ai/evidence/tests/model_v1_freeze_scenariotest.log)

---

### [TASK-019] Model v1 Tranche B — Strategic Control & Chain Composition

- **Status:** COMPLETE
- **Owner:** ox-alpha
- **Dependencies:** TASK-018
- **Objective:** تنفيذ §9.2: اختبار آلية Strategic Control وChain Composition الجديدتين كليًا في عزل تام بمعيار bitwise (C-T3/B-T2 grade) — بما فيها دورة سلطة فعلية لـ C4.
- **Acceptance Criteria:**
  - [x] `scripts/relevance_control.gd` (Possession/Authority/DFS بقواعد C1–C4) + عالم `data/worlds/model_v1/tranche_b.json` يشمل سلسلة ASML نمطية + **دورة سلطة فعلية** + مراقب disjoint.
  - [x] **النتيجة: PASS 11/11** — أبرزها: Washington يظهر متحكمًا سلسليًا لبوابة EUV_flow بدرجة 0.8 بالضبط (S4)، درجات الدورة 1.0/0.6/0.42 مع تسجيل الدورة تشخيصيًا (C4 على رسم دوري حقيقي)، ترتيب تقديم الأسهم/المفاتيح لا يؤثر bitwise (C1/C2)، كسر الحافة يسقط المتحكم المشتق ويبقي الحائز، وانقلاب stance لا يحرك شيئًا (L1 عبر السلاسل).
  - [x] Bystander لم يظهر متحكمًا في أي بوابة (L2/L3).
  - [x] خلال التنفيذ اكتُشف وأُصلح خطأ مفتاح داخلي (`deg` مقابل `degree`) كان يجعل كل درجات السلطة تُقرأ 0.0 — بوابة الصرامة التقطته قبل الاعتماد.
- **Validation Method:**
  `Godot_console --headless --script scripts/test_model_v1_tranche_b.gd`
- **Evidence:** [model_v1_tranche_b_v2.log](file:///.ai/evidence/tests/model_v1_tranche_b_v2.log) — Exit Code: 0

---

### [TASK-002] Decouple Domain Coupling in Simulation.gd (Phase 10 — Purification)

- **Status:** COMPLETE
- **Owner:** ox-alpha
- **Dependencies:** TASK-001
- **Objective:** تنفيذ Phase 10 (Purification): فك التحالف عبر Dispatch Registry من ملف خارجي، نقل منطق الدومين لطبقة محتوى مستقلة (`scripts/game_event_handlers.gd`)، تطهير الأرقام الحرفية — بمطابقة Checksum صارمة وتدقيق Baseline/Post ملزم بقرار صاحب المشروع.
- **Acceptance Criteria:**
  - [x] خلو `Simulation.gd` تماماً من أي أسماء أحداث/وظائف صلبة — **Gate = 0** في التدقيق الآلي بعد Baseline موثق (15 مخالفة: 12 تحكمية + 3 أرقام).
  - [x] Event-Handler Registry من `data/rules/dispatch.json` مع فحص اكتمال قاطع عند init (8 أحداث + 5 وظائف) وعلم `one_shot` من البيانات بدل مقارنة الاسم.
  - [x] ScenarioTest **5/5** و**Checksum مطابق حرفيًا** (`a7cff9f1...`) = إثبات صفرية تغير السلوك رياضيًا.
  - [x] نقل Magic numbers الثلاثة إلى politics.json بقيم مطابقة حرفيًا + إعلانها في ContentSchema.
  - [x] إعادة توليد `audit_report.md` المفقود + توثيق الجرد المؤجل كمهمة متابعة جديدة (TASK-013).
- **Validation Method:**
  تدقيق آلي مرتين (Baseline/Post) + `ScenarioTest.gd` + إعادة اختبارات Phase 7/8/9 (كلها خضراء)
- **Evidence:** [phase10_audit_baseline.log](file:///.ai/evidence/tests/phase10_audit_baseline.log) | [phase10_audit_post.log](file:///.ai/evidence/tests/phase10_audit_post.log) | [phase10_scenariotest.log](file:///.ai/evidence/tests/phase10_scenariotest.log)

---

### [TASK-005] Phase 7 / Test 1 Run 2 — Local Normalization (One-Assumption Change)

- **Status:** REVIEW
- **Owner:** ox-alpha
- **Dependencies:** TASK-004
- **Objective:** تنفيذ قرار صاحب المشروع بعد Run 1: تغيير assumption واحد فقط — نطاق مقام الـ normalization من Global إلى Local (`share` تُصفَّر لقدرة خارج DepNeighborhood(O)) — وإعادة نفس العوالم الستة بنفس العدّاء byte-by-byte ونفس التوقعات، للإجابة: هل يصلح النطاق المحلي الـ Isolation دون كسر البقية؟
- **Acceptance Criteria:**
  - [x] التعريف الجديد موثق ومجمد داخل `scripts/DerivedImportance.gd` قبل التشغيل، مع Prediction قابل للتفنيد مسجل مسبقًا: v2 ≡ v1 رقميًا (قدرة خارج الحي كان وزنها صفرًا أصلًا).
  - [x] العدّاء `test_phase7_test1.gd` وملفات العوالم لم تُلمس إطلاقًا.
  - [x] النتيجة موثقة بأمانة: **تطابق تام مع Run 1 رقمًا برقم** (20 PASS / 1 FAIL، نفس الفحص الفاشل) — التوقع المسجل تأكد.
  - [x] الأدلة الخام محفوظة في ملف لوج منفصل عن Run 1.
- **Validation Method:**
  `Godot_console --headless --script scripts/test_phase7_test1.gd` (بعد تعديل وحدة الاشتقاق فقط)
- **Evidence:** [.ai/evidence/tests/phase7_test1_run2_local_scope.log](file:///.ai/evidence/tests/phase7_test1_run2_local_scope.log) — Exit Code: 1

> **تصحيح الاستنتاج (بقرار صاحب المشروع):** Run 2 لم يثبت أن الصيغة صحيحة ولا خاطئة — أثبت فقط أن تغيير Global→Local **لم يكن مؤثرًا رياضيًا في هذه العوالم**. صياغة "المشكلة ليست في scope المقام وحدها — مطلوب تحقيق أعمق" كانت أوسع مما تسمح به الأدلة وصُححت.

---

### [TASK-012] Phase 9 — Test C: Structural Emergence

- **Status:** COMPLETE
- **Owner:** ox-alpha
- **Dependencies:** TASK-011
- **Objective:** تنفيذ Phase 9 وفق التعريف المجمد في خطة الطريق (خيار A — Structural Emergence): إثبات أن السلوك يتبع البنية لا الاسم — عمى كامل عن هوية الكيان وحساسية حصرية للموضع الهيكلي، بوصفه الشرط المسبق لأي شخصية لاحقة (الشخصيات الفعلية مؤجلة لمرحلة Derived Traits).
- **Acceptance Criteria:**
  - [x] جملة توضيح النطاق الملزمة موثقة في خطة الطريق قبل التنفيذ + تسجيل Derived Traits تحت "خارج النطاق".
  - [x] عالم `data/worlds/testc/w.json` بحقل `role` لكل كيان (9 كيانات، 5 مواضع هيكلية).
  - [x] عدّاء `scripts/test_phase9_testc.gd` بتوقعات مسجلة في الهيدر؛ الوحدة v3 لم تُلمس.
  - [x] **النتيجة: PASS 14/14** — أبرزها C-T3 Name-Swap: كل اسم حمل ملف الاسم الآخر bitwise بالضبط، وC-T2 Clone مطابق bitwise دون تشويش.
  - [x] Step 3: أدلة خام بمسار صريح، ولوج نظيف من أخطاء runtime (خطأ مقارنة self-key في أول تشغيل صُحح في العدّاء فقط وأُعيد التشغيل).
- **Validation Method:**
  `Godot_console --headless --script scripts/test_phase9_testc.gd`
- **Evidence:** [.ai/evidence/tests/phase9_testc.log](file:///.ai/evidence/tests/phase9_testc.log) — Exit Code: 0

---

### [TASK-011] Phase 8 — Test B: World-Sensitivity Validation

- **Status:** COMPLETE
- **Owner:** ox-alpha
- **Dependencies:** TASK-010
- **Objective:** تنفيذ Phase 8 وفق التعريف المجمد في خطة الطريق: إثبات أن القيم المشتقة تستجيب لتغيّر العالم اتجاهيًا للكيانات المرتبطة وتبقى bitwise ثابتة للكيانات غير المرتبطة هيكليًا — بعد تشديد تعريف B-T2 بقرار صاحب المشروع (Disjoint-Graph Invariance بدل أي غموض weakly-connected).
- **Acceptance Criteria:**
  - [x] Step 1: عوالم `data/worlds/testb/b1.json` و`b2.json` بحقل `role` إلزامي داخل كل كيان (توثيق الأدوار في البيانات نفسها) + تدقيقان آليان نظيفان.
  - [x] Step 2: عدّاء `scripts/test_phase8_testb.gd` بتوقعات مسجلة في الهيدر قبل أول تشغيل؛ الوحدة v3 لم تُلمس.
  - [x] **النتيجة: PASS 14/14** — B-T1 الاتجاهات مطابقة (بما فيها الانتشار عبر سلسلة enables)، B-T2 فرق 0.0 بالضبط لكامل صفوف الكيانين المنفصلين، B-T3 أصفار bitwise، B-T4 مصفوفات كاملة == الأساس bitwise، B-T5 ظهور الهدف الجديد، B-T6 نظافة.
  - [x] Step 3: الأدلة الخام محفوظة بمسار صريح + تحديث خطة الطريق (Phase 8 ✅) + الذاكرة.
- **Validation Method:**
  `Godot_console --headless --script scripts/test_phase8_testb.gd`
- **Evidence:** [.ai/evidence/tests/phase8_testb.log](file:///.ai/evidence/tests/phase8_testb.log) — Exit Code: 0

---

### [TASK-010] Roadmap Completion — Phase 7 Documentation & Phase 8 Definition

- **Status:** COMPLETE
- **Owner:** ox-alpha
- **Dependencies:** TASK-009
- **Objective:** تنفيذ قرار صاحب المشروع: إكمال `00-خطة-الطريق.md` كمصدر الحقيقة الوحيد قبل أي Task جديد — توثيق Phase 7 كاملة، وتعريف Phase 8 (Test B) بمعايير PASS/FAIL كاملة قبل أي حرف كود.
- **Acceptance Criteria:**
  - [x] إضافة قسم "✅ Phase 7" بنفس تنسيق الفيزات (ما اتعمل / اتثبت عمليًا / دروس منهجية / ملفات) من واقع TASK-004..009.
  - [x] تحديث جدول "الحالة الحالية": Phase 6 (stub بإحالة) + Phase 7 مقفولة + Phase 8 معرفة.
  - [x] تعريف Phase 8 الكامل: هدف محدد، عوالم B1/B2 بأسماء محايدة وقيم مجمدة، 3 خطوات مرقمة، Sub-tests B-T1..B-T6 بمعايير PASS/FAIL اتجاهية، قاعدة "مجمّد قبل التشغيل" وحدود صارمة.
  - [x] تنظيف مخلفات heredoc التاريخية أعلى وأسفل الملف.
  - [x] `validate_memory.py`: PASS.
- **Validation Method:** مراجعة بنية الملف + `python scripts/validate_memory.py`
- **Evidence:** [`00-خطة-الطريق.md`](file:///c:/tmp/maestro%20engine/00-خطة-الطريق.md)

---

### [TASK-009] Phase 7 / Test 10 v2 — Implementation Debt Fix (Indexed + Memoized v3)

- **Status:** REVIEW
- **Owner:** ox-alpha
- **Dependencies:** TASK-008
- **Objective:** تنفيذ قرار صاحب المشروع: أرخص إصلاح أولًا قبل أي قرار Gate 2 — إصلاح الـ bottleneck التنفيذيين الموثقين داخل GDScript (فهرسة العرض بدل مسح كل الكيانات + memoization لـ maxpath كدالة نقية في الزوج) وإعادة تشغيل Test 10 بنفس المعايير حرفيًا.
- **Acceptance Criteria:**
  - [x] `DerivedImportance.gd` v3 إضافي فقط: `build_world_index` / `refresh_supply_index` / `evaluate_indexed` مع عقود صلاحية موثقة — `evaluate()` المرجعية لم تُلمس إطلاقًا.
  - [x] **بوابة تكافؤ E0**: 98/98 زوج bitwise متطابقة بين المسارين على العوالم الستة — المسار السريع مطابق رياضيًا للمرجع قبل احتساب أي توقيت.
  - [x] Run 5 Regression: `test_phase7_test1.gd` بقي **21/21 PASS** بعد التعديل.
  - [x] النتائج موثقة بأمانة: P1 PASS (0.64x)، P2 PASS (28.7x)، **P3 لا يزال FAIL**: المسح الكامل عند N=200 انخفض من 22.08s إلى **4.04s** (تحسن 5.5x) لكنه أعلى من موازنة 2s؛ المسار المستهدف انخفض من 994ms إلى **141ms** (تحسن 7.1x).
- **Validation Method:**
  `Godot_console --headless --script scripts/test_phase7_test10_scale_v2.gd` + `test_phase7_test1.gd`
- **Evidence:** [.ai/evidence/tests/phase7_test10_scale_v2.log](file:///.ai/evidence/tests/phase7_test10_scale_v2.log) | [.ai/evidence/tests/phase7_test1_run5_regression.log](file:///.ai/evidence/tests/phase7_test1_run5_regression.log)

> **مقارنة v1 ↔ v2 عند N=200:** لكل-استعلام 554.7µs → 101.5µs (5.5x) | مسح كامل 22.08s → 4.04s (5.5x) | مستهدف 994ms → 141ms (7.1x) | ميزة الاستهداف 22.2x → 28.7x.
> **بنود متبقية خارج النطاق المعتمد (موثقة لا منفذة):** إعادة بناء عكس الـ enables داخل `dependency_neighborhood` في كل استدعاء (قابل للرفع للفهرس)، تخصيص result-dict لكل استدعاء، وكلفة GDScript التفسيرية ذاتها.

---

### [TASK-008] Phase 7 / Test 10 — Scale (Derived Importance Performance)

- **Status:** REVIEW
- **Owner:** ox-alpha
- **Dependencies:** TASK-007
- **Objective:** تنفيذ قرار صاحب المشروع: قياس الأداء عند حجم واقعي قبل أي توسع بناء — هل تكلفة الحساب O(الروابط ذات الصلة) أم O(كل الكيانات)؟ (مختلف عن TASK-003 المعلقة التي تستهدف ضغط Simulation kernel؛ هذا الاختبار يستهدف وحدة الاشتقاق تحديدًا).
- **Acceptance Criteria:**
  - [x] المعاملات والمعايير الثلاثة مسجلة في هيدر السكريبت قبل التشغيل: Flatness (≤3x بين N=200 وN=50 بكثافة ثابتة)، Targeted Advantage (≥10x عند N=200)، Budget (<2s للمسح الكامل عند N=200).
  - [x] مولد حتمي 100% (strides حسابية، صفر RNG)، نفس schema عوالم Test 1 يغذي نفس `DIModule.evaluate` المجمدة دون تعديل.
  - [x] النتيجة موثقة بأمانة: **FAIL إجمالي (2/3)** — P1 PASS (0.25x)، P2 PASS (22.2x)، **P3 FAIL**: المسح الكامل عند N=200 استغرق **~22 ثانية** مقابل موازنة 2 ثانية.
  - [x] لا تعديل على الموديول وسط الاختبار — الفشل وثّق كدليل Gate 2 كما هو.
- **Validation Method:**
  `Godot_console --headless --script scripts/test_phase7_test10_scale.gd`
- **Evidence:** [.ai/evidence/tests/phase7_test10_scale.log](file:///.ai/evidence/tests/phase7_test10_scale.log) — Exit Code: 1

> **قراءة الأرقام الخام (موثقة كما هي):**
> | N | أزواج | مسح كامل | لكل استعلام | مستهدف |
> |---|---|---|---|---|
> | 50 | 2,450 | 5.45s | 2226µs | 626ms |
> | 100 | 9,900 | 12.06s | 1219µs | 1.59s |
> | 150 | 22,350 | 22.60s | 1011µs | 1.07s |
> | 200 | 39,800 | 22.08s | 555µs | 994ms |
>
> - **P2 مطابق نظريًا**: تسارع 22.2x مقابل ~20x محسوبة من عدد الأزواج المتأثرة (1,194 من 39,800) — مبدأ O(relevant links) سليم معماريًا.
> - **P3 هو Bottleneck حقيقي**: حتى المسار المستهدف عند N=200 يكلف ~1 ثانية — أعلى من ميزانية tick مريحة. مصدر الكلفة البنيوي (من واقع الكود المجمد): مسح كل الكيانات داخل `supply_share` لكل حد (O(N) حيث 6 منتجين فقط ذوو صلة)، إعادة DFS لكل زوج (قدرة-اعتماد) رغم أن النتيجة دالة في الزوج وحده، وتخصيصات dictionaries لكل استدعاء — فوق كلفة GDScript التفسيري.
> - **ملاحظة صلاحية قياس P1 (موثقة لا مفسرة)**: اتجاه تنازلي غير مادي (لكل-استعلام يقل 4x مع كبر العالم رغم أن العمل الفعلي للاستعلام لا ينقص) يشبه تأثير CPU frequency scaling أثناء التشغيل؛ المعيار مرّ كما سُجل لكن الرقم لا يُعتبر إثباتًا قويًا بذاته — غياب توقيع التصاعد O(N) هو الملحوظ.

---

### [TASK-007] Phase 7 / Test 1 Run 4 — Corrected 1.4 & Overall Reclassification

- **Status:** COMPLETE
- **Owner:** ox-alpha
- **Dependencies:** TASK-006
- **Objective:** تنفيذ قرار صاحب المشروع الختامي: إعادة تعريف Sub-test 1.4 رسميًا (المعيار الوحيد للثبات bitwise هو zero-dependency الفعلي — weakly-connected ليس isolated)، وتصحيح العدّاء ليطابق التعريف المصحح، وإعادة احتساب Test 1 الكلية.
- **Acceptance Criteria:**
  - [x] تعديل رسمي موثق داخل وثيقة التسليم `05-Test1-Derived-Importance-Handoff.md` تحت بند 1.4 (النص الأصلي محفوظ + كتلة تعديل مؤرخة بالأساس).
  - [x] فحص واحد فقط استُبدل في العدّاء (مصر weakly-connected → مراقب zero-dep ثابت = 0.0 bitwise عبر كل التجارب المعزولة) — لا شيء آخر تغيّر.
  - [x] إعادة التشغيل: **PASS 21/21 — Exit Code 0.** Test 1 انتقل من FAIL إلى PASS.
  - [x] توثيق السبب: الفشل الأصلي false negative من تصميم فحص غير دقيق، لا من الصيغة ولا الـ kernel؛ وسؤال الـ Sensitivity محسوم منطقيًا بـ 1.3 نفسه (لا تناقض نمذجي).
- **Validation Method:**
  `Godot_console --headless --script scripts/test_phase7_test1.gd` (Run 4)
- **Evidence:** [.ai/evidence/tests/phase7_test1_run4_corrected_14.log](file:///.ai/evidence/tests/phase7_test1_run4_corrected_14.log)

> **نطاق النتيجة:** "هذه الصيغة قادرة على اشتقاق قيمة أهمية من بيانات العالم مع الحفاظ على الخصائص المختبرة في هذه العوالم الستة فقط — لا أكثر."

---

### [TASK-006] Phase 7 / Test 1 Run 3 — Zero-Dependency Isolation Control

- **Status:** REVIEW
- **Owner:** ox-alpha
- **Dependencies:** TASK-005
- **Objective:** تنفيذ قرار صاحب المشروع بحسم المستوى الأول فقط (Isolation): كيان بلا أي اعتماد مسجل يجب أن تبقى أهميته `0.0` بالضبط مهما تغير إنتاج الموردين — بنفس الدالة دون أي تعديل. المستوى الثاني (Sensitivity: هل اعتماد 0.02 ينبغي أن يجعل الكيان حساسًا للسوق؟) يبقى سؤال نمذجة مفتوحًا ولا يُحسم هنا.
- **Acceptance Criteria:**
  - [x] التوقع مسجل مسبقًا في هيدر السكريبت: القيم الثلاث == 0.0 bitwise وإلا FAIL.
  - [x] نفس الدالة v2 دون أي تعديل، نفس world_1، تجاوزات أحادية المتغير فقط في الذاكرة.
  - [x] النتيجة: **PASS (4/4)** — `Turkey(dep=0.0)→Taiwan = 0.000000000000000` في التجارب الثلاث (Taiwan.produces = 0.80/0.90/0.70).
  - [x] قيم مصر (اعتمادها 0.02) طُبعت كسياق خام فقط بلا أي assertion.
- **Validation Method:**
  `Godot_console --headless --script scripts/test_phase7_test1_control.gd`
- **Evidence:** [.ai/evidence/tests/phase7_test1_run3_zero_dep_control.log](file:///.ai/evidence/tests/phase7_test1_run3_zero_dep_control.log) — Exit Code: 0

> **الدلالة المسجلة:** آلية العزل تعمل (`dependency=0 ⇒ importance=0` بالضبط). فشل الفحص الأصلي في Run 1 سببه استخدام weakly connected entity (مصر، اعتماد 0.02) كمثال على isolated entity — خطأ تصميم فحص لا بالضرورة عيب صيغة.

---

### [TASK-004] Phase 7 / Test 1 — Derived Importance

- **Status:** REVIEW
- **Owner:** ox-alpha
- **Dependencies:** None (uses Phase 6 kernel as-is, untouched)
- **Objective:** تنفيذ `05-Test1-Derived-Importance-Handoff.md`: إثبات أو نفي إمكانية اشتقاق "أهمية" من حالة العالم وشبكة الاعتماديات وحدها، عبر 6 عوالم JSON منفصلة تُغذَّى لدالة اشتقاق واحدة بلا أي تفرّع باسم كيان، مع Sub-tests 1.1–1.6.
- **Acceptance Criteria:**
  - [x] العوالم الستة مخزنة كملفات بيانات منفصلة (`data/worlds/test1/world_1..6.json`).
  - [x] دالة اشتقاق واحدة محايدة (`scripts/DerivedImportance.gd`) بصيغة Supply Share مجمّدة قبل التشغيل — دليل الحياد: تدقيق آلي لمصدر الكود ضد كل أسماء الكيانات/القدرات.
  - [x] تشغيل Sub-tests 1.1–1.6 وتوثيق القيم الفعلية الخام + PASS/FAIL لكل فحص.
  - [x] النتيجة موثقة بأمانة: **Overall FAIL** (20 PASS / 1 FAIL) دون أي تعديل post-hoc على الصيغة.
  - [x] حفظ الـ raw output في الأدلة والإشارة إليه بمسار صريح.
- **Validation Method:**
  `Godot_console --headless --script scripts/test_phase7_test1.gd`
- **Evidence:** [.ai/evidence/tests/phase7_test1_derived_importance.log](file:///.ai/evidence/tests/phase7_test1_derived_importance.log) — Exit Code: 1 (FAIL)

> **قرار المراجعة (صدر):** صاحب المشروع صنّف فشل 1.4 تصنيفًا نهائيًا **(ب)** — عيب تصميمي في الصيغة المجمدة ذاتها (مقام normalization عالمي يحقن معلومة العالم كله في حساب كل كيان، مخالفًا لمبدأ O(الروابط ذات الصلة))، لا خطأ تعميم في عدّاء الاختبار. سُجل كسؤال مفتوح في [`04-اسئلة-تصميم-مفتوحة.md` — قسم 7](file:///c:/tmp/maestro%20engine/04-اسئلة-تصميم-مفتوحة.md).

---

### [TASK-001] Establish Project Memory & Agent Operating Protocol

- **Status:** COMPLETE
- **Owner:** Antigravity
- **Dependencies:** None
- **Objective:** إنشاء البنية المعرفية لوكلاء الذكاء الاصطناعي لتسهيل تداول الذاكرة وحفظ سياق تقدم المشروع دون فجوات.
- **Acceptance Criteria:**
  - [x] إنشاء ملف التوجيه `AGENTS.md` وقواعد الدستور `.ai/constitution.md`.
  - [x] إنشاء مستندات المعمارية والسياق وخارطة الربط وسجل القرارات.
  - [x] كتابة سكريبت التحقق `scripts/validate_memory.py` لتدقيق سلامة الذاكرة.
  - [x] نجاح تشغيل الـ Validator بنتيجة خضراء تماماً.
  - [x] الحفاظ على سلامة محاكاة السيناريوهات الحالية بمرور جناح `ScenarioTest.gd` بنجاح 5/5.
- **Validation Method:**
  `python scripts/validate_memory.py` و `ScenarioTest.gd`
- **Evidence:** [.ai/evidence/tests/task_001_validation.log](file:///.ai/evidence/tests/task_001_validation.log)

---

### [TASK-000] Phase 6 — Intelligence Gameplay Stress Test

- **Status:** COMPLETE
- **Owner:** Antigravity
- **Dependencies:** None
- **Objective:** إثبات قدرة محرك المحاكاة المطور على تشغيل واستيعاب آليات الاستخبارات والعملاء الممتدة زمنياً بنجاح ودون إعادة هيكلة جوهرية.
- **Acceptance Criteria:**
  - [x] تمثيل الكيانات غير الدولة وحفظها على الديسك (Step 1).
  - [x] تغيير خصائص الـ XP على مسارات الفشل والنجاح (Step 2).
  - [x] جدولة عمليات ممتدة زمنياً One-Shot وحفظ نوم الكيانات (Step 3).
  - [x] تفعيل حدث `Agent_Exposed` وتأثير الاستقرار الانتقائي والممتد طوال 10 أيام (Step 4).
  - [x] الحفظ والاستعادة بمنتصف الطريق (Mid-flight Save/Load) مع الحفاظ على الـ Determinism (Step 5).
- **Validation Method:**
  `ScenarioTest.gd` و `test_phase6_step4.gd` و `test_phase6_step5.gd`
- **Evidence:**
  [.ai/evidence/tests/test_phase6_step4.log](file:///.ai/evidence/tests/test_phase6_step4.log)
  [.ai/evidence/tests/test_phase6_step5.log](file:///.ai/evidence/tests/test_phase6_step5.log)

