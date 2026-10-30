#!/usr/bin/env python3
"""Copy the generated SystemVerilog that the walkthrough shows into docs/sv/generated/.

The views the flow generates (XLS RTL, V3 stage-TLM packages, V4/V5 lowering,
register models) live under rundir/, which is not committed. The docs show them
from these snapshots. Small files are copied whole; large ones are cut to their
first lines (`.head.sv`), and modules that other sources instantiate also get
a port-only copy (`.ports.sv`) that sphinx-systemverilog can parse. Only the files listed in sv_build_units (docs/conf.py)
are parsed by sphinx-systemverilog; the rest are shown with literalinclude.

Run from the repo root after the tasks named below have run:
    python3 docs/sv/snapshot.py
Files whose task has not run are reported and left as they are.
"""
import os
import sys

# (path under rundir/, name under docs/sv/generated/, lines to keep, None for all,
#  or "ports" for the module header only)
SNAPSHOTS = [
    # Step 1: register models and the A0 XLS RTL
    ("org.fwip.aes.reg-model/fw_aes_reg_pkg.sv", "fw_aes_reg_pkg.sv", None),
    ("org.fwip.aes.dma-reg-model/wb_dma_reg_pkg.sv", "wb_dma_reg_pkg.sv", None),
    ("org.fwip.aes.aes-dma-reg-model/fw_aes_dma_reg_pkg.sv", "fw_aes_dma_reg_pkg.sv", None),
    ("org.fwip.aes.a0-rtl/aes_pkg__encrypt.sv", "a0/aes_pkg__encrypt.head.sv", 150),
    ("org.fwip.aes.a0-rtl/aes_pkg__encrypt.sv", "a0/aes_pkg__encrypt.ports.sv", "ports"),
    ("org.fwip.aes.a0-rtl/aes_pkg__decrypt.sv", "a0/aes_pkg__decrypt.ports.sv", "ports"),
    ("org.fwip.aes.a0-rtl/aes_pkg__create_key_schedule.sv",
     "a0/aes_pkg__create_key_schedule.head.sv", 80),
    # Step 2: V3 from the XLS schedule
    ("org.fwip.aes.v3-fn-api/aes_pkg_api_pkg.sv", "aes_pkg_api_pkg.sv", None),
    ("org.fwip.aes.v3-stage-tlm/aes_stage_tlm_pkg.sv", "aes_stage_tlm_pkg.sv", None),
    # Step 3: V3 from architecture specs (same package name as A0's: not parsed)
    ("org.fwip.aes.v3-a1-sched/aes_stage_tlm_pkg.sv", "a1/aes_stage_tlm_pkg.sv", None),
    ("org.fwip.aes.v3-a2-sched/aes_stage_tlm_pkg.sv", "a2/aes_stage_tlm_pkg.sv", None),
    ("org.fwip.aes.v3-a3-sched/aes_stage_tlm_pkg.sv", "a3/aes_stage_tlm_pkg.sv", None),
    ("org.fwip.aes.v3-a4-sched/aes_stage_tlm_pkg.sv", "a4/aes_stage_tlm_pkg.sv", None),
    ("org.fwip.aes.v5-a1/aes_pkg__encrypt.A1.v5.v", "a1/aes_pkg__encrypt.A1.v5.head.sv", 150),
    ("org.fwip.aes.v5-a2/aes_pkg__encrypt.A2.v5.v", "a2/aes_pkg__encrypt.A2.v5.head.sv", 150),
    ("org.fwip.aes.v5-a3/aes_pkg__encrypt.A3.v5.v", "a3/aes_pkg__encrypt.A3.v5.head.sv", 150),
    ("org.fwip.aes.v5-a4/aes_pkg__encrypt.A4.v5.v", "a4/aes_pkg__encrypt.A4.v5.head.sv", 150),
    # Step 4: our lowering V3 -> V4 -> V5
    ("org.fwip.aes.a0-ll/aes_pkg__encrypt.v4.sv", "ll/aes_pkg__encrypt.v4.sv", None),
    ("org.fwip.aes.a0-ll/aes_pkg__encrypt.v4_stages.sv", "ll/aes_pkg__encrypt.v4_stages.head.sv", 150),
    ("org.fwip.aes.a0-ll/aes_pkg__encrypt.v5.sv", "ll/aes_pkg__encrypt.v5.head.sv", 150),
    ("org.fwip.aes.link-v3-v4/link_v3_v4_tb.sv", "ll/link_v3_v4_tb.sv", None),
    # Step 5: contracts
    ("cosynth/proofs/chk_C3.sv", "cosynth/chk_C3.sv", None),
]

HEAD_NOTE = "// [docs snapshot: first {n} of {total} lines of rundir/{src}]\n"
PORTS_NOTE = "// [docs snapshot: ports of rundir/{src} ({total} lines); body left out]\n"


def module_header(lines):
    """The lines from `module` up to the end of its port list."""
    out = []
    for ln in lines:
        if out or ln.startswith("module "):
            out.append(ln)
            if ln.strip() == ");":
                break
    return out


def main():
    root = os.getcwd()
    rundir = os.path.join(root, "rundir")
    outdir = os.path.join(root, "docs", "sv", "generated")
    missing = 0
    for src, dst, keep in SNAPSHOTS:
        sp = os.path.join(rundir, src)
        dp = os.path.join(outdir, dst)
        if not os.path.isfile(sp):
            print("missing (task not run?): rundir/%s" % src)
            missing += 1
            continue
        with open(sp) as f:
            # Absolute paths in generated comments would leak the build host.
            lines = f.read().replace(root + "/", "").splitlines(True)
        os.makedirs(os.path.dirname(dp), exist_ok=True)
        with open(dp, "w") as f:
            if keep == "ports":
                f.write(PORTS_NOTE.format(total=len(lines), src=src))
                f.writelines(module_header(lines) + ["endmodule\n"])
            elif keep is not None and len(lines) > keep:
                f.write(HEAD_NOTE.format(n=keep, total=len(lines), src=src))
                f.writelines(lines[:keep])
            else:
                f.writelines(lines)
        print("%-55s %s" % (dst, keep or "all"))
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
