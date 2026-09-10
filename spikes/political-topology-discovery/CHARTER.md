# POLITICAL TOPOLOGY DISCOVERY — CHARTER (v1.0 — FROZEN BEFORE EXTRACTION)

> **Status:** مجمدة قبل أي استخراج أو قياس (نمط PROBE-P1 pre-registration / Decision 004).
> هذا NOT a probe ولا benchmark ولا TASK-0xx — استخراج وقياس read-only من production code/data.
> **Hard boundary:** صفر تعديل على أي ملف production. كل المخرجات تحت `spikes/political-topology-discovery/`.
> الهدف الوحيد: وصف topology السياسة الفعلية بالأرقام، لتقرير ما إذا كان functional domain probe (PF-PROBE)
> يستحق المواصفة، وبأي workload. **البيانات هي التي تقرر — لا نفرض topology مسبقًا** (owner directive).

---

## 0) المصادر المجمّدة (ground truth — audit-complete 2026-09-10)

كود الـpolitical runtime (قرئ بالكامل، سطرًا سطرًا):

| الملف | الدور | الحجم |
|---|---|---|
| `scripts/politics/political_state.gd` | Owning-domain state + queries + mutators | 194 L |
| `scripts/politics/political_actions.gd` | 12 action — الـsemantics الفعلية | 444 L |
| `scripts/politics/institutional_rules.gd` | قواعد data-driven (can_appoint/can_dismiss/…) | 97 L |
| `scripts/politics/political_deadlines.gd` | جدولة/تنشيط deadlines (term/election) | 210 L |
| `scripts/politics/political_handlers.gd` | content layer integration | 107 L |
| `scripts/game_event_handlers.gd` (الجزء السياسي) | evt_coup_attempt/evt_minister_died/evt_election → WorldState.stability | 368 L (سياسي: ~80 L) |

بيانات:

| المصدر | الاستخدام في الـdiscovery |
|---|---|
| `data/rules/institutional_rules.json` (production) | القواعد المؤسسية production الحقيقية |
| `data/worlds/politics/batch_a_base.json` (production minimal world) | عالم سياسي production فعلي |
| `data/scenarios/t040/t040_{a10,a,b,c,d}/worlds/politics/world.json` | أعلى scale متاح (200 دولة، عُقد سياسية) |
| `data/scenarios/t040/t040_*/rules/institutional_rules.json` | wiring بالـfixture (بما فيه divergences الموثقة) |
| `.ai/evidence/tests/t040_scenario_*_ticklog.txt` | event traces حقيقية (PF-4 workload evidence) |

**ملاحظة نطاق (frozen):** الـpolitical runtime الحالي هو "Batch-A v0" (TASK-039/040) — 
نظام مؤسسي بسيط، لا سياسة أحزاب داخلية/فصائل/تحالفات متعددة. الـdiscovery يقيس **ما هو موجود فعلًا في الكود
الآن**، لا ما هو مخطط. أي نتيجة "small topology" لا تعني أن السياسة ستظل صغيرة عند اكتمال الدومين —
تعني أن **الدومين الحالي قابل للقياس بالكامل** وهناك room معماري واضح للنمو.

---

## 1) تعريف العقدة (frozen)

**عقدة propagation = كيان سياسي يحمل state قابلًا للتغير أثناء التشغيل ويُقرأ في semantics فعلية.**

مستبعدون بالتعريف (مع التعليل):

| مستبعد | السبب |
|---|---|
| Characters | identity-only بعد load (`{"character_id"}`) — لا state يُقرأ. طرفية إشاريًا فقط. |
| ElectionHistory/Results/Disputes/Succession/Regime | append-only records — تاريخ، لا state يُعاد تقييمه |
| Deadlines (سجلات) | lifecycle records تُدار بالجدولة، لا بالـpropagation |
| Bills | في v0: status record يُدار بالقرار الصريح (vote)، لا re-derivable |
| `event_log` / counters (`_seq`, `deadline_stats`) | bookkeeping |

عقد في الـgraph (بعد الاستبعاد): **Office, Party, Legislature, Government** — وstate قابل للتغير:
`offices[x].holder/.status` · `parties[x].leader/.electoral_strength/.seats[leg]` ·
`legislatures[x].seats/.procedural_state.dissolved` · `governments[x].status/.head/.officeholders[]` ·
`government_support[party]→gov` (edge-state وليس عقدة — انظر §2).

**اكتشاف موثق يجب أن يظهر في التقرير:** `_hold_election` يعدّ `state.parties.keys()` ككل —
يعني عقدة الحزب في الدولة X عقدة زمالة نظريًا لأي انتخابات في الدولة Y (winner global sort + quota
largest-remainder على مجموع أحزاب العالم كله). هذا **إما coupling حقيقي بالكود الحالي** وإما
قصور دقة wiring يتعين على المالك تفسيره — الـdiscovery يوثقه بالأرقام (impact per-election)، لا يفسره.

---

## §2) تعريف الحافة (frozen — semantic, not structural)

**حافة A→B مقبولة iff: production code path فعلي يقرأ state الـA أثناء تقييم أو تطبيق state الـB.**

### جرد الحواف (audit-complete — كل قراءة state في political_actions.gd + institutional_rules.gd):

| # | Edge | القارئ (production path) | Provenance | Direction |
|---|---|---|---|---|
| E1 | office(auth) → office(target).can_appoint | `can_appoint` → `holder_of(auth)` (institutional_rules.gd:61-71) | **static-rule** (appointing_authority من rules JSON) | office→office |
| E2 | office(d) → office(target).can_dismiss | `can_dismiss` → `dismissible_by[]` (institutional_rules.gd:75-83) | **static-rule** | office→office |
| E3 | party.seats[leg] → leg.seat_share → gov.FormGovernment threshold / bill propose / vote tallies | `seat_share`/`seats_total` (political_state.gd:87-95) + `_form_government`/`_propose_bill`/`_tally_aye_share` | **dynamic-state** | party→legislature (بعدد المقاعد)، leg→gov (الكواتا والتشكيل) |
| E4 | gov.status → party.SupportGovernment/WithdrawSupport eligibility | `_support_government` (gstatus != active/forming ⇒ reject) | **dynamic-state** | gov→party(عمل) |
| E5 | party.government_support → gov (علاقة الدعم الوحيدة) | `apply_support`/`apply_withdraw_support`/`supporting_parties()` | **dynamic-state** (edge-state: sparse map) | party→gov |
| E6 | office(head).holder → party.leader → Succession/Election chain | `_hold_election` `changes_head` path: `holder_of(head_office)` + `party_of_leader(out_holder)` + `parties[winner].leader` | **dynamic-state + static-rule** (election_rules) | office→party→office |
| E7 | party.electoral_strength → election tally/winner/seats | `_hold_election` (political_actions.gd:364-393) | **dynamic-state** | party→legislature (كواتا) + party→office (winner→head) |
| E8 | leg.rules.government_term_days / causes_election → deadline → election | `schedule_term` → `pump` → `_activate` (political_deadlines.gd) | **static-rule** (جدولة زمنية، ليست state-propagation داخل tick) | leg→(time)→leg |
| E9 | gov.head → ResignGovernment eligibility | `_resign_government` (gov.head == actor) | **dynamic-state** | gov→gov(self eligibility) |
| E10 | bill.status → VoteBill eligibility (`bill_not_open`) | `_vote_bill` | **dynamic-state** | bill→leg action path (مستبعدة كعقدة، مسجلة كـread-path) |

**حواف خارج PoliticalState (cross-domain boundary — تُوثق ولا تدخل في political graph):**
- `evt_coup_attempt`/`evt_minister_died`/`evt_election` تكتب `WorldState.countries[cid].stability` —
  السياسة ← الاستراتيجي (سياسي→country state)؛ الاتجاه المعاكس **غير موجود في الكود** (لا handler يقرأ PoliticalState).
- **اكتشاف:** في TASK-040 fixtures، أحداث Coup/Minister_Died/Election كلها تُدفع من مصدر خارجي على country id،
  ولا تمر عبر PoliticalState إطلاقًا — أي "political event" في الـfixture الحالي ليس عقدة سياسية. (توصيف، لا حكم.)

### static vs dynamic (frozen):
- **static-rule edge:** علاقة مقررة من rules JSON لا تتغير أثناء التشغيل (E1/E2/E8 wiring).
- **dynamic-state edge:** طرفها يعتمد على state قابلة للتغير (holder/support/seats/strength).
- التصنيف يُحسب آليًا لكل edge من الجرد أعلاه — لا اجتهاد.

---

## 3) تعريف الـclosure (frozen — لسؤال PF-2/PF-3)

الـaffected closure لعملية ما = كل العقد التي **يتغير قيم قراءتها المحفوظة** نتيجة العملية، عبر المسارات
الدلالية أعلاه، transitively. عمليًا (read-only):

- بعد كل production path (HoldElection على دولة، FormGovernment، Support/Withdraw، Dismiss، …):
  نحسب diff على مستوى العقد (office holder تغير؟ party seats تغيرت؟ gov status؟) ونستخرج منها
  الـaffected set الدلالي عبر الحواف المجمّدة.
- **شرط الحتمية:** نفس التشغيلة مرتين ⇒ نفس الـclosure set bitwise.
- **لا "قد يكون قد تغير" البنيوي:** النمط البنيوي لـPROBE-P1 (dirty = كل المنحدرين) يُحسب أيضًا
  كمرجع مقارنة (structural closure) لكن الرقم الحاكم لسؤال المالك هو **semantic closure**
  (ما تغيرت قراءته فعلًا). الاثنان يُعرضان معًا.

---

## 4) Metrics المطلوبة (frozen — قائمة المالك + إضافات مراجعة التصميم)

لكل world (production minimal + 5 fixtures) وعلى المجموع:

- Political Nodes (by type + total، قبل وبعد استبعاد §1)
- Political edges (by edge type E1-E10 + total، semantic فقط)
- Static-rule vs dynamic-state edges (نسبة)
- Average out-degree / P50 / P95 / Max out-degree (semantic)
- Average in-degree / Max in-degree (fan-in)
- Max causal depth (أطول مسار دلالي حتمي متصل، بالحواف المجمّدة)
- Connected components (عدد + أكبر حجم + متوسط) — **والسؤال الحاسم: هل يوجد أي component يعبر حدود دولة؟**
- Cross-country edges count + list (متوقع 0 عدا E7 global-parties anomaly)
- **Closures (semantic):** لكل production path من: HoldElection (واحدة)، FormGovernment،
  Dismiss، WithdrawSupport، succession chain — median / P95 / max / mean affected nodes
- **Closures (structural — مرجع PROBE-P1 semantics):** نفس العمليات بالمنطق البنيوي (كل المنحدرين)
- Hub audit: أي عقدة in-degree ≥ 20 (تعريف الـhub في PROBE-P1 كان 5% fan-out؛ هنا نسجل top-10 in/out-degree مع القيم)
- Per-country subgraph: nodes/edges متوسط وأقصى (يقيس "هل الدومين شظايا معزولة")
- Anomaly E7 quantified: حجم تأثير انتخابات دولة واحدة على أحزاب/مقاعد العالم كله (عدد الأحزاب الأجنبية التي يمر بها الفرز)
- Node-state audit: عدد العقد ذات state فعلية قابلة للتغير vs identity-only (characters)

### Workload evidence (PF-4 pre-work — قراءة فقط):
- من ticklogs TASK-040: توزيع daily political state changes الفعلي (A: 30 governed يوم ذروة،
  C: 120، D: 45+15 crisis) — يُستخرج كـchange-count distribution، لا workload اختراعي.

---

## 5) المخرجات (frozen)

- `spikes/political-topology-discovery/REPORT.md` — كل الحقول أعلاه + جداول لكل world + anomaly توثيق + قراءة أولية (بلا توصيات معمارية)
- `spikes/political-topology-discovery/results/*.json` — raw: graph edge list لكل world، metrics، closure computations، workload counts
- `spikes/political-topology-discovery/extract_topology.py` — الأداة (read-only على production data)
- `spikes/political-topology-discovery/logs/*.log` — تشغيلات

**لا يوجد:** verdict معماري، توصية adoption، أرقام أداء تنفيذية (الموضوع discovery لا benchmark)،
ولا أي ملف خارج `spikes/political-topology-discovery/`.

---

## 6) ما الذي لا يقرره هذا الـdiscovery (frozen)

- لا يقرر كتابة PF-PROBE spec (سؤال المالك بعد قراءة التقرير).
- لا يقرر صلاحية E7 كـcoupling (توثيق فقط — تفسيره قرار تصميم للمالك).
- لا يقيس أداء (لا benchmark) — الـdiscovery يصف فقط.
- نتائجه لا تدخل acceptance chain ولا تعديل production.
- "السياسة sparse" كنتيجة **لا تعني** أن C2 سيكون بلا قيمة إذا اتسع الدومين لاحقًا (§0 نطاق).
