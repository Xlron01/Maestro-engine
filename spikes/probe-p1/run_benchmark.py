"""PROBE-P1 — run_benchmark.py — orchestrator (DESIGN.md v1.1 §4 matrix).

Runs each (scenario-instance, candidate, pass) as an ISOLATED subprocess,
sequentially, on the same machine/build. Raw JSON per run -> results/,
console log -> logs/. No parallelism (§2/§17).

Matrix: S1..S10 locked + SUPP (T1@40K x C3/C5/C6 + conditional C7) + SUPP-B
(batch cadence series for break-even B1) + tracemalloc spot-checks (A6).
Two independent passes (pass1/pass2) => COR-3.
"""
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
RESULTS = os.path.join(HERE, "results")
LOGS = os.path.join(HERE, "logs")
N40 = 40000


def pct(c, n):
    return max(1, int(round(n * c / 100.0)))


def build_matrix():
    specs = []
    state = {"order": 0}

    def add_group(sid, topo, n, cc, anchors, cadence="per_change", candidates=(0, 1, 2)):
        """One order per SCENARIO (same seed for c0/c1/c2 - DESIGN §6);
        order identifies the scenario, never the individual run."""
        state["order"] += 1
        o = state["order"]
        for cand in candidates:
            specs.append({"id": sid, "topo": topo, "n": n, "candidate": cand,
                          "change_count": cc, "anchors": anchors, "order": o,
                          "cadence": cadence, "tm": False, "note": ""})

    # -- locked matrix S1..S8 (N=40K) --
    add_group("S1", "T1", N40, 0, [])
    add_group("S2", "T1", N40, 1, [N40 - 1])
    add_group("S3", "T3", N40, 1, [0])
    add_group("S4", "T1", N40, pct(1, N40), [])
    add_group("S5", "T4", N40, pct(1, N40), [])
    add_group("S6", "T3", N40, 4, [0, 1, 2, 3])
    add_group("S7", "T2", N40, 1, [0])
    add_group("S8", "T5", N40, pct(20, N40), [])

    # S9: local work fixed (closure=1 via node N-1) across N ladder
    for n in (1000, 10000, 40000, 100000):
        add_group("S9", "T1", n, 1, [n - 1])

    # S10: work scaling (1% of N) across ladder
    for n in (1000, 10000, 40000, 100000):
        add_group("S10", "T1", n, pct(1, n), [])

    # -- SUPP: break-even change-density series (T1@40K, per_change cadence) --
    for cc in (pct(0.1, N40), pct(5, N40), pct(20, N40)):
        add_group("SUPP", "T1", N40, cc, [])

    # -- SUPP-B: batch cadence series (B1) — one propagation after ALL changes --
    for cc in (1, 4, 40, 400, pct(5, N40), pct(20, N40), pct(50, N40)):
        add_group("SUPP-B", "T1", N40, cc, [], cadence="batch")

    return specs


def run_all(passes=(1, 2)):
    os.makedirs(os.path.join(RESULTS, "_p1"), exist_ok=True)
    os.makedirs(os.path.join(RESULTS, "_p2"), exist_ok=True)
    os.makedirs(LOGS, exist_ok=True)
    specs = build_matrix()
    summary = []
    t_all0 = time.time()
    for p in passes:
        pdir = os.path.join(RESULTS, "_p%d" % p)
        for s in specs:
            tag = "%s_%s_n%d_c%d_cc%d_%s" % (s["id"], s["topo"], s["n"], s["candidate"],
                                             s["change_count"], s["cadence"])
            out_path = os.path.join(pdir, tag + ".json")
            if os.path.exists(out_path):
                continue
            t0 = time.time()
            pr = subprocess.run([sys.executable, os.path.join(HERE, "probe_core.py"), "-"],
                                input=json.dumps(s), capture_output=True, text=True, timeout=3600)
            dt = time.time() - t0
            if pr.returncode != 0:
                rec = {"spec": s, "error": pr.stderr[-2000:], "returncode": pr.returncode}
                with open(out_path, "w", encoding="utf-8") as f:
                    json.dump(rec, f, indent=1)
                summary.append((p, tag, "ERROR", dt))
                print("[%d] ERROR %s (%.1fs)" % (p, tag, dt), flush=True)
                continue
            with open(out_path, "w", encoding="utf-8") as f:
                f.write(pr.stdout)
            r = json.loads(pr.stdout)
            summary.append((p, tag, "ok", dt))
            print("[%d] %-58s run=%8.1fms  closure=%7d  eff=%6d  %s" % (
                p, tag, r["propagation_total_ms"], r["affected_union_size"],
                r["final_effect_count"], r["hash_final"][:12]), flush=True)
    print("TOTAL %.1f min" % ((time.time() - t_all0) / 60.0))
    return summary


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    if which == "matrix":
        m = build_matrix()
        print(json.dumps(m, indent=1))
        print("count:", len(m))
    else:
        run_all()
