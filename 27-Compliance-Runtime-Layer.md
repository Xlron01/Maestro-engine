# 27 — Compliance Runtime Layer (TASK-038)

> **الحالة:** COMPLETE (PROVISIONAL — بانتظار ختم المالك) · **Owner:** ox-alpha · **Dependencies:** TASK-037 (T5-C)، سلسلة Model v1/Decision Gates
> **النطاق:** تنفيذ Compliance Runtime Layer فوق النواة الحالية — **صفر تعديل** على النواة التسعة وعلى Simulation/EventQueue/Scheduler/dispatch.json/طبقة المحتوى الإنتاجية (diff مثبت).
> **المنهج:** tests-first — توقعات A–L جمّدت قبل كتابة compliance_query.gd (الجناح مكتوب ومجمد قبل كود الـresolution في شجرة العمل).

---

## 0) العقود المقفولة المنفذة

### إقفال Capability (بتعديلات المالك المعتمدة)
```text
Capability(actor, action, target, context) → CapabilityAssessment
├── feasibility = FEASIBLE | INFEASIBLE | UNKNOWN   (ثلاثي — لا يُجبر true/false عند نقص البيانات)
├── status      = COMPLETE | PARTIAL
├── limiting_factors[]  ·  used_inputs[]  ·  missing_inputs[]
```
- **القاعدة المقفولة:** غياب Geography/Logistics ⇒ `UNKNOWN + PARTIAL` — **لا** يتحول إلى INFEASIBLE (يمنع خطأ "غياب البيانات = الجيش لا يستطيع").
- **قاعدة الاستهلاك العامة المقفولة:** Assessment يجوز له استهلاك World Facts الخام عندما تكون جزءًا مباشرًا من الظاهرة التي يقيمها؛ قاعدة "الاستهلاك عبر domain-owned assessment" تمنع الحساب المكرر ولا تمنع قراءة الحقائق الخام التي لا يملكها نظام آخر كـDerived State. لذلك `Capability → Geography Facts` مشروع و`Capability → حساب Economic Performance` ممنوع.
- Capability **قدرة تنفيذية مادية/تنظيمية** — قد تعتمد لاحقًا على بنية القيادة/التدريب/الاتصالات/الجاهزية؛ أول طبقة لها World Facts الخام مصدر مشروع.

### Compliance
```text
Compliance(actor, action, target, context) → ComplianceAssessment
├── compliance_degree (0..1)     ⊥ مستقل عن
├── resistance_mode = NONE | PASSIVE | ACTIVE
├── resistance_strength (0..1 عند الصلة)
├── status = COMPLETE | PARTIAL  ·  used_inputs[]  ·  missing_inputs[]
└── short_circuited (حقل إضافي معلن لبوابة B — قيم null عند القص)
```
- `actor` = **المستجيب** الذي نقيّم امتثاله؛ `target` = مصدر الأمر/الطرف المقابل.
- التركيبة `(0.4, ACTIVE)` مسموحة (تنفيذ جزئي + مقاومة فعلية) — ممنوع probability.

### Influence / Legitimacy
- `Influence(source, target, context)` بقناتين غير alias: **structural** (من ناتج control_chains المُمرَّر) و**informal** (قناة trust من sparse social_relations).
- `Legitimacy(subject, domain, audience, context)` — domains: State/Regime/Government/Action؛ primitive facts تُستهلك إن وُجدت؛ derived states (Stability/PopularSupport/PublicOrder...) ملك لأنظمة أخرى ولا يُعاد حسابها؛ نقصها ⇒ PARTIAL.

### Coercion/Threat = future dependency فقط — لا FearSystem ولا schemas.

## 1) التوضيحان المعتمدان من المراجعة (منفذان نصًا)

### §0-b-1 — social_relations قاموس واحد متعدد القنوات
`social_relations[target] = {loyalty, trust, kinship, ...}` — Influence يقرأ `trust` وCompliance يقرأ `loyalty` **من نفس الـedge الخام**. قراءة قنوات مختلفة من نفس الـedge — **ليست نسخًا مستقلة من المفهوم لكل نظام ولا تكرار بيانات**. موثق في هيدرات `compliance_types.gd` + `influence_query.gd` + `compliance_query.gd` (ثوابت `CHANNEL_*`).

### §0-b-2 — عقد الاستخدام (precondition)
الـ**caller** هو المسؤول عن استدعاء `RelevanceControl.control_chains()` مرة واحدة وتمرير الناتج في `context["chains"]`. الطبقة **لا تعيد حسابه ولا تفترض وجوده إلا كمدخل** — غيابه ⇒ `structural = null + missing_inputs += ControlChains` (وليس إعادة حساب). موثق في هيدرات `influence_query.gd` + `compliance_query.gd` أعلاه.

## 2) الملفات (كلها جديدة)
| ملف | Commit |
|---|---|
| `scripts/compliance/compliance_types.gd` | acb61208 |
| `data/rules/compliance_config.json` (عتبات v0 — **NON-FINAL**) | acb61208 |
| `data/worlds/compliance/base.json` | acb61208 + Regime_H في 889c948c |
| `scripts/compliance/capability_query.gd` | 98d94f52 |
| `scripts/compliance/influence_query.gd` | 4c0563ca |
| `scripts/compliance/legitimacy_query.gd` | 4c0563ca + خطاف counterparty في e7674d02 |
| `scripts/compliance/compliance_query.gd` | e7674d02 |
| `scripts/test_compliance_runtime.gd` + raw log | 889c948c |

## 3) v0 Resolution (NON-FINAL — pending owner formula)
جدول قواعد عتبة من `compliance_config.json` — **بلا أوزان ولا مجاميع موزونة**:
- **Gate 1:** `INFEASIBLE + COMPLETE` ⇒ short-circuit (degree/mode/strength = null — لا compliance مختلق ولا تحول إلى refusal بسبب Loyalty/Fear). `UNKNOWN + PARTIAL` ⇒ يستمر.
- **Stage 2:** يُحسب فقط ما يطلبه `action.needs` (authority/loyalty/goal_conflict/legitimacy/coercion) — بلا سلسلة قسرية.
- **Stage 3:** willingness (SUPPORTS/NEUTRAL/OPPOSES من loyalty×conflict) × pressure (structural ≥ عتبة) ⇒ جدول:
  | willingness | pressure | (degree, mode, strength) |
  |---|---|---|
  | SUPPORTS | أي | (1.0, NONE, 0.0) |
  | NEUTRAL | نعم | (partial_degree=0.5, NONE, 0.0) |
  | NEUTRAL | لا | (0.0, PASSIVE, passive_strength=0.5) |
  | OPPOSES | نعم | (partial_active_degree=0.4, ACTIVE, active_strength=0.7) |
  | OPPOSES | لا | (0.0, ACTIVE, active_strength=0.7) |
- قيم الـconfig placeholders معلنة — **ليست gameplay-final**؛ استبدالها بformula المالك لاحقًا لا يلمس العقود ولا الاختبارات السلوكية.
-loyalty ممزق +conflict ⇒ NEUTRAL (حتمي وموثق).

## 4) نتائج القبول A–L — `test_compliance_runtime.gd`: **PASS 25 / FAIL 0**
raw: `.ai/evidence/tests/test_t038_compliance_run01.log`
| # | الفحص | النتيجة |
|---|---|---|
| A1/A2 | determinism bitwise ×2 (compliance + legitimacy) | PASS |
| B1/B2 | short-circuit nulls + عدم تأثره بloyalty/conflict | PASS |
| C1/C2 | UNKNOWN ≠ INFEASIBLE + استمرار resolution + propagation | PASS |
| D1/D2 | compliance يتغير بauthority + capability bitwise ثابت | PASS |
| E1/E2 | influence pinned أثناء تغيير loyalty + compliance يتغير | PASS |
| F1/F2 | structural ≠ informal (ليستا alias) | PASS |
| G1/G2 | PARTIAL + missing PopularSupport + value من الأدلة فقط | PASS |
| H1/H2 | PARTIAL + missing ConstitutionalValidity + استمرار الحساب | PASS |
| I1–I5 | الحالات الخمس (1.0,NONE)/(0.5,NONE)/(0.0,PASSIVE,0.5)/(0.0,ACTIVE,0.7)/(0.4,ACTIVE) | PASS |
| J1 | before == after bitwise (لا world mutation) | PASS |
| K1/K2/K3 | تدقيق مصدري + dispatch نظيف + 30 ticks ⇒ 0 تقييم، نداء صريح ⇒ +1 | PASS |

## 5) Regression (L) — كلها PASS
| الجناح | النتيجة | raw |
|---|---|---|
| ScenarioTest | EXIT=0 + State Checksum anchor PASS | `test_t038_regression_scenariotest.log` |
| D1 Decision Boundary | **PASS (28 checks)** | `test_t038_regression_d1.log` |
| Model v1 Integration | **PASS (7 checks)** | `test_t038_regression_model_v1_integration.log` |
| Economy Phase 2 | **14 PASS / 0 FAIL** | `test_t038_regression_economy_phase2.log` |

## 6) Dependencies الباقية PARTIAL (معلنة — لا أنظمة مبنية)
`PopularSupport` · `ConstitutionalValidity` · `ThreatAssessment` · `PublicOrder` · `AudienceView` · عناصر الحقائق البدائية غير المملوءة في fixtures. لذلك `status=PARTIAL` هو الوضع الطبيعي للطبقة في v0 — قرار "هل النتيجة الجزئية كافية؟" للمستهلك.

## 7) الأداء وحدود التشغيل
- **صفر أثر على tick**: لا wiring في dispatch.json/run_step (K2/K3) — الطبقة on-demand حصرًا.
- لا caching subsystem (عقد الاستخدام §1-b) — `control_chains` يُحسب مرة عند الـcaller.
- لا NxN matrices ولا per-tick polling ولا stochastic — determinism bitwise مثبت (A).

## 8) انحرافات معمارية معلنة (كلها موثقة ومبررة)
1. **دلالة actor**: Compliance تُقيّم امتثال **المستجيب** لفعل مصدره `target` — توضيح دلالي لازم لتثبيت مصادر loyalty/conflict/authority (منشأ خلال الاختبارات، موثق في هيدر `compliance_query.gd`).
2. **خطاف `authority_counterparty_id`** في Action-legitimacy (تعديل على `legitimacy_query.gd` نزل مع commit الـresolution لأن الـresolution هو مستهلكه الأول).
3. كيان `Regime_H` أُضيف للـfixture مع commit الاختبارات (يلزمه فحص G المجمد).

## 9) التوصية للخطوة التالية (قرار المالك)
1. تعريف formula الـCompliance النهائية (تستبدل v0 دون مساس بالعقود/الاختبارات السلوكية).
2. ربط on-demand من طبقة المحتوى عند أول action يحتاج response (بمحاكاة استعلام لا بنظام حي).
3. ملء future dependencies كلٌّ بمهمته عند الحاجة الفعلية — لا استباقًا.
