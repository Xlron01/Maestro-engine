# CHANGELOG

سجل زمني لجميع التعديلات الهامة التي طرأت على مشروع **Maestro Engine**.

---

## [2026-08-24]

### Added
- تنفيذ Phase 7 / Test 1 (Derived Importance) وفق تسليم `05-Test1-Derived-Importance-Handoff.md`:
  - العوالم الستة كملفات بيانات منفصلة `data/worlds/test1/world_1..6.json`.
  - وحدة اشتقاق محايدة واحدة `scripts/DerivedImportance.gd` بصيغة Supply Share مع توثيق كامل لسيمانتيك الـ traversal (max-path، تجاهل cycles مع تحذير، domestic_capacity مباشر فقط).
  - عدّاء headless `scripts/test_phase7_test1.gd` للـ Sub-tests 1.1–1.6 مع تدقيقين آليين (نظافة المدخلات + حياد مصدر المحرك).
- تأسيس بنية تحتية كاملة لذاكرة المشروع (Project Memory) كبروتوكول تشغيل للـ Agents الذكية (Agent Operating Protocol).
- إضافة مستند التوجيه الرئيسي `AGENTS.md` في جذر المشروع.
- إضافة دليل الدستور `.ai/constitution.md` وقواعد نزاهة الذاكرة.
- إضافة خريطة الربط الذكي للنطاقات `.ai/context-map.md`.
- إضافة ملفات التتبع والمهام لـ active/pending/completed وتحديد حالات المهام الرسمية.
- إضافة نموذج Handoff رسمي ثابت البنية.
- إضافة سكريبت تحقق آلي من سلامة ونزاهة الذاكرة `scripts/validate_memory.py`.
- توثيق حكم تصنيف فشل Test 1 (تصنيف ب — عيب الصيغة) كسؤال مفتوح قسم 7 في `04-اسئلة-تصميم-مفتوحة.md` (نطاق المقام في صيغ الـ normalization).
- تنفيذ Run 2 لـ Test 1 بتغيير assumption واحد (Local Normalization) وفق قرار صاحب المشروع: تعريف DepNeighborhood(O) مجمد في `scripts/DerivedImportance.gd` مع Prediction مسجل قبل التشغيل، دون أي تعديل على العدّاء أو العوالم.
- تنفيذ Run 3 لـ Test 1 (Zero-Dependency Isolation Control) وفق قرار صاحب المشروع: سكريبت تحكم جديد `scripts/test_phase7_test1_control.gd` بحسم مستوى Isolation منفصلًا عن مستوى Sensitivity، مع تصحيح سجلي موثق في قسم 7 من `04-اسئلة-تصميم-مفتوحة.md`.
- إقفال Test 1 بنتيجة **PASS 21/21** (Run 4): تعديل رسمي لتعريف Sub-test 1.4 في وثيقة التسليم + تصحيح فحص واحد في العدّاء وفق القرار الختامي لصاحب المشروع، وتوثيق الفشل الأصلي كـ false negative من تصميم الفحص.
- تنفيذ Test 10 — Scale وفق قرار صاحب المشروع: سكريبت قياس `scripts/test_phase7_test10_scale.gd` بمولد حتمي (N حتى 200، كثافة ثابتة) ومعايير ثلاثة مسجلة قبل التشغيل؛ النتيجة FAIL في موازنة الزمن = دليل Gate 2 رقمي.
- تنفيذ Test 10 v2 وفق قرار صاحب المشروع (أرخص إصلاح أولًا): `DerivedImportance.gd` v3 إضافي — Supply Index + Maxpath Memoization بعقود صلاحية موثقة، بوابة تكافؤ bitwise إلزامية، وعدّاء `scripts/test_phase7_test10_scale_v2.gd` بنفس المعايير.
- إكمال `00-خطة-الطريق.md` بقرار صاحب المشروع: توثيق Phase 7 كاملة + جدول حالة محدث (Phase 6/7/8) + تعريف Phase 8 الكامل (Test B: World-Sensitivity Validation) بمعايير PASS/FAIL مجمدة قبل التنفيذ، وتنظيف مخلفات heredoc التاريخية.
- تنفيذ Phase 8 وفق التعريف المجمد بعد تشديد B-T2 (Disjoint-Graph Invariance + حقل role داخل بيانات العوالم + إضافة كيانات B2 الناقصة): عوالم `data/worlds/testb/` وعدّاء `scripts/test_phase8_testb.gd` — النتيجة PASS 14/14 دون أي لمس لوحدة الاشتقاق.
- تنفيذ Phase 9 وفق التعريف المجمد (Structural Emergence): عالم `data/worlds/testc/w.json` وعدّاء `scripts/test_phase9_testc.gd` — إثبات عمى الوحدة عن الهوية (Name-Swap/Clone bitwise) مع توثيق تأجيل Derived Traits في خارج النطاق.
- تنفيذ Phase 10 (Purification / TASK-002) بقرار صاحب المشروع: Dispatch Registry من `data/rules/dispatch.json` + طبقة محتوى `scripts/game_event_handlers.gd` + تطهير Magic Numbers إلى politics.json + إعادة توليد `audit_report.md` — بتدقيق Baseline/Post ملزم ومطابقة Checksum صارمة، مع فك تحالف `Simulation.gd` نهائيًا.
- **Model Discovery (بلا كود — قرار صاحب المشروع):** وثيقة `07-Strategic-Relevance-Model-Discovery.md` — 6 حالات واقعية متنوعة + Evidence Matrix (✓/؟/✗) + تقليم بالاختبار الحذفي ⇒ نموذج أدنى من 3 مفاهيم (Exposure / EaseOfReplacement / HostileControl) بصيغة دمج متروكة عمدًا لوثيقة Strategic Relevance Model v1 بعد المراجعة الثلاثية، شكل حسابي محصور بالجوار بمرساة Test 10، 8 مجهولات موثقة، واقتراح Test E وحيد غير منفذ.
- **Control Semantics Stress Test (بلا كود — قرار صاحب المشروع، بديل Test E المجمّد):** وثيقة `08-Control-Semantics-Stress-Test.md` — 8 سيناريوهات بتوقعات مسجلة (ثابت/يتغير/ممنوع الاستنتاج) + حكم واقعي لكل سيناريو ⇒ الحكم: Control قابل للفصل كليًا عن Intent بشرط انقسام Possession/ExerciseCapability وتثبيت القوانين L1/L2/L3؛ رفض مفردة HostileControl بالدليل والتوصية المؤقتة بـ Strategic Control.
- **Control Chain Stress Test (بلا كود — قرار صاحب المشروع):** وثيقة `09-Control-Chain-Stress-Test.md` — حسم سؤال ASML بمعيار A/B عبر 7 سيناريوهات بأعمدة ثابت-يتغير-ممنوع. **النتيجة: الخيار A — Composition sufficient** بعلاقة موزونة واحدة `Authority(A,B,degree)` (بيانات ربط لا primitive) + قواعد تركيب C1–C4؛ النموذج تقلص: Chain Composition آلية اشتقاق رقم 4 في سلسلة Model v1.
- **Strategic Relevance Model v1 (وثيقة تصميم — بلا كود):** `10-Strategic-Relevance-Model-v1.md` — خط رباعي World Facts → Primitive Derived State → Chain Composition → Relevance بقناتين بنيويتين (Supply/Access) وصيغ مرجعية رتيبة؛ **محور إلزامي §6: الامتثال المشترك للقوانين L1/L2/L3 على التجميع الكامل** (خنادق منفصلة + مسيرة ASML موحدة عبر الطبقات الأربع + الإغراءات الثلاثة + تفاعلات زوجية تجعل الامتثال المتزامن هيكليًا لا صدفة).

### Changed
- نقل وتبسيط `state.md` ليقتصر فقط على الحالة الفورية للـ Engine بدون تاريخ متراكم.

### Tests
- **Model v1 Tranches A+B (بروتوكول §9 المتدرج المعتمد):** **Tranche A — PASS 13/13** بعد تصحيح assertions معتمد من المالك (A-3c′ اتجاهي بحجة موثقة: نسبة الحركة = سوقي موحد × استجابة slack خاصة بالمستهلك؛ A-3d حساسية المخزون خاصية مؤكدة .5952/.6053) و**Tranche B — PASS 11/11** عزلًا تامًا للجديد كليًا (دورة سلطة فعلية C4، ترتيب مسارات bitwise، كسر حافة، L1 عبر السلاسل). خطأ مفتاح داخلي (`deg`/`degree`) التقطته البوابة الصارمة وأصلح. Evidence: `model_v1_tranche_a_v2.log` | `model_v1_tranche_b_v2.log`.
- **TASK-013 (تصفير الجرد المؤجل):** أوزان fallback حُذفت من `DecisionSystem` (الوزنات صارت بيانات خالصة في politics.json/Schema) + `evaluate_coup_risk` نقية وتخزين `coup_risk_score` انتقل لطبقة المحتوى محافظًا على Selective Activation + `make_country` growth بارامتر + **إصلاح خطأ إملائي كامن** `border_insecureity` (خامل سلوكيًا). التدقيق: **CLEAN — Inventory 15→0، Gate=0**؛ ScenarioTest **5/5 + Checksum مطابق حرفيًا**. Evidence: `task013_audit_post.log` | `task013_scenariotest.log`.
- **Phase 10 — Purification (تنفيذ TASK-002 بقرار صاحب المشروع):** تدقيق Baseline وثّق **15 Gate violation** في `Simulation.gd` ثم Post-Audit **CLEAN (Gate=0)** بعد نقل منطق الدومين لطبقة المحتوى `scripts/game_event_handlers.gd` عبر `data/rules/dispatch.json` وتطهير الأرقام الحرفية الثلاثة إلى politics.json. **ScenarioTest 5/5 + Checksum مطابق حرفيًا** = صفرية تغير السلوك؛ اختبارات Phase 7/8/9 أعيدت كلها خضراء (21+14+14). `audit_report.md` أعيد توليده + TASK-013 للجرد المتبقي. Evidence: `phase10_audit_baseline.log` | `phase10_audit_post.log` | `phase10_scenariotest.log`.
- `test_phase9_testc.gd` **Phase 9 — Test C: Structural Emergence (خيار A بقرار صاحب المشروع):** **PASS 14/14 — Exit Code 0.** السلوك يتبع البنية لا الاسم: C-T3 Name-Swap (كل اسم حمل ملف الآخر bitwise)، C-T2 Clone Determinism، الرتيبية والعزل والتدقيقات خضراء؛ الوحدة v3 مجمّدة والشخصيات الفعلية (Derived Traits) مؤجلة موثقة. Evidence: `phase9_testc.log`.
- `test_phase8_testb.gd` **Phase 8 — Test B: World-Sensitivity Validation (بعد تشديد B-T2 بقرار صاحب المشروع):** **PASS 14/14 — Exit Code 0.** عوالم `data/worlds/testb/b1.json`/`b2.json` بحقل `role` إلزامي داخل البيانات؛ الاتجاهات مطابقة (بما فيها الانتشار عبر enables)، والمنفصلون هيكليًا bitwise ثابتون (فرق 0.0 بالضبط)، والعزل صفر-الاعتماد باسمًا، والانهيار يرجع المصفوفات الكاملة للأساس bitwise. Evidence: `phase8_testb.log`.
- `test_phase7_test10_scale_v2.gd` **Test 10 v2 (إصلاح الـ implementation debt — قرار صاحب المشروع):** E0 تكافؤ bitwise **PASS** (98/98) + Run 5 regression **21/21**؛ عند N=200: P1 PASS، P2 PASS (28.7x)، **P3 FAIL** — المسح الكامل 22.08s → **4.04s** (5.5x تحسن) والمسار المستهدف 994ms → **141ms** (7.1x). Exit Code: 1. Evidence: `phase7_test10_scale_v2.log` | `phase7_test1_run5_regression.log`.
- `test_phase7_test10_scale.gd` **Test 10 — Scale (قرار صاحب المشروع قبل أي توسع بناء):** **FAIL إجمالي 2/3 — Exit Code 1** (دليل Gate 2 موثق، لا تعديل وسط الاختبار). P1 Flatness PASS (0.25x ≤ 3x)، P2 Targeted Advantage PASS (22.2x ≥ 10x — مبدأ O(relevant links) سليم معماريًا)، **P3 Budget FAIL**: المسح الكامل عند N=200 ~22s مقابل موازنة 2s والمسار المستهدف ~994ms. Evidence: `phase7_test10_scale.log`.
- `test_phase7_test1.gd` **Run 4 (Corrected 1.4 — القرار الختامي لصاحب المشروع):** **PASS 21/21 — Exit Code 0.** إعادة تعريف Sub-test 1.4 رسميًا في وثيقة التسليم (الثبات bitwise لكيان zero-dependency فعلي فقط) وتصحيح فحص واحد في العدّاء ليطابقها؛ Test 1 انتقل من FAIL إلى PASS، والفشل الأصلي موثق false negative من تصميم الفحص لا من الصيغة ولا الـ kernel. Evidence: `phase7_test1_run4_corrected_14.log`.
- `test_phase7_test1_control.gd` **Run 3 (Zero-Dependency Isolation Control — قرار صاحب المشروع):** **PASS (4/4)** — `dependency=0 ⇒ importance=0.0` bitwise عبر ثلاث تجارب تغيّر إنتاج الموردين بنفس الدالة دون تعديل؛ آلية العزل تعمل. Exit Code: 0. Evidence: `phase7_test1_run3_zero_dep_control.log`.
- `test_phase7_test1.gd` **Run 2 (Local Normalization — قرار صاحب المشروع بتغيير assumption واحد):** FAIL مطابق لـ Run 1 رقمًا برقم (20 PASS / 1 FAIL) مؤكدًا التوقع المسجل مسبقًا (v2 ≡ v1). Exit Code: 1. Evidence: `phase7_test1_run2_local_scope.log`.
- `test_phase7_test1.gd` **Run 1:** FAIL (20 PASS / 1 FAIL — Sub-test 1.4). Exit Code: 1.
- **تصحيح السجل النهائي (صاحب المشروع):** سؤال الـ Sensitivity محسوم منطقيًا بـ Sub-test 1.3 نفسه (كيانات مرتبطة المفروض تتحرك نسبيًا مع السوق — لا تناقض نمذجي)؛ التناقض كان في نص تسليم 1.4 وحده، موثق قسم 7 في `04-اسئلة-تصميم-مفتوحة.md`.
- سكريبت `validate_memory.py`: PASS.
- سكريبت `ScenarioTest.gd`: PASS (5/5).

---

## [2026-08-23]

### Added
- تفعيل قدرة الاستخبارات (Phase 6):
  - **Step 1:** إثبات استضافة الكيانات غير الدولة (Agent + Agency) وحفظها على الديسك.
  - **Step 2:** تفعيل دالة `evaluate_operation` وتعديل الـ XP للعملاء.
  - **Step 3:** جدولة العمليات الممتدة One-Shot مع الحفاظ على نوم الكيانات.
  - **Step 4:** تفعيل حدث `Agent_Exposed` وتأثير الاستقرار الانتقائي وعقوبة الـ stability لـ egypt.
  - **Step 5:** إثبات نجاح الحفظ والاستعادة بمنتصف الطريق (Mid-flight Save/Load) مع الحفاظ التام على الـ Determinism.
- إضافة فحص `test_phase6_step4.gd` و `test_phase6_step5.gd` للتأكد من المكتملية.
- إضافة الحقل الاختياري `agent_exposure_stability_penalty` لـ `ContentSchema.gd` لمنع التجاهل التلقائي.

### Tests
- ScenarioTest: PASS (5/5).
- test_phase6_step4: PASS (6/6 Checks).
- test_phase6_step5: PASS (6/6 Checks).
