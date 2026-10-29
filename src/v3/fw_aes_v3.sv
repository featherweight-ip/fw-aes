// The `v3` view (stage-TLM), hand-written stand-in for the class that the
// XLS schedule import (PLAN Ph1 "dump B") should generate; see
// state/requests/fw-hdl-v3-import.md in the work packet.
// A0's schedule (src/ref a0-rtl, aes_pkg__encrypt.schedule.textproto) has
// 2 stages; XLS codegen adds input and output flops, so an op takes
// IN_FLOP + STAGES + OUT_FLOP = 4 clocks, as the `rtl` view measures.
// Each op computes its result at zero time (aes_pkg, like V0) and then
// spends one clock per stage: cost per stage, not per gate.
// clks_per_op (ctor arg, default `FW_AES_V3_CLKS, 0 = the A0 schedule) stands
// in for other architectures (src/arch: A1 11, A2 44) until zuspec-synth
// generates them (request zuspec-arch-sched).
`ifndef FW_AES_V3_CLKS
`define FW_AES_V3_CLKS 0
`endif
interface fw_aes_clk_if(input logic clk);
endinterface

package fw_aes_v3_pkg;
    import aes_pkg::*;
    import fw_aes_api_pkg::*;

    class fw_aes_v3 implements fw_aes_api;
        // From the A0 schedule; the import would fill these in.
        static const int unsigned STAGES   = 2;
        static const int unsigned IN_FLOP  = 1;
        static const int unsigned OUT_FLOP = 1;

        virtual fw_aes_clk_if vif;
        Key                   m_key;
        KeyWidth              m_width;
        int unsigned          m_clks;   // clocks spent in encrypt/decrypt
        int unsigned          m_clks_per_op;

        function new(virtual fw_aes_clk_if vif,
                     int unsigned clks_per_op = `FW_AES_V3_CLKS);
            this.vif = vif;
            m_clks_per_op = (clks_per_op != 0) ? clks_per_op
                                               : IN_FLOP + STAGES + OUT_FLOP;
        endfunction

        virtual task set_key(key_t key, aes_mode_e mode);
            for (int i = 0; i < MAX_KEY_BYTES; i++) m_key[i] = key[255-8*i -: 8];
            m_width = KeyWidth'(mode);
        endtask

        // One transaction through the pipeline: a clock per register stage.
        task advance();
            repeat (m_clks_per_op) begin
                @(posedge vif.clk);
                m_clks++;
            end
        endtask

        virtual task encrypt(block_t pt, output block_t ct);
            Block r = aes_pkg::encrypt(m_key, m_width, to_block(pt));
            advance();
            ct = from_block(r);
        endtask

        virtual task decrypt(block_t ct, output block_t pt);
            Block r = aes_pkg::decrypt(m_key, m_width, to_block(ct));
            advance();
            pt = from_block(r);
        endtask
    endclass
endpackage
