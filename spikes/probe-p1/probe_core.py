"""PROBE-P1 — probe_core.py — isolated benchmark core (DESIGN.md v1.1, commit 37170714).

No production imports. Pure stdlib. Single-threaded. Deterministic by construction.
One subprocess = one (scenario-instance, candidate, pass) run; prints one JSON result.
Usage: python probe_core.py <spec-json-path>   (or '-' for stdin)

Implementation notes (pre-registered in DESIGN v1.1):
- C1/C2 collect the dirty set WITHOUT an O(N) membership scan per change:
  C1 appends during the edge sweep, C2 appends during BFS; both then sort the
  closure ascending (the only ordering that matches C0's semantics bitwise).
- Effects: every candidate pays the SAME per-recomputation overhead - one float
  compare against the previous derived value (symmetric, documented, negligible
  vs the formula). direct = the changed node itself, propagated = the rest.
- T1/T3/T4 dependency picks are WITHOUT replacement (rng.sample) so the frozen
  "average out-degree 4.0 / 20.0, 20 hub-deps" holds exactly.
"""
import ctypes
import ctypes.wintypes as wt
import hashlib
import json
import math
import os
import random
import sys
import time

SEED_BASE = 90210


def clamp01(x):
    return 0.0 if x < 0.0 else (1.0 if x > 1.0 else x)


class World:
    __slots__ = ("n", "e", "ind", "dep_off", "dep_idx", "dep_w", "k",
                 "edge_src", "edge_dst")

    def __init__(self, n):
        self.n = n
        self.e = 0
        self.ind = [0.0] * n
        self.dep_off = [0] * (n + 1)
        self.dep_idx = []
        self.dep_w = []
        self.k = [0] * n
        self.edge_src = []
        self.edge_dst = []


def _draw_k(topo, i):
    """Deterministic per-node dep-count within the frozen ranges (no rng)."""
    if topo == "T1":
        return 2 + (i * 7) % 5          # 2..6, avg 4.0
    if topo == "T4":
        return 10 + (i * 13) % 21      # 10..30, avg 20.0
    return 0


def build_world(topo, n, seed):
    """Frozen rng order: state-init -> topology -> weights (DESIGN §6)."""
    rng = random.Random(seed)
    w = World(n)
    for i in range(n):
        w.ind[i] = rng.random()

    deps = [None] * n
    if topo == "T1":
        for i in range(n):
            k = 0 if i == 0 else min(_draw_k(topo, i), i)
            deps[i] = rng.sample(range(i), k) if k else []
    elif topo == "T2":
        for i in range(n):
            deps[i] = [] if i % 1000 == 0 else [i - 1]
    elif topo == "T3":
        h = max(20, n // 100)          # ensure sample(20) always valid
        for i in range(n):
            deps[i] = [] if i < h else None
        for i in range(h, n):
            sel = rng.sample(range(h), 20)              # exactly 20 distinct hubs
            others = rng.sample(range(h, i), min(1, i - h))
            deps[i] = sel + others
    elif topo == "T4":
        for i in range(n):
            k = 0 if i == 0 else min(_draw_k(topo, i), i)
            deps[i] = rng.sample(range(i), k) if k else []
    elif topo == "T5":
        hub_top = max(1, int(n * 0.05))
        med_top = hub_top + max(1, int(n * 0.15))
        for i in range(n):
            if i == 0:
                deps[i] = []
                continue
            if i >= med_top:            # 80% sparse
                k = min(2 + (i * 7) % 5, i)
                sel = []
                for _ in range(k):
                    if rng.random() < 0.30:
                        sel.append(rng.randrange(hub_top))
                    else:
                        sel.append(rng.randrange(i))
            elif i >= hub_top:          # 15% medium: half window +/-64, 30% hubs
                k = min(8 + (i * 11) % 9, i)
                sel = []
                half = k // 2
                lo = max(0, i - 64)
                for _ in range(half):
                    sel.append(rng.randrange(lo, i))
                for _ in range(k - half):
                    if rng.random() < 0.30:
                        sel.append(rng.randrange(hub_top))
                    else:
                        sel.append(rng.randrange(i))
            else:                       # 5% hub-role
                k = min(4, i)
                sel = [rng.randrange(i) for _ in range(k)]
            deps[i] = sorted(set(sel))
    else:
        raise ValueError("unknown topology " + topo)

    for i in range(n):
        deps[i] = sorted(set(deps[i]))
    w.k = [len(deps[i]) for i in range(n)]

    edges = []
    for i in range(n):
        for j in deps[i]:
            edges.append((j, i))
    edges.sort()                        # (src, dst) ascending = topological
    w.edge_src = [a for a, _ in edges]
    w.edge_dst = [b for _, b in edges]
    w.e = len(edges)

    w.dep_idx = []
    w.dep_w = []
    for i in range(n):
        w.dep_off[i] = len(w.dep_idx)
        for j in deps[i]:
            w.dep_idx.append(j)
            w.dep_w.append(0.1 + 0.8 * rng.random())     # weights last
    w.dep_off[n] = len(w.dep_idx)
    return w


def build_reverse_csr(w):
    rev_off = [0] * (w.n + 1)
    for s in w.edge_src:
        rev_off[s + 1] += 1
    for i in range(1, w.n + 1):
        rev_off[i] += rev_off[i - 1]
    pos = rev_off[:]
    rev_idx = [0] * w.e
    for t in range(w.e):
        s, d = w.edge_src[t], w.edge_dst[t]
        p = pos[s]
        rev_idx[p] = d
        pos[s] = p + 1
    return rev_off, rev_idx


def eval_node(st, der, w, i):
    off0, off1 = w.dep_off[i], w.dep_off[i + 1]
    if off1 <= off0:
        return clamp01(st[i])
    acc = 0.0
    for t in range(off0, off1):
        acc += w.dep_w[t] * der[w.dep_idx[t]]
    return clamp01(0.5 * st[i] + 0.5 * (acc / float(off1 - off0)))


def initial_eval(st, der, w):
    for i in range(w.n):
        der[i] = eval_node(st, der, w, i)


def apply_change(st, i, sign):
    st[i] = clamp01(st[i] + 0.30 * sign)


def state_hash(st, der, n):
    parts = []
    for i in range(n):
        parts.append("%d|%.17g|%.17g\n" % (i, st[i], der[i]))
    return hashlib.sha256("".join(parts).encode("ascii")).hexdigest()


def graph_hash(w):
    h = hashlib.sha256()
    h.update(("%d|%d|" % (w.n, w.e)).encode("ascii"))
    h.update(",".join(str(x) for x in w.edge_src).encode("ascii"))
    h.update(",".join(str(x) for x in w.edge_dst).encode("ascii"))
    h.update("".join(x.hex() for x in w.dep_w).encode("ascii"))
    return h.hexdigest()


# ---------------------------------------------------------------- candidates
def run_candidate0(st, der, w, changes, timers, m):
    """Full recompute. Ascending id sweep; per-node compare for effect counts
    (symmetric overhead across candidates - see module docstring)."""
    n = w.n
    for (i, sign) in changes:
        t0 = time.perf_counter_ns()
        apply_change(st, i, sign)
        for j in range(n):
            new = eval_node(st, der, w, j)
            if new != der[j]:
                if j == i:
                    m["effects_direct"] += 1
                else:
                    m["effects_propagated"] += 1
            der[j] = new
        t1 = time.perf_counter_ns()
        timers.append(t1 - t0)
        m["nodes_evaluated"] += n
        m["dependencies_traversed"] += w.e
        m["propagation_visits"] += n
        m["recomputations"] += n
        m["skipped_nodes"] += 0
        m["closure_union"].add(i)
        m["closure_union"].update(range(n))


def run_candidate1(st, der, w, changes, timers, m):
    """Affected-set: one flat edge-array sweep per change, closure collected
    during the sweep (no O(N) scan), sorted ascending, re-evaluated only."""
    n = w.n
    e_src, e_dst = w.edge_src, w.edge_dst
    dirty_flag = [-1] * n
    gen = 0
    for (i, sign) in changes:
        t0 = time.perf_counter_ns()
        apply_change(st, i, sign)
        gen += 1
        dirty_flag[i] = gen
        closure = [i]
        for src, dst in zip(e_src, e_dst):
            if dirty_flag[src] == gen:
                if dirty_flag[dst] != gen:
                    dirty_flag[dst] = gen
                    closure.append(dst)
        closure.sort()
        for j in closure:
            new = eval_node(st, der, w, j)
            if new != der[j]:
                if j == i:
                    m["effects_direct"] += 1
                else:
                    m["effects_propagated"] += 1
            der[j] = new
        t1 = time.perf_counter_ns()
        timers.append(t1 - t0)
        m["nodes_evaluated"] += len(closure)
        m["dependencies_traversed"] += w.e
        m["propagation_visits"] += len(closure)
        m["recomputations"] += len(closure)
        m["skipped_nodes"] += n - len(closure)
        m["closure_union"].update(closure)
        m["closure_sizes"].append(len(closure))


def run_candidate2(st, der, w, changes, timers, m, rev_off, rev_idx):
    """Indexed: reverse-CSR BFS closure, collected during traversal (each node
    appended exactly once at mark time - no O(N) scan), sorted ascending,
    re-evaluated only."""
    n = w.n
    dirty_flag = [-1] * n
    gen = 0
    for (i, sign) in changes:
        t0 = time.perf_counter_ns()
        apply_change(st, i, sign)
        gen += 1
        dirty_flag[i] = gen
        stack = [i]
        closure = [i]
        bfs_edges = 0
        while stack:
            cur = stack.pop()
            for p in range(rev_off[cur], rev_off[cur + 1]):
                bfs_edges += 1
                d = rev_idx[p]
                if dirty_flag[d] != gen:
                    dirty_flag[d] = gen
                    stack.append(d)
                    closure.append(d)
        closure.sort()
        for j in closure:
            new = eval_node(st, der, w, j)
            if new != der[j]:
                if j == i:
                    m["effects_direct"] += 1
                else:
                    m["effects_propagated"] += 1
            der[j] = new
        t1 = time.perf_counter_ns()
        timers.append(t1 - t0)
        m["nodes_evaluated"] += len(closure)
        m["dependencies_traversed"] += bfs_edges
        m["propagation_visits"] += len(closure)
        m["recomputations"] += len(closure)
        m["skipped_nodes"] += n - len(closure)
        m["closure_union"].update(closure)
        m["closure_sizes"].append(len(closure))


def _marked_list(dirty_flag, gen, n):
    """O(N) membership scan — used ONLY in C2's discovery-list rebuild (kept out
    of the timed region? No: it IS timed. See note below.)"""
    return [j for j in range(n) if dirty_flag[j] == gen]


def run_candidate0_batch(st, der, w, changes, timers, m):
    n = w.n
    t0 = time.perf_counter_ns()
    for (i, sign) in changes:
        apply_change(st, i, sign)
    for j in range(n):
        new = eval_node(st, der, w, j)
        if new != der[j]:
            m["effects_propagated"] += 1
        der[j] = new
    t1 = time.perf_counter_ns()
    timers.append(t1 - t0)
    m["nodes_evaluated"] += n
    m["dependencies_traversed"] += w.e
    m["recomputations"] += n
    m["closure_union"].update(range(n))


def run_candidate1_batch(st, der, w, changes, timers, m):
    n = w.n
    t0 = time.perf_counter_ns()
    for (i, sign) in changes:
        apply_change(st, i, sign)
    dirty = [False] * n
    closure = []
    for (i, _s) in changes:
        if not dirty[i]:
            dirty[i] = True
            closure.append(i)
    for src, dst in zip(w.edge_src, w.edge_dst):
        if dirty[src] and not dirty[dst]:
            dirty[dst] = True
            closure.append(dst)
    closure.sort()
    for j in closure:
        new = eval_node(st, der, w, j)
        if new != der[j]:
            m["effects_propagated"] += 1
        der[j] = new
    t1 = time.perf_counter_ns()
    timers.append(t1 - t0)
    m["nodes_evaluated"] += len(closure)
    m["dependencies_traversed"] += w.e
    m["recomputations"] += len(closure)
    m["closure_union"].update(closure)


def run_candidate2_batch(st, der, w, changes, timers, m, rev_off, rev_idx):
    n = w.n
    t0 = time.perf_counter_ns()
    for (i, sign) in changes:
        apply_change(st, i, sign)
    dirty = [False] * n
    stack = []
    closure = []
    for (i, _s) in changes:
        if not dirty[i]:
            dirty[i] = True
            stack.append(i)
            closure.append(i)
    while stack:
        cur = stack.pop()
        for p in range(rev_off[cur], rev_off[cur + 1]):
            d = rev_idx[p]
            if not dirty[d]:
                dirty[d] = True
                stack.append(d)
                closure.append(d)
    closure.sort()
    for j in closure:
        new = eval_node(st, der, w, j)
        if new != der[j]:
            m["effects_propagated"] += 1
        der[j] = new
    t1 = time.perf_counter_ns()
    timers.append(t1 - t0)
    m["nodes_evaluated"] += len(closure)
    m["recomputations"] += len(closure)
    m["closure_union"].update(closure)


# ---------------------------------------------------------------- memory
_PMC_FIELDS = None
_K32 = None


def _init_mem_api():
    """K32GetProcessMemoryInfo via kernel32 with full PROCESS_MEMORY_COUNTERS_EX
    (psapi.GetProcessMemoryInfo silently fails with ERROR_INSUFFICIENT_BUFFER 122
    when fed a short struct on modern Windows)."""
    global _PMC_FIELDS, _K32
    if _K32 is not None:
        return _K32 is not False

    class PMC(ctypes.Structure):
        _fields_ = [("cb", wt.DWORD), ("PageFaultCount", wt.DWORD),
                    ("PeakWorkingSetSize", ctypes.c_size_t),
                    ("WorkingSetSize", ctypes.c_size_t),
                    ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
                    ("QuotaPagedPoolUsage", ctypes.c_size_t),
                    ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
                    ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
                    ("PagefileUsage", ctypes.c_size_t),
                    ("PeakPagefileUsage", ctypes.c_size_t),
                    ("PrivateUsage", ctypes.c_size_t)]

    _PMC_FIELDS = PMC
    try:
        k32 = ctypes.WinDLL("kernel32", use_last_error=True)
        k32.K32GetProcessMemoryInfo.argtypes = [wt.HANDLE, ctypes.POINTER(PMC), wt.DWORD]
        k32.K32GetProcessMemoryInfo.restype = wt.BOOL
        _K32 = k32
        return True
    except Exception:
        _K32 = False
        return False


def peak_working_set_bytes():
    if not _init_mem_api():
        return -1
    pmc = _PMC_FIELDS()
    pmc.cb = ctypes.sizeof(_PMC_FIELDS)
    if not _K32.K32GetProcessMemoryInfo(_K32.GetCurrentProcess(), ctypes.byref(pmc), pmc.cb):
        return -1
    return int(pmc.PeakWorkingSetSize)


def deep_size(x, seen=None):
    if seen is None:
        seen = set()
    if id(x) in seen:
        return 0
    seen.add(id(x))
    total = sys.getsizeof(x)
    if isinstance(x, dict):
        for k, v in x.items():
            total += deep_size(k, seen) + deep_size(v, seen)
    elif isinstance(x, (list, tuple, set)):
        for v in x:
            total += deep_size(v, seen)
    return total


def percentile(sorted_vals, p):
    if not sorted_vals:
        return 0
    idx = int(math.ceil(p / 100.0 * len(sorted_vals))) - 1
    return sorted_vals[max(0, min(idx, len(sorted_vals) - 1))]


# ---------------------------------------------------------------- driver
def run(spec):
    topo = spec["topo"]
    n = spec["n"]
    seed = SEED_BASE + 1000 * spec["order"]
    rng = random.Random(seed)
    t_b0 = time.perf_counter_ns()
    w = build_world(topo, n, seed)
    t_b1 = time.perf_counter_ns()

    st = w.ind[:]
    der = [0.0] * n
    der0 = None

    t_i0 = time.perf_counter_ns()
    initial_eval(st, der, w)
    t_i1 = time.perf_counter_ns()
    der0 = der[:]      # initial snapshot for final effect count (untimed)
    h_init = state_hash(st, der, n)
    h_graph = graph_hash(w)

    cand = spec["candidate"]
    cadence = spec.get("cadence", "per_change")
    tm = bool(spec.get("tm"))
    if tm:
        import tracemalloc
        tracemalloc.start()

    rev_off = rev_idx = None
    t_p0 = t_p1 = 0
    if cand == 2:
        t_p0 = time.perf_counter_ns()
        rev_off, rev_idx = build_reverse_csr(w)
        t_p1 = time.perf_counter_ns()

    # structure-size estimates BEFORE execution (so peak WS reflects the run only)
    mem = {
        "peak_ws_bytes": 0,
        "dep_storage_est_bytes": deep_size(w.dep_idx) + deep_size(w.dep_w) + deep_size(w.dep_off),
        "edge_array_est_bytes": deep_size(w.edge_src) + deep_size(w.edge_dst),
        "reverse_index_est_bytes": (deep_size(rev_off) + deep_size(rev_idx)) if rev_idx is not None else 0,
        "states_est_bytes": deep_size(st) + deep_size(der) + deep_size(w.ind),
    }

    changes = []
    for a in spec.get("anchors", []):
        changes.append((a, +1.0))
    need = spec.get("change_count", 0) - len(changes)
    if need > 0:
        lo = spec.get("uniform_lo", 0)
        hi = spec.get("uniform_hi", n)
        picks = [rng.randrange(lo, hi) for _ in range(need)] if hi > lo else []
        changes.extend((p, +1.0 if (t % 2 == 0) else -1.0) for t, p in enumerate(picks))

    # warm-up (DESIGN §5): scratch world, excluded from metrics/timing tables
    warm = build_world("T1", 256, seed + 777)
    wst = warm.ind[:]
    wder = [0.0] * 256
    initial_eval(wst, wder, warm)
    run_candidate0(wst, wder, warm, [(i % 256, +1.0) for i in range(8)], [], _m())

    m = _m()
    timers = []

    if cadence == "per_change":
        if cand == 0:
            run_candidate0(st, der, w, changes, timers, m)
        elif cand == 1:
            run_candidate1(st, der, w, changes, timers, m)
        else:
            run_candidate2(st, der, w, changes, timers, m, rev_off, rev_idx)
    else:
        if cand == 0:
            run_candidate0_batch(st, der, w, changes, timers, m)
        elif cand == 1:
            run_candidate1_batch(st, der, w, changes, timers, m)
        else:
            run_candidate2_batch(st, der, w, changes, timers, m, rev_off, rev_idx)

    h_final = state_hash(st, der, n)
    for h in (h_init, h_graph, h_final):
        if len(h) != 64 or any(c not in "0123456789abcdef" for c in h):
            print(json.dumps({"error": "HASH_FORMAT", "hash": h}))
            sys.exit(2)

    final_effects = 0
    for j in range(n):
        if der[j] != der0[j]:
            final_effects += 1

    ts = sorted(t / 1e6 for t in timers)
    total_ms = sum(ts)
    mem["peak_ws_bytes"] = peak_working_set_bytes()
    if tm:
        mem["tracemalloc_peak_bytes"] = tracemalloc.get_traced_memory()[1]
        tracemalloc.stop()
    cs = m["closure_sizes"]
    return {
        "spec": spec, "seed": seed,
        "n": n, "e": w.e, "topo": topo, "candidate": cand, "cadence": cadence,
        "changes": len(changes),
        "graph_build_ms": (t_b1 - t_b0) / 1e6,
        "initial_eval_ms": (t_i1 - t_i0) / 1e6,
        "prep_ms": (t_p1 - t_p0) / 1e6 if cand == 2 else 0.0,
        "propagation_total_ms": total_ms,
        "propagation_mean_ms": total_ms / len(ts) if ts else 0.0,
        "propagation_p50_ms": percentile(ts, 50),
        "propagation_p95_ms": percentile(ts, 95),
        "propagation_peak_ms": ts[-1] if ts else 0.0,
        "first20_ms": ts[:20],
        "nodes_evaluated": m["nodes_evaluated"],
        "dependencies_traversed": m["dependencies_traversed"],
        "propagation_visits": m["propagation_visits"],
        "recomputations": m["recomputations"],
        "skipped_nodes": m["skipped_nodes"],
        "effects_direct": m["effects_direct"],
        "effects_propagated": m["effects_propagated"],
        "final_effect_count": final_effects,
        "affected_union_size": len(m["closure_union"]),
        "closure_per_change_max": max(cs) if cs else 0,
        "closure_per_change_mean": (sum(cs) / len(cs)) if cs else 0,
        "hash_initial": h_init, "hash_graph": h_graph, "hash_final": h_final,
        "memory": mem,
        "env": {"python": sys.version.split()[0], "os": os.name,
                "cpu": os.environ.get("PROCESSOR_IDENTIFIER", "?")},
    }


def _m():
    return {"nodes_evaluated": 0, "dependencies_traversed": 0, "propagation_visits": 0,
            "recomputations": 0, "skipped_nodes": 0, "effects_direct": 0,
            "effects_propagated": 0, "closure_union": set(), "closure_sizes": []}


if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else "-"
    raw = sys.stdin.read() if arg == "-" else arg
    print(json.dumps(run(json.loads(raw))))
