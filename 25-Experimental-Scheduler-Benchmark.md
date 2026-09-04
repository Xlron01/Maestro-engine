# 25 — Experimental Scheduler Benchmark (T5-B)

> **Deliverable gate per owner directive** — مقارنة Current Core Scheduler مقابل تجريبيين (Bucket + Heap)
> فوق **الحمل الحقيقي** (نظام الاقتصاد والإنتاج كما هو، بلا تبسيط) و**شروط T5-P0 الفعلية** (N=10K، 90 يومًا،
> عواصف الأيام 30/60/90). **صفر تعديل عل الإنتاجي.**

---

## §0 — النتيجة التنفيذية

| المجرى | التصنيف (بحسب العتبات المجمدة مسبقًا) |
|---|---|
| **Bucket Scheduler** | ✅ **FULL PASS** — العواصف −38 إلى −41% كلها وطمأنينة السيميانتكس القطعية |
| **Heap Scheduler** | 🟡 **PARTIAL PASS** — هادئ −≈70× لكن العاصفة −18 إلى −26% (دون عتبة FULL الكاملة ≥25% في كل عاصفة) |

**(القرار النهائي التبني/الرفض يبقى للمالك عند المراجعة؛ هذا gate يُقرّر قياسات فقط — لا أُعلن إغلاقًا نهائيًا منفردًا.)**

---

## §1 — كيفية استخراج/إعادة إنتاج الحمل الحقيقي (الإلزامي)

**الاستخراج = حقن فقط، وليس إعادة كتابة:**

1. نفس `Simulation.gd` التشغيلي: `Simulation.new()` → `data_root_override = "res://data/scenarios/t5_p0"` → `init_world(12345)` — يبني العالمان الحقيقيان عبر `ContentLoader` + `dispatch.json`.
2. الحقنية الوحيدة: `sim.scheduled = <candidate>` بعد init — استبدال كائن الجدولة فقط بواحد من النوعين التجريبيين، مع نقل `_jobs` بنفس ترتيب التسجيل.
3. **لا تغيير لعمل ال scheduler الفعلي** — الأربعون ألف job واثنان نظاما economy ينفذان معالجات dispatch.json الخام كما هي.
4. الـProbe (`SchedulerProbe`) يُطبق على الثلاثة مسارات بالتساوي — نفس معدل overhead لكل، فالمقارنة عادلة.

`git diff` على الملفات الإنتاجية (Simulation/SimClock/EventQueue/ScheduledQueue/ActivationSet/DecisionSystem/game_event_handlers/economy*): **صفر تعديلات كود إنتاجي** (فقط إضافة `data_root_override` المعتمدة سلفًا في T5-P0 و`decision_counters`+`activity_counters` في طبقة المحتوى — موثقتان سابقًا).

## §2 — المرشحان التجريبيان

| | بنية | تعقيد get_due/reschedule | التنفيذ لحفظ ترتيب baseline |
|---|---|---|---|
| **Bucket** | `Dictionary day→Array` | O(1)/ O(1) ✓ | عناصر تحمل `_seq` (ترتيب الإدراج الأصلي)، يُفرز بها الاستخراج اليومي |
| **Heap** | min-heap (day, seq) | O(log n)/O(log n) | seq = رقم التسجيل الأصلي (ثابت عبر الرفرشات) |

## §3 — السيناريوهات (ت_mapping الحرفي)

- **A (Stable):** الأيام غير المورطة بعاصفة (غير ت من 30×).
- **B (T5-P0 Storm):** يوم 30/60/90 منفردات — نفس الـ10,000 دولة + نفس الجدولة والأفعال (40002 jobs = 10k×4 + economy v1/v2).
- **C (Repeated Storm):** الثلاث عواصف داخل الران الواحد — تُثبت أن النمط منهجي وليس نقطة.

## §4 — قياسات الأساس (Current Core أولًا)

| البند | القيمة |
|---|---|
| quiet-p50 (أيام عادية) | 11,461 µs |
| quiet-p95 | 16,951 µs |
| storm days (30/60/90) | 259.71s / 273.62s / 290.83s |
| peak-activated | 30,002 (d30/60) ثم 40,002 (d90 مع gdp_update كل 90 يومًا) |
| storm duration | تكة واحدة |
| total (90 يوم) | 825.17 s |
| mem baseline (d30/60/90) | 91.06 / 91.34 / 91.61 MB |

## §5 — النتائج التجريبية (مقارنة مباشرة)

### Bucket Scheduler

| البند | القيمة | مقارنة Current |
|---|---|---|
| quiet-p50 | **149 µs** | **−98.7%** (77× أسرع) |
| quiet-p95 | 2,799 µs | −83.5% |
| storm d30/d60/d90 | **161.59 / 162.05 / 184.93 s** | **−37.8 / −40.8 / −36.4 %** (كلها ≥25%) |
| total | 508.58s | −38.4% |
| mem (d30/60/90) | 116.19 / 116.17 / 116.73 MB | **+27.6%** |

### Heap Scheduler

| البند | القيمة | مقارنة Current |
|---|---|---|
| quiet-p50 | **202 µs** | **−98.2%** |
| quiet-p95 | 2,997 µs | −82.3% |
| storm d30/d60/d90 | 211.78 / 202.02 / 232.41 s | **−18.4 / −26.2 / −20.1 %** |
| total | 646.24s | −21.7% |
| mem (d90) | 119.0 MB | +30% |

## §5 ب — ما لم يُقَس
**استهلاك الـCPU%** غير قابل للقياس عبر Godot headless + GDScript (`OS` API لا يوفّر cpu_time per call) — مُسجَّل كحدود أداة، لا تفسير.

## §6 — إثبات الصحة (قبل أي مقارنة سرعة — §6 من الموجّه)

**bitwise عبر الثلاثة** (كامل العالم + التسلسل اليومي):

| دليل | القيمة |
|---|---|
| `SEM_HASH` (canonical world state after 90 days) | `bcd2763c957c1c21f73cf8e0f637fa81e1ca8d76eb3354feb20f63108956c2b4` — متطابق للكل |
| `SEQ_HASH` (ordered per-day executed job ids) | `795365ba15cf63228be9d7672e36cad4dff9cd6ef938114c6e402d93a9c5b89d` — متطابق للكل |
| counters |events / coup / exposure| `30104 / 6000 / 0` — متطابق |

**اختبار الترتيب المسبق (قبل الرانات الكاملة):** test_t5b_compare_diag3 — أوامر get_due_jobs عند t=1/t=30 للثلاثة متطابق bitwise.

## §7 — الحكم بالعتبات المجمّدة مسبقًا

| محك | Bucket | Heap |
|---|---|---|
| سيميانتكس حرفية | ✓ | ✓ |
| هادئ ≥30% أسرع | ✓ (≈77×) | ✓ (≈57×) |
| عاصفة ≥25% أسرع في كل العواصف | ✓ (36–41%) | ✗ (18–26%) |
| **⇒ الحكم** | **FULL PASS** | **PARTIAL PASS** |

*حدود الحكم:* نتيجة التحسن في العاصفة ليست من "ذكاء" الجدولة الإضافية بل من إزالة فاتورة المسح الخطي لـ40,002 عنصرًا في كل tick قاحصة + توزيع الرسوم الذرية عبر قسم اليوم. ذاكرة أعلى بـ~28% (قابل للبحث لاحقًا).

## §8 — التوصية

- **Bucket:** المرشح المؤهل للنظر بالهجرة كتجربة لاحقة (جولة gate مستقل) — مع دراسة استهلاك الذاكرة (+28%) حتمية الإصدار للمحاكاة الطويلة.
- **Heap:** يعمل بشكل صحيح لكن بلا ثبات كافٍ لعتبة FULL — لا لهجرة.
- **لا حكم ولا تركيب تلقائي:** الحكم النهائي （التبني/الإرشاد المعماري） للمالك يناقش منفصلًا.

## §9 — الأدلة الخام

| artifact | الملف |
|---|---|
| baseline (Current) | [`.ai/evidence/tests/test_t5b_current_baseline.log`](file:///c:/tmp/maestro%20engine/.ai/evidence/tests/test_t5b_current_baseline.log) (run04=baseline, run01-03 محاولات أرشيفية) |
| Bucket | [`.ai/evidence/tests/test_t5b_bucket_run02.log`](file:///c:/tmp/maestro%20engine/.ai/evidence/tests/test_t5b_bucket_run02.log) (run01 ما قبل التصحيح الترتيبي — أُرشف) |
| Heap | [`.ai/evidence/tests/test_t5b_heap_run01.log`](file:///c:/tmp/maestro%20engine/.ai/evidence/tests/test_t5b_heap_run01.log) + [run02](file:///c:/tmp/maestro%20engine/.ai/evidence/tests/test_t5b_heap_run02.log) (run01 ما قبل التصحيح التسلسلي) |
| تشخيص الترتيب | [test_t5b_compare_diag.log](file:///c:/tmp/maestro%20engine/.ai/evidence/tests/test_t5b_compare_diag.log) / [_diag2](file:///c:/tmp/maestro%20engine/.ai/evidence/tests/test_t5b_compare_diag2.log) / [_diag3](file:///c:/tmp/maestro%20engine/.ai/evidence/tests/test_t5b_compare_diag3.log) |

### سجل المراجعة

| التاريخ | الإجراء | السبب |
|---|---|---|
| 2026-08-26 rev.1 | درجة بناء المرشحين + تشغيل current | اكتشاف تنبؤي: bucket ترتيب عاصفة مخالف ⇒ اعتبرdeg-before-rerun: التشغيل المتأخر عكس إعادة من الصفر |
| 2026-08-26 rev.2 | إصلاح ترتيب bucket (seq عالمي) + إصلاح all_jobs في heap + إعادة الثلاثة كاملة بتقارن bitwise نهائي | «لا استنتاج ضمني» — أُثبتت الهوية قبل أي ادعاء أداء |

---

**Evidence trail:** docs 21/22 + هذا الملف + الأرشيف الخام أعلاه. **Verdict محكم بالتشغيل، إغلاقه النهائي يعود لمراجعة المالك.**
