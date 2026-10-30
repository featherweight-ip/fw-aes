#!/usr/bin/env python3
"""Re-entry check for the arch scheduling path A1-A4 (batch 4).

Single-shot: v3-a<N>-sched (zuspec.synth.ArchSched) schedules aes_pkg::encrypt/decrypt on
src/arch/a<N>.yaml and writes V3 (aes_stage_tlm_pkg.sv) plus the full schedule
<m>.A<N>.sched.full.json (filetype archSchedule); v5-a<N> (zuspec.synth.ArchLower) reads
that schedule and writes V5 (<m>.A<N>.v5.v).
Re-entered: copy only the sched.full.json files to a fresh directory, run the ArchLower
task there (zuspec.synth.archsched.task.ArchLower, with the copied schedule as its
archSchedule input and the rundir IR/specs), and regenerate V3 and the sched.txt reports
from the copied json (archsched.load -> emit_v3 / sched.report); every file must be
byte-identical to the rundir's. Then a mutation check (one S-box lookup of encrypt moved
one step later in the copied json: V5 must differ or the lowering must reject it) and a
guard check (json with another IR hash: rejected).

Run from the repo root after `dfm run v5-a1 v5-a2 v5-a3 v5-a4` (env.md shell setup +
PYTHONPATH incl. zuspec-synth/src):
    python3 tests/reentry/reentry_arch.py [--keep DIR]
Prints one line per check and `REENTRY PASSED` / `REENTRY FAILED`; rc 0 on pass.
"""
import argparse
import asyncio
import glob
import json
import os
import shutil
import sys
import tempfile
from types import SimpleNamespace

from zuspec.synth.archsched import emit_v3, load, sched, spec as spec_mod, task

RUNDIR = os.path.join("rundir", "org.fwip.aes")
ARCHS = ["A1", "A2", "A3", "A4"]
MODS = ["aes_pkg__encrypt", "aes_pkg__decrypt"]
ENC = "aes_pkg__encrypt"
# Same as src/v3/flow.yaml (v3-a<N>-sched) and src/v5/flow.yaml (v5-a<N>).
CONSTS = {"key_width": 0}
DATA_INPUTS = ["block_"]
V3 = dict(pkg="aes_stage_tlm_pkg", clk_if="fw_aes_clk_if", imports=["aes_pkg"],
          arg_types={"key_width": "aes_pkg::KeyWidth"})


def fs(filetype, basedir, files):
    return SimpleNamespace(filetype=filetype, basedir=os.path.abspath(basedir), files=files)


def arch_lower(arch, sched_dir, rtl, out):
    """Run the ArchLower task (as v5-a<N> runs it) with `sched_dir`'s schedules."""
    specs = sorted(os.path.basename(f) for f in glob.glob("src/arch/*.yaml"))
    inp = SimpleNamespace(
        name=f"reentry-v5-{arch.lower()}", rundir=out,
        params=SimpleNamespace(arch=arch, functions=["aes_pkg::encrypt"],
                               specialize=dict(CONSTS), data_inputs=list(DATA_INPUTS),
                               passthrough=[]),
        inputs=[fs("xlsOptIR", rtl, [f"{m}.opt.ir" for m in MODS]),
                fs("yaml", "src/arch", specs),
                fs("archSchedule", sched_dir,
                   sorted(os.path.basename(f) for f in glob.glob(os.path.join(sched_dir, "*.json"))))])
    return asyncio.run(task.ArchLower(None, inp))


def same(a, b):
    with open(a, "rb") as x, open(b, "rb") as y:
        return x.read() == y.read()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rundir", default=RUNDIR, help="prefix of the dfm task rundirs")
    ap.add_argument("--keep", help="work here (default: a temp dir)")
    args = ap.parse_args()
    rtl = args.rundir + ".a0-rtl"
    work = args.keep or tempfile.mkdtemp(prefix="reentry-arch-")
    ok = True
    for arch in ARCHS:
        a = arch.lower()
        v3d, v5d = f"{args.rundir}.v3-{a}-sched", f"{args.rundir}.v5-{a}"
        wd = os.path.join(work, a)
        ind = os.path.join(wd, "in")
        os.makedirs(ind, exist_ok=True)
        for m in MODS:
            shutil.copy(os.path.join(v3d, f"{m}.{arch}.sched.full.json"), ind)

        # V5: the ArchLower task from the copied schedule.
        out = os.path.join(wd, "out")
        r = arch_lower(arch, ind, rtl, out)
        good = r.status == 0
        for f in (f"{ENC}.{arch}.v5.v", "v5.json"):
            s = good and same(os.path.join(out, f), os.path.join(v5d, f))
            ok &= s
            print(f"{'SAME' if s else 'DIFF'} schedule->v5 {arch}: {f}")

        # V3 and the reports from the copied schedule.
        sp = spec_mod.load(os.path.abspath(f"src/arch/{a}.yaml"))
        items = []
        for m in MODS:
            with open(os.path.join(rtl, f"{m}.opt.ir")) as fp:
                ir = fp.read()
            with open(os.path.join(ind, f"{m}.{arch}.sched.full.json")) as fp:
                orig, s = load(fp.read(), ir, sp, CONSTS, DATA_INPUTS)
            rep = f"{m}.{arch}.sched.txt"
            with open(os.path.join(wd, rep), "w") as fp:
                fp.write(sched.report(s))
            r_ok = same(os.path.join(wd, rep), os.path.join(v3d, rep))
            ok &= r_ok
            print(f"{'SAME' if r_ok else 'DIFF'} schedule->report {arch}: {rep}")
            items.append((orig, s, rep))
        v3 = os.path.join(wd, f"{V3['pkg']}.sv")
        with open(v3, "w") as fp:
            fp.write(emit_v3.stage_tlm_sv(items, V3["pkg"], V3["clk_if"], V3["imports"],
                                          V3["arg_types"], CONSTS))
        s3 = same(v3, os.path.join(v3d, os.path.basename(v3)))
        ok &= s3
        print(f"{'SAME' if s3 else 'DIFF'} schedule->v3 {arch}: {os.path.basename(v3)}")

        # Mutation: the first S-box lookup of encrypt at step 1 moves to step 2.
        src = os.path.join(ind, f"{ENC}.{arch}.sched.full.json")
        with open(src) as fp:
            j = json.load(fp)
        ent = next(e for e in j["placed"] if e[1] == 1 and e[2])
        ent[1] = 2
        mdir = os.path.join(wd, "in-mutated")
        os.makedirs(mdir, exist_ok=True)
        with open(os.path.join(mdir, os.path.basename(src)), "w") as fp:
            json.dump(j, fp)
        mout = os.path.join(wd, "out-mutated")
        r = arch_lower(arch, mdir, rtl, mout)
        if r.status != 0:
            how = "rejected: " + "; ".join(mk.msg for mk in r.markers)[:120]
            det = True
        else:
            det = not same(os.path.join(mout, f"{ENC}.{arch}.v5.v"),
                           os.path.join(v5d, f"{ENC}.{arch}.v5.v"))
            how = "v5 differs" if det else "v5 unchanged"
        ok &= det
        print(f"{'DETECTED' if det else 'MISSED'} schedule-mutation {arch} "
              f"(moved {ent[0]} to step 2): {how}")

        # Guard: a schedule claiming another IR is refused.
        j = json.load(open(src))
        j["ir_sha256"] = "0" * 64
        gdir = os.path.join(wd, "in-guard")
        os.makedirs(gdir, exist_ok=True)
        with open(os.path.join(gdir, os.path.basename(src)), "w") as fp:
            json.dump(j, fp)
        r = arch_lower(arch, gdir, rtl, os.path.join(wd, "out-guard"))
        rej = r.status != 0 and any("different IR" in mk.msg for mk in r.markers)
        ok &= rej
        print(f"{'REJECTED' if rej else 'ACCEPTED'} ir-hash-mismatch {arch}")
    print("REENTRY PASSED" if ok else "REENTRY FAILED")
    if not args.keep:
        shutil.rmtree(work)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
