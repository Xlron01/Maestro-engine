# 28 — BATCH-A: Political Institutional Core (TASK-039)

> **الحالة:** COMPLETE (PROVISIONAL — بانتظار ختم المالك) · **Owner:** ox-alpha
> **النطاق:** minimum real political model يشغل حلقة P0 السياسية كاملة — صفر تعديل نواة، tests-first (A–K جمّدت قبل الـactions)، deterministic، data-driven.

## 1) الموديلات الخمسة (ملكية: `scripts/politics/political_state.gd`)
Office (5 حقول minimum، بلا تاريخ مكرر) · Party (Actor حقيقي) · Legislature (+Bills/Motions) · Government (Actor، لا يفترض دعمًا تلقائيًا) · Election — + عقود التاريخ: `ElectionHistory[]` `ElectionResult[]` `ElectionDisputeHistory[]` `SuccessionHistory[]` `RegimeHistory[]`.
> **تعارض موثق:** المواصفة قالت "استخدم الـcontracts الموجودة" — تدقيق grep أثبت أنها غير موجودة في أي كود سابق؛ هذا أول implementation لها بالأشكال المحددة (بلا تغيير معماري صامت).

## 2) الـActions الاثنا عشر (political_actions.gd — pipeline ملزم)
`Actor → Action → Queries/Assessments → Resolution → Event(s) → Owning Domain mutation`
FormGovernment (succeeds/fails/incomplete) · AppointOfficeholder (سلطة تعيين من البيانات + Compliance assessment للموافقة) · DismissOfficeholder · ResignGovernment · ProposeBill · VoteBill (التصويت ≠ النتيجة) · VoteConfidence/VoteNoConfidence (consequence فقط حيث تسمح القواعد) · SupportGovernment/WithdrawSupport (sparse — لا seats mutation) · HoldElection (توزيع largest-remainder حتمي؛ Election ≠ Succession) · ContestElectionResult (عبر ElectionDisputeHistory لا bool).

## 3) القواعد المؤسسية
`data/rules/institutional_rules.json` — data-driven: عتبات التكوين/الثقة/القوانين + من يعيّن/يعزل + هل الإنتخاب يغيّر الحاكم. **NON-FINAL** — لا constitutional engine.

## 4) نتائج القبول A–K: **PASS 31/31**
(`test_t039_politics_run01.log`) — الحلقة السياسية الكاملة بـsnapshots لكل انتقال (A) · Election ≠ Succession بالحالتين + dispute (B) · دعم sparse بلا لمس البرلمان (C) · دورة Office بلا تاريخ مكرر (D) · فصل التصويت عن النتيجة (E) · انتقالات الثقة الحتمية (F) · استهلاك Compliance بلا تنفيذ مباشر (G) · PARTIAL بلا اختلاق (H) · checksum + events bitwise ×2 (I) · **J: 30 ticks ⇒ 0 تقييم + audit مصدري** · (L regression أدناه).

## 5) Actor Runtime Benchmark (§11) — `test_politics_benchmark_run01.log`
```
N=100 دول: 400 حزب · 100 تشريعية · 400 منصب · 100 حكومة · 100 bills · 700 شخصية
CPU: 1100 actions في 363ms (mean 330.3µs/action) — generation 7.9ms
Memory: delta ≈ 33.2MB (يشمل event_log وسجلات التاريخ الكاملة)
Assessments: 200 compliance · Events: 1600 · peak burst: 3
Active actors: 600/1200 (0.500) — persistent ≠ per-tick
per_tick: political_evaluations_in_30_production_ticks = 0 ✓
verdict: PASS
```

## 6) Regression — كلها EXIT=0
ScenarioTest · D1 28 · Integration 7 · Economy 14 · TASK-038 compliance · T5-C (c1) ببوابات bitwise المجمدة.

## 7) انحرافات/فجوات معمارية معلنة
1. عقود التاريخ لم تكن موجودة (أول تنفيذ — أعلاه).
2. Task039 v0 resolution rule-table بقي كما هو (بلا formula جديدة — توجيه المالك).
3. **Architectural gap مرفوع:** سقوط الحكومة بعد فقد الدعم لا يحدث تلقائيًا (ممنوع مباشرة من WithdrawSupport) — يحتاج institutional resolution لاحق (مثل motion تلقائي أو قاعدة "أقلية معلنة") — قرار مالك.
4. لامركزية قواعد المكاتب المولدة (benchmark) تُحقن data-driven — نفس الآلية متاحة لأي عالم.

## 8) الأدلة
`test_t039_politics_run01.log` · `test_t039_politics_benchmark_run01.log` · `test_t039_regressionK_*.log` (6) · commits: 0e32c9ac → 80ba4e27 → cc04b712 → (benchmark) → (docs).
