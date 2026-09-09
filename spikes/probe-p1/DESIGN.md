# PROBE-P1 — PRE-REGISTERED EXECUTION DESIGN (v1.1 — RATIFIED+FROZEN)

> **Status: RATIFIED (المالك أحمد + مراجع Architecture/Engineering، 2026-09-09) — مجمّدة قبل أول تشغيل.**
> المواصفة الأصلية (`SPEC.md` في هذا المجلد — نص المالك حرفيًا) هي مصدر الحقيقة؛ هذا المستند يجمّد
> القراءات التشغيلية والأرقام الدقيقة والتنبؤات قبل أي benchmark run. أي تعارض ⇒ المواصفة تحسم.
> **سجل التعديلات عن v1 المعروض للتصديق: §11 (كلها pre-run، قبل commit التصميم وقبل أي تشغيل).**

---

## 0) Compliance Mapping — Hard Scope Boundary (§2)

| القيد | التنفيذ |
|---|---|
| لا تعديل production | كل الكود تحت `spikes/probe-p1/` فقط، لا imports من `scripts/` أو `economy/` |
| لا subsystem في Simulation.gd | الـprobe عملية Python مستقلة تمامًا |
| لا تغيير EventQueue/ScheduledQueue/ActivationSet | غير مستوردة أصلًا |
| لا parallel/multithreading داخل الـprobe | single-threaded، تنفيذ sequential للسيناريوهات |
| لا Actor/Political/Economy Runtime | نموذج مجرد: node/state/dependency/derived فقط |
| لا قرار معماري من النتيجة | §20/§21 من المواصفة منقولان حرفيًا لقسم Verdict في التقرير |

## 1) Operational Semantics (مصادقة — مجمّدة)

- **Node i:** `state s_i ∈ [0,1]`، `derived d_i ∈ [0,1]`، قائمة deps `[(j, w_ij), …]` بترتيب توليد ثابت.
- **Derived formula (حتمية، خالصة):**
  - بلا deps: `d_i = clamp01(s_i)`
  - بها deps: `d_i = clamp01(0.5·s_i + 0.5·(Σ_j w_ij·d_j)/k_i)` — w seeded ∈ [0.1, 0.9]
- **Change:** `s_i ← clamp01(s_i ± 0.30)` تبادل +/− يبدأ بـ+ (لا RNG للقيمة).
- **Propagation semantics (بنيوية):** dirty = العقدة المتغيرة ∪ كل المنحدرين عبر حواف A→B
  (transitive closure) — بغض النظر عما إذا تغيرت قيمة d فعليًا ("قد تكون نتيجته تغيرت" §4).
  إعادة الحساب بترتيب id تصاعدي (DAG بالبناء: كل الحواف من id أدنى لأعلى).
- **Cadence (مصادقة ضمن التصميم):** كل change يُطبق ثم يُنفذ propagation وتُقاس latency ثم التالي
  (§12 يتطلب mean/p95/peak propagation latency ⇒ عينات متعددة). **قراءة تفسيرية ثانية للـbatch
  (كل التغييرات دفعة واحدة ثم propagation واحدة) تُغطى بسلسلة SUPP-B المعزولة (§4/§11-A5).**
- **Effects:** لكل change: `direct` = العقدة المتغيرة نفسها إن اشتقاقها تغير؛ `propagated` = باقي
  العقد المُعاد حسابها ذات القيم المتغيرة. المقارنة bitwise على floats، خارج المناطق المُوقتة.

## 2) Candidates — الخوارزميات الدقيقة (مصادقة Q1)

**C0 — Full Recompute:** بعد كل change: مسحة id كاملة تُعيد حساب كل N عقدة (deps أدنى id ⇒ مسحة
واحدة كافية). التخزين: CSR أمامي فقط.

**C1 — Affected-Set (بلا reverse index جاهز):** مسحة واحدة على **edge array مسطح** مرتب
(source-then-destination = ترتيب topological): لكل حافة (src→dst): لو src ∈ dirty ⇒ dst ∈ dirty.
تعليم dirty عبر generation-stamping (بلا مسح O(N) بين التغييرات — تقنية تنفيذ متاحة لأي
implementation، ليست shortcut مفاهيمي). ثم فرز dirty تصاعديًا وإعادة حسابه فقط.
التكلفة: O(E) مسحة اكتشاف + O(closure) حساب. الـedge array = إعادة ترتيب لبنية الاعتماد
الموجودة (يُعد prep منفصلًا مُقاسًا). صفر تقييم لأي عقدة خارج closure (§5-C1 بند 5 ✓).

**C2 — Indexed:** reverse index `src → [dependents]` يُبنى مرة (زمن بناء مُقاس منفصلًا). لكل
change: BFS/worklist عبر الـindex ثم فرز dirty وإعادة الحساب. الـgraph ثابت أثناء الـrun ⇒ لا
index update cost (موثق). التخزين الإضافي: CSR عكسي.

**Bitwise-identity argument (COR-1/2):** نفس الصيغة، نفس ترتيب جلب deps لكل عقدة (CSR ثابت)،
قيم المدخلات نهائية لحظة التقييم (الفرز التصاعدي يضمن تقييم deps الـdirty أولاً) ⇒ floats
متطابقة bitwise. العقد خارج dirty مدخلاتها لم تتغير (induction) ⇒ قيمها الموروثة = قيم C0.

## 3) Topology Recipes — أرقام مجمّدة (DAG: حواف id أدنى → أعلى فقط)

| ID | الوصفة | E تقريبي @40K |
|---|---|---|
| T1 Sparse | k_i ∈ [2..6] (متوسط 4.0 بالضبط، أقصى 6 ≤ 8)، أهداف uniform في [0,i)، لا hub متعمد | 160K |
| T2 Chain | 40 سلسلة × عمق 1000 (رؤوس السلاسل بلا deps، t يعتمد على t−1)، out-degree ≤ 1 | 39.6K |
| T3 Hub | H = أول 1% من الـids = hubs (مصادر خالصة، بلا deps). كل non-hub: **20 hub-deps** (عينة بلا إعادة من الـ400 hubs) + 1 non-hub dep uniform في [H, i). Fan-out كل hub = 39600×20/400 = 1,980 ≈ 5% من العالم بالبناء. Out-degrees للـnon-hubs ناشئة (غير مُقننة) | 831K |
| T4 Dense | k_i ∈ [10..30] (متوسط 20.0 بالضبط، أقصى 30 ≤ 40) | 800K |
| T5 Mixed | bands بالـid: أول 5% hub-role (k=4)، التالي 15% متوسط (k∈[8..16]، نصف اختياراته غير الـhub داخل نافذة ±64)، آخر 80% sparse (k∈[2..6]). 30% من كل الاختيارات تستهدف hub-role ids | ≈208K |

⚠️ **T3 — مقبول (تصديق المالك بتوصية المراجع + القرار النهائي كمصمم التجربة، 2026-09-09):**
حساب 1%×5% يفرض ~20 hub-deps لكل non-hub (متوسط in-degree ≈21) — ده ليس bug بل هو بالضبط
غرض T3 المعلن: قياس wide fan-out concentrated topology (worst-case concentrated). "بقية الشبكة
sparse" تتحقق في الحواف non-hub→non-hub (dep واحد لكل عقدة).

**Topology Qualification (§8):** هذه probe definitions — التقرير سيتضمن مقارنة مع كثافة
domains المحرك الحالية (سياسات: sparse؛ سلاسل authority قصيرة) — لا ادعاء تمثيل GSG.

## 4) Scenario Matrix + Anchors (مصادقة Q2 + التصحيح §11-A1)

| ID | N | Topo | Changes | Anchor | هدف |
|---|---|---|---|---|---|
| S1 | 40K | T1 | C0 (0) | — | idle: صفر عمل |
| S2 | 40K | T1 | C1 (1) | **العقدة N−1** (أعلى id — closure = 1 بالبناء) | أفضل حالة (A1) |
| S3 | 40K | T3 | C1 (1) | hub id-0 (closure متوقع ≈2-4K ⇒ A4) | concentrated fan-out |
| S4 | 40K | T1 | C4 (400) | seeded-uniform | low density |
| S5 | 40K | T4 | C4 (400) | seeded-uniform | density effect |
| S6 | 40K | T3 | C2 (4) | hubs 0..3 (متوقع A4/A5) | wide cascade |
| S7 | 40K | T2 | C1 (1) | id-0 = رأس السلسلة-0 (closure=1000، depth=1000) | propagation depth |
| S8 | 40K | T5 | C6 (8000) | seeded-uniform | high-density regime |
| S9 | 1K/10K/40K/100K | T1 | C1 (1) | **العقدة N−1** في كل N (closure=1 دائمًا) | locality vs N |
| S10 | 1K/10K/40K/100K | T1 | 1%×N | seeded-uniform | world vs work scaling |

**SUPP (break-even §15 — خارج الـlocked matrix):** T1@40K × C ∈ {C3(40), C5(2000), C6(8000)}
seeded-uniform. **C7(20000) مشروطة:** تُشغَّل فقط لو لم يعبر C6 نقطة التعادل بعد (قرارة
تكلفة مجمّدة قبل التشغيل — §11-A4).

**SUPP-B (قراءة الـbatch لسؤال B1 — §11-A5):** T1@40K، batch semantics (كل التغييرات تُطبق
ثم propagation واحدة؛ C0 = مسحة كاملة واحدة)، counts ∈ {1, 4, 40, 400, 2000, 8000, 20000}،
uniform. الغرض: B1 "مع زيادة C" لا معنى له تحت cadence الفردية (النسبة مستقلة عن C — كل
تغيير يحمل إغلاقه الخاص)، بينما تحت الـbatch يزداد union closure مع C ⇒ التعادل قابل للقياس.
السلسلتان تُعرضان معًا في التقرير بتفسيريهما — لا دمج ولا انتقاء.

**A-levels (§10):** التصنيف بالـunion closure لكل run (مع تسجيل per-change: max/mean/union).

## 5) Measurement Protocol (§17)

- **Isolation:** subprocess مستقل لكل (scenario, candidate, pass) — تنفيذ sequential واحدًا تلو
  الآخر (نفس الجهاز، بلا منافسة). الـharness نفسه لا يوازي التشغيلات.
- **Timers منفصلة:** graph-build / prep (edge-array أو index) / initial-eval / propagation — لا خلط.
  perf_counter_ns لكل change (mean/p50/p95/peak + أول 20 عينات للتحقق) + total.
- **Warm-up:** عالم scratch صغير (256 عقدة، 8 تغييرات) قبل القياس — مسجل ومستثنى.
- **Memory:** Peak Working Set (psapi عبر ctypes — محاسبة OS بلا تشويه توقيت) + تقدير عميق
  getsizeof للبنيات (CSR أمامي / edge-array / index عكسي / states) ⇒ Memory/N، Memory/dep.
  **tracemalloc في spot-checks معزولة فقط** (S2/c0، S2/c2، S8/c2، SUPP-C6/c2 — عمليات موسومة
  `_tm`، توقيتها مستبعد من الجداول): تشغيله الدائم يشوه التوقيتات 2-4× (§11-A6).
- **Hash:** SHA-256 على `"id|state:.17g|derived:.17g\n"` بترتيب id + graph-structure hash
  (tobytes للـCSR الثلاثة + n) + initial hashes — **فحص برمجي للطول 64-hex قبل أي عرض**.
- **Two independent full passes** (عمليات كاملة منفصلة) ⇒ COR-3. تتحقق الـorchestrator من تطابق
  الـgraph/init hashes عبر عمليات السيناريو الستة (integrity).
- **الجهاز/النسخة:** تُسجَّل في كل JSON (Python، OS، CPU، cores).

## 6) Seeds

`SEED_BASE = 90210` + 1000×ترتيب السيناريو المجمّد (معلن في JSON): rng مستقل بالترتيب نفسه
(state-init → topology → weights → anchors). Deltas ثابتة ±0.30 (بلا RNG). C0=C0-changes
(صفر تغييرات) لا RNG anchors.

## 7) Gates Mapping (تُقيَّم من البيانات)

- **COR-1/2:** hash(C1/C2) == hash(C0) bitwise لكل scenario. **COR-3:** pass1 == pass2 لكل شيء.
- **COR-4:** effect counts (direct/propagated/total) متطابقة عبر candidates.
- **PERF-1 (S1):** C1/C2 صفر propagation/evaluation في idle. أي full-world work = FAIL.
- **PERF-2 (S2/S9، closure ≤0.1%N):** أفضل candidate ≥50% أقل runtime عند N≥40K.
- **PERF-3 (S4):** شرطي على القياس الفعلي — لو تجاوز closure الـ10% يُسجل "condition not met"
  مع الأرقام (لا فشل زورًا ولا نجاح زورًا) + السرعة الفعلية تُعرض.
- **PERF-4 (S9):** Runtime(100K)/Runtime(1K) ≤3× لكل candidate على حدة + حكم البوابة على أفضل
  candidate (أسلوب §14-2/3) مع عرض نتيجة الآخر كـfinding.
- **PERF-5 (S3/S5/S6):** لا crash/OOM، peak WS ≤2× baseline، تسجيل closure الفعلي.
- **PERF-6 (C≥20%):** runtime(candidate) ≤3× baseline.
- **PERF-7:** في scenarios الاستفادة المتوقعة: peak WS ≤1.5× baseline. (Caveat موثق: قياس
  Python-object overhead — working set هو المحك.)
- **COMP-1..4** + **B1..B4** من SUPP/SUPP-B + locked data (نتائج، لا thresholds مسبقة).

**ملاحظة Q3 المصادقة:** PROBE-P1 ينتج **نسبًا فقط** (candidate/candidate، scaling عبر N).
الأرقام المطلقة ليست GDScript-comparable — أي سؤال tick-budget مطلق يحتاج probe لاحق بلغة
المحرك (§21 functional domain probe) — قرار معماري لا يُبنى على أرقام PROBE-P1 المطلقة.

## 8) Pre-Registered Predictions (قابلة للتفنيد — كتبت قبل أي تشغيل)

- **P-A (Saturation):** S4/S10: مع anchors موزعة على DAG sparse عشوائي، أتوقع union closures
  ضخمة (30-70% من N) — قد لا يتحقق شرط PERF-3 (closure≤10%) ويصبح incremental ≈ full عند 1%.
  ده نتيجة مشيرة لطبيعة future-cone، لا فشل تشغيل.
- **P-B:** S9: C2 ratio ≈1-2× (بوابة ✓)؛ **C1 ratio ≈ E-ratio ≈100× ⇒ يفشل PERF-4** —
  النتيجة: locality مصدرها الـindex لا مفهوم الـaffected-set وحده (يحسم P1-COMP-4).
- **P-C:** S2: C2 يحقق ≥50% بسهولة؛ C1 مكسب متواضع (O(E) sweep مقابل O(N+E) حساب).
- **P-D:** S8 (20%): كلا الـcandidate ضمن ≤3× baseline (T5: E≈N×5.2 يجعل C1 قريبًا من التعادل).
- **P-E (Break-evens):** تحت الـper-change: نسبة C2 مستقلة عن C تقريبًا (التعادل عبر closure
  fraction/topology لا عبر C) — أتوقع عدم عبور C2 للتعادل حتى C6، وC1 قريب من التعادل على
  T1/T5. تحت الـbatch (SUPP-B): أتوقع عبورًا واضحًا بين C4-C7 (union closure → N).
  B2 ≈ closure ≥30-50% من N؛ B3: T4 أول تراجع لـC1؛ B4: index ≈ مرآة edge-array في الحجم
  (الفرق الحقيقي في per-change cost لا في memory).

## 9) Outputs

`spikes/probe-p1/`: `SPEC.md` (مواصفة المالك حرفيًا) · `DESIGN.md` (هذا) · `probe_core.py` ·
`run_benchmark.py` · `report.py` · `results/*.json` (خام لكل subprocess) · `logs/*.log` ·
`REPORT.md` (§18: correctness + performance/memory/topology/scaling tables + hashes + C1-vs-C2
+ break-even + boundary analysis + verdict §19).

## 10) Ratification Record (2026-09-09)

- **Q1 (C1 edge-sweep):** مصادقة — "C1 بيدفع تكلفة O(E) في كل change، C2 يبني index مرة" —
  الفرق المفهومي المقصود في المواصفة.
- **Q2 (anchors):** مصادقة (مع التصحيح §11-A1 على قاعدة S2/S9 — النية A1 محفوظة).
- **Q3 (Python stdlib):** مصادقة + ملاحظة النسب-only المسجلة في §7.
- **Q4 (T3):)** توصية المراجع "اقبل الحساب لأنه بيخدم غرض T3 الأصلي" + القرار النهائي
  المفوض لمصمم التجربة: **مقبول** — موثق في §3.
- **Q5 (commit policy):** مصادقة الخيار (أ) — commit تجميد التصميم قبل التشغيل، ثم تشغيل.
  commit النتائج لاحقًا بموافقة المالك بعد عرض التقرير.

## 11) Amendment Log (pre-run — قبل commit التصميم وقبل أي تشغيل)

- **A1 — تصحيح anchor لـS2/S9 (تصحيح قاعدة صادق عليها المراجع):** v1 قالت "أدنى id بلا
  dependents ⇒ closure=1". هذا **مستحيل رياضيًا** على T1: في DAG عشوائي uniform بـk~4،
  العقد منخفضة الـid لها descendant cones ضخمة (متوسط إغلاق عقدة عشوائية ≈ N/5)، وعقدة بلا
  dependents لا تظهر عمليًا إلا في النطاق الأعلى من الـids وبإغلاق ليس A1. **التصحيح:
  العقدة N−1** — بلا dependents بالبناء (لا يوجد id أعلى) ⇒ إغلاقها = {N−1} بالضبط = A1
  كما تقصد المواصفة تمامًا. اكتُشف بفحص الحساب قبل التشغيل — وهو بالضبط غرض الـpre-registration.
- **A2 — T1/T4 نطاقات الدرجات:** v1: T1 [1..8] (متوسط 4.5 ≠ 4)، T4 [10..40] (متوسط 25 ≠ 20)
  ⇒ مصحح إلى [2..6] (متوسط 4.0، أقصى 6≤8) و[10..30] (متوسط 20.0، أقصى 30≤40) — مطابقة
  حرفية لأرقام §8.
- **A3 — T3 صياغة:** توضيح أن fan-out الـhub بالبناء (1980≈5%) وأن out-degrees للـnon-hubs
  ناشئة غير مُقننة (إزالة عبارة out-cap الملتبسة في v1).
- **A4 — SUPP C7 مشروطة:** تُشغَّل فقط لو لم يعبر C6 التعادل (توفير ~40-80 دقيقة تكلفة
  تشغيل — قرار تكلفة مجمّد قبل النتيجة، وليس انتقاء نتائج).
- **A5 — إضافة SUPP-B:** سلسلة batch-cadence معزولة لسؤال B1 — تحت الـper-change
  (المجمّدة) النسبة مستقلة عن C، بينما سؤال B1 "مع زيادة C" لا معنى له إلا تحت الـbatch.
  السلسلتان تُقاسان وتُعرضان معًا بتفسيريهما — تغطية صريحة لغموض cadence في §6 الأصلية
  بلا انتقاء.
- **A6 — tracemalloc محصور في spot-checks معزولة:** تشغيله الدائم يشوه توقيتات المقارنة
  2-4× (رغم أن §12 تطلبه "إن أمكن" — يُلبى بالعينة المعزولة الموثقة).
