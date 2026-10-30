// V4: stage-annotated cycle model of aes_pkg__encrypt (schedule: 2 stages,
// latency 3), from dv_flow.libsynth.xls.lower (synth.xls.Lower).
// Same registers as V5; stage<s>() runs stage s (aes_pkg__encrypt_v4_stages_pkg::stage<s>_f).
interface aes_pkg__encrypt_v4_clk_if(input logic clk);
endinterface

package aes_pkg__encrypt_v4_pkg;
    import aes_pkg__encrypt_v4_stages_pkg::*;

    class aes_pkg__encrypt_v4;
        static const int unsigned STAGES = 2;
        static const int unsigned LATENCY = 3;
        virtual aes_pkg__encrypt_v4_clk_if vif;
        int unsigned m_clks;
        // named stage registers (current value; *_n: next)
        bit v0, v0_n;
        bit [255:0] in_key, in_key_n;
        bit [1:0] in_key_width, in_key_width_n;
        bit [127:0] in_block_, in_block__n;
        bit v1, v1_n;
        bit [0:0] p1_b__17, p1_b__17_n;
        bit [0:0] p1_or_50186, p1_or_50186_n;
        bit [31:0] p1_word__172, p1_word__172_n;
        bit [7:0] p1_word__15, p1_word__15_n;
        bit [7:0] p1_word__13, p1_word__13_n;
        bit [7:0] p1_word__12, p1_word__12_n;
        bit [7:0] p1_word__11, p1_word__11_n;
        bit [31:0] p1_word__184, p1_word__184_n;
        bit [31:0] p1_word__190, p1_word__190_n;
        bit [31:0] p1_word__196, p1_word__196_n;
        bit [31:0] p1_sel_31603, p1_sel_31603_n;
        bit [31:0] p1_sel_31606, p1_sel_31606_n;
        bit [31:0] p1_sel_31608, p1_sel_31608_n;
        bit [7:0] p1_array_index_33517, p1_array_index_33517_n;
        bit [7:0] p1_array_index_33506, p1_array_index_33506_n;
        bit [7:0] p1_array_index_33510, p1_array_index_33510_n;
        bit [7:0] p1_array_index_33515, p1_array_index_33515_n;
        bit [7:0] p1_array_index_33505, p1_array_index_33505_n;
        bit [7:0] p1_array_index_33512, p1_array_index_33512_n;
        bit [7:0] p1_array_index_33511, p1_array_index_33511_n;
        bit [7:0] p1_array_index_33516, p1_array_index_33516_n;
        bit [7:0] p1_xor_35796, p1_xor_35796_n;
        bit [7:0] p1_xor_35797, p1_xor_35797_n;
        bit [7:0] p1_xor_35798, p1_xor_35798_n;
        bit [7:0] p1_xor_35795, p1_xor_35795_n;
        bit [7:0] p1_array_index_33772, p1_array_index_33772_n;
        bit [7:0] p1_array_index_33774, p1_array_index_33774_n;
        bit [7:0] p1_array_index_33773, p1_array_index_33773_n;
        bit [7:0] p1_array_index_33775, p1_array_index_33775_n;
        bit v2, v2_n;
        bit [127:0] out_flop, out_flop_n;

        function new(virtual aes_pkg__encrypt_v4_clk_if vif = null);
            this.vif = vif;
        endfunction

        function void reset();
            v0 = 0;
            in_key = '0;
            in_key_width = '0;
            in_block_ = '0;
            v1 = 0;
            p1_b__17 = '0;
            p1_or_50186 = '0;
            p1_word__172 = '0;
            p1_word__15 = '0;
            p1_word__13 = '0;
            p1_word__12 = '0;
            p1_word__11 = '0;
            p1_word__184 = '0;
            p1_word__190 = '0;
            p1_word__196 = '0;
            p1_sel_31603 = '0;
            p1_sel_31606 = '0;
            p1_sel_31608 = '0;
            p1_array_index_33517 = '0;
            p1_array_index_33506 = '0;
            p1_array_index_33510 = '0;
            p1_array_index_33515 = '0;
            p1_array_index_33505 = '0;
            p1_array_index_33512 = '0;
            p1_array_index_33511 = '0;
            p1_array_index_33516 = '0;
            p1_xor_35796 = '0;
            p1_xor_35797 = '0;
            p1_xor_35798 = '0;
            p1_xor_35795 = '0;
            p1_array_index_33772 = '0;
            p1_array_index_33774 = '0;
            p1_array_index_33773 = '0;
            p1_array_index_33775 = '0;
            v2 = 0;
            out_flop = '0;
        endfunction

        // stage 0: 1612 nodes
        function void stage0();
            v1_n = v0;
            if (v0) {p1_array_index_33775_n, p1_array_index_33773_n, p1_array_index_33774_n, p1_array_index_33772_n, p1_xor_35795_n, p1_xor_35798_n, p1_xor_35797_n, p1_xor_35796_n, p1_array_index_33516_n, p1_array_index_33511_n, p1_array_index_33512_n, p1_array_index_33505_n, p1_array_index_33515_n, p1_array_index_33510_n, p1_array_index_33506_n, p1_array_index_33517_n, p1_sel_31608_n, p1_sel_31606_n, p1_sel_31603_n, p1_word__196_n, p1_word__190_n, p1_word__184_n, p1_word__11_n, p1_word__12_n, p1_word__13_n, p1_word__15_n, p1_word__172_n, p1_or_50186_n, p1_b__17_n} = stage0_f({in_block_, in_key_width, in_key});
        endfunction

        // stage 1: 1533 nodes
        function void stage1();
            v2_n = v1;
            if (v1) {out_flop_n} = stage1_f({p1_array_index_33775, p1_array_index_33773, p1_array_index_33774, p1_array_index_33772, p1_xor_35795, p1_xor_35798, p1_xor_35797, p1_xor_35796, p1_array_index_33516, p1_array_index_33511, p1_array_index_33512, p1_array_index_33505, p1_array_index_33515, p1_array_index_33510, p1_array_index_33506, p1_array_index_33517, p1_sel_31608, p1_sel_31606, p1_sel_31603, p1_word__196, p1_word__190, p1_word__184, p1_word__11, p1_word__12, p1_word__13, p1_word__15, p1_word__172, p1_or_50186, p1_b__17});
        endfunction

        // one clock edge: open (n = v), the stage methods, commit (v = n)
        function void tick(bit input_valid, bit [255:0] key, bit [1:0] key_width, bit [127:0] block_);
            v0_n = v0;
            in_key_n = in_key;
            in_key_width_n = in_key_width;
            in_block__n = in_block_;
            v1_n = v1;
            p1_b__17_n = p1_b__17;
            p1_or_50186_n = p1_or_50186;
            p1_word__172_n = p1_word__172;
            p1_word__15_n = p1_word__15;
            p1_word__13_n = p1_word__13;
            p1_word__12_n = p1_word__12;
            p1_word__11_n = p1_word__11;
            p1_word__184_n = p1_word__184;
            p1_word__190_n = p1_word__190;
            p1_word__196_n = p1_word__196;
            p1_sel_31603_n = p1_sel_31603;
            p1_sel_31606_n = p1_sel_31606;
            p1_sel_31608_n = p1_sel_31608;
            p1_array_index_33517_n = p1_array_index_33517;
            p1_array_index_33506_n = p1_array_index_33506;
            p1_array_index_33510_n = p1_array_index_33510;
            p1_array_index_33515_n = p1_array_index_33515;
            p1_array_index_33505_n = p1_array_index_33505;
            p1_array_index_33512_n = p1_array_index_33512;
            p1_array_index_33511_n = p1_array_index_33511;
            p1_array_index_33516_n = p1_array_index_33516;
            p1_xor_35796_n = p1_xor_35796;
            p1_xor_35797_n = p1_xor_35797;
            p1_xor_35798_n = p1_xor_35798;
            p1_xor_35795_n = p1_xor_35795;
            p1_array_index_33772_n = p1_array_index_33772;
            p1_array_index_33774_n = p1_array_index_33774;
            p1_array_index_33773_n = p1_array_index_33773;
            p1_array_index_33775_n = p1_array_index_33775;
            v2_n = v2;
            out_flop_n = out_flop;
            v0_n = input_valid;
            if (input_valid) in_key_n = key;
            if (input_valid) in_key_width_n = key_width;
            if (input_valid) in_block__n = block_;
            stage0();
            stage1();
            v0 = v0_n;
            in_key = in_key_n;
            in_key_width = in_key_width_n;
            in_block_ = in_block__n;
            v1 = v1_n;
            p1_b__17 = p1_b__17_n;
            p1_or_50186 = p1_or_50186_n;
            p1_word__172 = p1_word__172_n;
            p1_word__15 = p1_word__15_n;
            p1_word__13 = p1_word__13_n;
            p1_word__12 = p1_word__12_n;
            p1_word__11 = p1_word__11_n;
            p1_word__184 = p1_word__184_n;
            p1_word__190 = p1_word__190_n;
            p1_word__196 = p1_word__196_n;
            p1_sel_31603 = p1_sel_31603_n;
            p1_sel_31606 = p1_sel_31606_n;
            p1_sel_31608 = p1_sel_31608_n;
            p1_array_index_33517 = p1_array_index_33517_n;
            p1_array_index_33506 = p1_array_index_33506_n;
            p1_array_index_33510 = p1_array_index_33510_n;
            p1_array_index_33515 = p1_array_index_33515_n;
            p1_array_index_33505 = p1_array_index_33505_n;
            p1_array_index_33512 = p1_array_index_33512_n;
            p1_array_index_33511 = p1_array_index_33511_n;
            p1_array_index_33516 = p1_array_index_33516_n;
            p1_xor_35796 = p1_xor_35796_n;
            p1_xor_35797 = p1_xor_35797_n;
            p1_xor_35798 = p1_xor_35798_n;
            p1_xor_35795 = p1_xor_35795_n;
            p1_array_index_33772 = p1_array_index_33772_n;
            p1_array_index_33774 = p1_array_index_33774_n;
            p1_array_index_33773 = p1_array_index_33773_n;
            p1_array_index_33775 = p1_array_index_33775_n;
            v2 = v2_n;
            out_flop = out_flop_n;
        endfunction

        // an op timed as the RTL transactor sees it: inputs valid for one
        // edge, then edges until output_valid is seen (sampled before the edge)
        task op(bit [255:0] key, bit [1:0] key_width, bit [127:0] block_, output bit [127:0] result);
            bit seen;
            @(posedge vif.clk);
            m_clks++;
            tick(1, key, key_width, block_);
            do begin
                @(posedge vif.clk);
                m_clks++;
                seen = v2;
                tick(0, key, key_width, block_);
            end while (!seen);
            result = out_flop;
        endtask
    endclass
endpackage
