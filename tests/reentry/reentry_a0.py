#!/usr/bin/env python3
"""Re-entry check for the A0 lowering path (batch 4).

Single-shot: a0-rtl (XLS Codegen) -> a0-ll (synth.xls.Lower) writes V4/V5 in rundir/.
Re-entered:  copy a0-rtl's schedule artifacts (schedule.textproto + sched.ir) to a fresh
directory, lower them there with dv_flow.libsynth.xls.lower, and require every emitted
view to be byte-identical to the single-shot output (same views => same QoR).

Run from the repo root after `dfm run a0-ll` (env.md shell setup + PYTHONPATH):
    python3 tests/reentry/reentry_a0.py [--keep DIR]
Prints one line per artifact and `REENTRY PASSED` / `REENTRY FAILED`; rc 0 on pass.
"""
import argparse
import os
import shutil
import sys
import tempfile

from dv_flow.libsynth.xls.lower import lower_files

MODULE = "aes_pkg__encrypt"
RUNDIR = os.path.join("rundir", "org.fwip.aes")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rundir", default=RUNDIR, help="prefix of the dfm task rundirs")
    ap.add_argument("--keep", help="write the re-entered views here (default: a temp dir)")
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

    ok = True
    for view, path in sorted(out.items()):
        ref = os.path.join(ll, os.path.basename(path))
        with open(path, "rb") as a, open(ref, "rb") as b:
            same = a.read() == b.read()
        ok &= same
        print(f"{'SAME' if same else 'DIFF'} schedule->{view}: {os.path.basename(path)}")
    print("REENTRY PASSED" if ok else "REENTRY FAILED")
    if not args.keep:
        shutil.rmtree(work)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
