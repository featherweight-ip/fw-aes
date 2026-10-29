#!/usr/bin/env python3
"""B2-4b sweep: bus speed x block count x arch on standalone-stream and aesdma-pipe.

Each point rebuilds the bench image with `dfm run -P` overriding the image
task's defines (FW_AES_NB, FW_AES_BUS_PS), then parses the BENCH line and
TEST PASSED from the run's sim.log. Rows go to logs/sweep.csv (points already
there are skipped, so the sweep can be resumed); logs/sweep.md is the table.

Run from the repo root with the env.md shell setup:
    python3 tests/bench/sweep.py [--config stream|pipe] [--arch A0,A1,A4]
    python3 tests/bench/sweep.py --restore   # rerun the 6 tasks with default defines
"""
import argparse
import csv
import json
import os
import re
import subprocess
import sys

BUS_PS = [3500, 7000, 14000]
NB = [1, 8, 64]
ARCHS = ["A0", "A1", "A4"]
SUFFIX = {"A0": "", "A1": "-a1", "A4": "-a4"}
CONFIGS = {
    "stream": ("bench-v3-stream%s", ["FW_AES_BENCH_V3", "FW_AES_BENCH_STREAM"]),
    "pipe": ("bench-aesdma-pipe%s", ["FW_AES_DMA_PIPE"]),
}
FIELDS = ["config", "arch", "bus_ps", "nb", "clks", "blocks_per_clk", "first", "passed"]
BENCH_RE = re.compile(r"BENCH:.*blocks=(\d+) clks=(\d+).*blocks/clk=([\d.]+) first=(\d+) bus_ps=(\d+)")


def run(task, defines=None):
    cmd = ["dfm", "run", "-u", "log"]
    if defines is not None:
        cmd += ["-P", json.dumps({"tasks": {task + "-img": {"defines": defines}}})]
    cmd.append(task + "-run")
    log = os.path.join("logs", "sweep-%s.log" % task)
    with open(log, "w") as fp:
        rc = subprocess.call(cmd, stdout=fp, stderr=subprocess.STDOUT)
    sim = os.path.join("rundir", "org.fwip.aes.%s-run" % task, "sim.log")
    text = open(sim).read() if os.path.exists(sim) else ""
    return rc, text


def table(rows):
    out = ["| config | arch | bus_ps | NB | clks | blocks/clk | clks/block | first | pass |",
           "|---|---|---|---|---|---|---|---|---|"]
    for r in rows:
        cpb = "%.1f" % (int(r["clks"]) / int(r["nb"])) if r["clks"] else "-"
        out.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
            r["config"], r["arch"], r["bus_ps"], r["nb"], r["clks"],
            r["blocks_per_clk"], cpb, r["first"], r["passed"]))
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", default="stream,pipe")
    ap.add_argument("--arch", default=",".join(ARCHS))
    ap.add_argument("--restore", action="store_true")
    args = ap.parse_args()
    os.makedirs("logs", exist_ok=True)
    configs = args.config.split(",")
    archs = args.arch.split(",")

    if args.restore:
        for c in configs:
            for a in archs:
                rc, text = run(CONFIGS[c][0] % SUFFIX[a])
                print(c, a, rc, "TEST PASSED" in text)
        return

    path = os.path.join("logs", "sweep.csv")
    rows = []
    if os.path.exists(path):
        rows = list(csv.DictReader(open(path)))
    done = {(r["config"], r["arch"], r["bus_ps"], r["nb"]) for r in rows}
    for c in configs:
        base, defs = CONFIGS[c]
        for a in archs:
            for ps in BUS_PS:
                for nb in NB:
                    key = (c, a, str(ps), str(nb))
                    if key in done:
                        continue
                    rc, text = run(base % SUFFIX[a],
                                   defs + ["FW_AES_NB=%d" % nb, "FW_AES_BUS_PS=%d" % ps])
                    m = BENCH_RE.search(text)
                    ok = rc == 0 and "TEST PASSED" in text and m is not None \
                        and int(m.group(1)) == nb and int(m.group(5)) == ps
                    r = dict(config=c, arch=a, bus_ps=ps, nb=nb,
                             clks=m.group(2) if m else "", blocks_per_clk=m.group(3) if m else "",
                             first=m.group(4) if m else "", passed="yes" if ok else "NO")
                    print(",".join(str(r[f]) for f in FIELDS), flush=True)
                    rows.append({k: str(v) for k, v in r.items()})
                    with open(path, "w", newline="") as fp:
                        w = csv.DictWriter(fp, fieldnames=FIELDS)
                        w.writeheader()
                        w.writerows(rows)
    order = {c: i for i, c in enumerate(CONFIGS)}
    rows.sort(key=lambda r: (order[r["config"]], r["arch"], int(r["bus_ps"]), int(r["nb"])))
    md = table(rows)
    open(os.path.join("logs", "sweep.md"), "w").write(md)
    print(md)
    print("%d rows, %d passed" % (len(rows), sum(r["passed"] == "yes" for r in rows)))
    return 0 if all(r["passed"] == "yes" for r in rows) else 1


if __name__ == "__main__":
    sys.exit(main())
