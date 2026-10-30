#!/usr/bin/env python3
"""Re-entry check for the A0 lowering path (batch 4).

Single-shot: a0-rtl (XLS Codegen) -> a0-ll (synth.xls.Lower) writes V4/V5 in rundir/.
Re-entered:  copy a0-rtl's schedule artifacts (schedule.textproto + sched.ir) to a fresh
directory, lower them there with dv_flow.libsynth.xls.lower, and require every emitted
view to be byte-identical to the single-shot output (same views => same QoR).
Level 2, structure: copy a0-ll's <module>.structure.full.json (the lowering's whole
in-memory structure) to a fresh directory, emit from it with lower_structure (no IR or
schedule read), and require every emitted file byte-identical to a0-ll's. Then a
mutation check: move one node to the next stage in the copied structure and require
the re-emitted views to differ (the structure, not the IR, drives the emitters).

Run from the repo root after `dfm run a0-ll` (env.md shell setup + PYTHONPATH):
    python3 tests/reentry/reentry_a0.py [--keep DIR]
Prints one line per artifact and `REENTRY PASSED` / `REENTRY FAILED`; rc 0 on pass.
"""
import argparse
import os
import shutil
import sys
import tempfile

import json

from dv_flow.libsynth.xls.lower import lower_files, lower_structure

MODULE = "aes_pkg__encrypt"
RUNDIR = os.path.join("rundir", "org.fwip.aes")


def compare(level, out, ll):
    """Each emitted file of `out` against the file of the same name in `ll`."""
    ok = True
    for view, path in sorted(out.items()):
        ref = os.path.join(ll, os.path.basename(path))
        with open(path, "rb") as a, open(ref, "rb") as b:
            same = a.read() == b.read()
        ok &= same
        print(f"{'SAME' if same else 'DIFF'} {level}->{view}: {os.path.basename(path)}")
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rundir", default=RUNDIR, help="prefix of the dfm task rundirs")
    ap.add_argument("--keep", help="write the re-entered views here (default: a temp dir)")
    ap.add_argument("--no-mutate", action="store_true", help="skip the structure mutation check")
    args = ap.parse_args()

    rtl, ll = args.rundir + ".a0-rtl", args.rundir + ".a0-ll"
    work = args.keep or tempfile.mkdtemp(prefix="reentry-a0-")
    os.makedirs(os.path.join(work, "in"), exist_ok=True)

    # Level: XLS schedule. Only the files a scheduled description consists of are copied.
    ins = []
    for ext in ("sched.ir", "schedule.textproto"):
        src = os.path.join(rtl, f"{MODULE}.{ext}")
        dst = os.path.join(work, "in", os.path.basename(src))
        shutil.copy(src, dst)
        ins.append(dst)
    out = lower_files(ins[0], ins[1], os.path.join(work, "out"), module=MODULE)

    ok = compare("schedule", out, ll)

    # Level: lowering structure. Only the full structure is copied.
    sdir = os.path.join(work, "in-structure")
    os.makedirs(sdir, exist_ok=True)
    full = os.path.join(sdir, f"{MODULE}.structure.full.json")
    shutil.copy(os.path.join(ll, os.path.basename(full)), full)
    out = lower_structure(full, os.path.join(work, "out-structure"))
    ok &= compare("structure", out, ll)

    if not args.no_mutate:
        # mutation: the first node of the last stage moves to the previous stage
        with open(full) as f:
            j = json.load(f)
        last = j["stage_nodes"][-1]
        node = last.pop(0)
        j["stage_nodes"][-2].append(node)
        mfull = os.path.join(work, "in-mutated", os.path.basename(full))
        os.makedirs(os.path.dirname(mfull), exist_ok=True)
        with open(mfull, "w") as f:
            json.dump(j, f)
        out = lower_structure(mfull, os.path.join(work, "out-mutated"))
        diff = [v for v in ("v4_stages", "v5")
                if open(out[v], "rb").read() != open(os.path.join(ll, os.path.basename(out[v])), "rb").read()]
        detected = len(diff) == 2
        ok &= detected
        print(f"{'DETECTED' if detected else 'MISSED'} structure-mutation (moved {node} to stage "
              f"{len(j['stage_nodes']) - 2}): differs in {', '.join(diff) or 'nothing'}")
    print("REENTRY PASSED" if ok else "REENTRY FAILED")
    if not args.keep:
        shutil.rmtree(work)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
