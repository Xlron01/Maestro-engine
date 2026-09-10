"""PROBE-P1 — memory-gate rerun (isolated sample, DESIGN A6 + PERF-7).

Reruns the PERF-5/7-relevant scenario set with the FIXED working-set reader
(K32GetProcessMemoryInfo) plus tracemalloc in separate tagged runs (tm=true).
Only memory conclusions are drawn from this rerun; timing from the main matrix
(untainted by tracemalloc). Sequential subprocesses, same machine/build.
"""
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_mem")
N40 = 40000

CASES = [
    # (sid, topo, n, candidates, cc, anchors, cadence)
    ("S2", "T1", N40, (0, 1, 2), 1, [N40 - 1], "per_change"),
    ("S3", "T3", N40, (0, 1, 2), 1, [0], "per_change"),
    ("S5", "T4", N40, (0, 1, 2), 400, [], "per_change"),
    ("S6", "T3", N40, (0, 1, 2), 4, [0, 1, 2, 3], "per_change"),
    ("S9", "T1", 100000, (0, 1, 2), 1, [99999], "per_change"),
    ("S8", "T5", N40, (0, 1, 2), 8000, [], "per_change"),  # high-density memory bound
]

# scenario order values MUST match the main matrix seeds (DESIGN §6) so the
# measured worlds are identical to the timing runs. From build_matrix order:
ORDERS = {}


def main():
    sys.path.insert(0, HERE)
    from run_benchmark import build_matrix
    for s in build_matrix():
        ORDERS[(s["id"], s["n"], s["change_count"], s["cadence"])] = s["order"]

    os.makedirs(OUT, exist_ok=True)
    rows = []
    for (sid, topo, n, cands, cc, anch, cad) in CASES:
        o = ORDERS[(sid, n, cc, cad)]
        for c in cands:
            for tm in (False, True):
                spec = {"id": sid, "topo": topo, "n": n, "candidate": c,
                        "change_count": cc, "anchors": anch, "order": o,
                        "cadence": cad, "tm": tm, "note": "mem-rerun"}
                tag = "%s_n%d_c%d_cc%d_%s%s.json" % (sid, n, c, cc, cad, "_tm" if tm else "")
                fp = os.path.join(OUT, tag)
                if os.path.exists(fp):
                    continue
                pr = subprocess.run([sys.executable, os.path.join(HERE, "probe_core.py"), "-"],
                                    input=json.dumps(spec), capture_output=True, text=True,
                                    timeout=3600)
                if pr.returncode != 0:
                    print("ERROR", tag, pr.stderr[-300:])
                    continue
                with open(fp, "w", encoding="utf-8") as f:
                    f.write(pr.stdout)
                r = json.loads(pr.stdout)
                rows.append(r)
                print("%-46s peak_ws=%7.1fMB tm_peak=%s" % (
                    tag, r["memory"]["peak_ws_bytes"] / 1048576.0,
                    ("%8.1fMB" % (r["memory"]["tracemalloc_peak_bytes"] / 1048576.0))
                    if "tracemalloc_peak_bytes" in r["memory"] else "-"), flush=True)

    # gate evaluation from rerun data (timing NOT used from tm runs)
    print("\n--- PERF-5 / PERF-7 (from fixed reader) ---")
    by_key = {}
    for fp in os.listdir(OUT):
        r = json.load(open(os.path.join(OUT, fp), encoding="utf-8"))
        s = r["spec"]
        by_key[(s["id"], s["n"], s["candidate"], s["change_count"], s["cadence"], s.get("tm", False))] = r

    ok5 = ok7 = True
    for (sid, n, cc) in (("S3", N40, 1), ("S5", N40, 400), ("S6", N40, 4), ("S8", N40, 8000)):
        b = by_key.get((sid, n, 0, cc, "per_change", False))
        for c in (1, 2):
            r = by_key.get((sid, n, c, cc, "per_change", False))
            if not b or not r:
                continue
            x = r["memory"]["peak_ws_bytes"] / b["memory"]["peak_ws_bytes"]
            print("PERF-5 %s c%d: ws_ratio=%.3f closure=%d" % (sid, c, x, r["affected_union_size"]))
            if x > 2.0:
                ok5 = False
    for (sid, n, cc) in (("S2", N40, 1), ("S9", 100000, 1)):
        b = by_key.get((sid, n, 0, cc, "per_change", False))
        for c in (1, 2):
            r = by_key.get((sid, n, c, cc, "per_change", False))
            if not b or not r:
                continue
            x = r["memory"]["peak_ws_bytes"] / b["memory"]["peak_ws_bytes"]
            print("PERF-7 %s c%d: ws_ratio=%.3f" % (sid, c, x))
            if x > 1.5:
                ok7 = False
    print("PERF-5 pass:", ok5, " PERF-7 pass:", ok7)
    json.dump({"perf5_pass": ok5, "perf7_pass": ok7},
              open(os.path.join(OUT, "gates.json"), "w"))


if __name__ == "__main__":
    main()
