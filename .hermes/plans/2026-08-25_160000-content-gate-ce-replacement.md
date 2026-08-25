# TASK-024 — استبدال قائمة الـ Counterexamples في Content Ontology Gate

> **For Hermes:** تنفيذي — لكن هذه النوبة تخطيط فقط (plan mode). لا تعديل ملفات المشروع إلا عند التفعيل.

**Goal:** استبدال §2 من وثيقة `12-Content-Ontology-Gate.md` بقائمة CEs جديدة تضغط على سؤال الـ Ontology نفسه (ما أقل مجموعة Primitives؟) لا على قدرات الـ Kernel المُثبتة، مع تسجيل مسبق مجمد لكل توقع قابل للكسر — دون بدء التحليل.

**Architecture:** نفس بروتوكول Gates 08/09/11: Observation من العالم → تسجيل توقع قابل للكسر → تحليل اختزال → Confirmed / Rejected / Open. الـ Kernel يعتبر Evidence مؤكدًا (Phase 6)، وليس موضوع الاختبار.

**Owner decision مسجل (المالك، 2026-08-25):**
- رفض القائمة السابقة لأن CE-1→CE-4 كانت اختبارات Kernel (Entity/Mutable State, Scheduling, Propagation, Save/Load) لا ضغط ontological.
- القائمة الجديدة أدناه معتمدة من المالك نصًا.
- CE-5 تبقى Boundary Case تحت الـ Boundary Rule المجمدة: حاجة Temporal Primitive ⇒ Open Question فقط («Content Schema requires unresolved temporal semantics») وإغلاق Gate الـ Content عند هذا الحد.
- **ممنوع بدء التحليل (§3) في نفس نوبة الاستبدال.**

---

## السياق الحالي

| الملف | الحالة |
|---|---|
| `12-Content-Ontology-Gate.md` | §0 Boundary Rule + §1 قواعد + §2 قائمة قديمة (PROPOSED) — القائمة القديمة تُستبدل كاملة |
| `.ai/tasks/active.md` | TASK-024 IN_PROGRESS — يحتاج تحذير «القائمة غير مسجلة» يُستبدل بإشارة «القائمة الجديدة مجمدة من المالك» |
| `scripts/validate_memory.py` | يجب أن يمر بعد التعديل |

---

## الخطوات

### Step 1: استبدال §2 كاملًا في `12-Content-Ontology-Gate.md`

استبدل القسم §2 بالكامل بهذا المحتوى:

```markdown
## 2) التسجيل المسبق — القائمة المعتمدة من المالك (2026-08-25 — مجمدة)

> ملاحظة المالك على القائمة الأولى: كانت في معظمها اختبارات قدرات Kernel مُثبتة
> (Entity+Mutable State, Scheduling, Propagation, Save/Load — كلها Phase 6 PASS)
> ولا تضغط على سؤال الـ Ontology. القائمة أدناه تجبر على محاولة تمثيل Content مختلف:
> هل النموذج الأبسط يستوعبه أم يحتاج Primitive؟ — بنفس منطق اختبارات 08/09.
>
> الدرس الحاكم (درس HostileControl): نبدأ من Observation من العالم ← نحدد الـ primitive
> الضروري ← وبعدها فقط نسمّي الـ domain concept. ليس العكس.

القدرات التمثيلية المسموح افتراضها (موروثة من Gate 2 — شروط اعتماده):

| الرمز | القدرة |
|---|---|
| **R1** | تاريخ دائم (عدادات تراكمية كحقائق محفوظة) |
| **R2** | حالة مؤقتة مؤرخة (مَن/أين/متى) |
| **R3** | سجل حقائق/التزامات علنية |

السؤال الحاكم:

> ما أقل مجموعة Primitives يمكنها وصف العالم الذي يحتاجه Grand Strategy Engine،
> قبل تسمية أي شيء باسم Country / Resource / Event / Goal؟

### الفصل الإلزامي داخل كل تحليل

كل CE يُحلل عبر الفصيلة الثلاثية المجمدة: **Definition / Runtime State / Historical Change**
— ولا يجوز خلط مستوى بأخر لإعلان اختزال.

| # | Counterexample | صيغة التوقع المجمدة (قابلة للكسر) |
|---|---|---|
| **CE-1** | دولة + كيان غير دولتي + مورد | Likely reducible إلى Entity عام واحد قاموسي (kind كسمة data لا نوع). **يفشل التوقع** إذا ظهرت عملية أو قيد تمثيل يتطلب فروقًا بنيوية بين Country/Organization/Resource لا يمكن حملها كبيانات |
| **CE-2** | علاقة تتغير عبر الزمن: تحالف 1950→1960 ثم انتهاؤه | Test reducibility — المرشح الأضيق: Edge موزون بين كيانين + سجل تغيّره (R1/R3). **يفشل** إذا احتاجت العلاقة نفسها هوية/حالة/سلوكًا مستقلًا عن طرفيها لا يمكن تمثيله كحقائق مؤرخة على الزوج (L2 Pair-Indexing) |
| **CE-3** | حدث يغيّر عدة كيانات: Coup / اكتشاف مورد / توقيع اتفاق | Likely reducible — Historical Change كسجل حقائق (R3) + propagation rules data-driven. **يفشل** إذا ظهر حدث يحتاج وجودًا مستمرًا بعد وقوعه (شيء يتصرف/يتغير) لا يمكن تفكيكه إلى سجل + حالات ناتجة |
| **CE-4** | حقيقة مشتقة من عدة حقائق: حصة في مورد + المورد يمر عبر ممر + طرف ثالث يملك سلطة | Test reducibility — مرشحة للتركيب داخل Derived State (سلسلة Model v1: Facts → Derived → Composition). **يفشل** إذا احتاجت المعلومة المركبة أن تكون fact أولية مخزنة (Observation primitive) لا مشتقة حسابيًا وقت القرار |
| **CE-5** | الحالة الزمنية | **Boundary Case — §0 يسود:** إن أظهر التحليل حاجة Temporal Primitive مستقل ⇒ يُسجل فقط Open Question «Content Schema requires unresolved temporal semantics» ويُغلق Gate الـ Content بما ثبت حتى تلك النقطة. لا تصميم ولا حسم زمني هنا |

قاعدة عامة إضافية (مجمدة): أي اقتراح Primitive جديد في التحليل يجب أن يمر اختبار
«لا Primitive لمجرد الراحة» — يثبت فشل البديل الأضيق أولًا.
```

### Step 2: تحديث `.ai/tasks/active.md`

- عدّل معيار القبول الأول ليقرأ: «تسجيل مسبق مجمد للقائمة الخمسة **المعتمدة من المالك** (Ontology-focused: Entity/Relationship/Event/Derived-Fact/Temporal)».
- احذف الفقرة الأخيرة (تحذير «القائمة غير مسجلة») واستبدلها بـ: «§2 مجمد بتوقيع المالك 2026-08-25 — القائمة الجديدة Ontology-focused، والقائمة القديمة مرفوضة كاختبارات Kernel مكررة».

### Step 3: تحقق

Run: `python scripts/validate_memory.py`
Expected: `0 Errors` (التحذير الموروث في `00-خطة-الطريق.md` مقبول baseline).

### Step 4: Commit ذاتي (وفق الدستور §3-5)

```bash
git add -A && git commit -m "TASK-024: replace CE list with owner-ratified ontology-focused set; freeze pre-registration"
```

### Step 5: توقف

⛔ لا كتابة §3 (التحليل التطبيقي) في هذه النوبة — بدء التحليل نوبة مستقلة بعد تأكيد المالك.

---

## Risks / Open

- **خطر:** الانزلاق في التحليل لاحقًا نحو اختبار Kernel من جديد — يعالجه سطر «الدرس الحاكم» المثبت في §2.
- **Open:** هل يحتاج CE-4 تعريف كمي لحد الفرق بين fact أولية ومشتقة (متى التركيب مكلف جدًا بحيث يبرر تخزين)؟ — يُحسم داخل تحليل CE-4 نفسه، لا الآن.
