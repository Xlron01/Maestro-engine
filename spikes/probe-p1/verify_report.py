#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Owner-directed evidence verification: cross-check REPORT.md numbers against raw JSONs.

Run AFTER results exist. Prints PASS/FAIL per claim. Read-only with respect to results/.
"""
import json, glob, os, collections, sys

base = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'results')

def load(p):
    with open(p, encoding='utf-8') as f:
        return json.load(f)

def jget(d, *names, default=None):
    for n in names:
        if n in d:
            return d[n]
    return default

fails = []

def check(label, ok, detail=''):
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  [{detail}]" if detail else ''))
    if not ok:
        fails.append(label)

def total_ms(d):
    return jget(d, 'propagation_total_ms', 'total_ms', default=0.0)

def closure(d):
    return jget(d, 'affected_union_size', 'closure_union', default=0)

# ---------- COR-3: pass1 == pass2 for every run ----------
pairs = collections.defaultdict(dict)
for run in ('_p1', '_p2'):
    for p in sorted(glob.glob(os.path.join(base, run, '*.json'))):
        d = load(p)
        pairs[os.path.basename(p)][run] = jget(d, 'hash_final', 'hash')
bad = [k for k, v in pairs.items() if len(v) == 2 and len(set(v.values())) != 1]
check('COR-3 pass1==pass2 (all runs)', not bad, f'{len(pairs)} runs, mismatches={bad[:3]}')

# ---------- COR-1/2: candidate agreement within each scenario/pass ----------
groups = collections.defaultdict(dict)
for run in ('_p1', '_p2'):
    for p in sorted(glob.glob(os.path.join(base, run, '*.json'))):
        d = load(p)
        parts = os.path.basename(p)[:-5].split('_')
        scen = '_'.join([parts[0], parts[1], parts[2], parts[4], parts[5]])
        groups[(run, scen)][parts[3]] = jget(d, 'hash_final', 'hash')
cand_bad = [(s, c) for s, c in groups.items() if len(c) > 1 and len(set(c.values())) != 1]
check('COR-1/2 hash agreement c0==c1==c2 per scenario', not cand_bad, f'{len(groups)} scenario-passes, mismatches={cand_bad[:2]}')

# ---------- COR-4: effect counts identical across candidates ----------
eff_bad = []
for run in ('_p1', '_p2'):
    for scen_key in {s[1] for s in groups}:
        cand_eff = {}
        pt = scen_key.split('_')
        for c in ('c0', 'c1', 'c2'):
            name = f"{pt[0]}_{pt[1]}_n{pt[2].split('n')[-1]}_{c}_{pt[3]}_{pt[4]}.json"
            p = os.path.join(base, run, name)
            if os.path.exists(p):
                d = load(p)
                cand_eff[c] = (jget(d, 'effects_direct', default=0),
                               jget(d, 'effects_propagated', default=0),
                               jget(d, 'final_effect_count', default=0))
        if len(cand_eff) > 1 and len(set(cand_eff.values())) != 1:
            eff_bad.append((run, scen_key, cand_eff))
check('COR-4 effect counts identical across candidates', not eff_bad, str(eff_bad[:2]))

# ---------- Scenario spot checks vs REPORT.md ----------
def run_json(scen, topo, n, cand, cc, cadence='per_change', run='_p1'):
    name = f"{scen}_{topo}_n{n}_{cand}_cc{cc}_{cadence}.json"
    p = os.path.join(base, run, name)
    return load(p) if os.path.exists(p) else None

# S2: c0=33.7 / c1=9.3 / c2~0.006 (report shows 0.0 at 1 decimal), closure=1
s2 = {c: run_json('S2', 'T1', 40000, c, 1) for c in ('c0', 'c1', 'c2')}
t = {c: total_ms(s2[c]) for c in s2}
check('S2 totals ~33.7/9.3/<0.06ms',
      abs(t['c0'] - 33.7) < 3 and abs(t['c1'] - 9.3) < 2 and t['c2'] < 0.06,
      f"c0={t['c0']:.2f} c1={t['c1']:.2f} c2={t['c2']:.4f}")
check('S2 closure(c1)=closure(c2)=1', closure(s2['c1']) == 1 and closure(s2['c2']) == 1,
      f"c1={closure(s2['c1'])} c2={closure(s2['c2'])}")

# S9 locality ratios: c1 ~256.8x, c2 ~1.35x (100K vs 1K)
s9 = {}
for n in (1000, 10000, 100000):
    s9[n] = {c: run_json('S9', 'T1', n, c, 1) for c in ('c0', 'c1', 'c2')}
r_c1 = total_ms(s9[100000]['c1']) / total_ms(s9[1000]['c1'])
check('S9 c1 ratio 100K/1K ~256.8x (>3 => C1 fails PERF-4)', 200 < r_c1 < 320, f'{r_c1:.1f}x')
if total_ms(s9[1000]['c2']) > 0:
    r_c2 = total_ms(s9[100000]['c2']) / total_ms(s9[1000]['c2'])
    check('S9 c2 ratio 100K/1K ~1.35x (<=3 => PASS)', 0.5 < r_c2 < 3, f'{r_c2:.2f}x')
else:
    r_c2 = total_ms(s9[100000]['c2']) / total_ms(s9[10000]['c2'])
    check('S9 c2: 100K vs 10K fallback (c2@1K under timer floor)', 0.3 < r_c2 < 3, f'{r_c2:.2f}x via 10K')
for n in (1000, 10000, 40000, 100000):
    d = run_json('S9', 'T1', n, 'c1', 1)
    if d:
        check(f'S9 n={n} closure=1', closure(d) == 1, f'got {closure(d)}')

# S4: closure 39722 => 99.3% (PERF-3 precondition not met) + actual c2 speedup ~87.4%
s4c1 = run_json('S4', 'T1', 40000, 'c1', 400)
cl = closure(s4c1)
check('S4 union closure=39722 (~99.3% => PERF-3 precondition not met)', cl == 39722,
      f'closure={cl}, frac={cl/40000:.3f}')
s4c0 = run_json('S4', 'T1', 40000, 'c0', 400)
s4c2 = run_json('S4', 'T1', 40000, 'c2', 400)
sp = 1 - total_ms(s4c2) / total_ms(s4c0)
check('S4 actual c2 speedup ~87.4% (bar: 25%)', abs(sp - 0.874) < 0.02,
      f'speedup={sp:.3f} (c0={total_ms(s4c0):.0f}ms c2={total_ms(s4c2):.0f}ms)')

# S1 idle: zero evaluations
for c in ('c1', 'c2'):
    d = run_json('S1', 'T1', 40000, c, 0)
    ev = jget(d, 'nodes_evaluated', default=0)
    check(f'S1 idle {c} nodes_evaluated=0', ev == 0, f'evaluated={ev}')

# S3/S5/S6 closures
for scen, topo, cc, exp in (('S3', 'T3', 1, 14566), ('S5', 'T4', 400, 39859), ('S6', 'T3', 4, 39604)):
    d = run_json(scen, topo, 40000, 'c1', cc)
    check(f'{scen} closure={exp}', closure(d) == exp, f'got {closure(d)}')

# S8: within 3x baseline
s8 = {c: run_json('S8', 'T5', 40000, c, 8000) for c in ('c0', 'c1', 'c2')}
r1 = total_ms(s8['c1']) / total_ms(s8['c0'])
r2 = total_ms(s8['c2']) / total_ms(s8['c0'])
check('S8 c1/c2 within 3x baseline (reported 0.56x/0.26x)', r1 <= 3 and r2 <= 3, f'c1={r1:.2f}x c2={r2:.2f}x')

# SUPP-B batch crossover at cc=40
sb = lambda cc, c: run_json('SUPP-B', 'T1', 40000, c, cc, 'batch')
r_b1 = total_ms(sb(40, 'c1')) / total_ms(sb(40, 'c0'))
r_b2 = total_ms(sb(40, 'c2')) / total_ms(sb(40, 'c0'))
check('SUPP-B cc=40: both candidates slower than baseline (crossover)',
      r_b1 > 1.2 and r_b2 > 1.2, f'c1/c0={r_b1:.2f} c2/c0={r_b2:.2f}')

# ---------- Memory gates (fixed reader, _mem reruns) ----------
mg = load(os.path.join(base, '_mem', 'gates.json'))
print('\n_mem/gates.json:', json.dumps(mg, indent=1)[:1500])

# peak WS ratio c1/c2 vs c0 for S2 and S9@100K
def mem_run(name):
    p = os.path.join(base, '_mem', name + '.json')
    return load(p) if os.path.exists(p) else None

for scen_prefix in ('S2_n40000', 'S9_n100000'):
    ws = {}
    for c in ('c0', 'c1', 'c2'):
        d = mem_run(f"{scen_prefix}_{c}_{'cc1_per_change'}" if scen_prefix.startswith('S2') else f"{scen_prefix}_{c}_cc1_per_change")
        ws[c] = jget(d.get('memory', {}), 'peak_ws_bytes', default=0) if d else 0
    if ws['c0']:
        check(f'{scen_prefix}: peak WS c1<=1.5x c0, c2<=1.5x c0',
              ws['c1'] <= 1.5 * ws['c0'] and ws['c2'] <= 1.5 * ws['c0'],
              f"c0={ws['c0']/1e6:.1f}MB c1={ws['c1']/1e6:.1f}MB ({ws['c1']/ws['c0']:.2f}x) c2={ws['c2']/1e6:.1f}MB ({ws['c2']/ws['c0']:.2f}x)")

# ---------- Counts ----------
n_p1 = len(glob.glob(os.path.join(base, '_p1', '*.json')))
n_p2 = len(glob.glob(os.path.join(base, '_p2', '*.json')))
n_mem = len(glob.glob(os.path.join(base, '_mem', '*.json')))
print(f'\nruns: _p1={n_p1} _p2={n_p2} _mem={n_mem}')
check('matrix count 78 per pass', n_p1 == n_p2 == 78, f'{n_p1}/{n_p2}')

print('\n' + ('ALL CHECKS PASSED' if not fails else f'{len(fails)} FAILURES: {fails}'))
sys.exit(1 if fails else 0)
