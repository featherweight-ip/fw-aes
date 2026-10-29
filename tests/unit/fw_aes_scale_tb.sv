// Scaling bench (item 11, PLAN 6.4.3): FW_AES_SCALE_N engines, of which
// FW_AES_SCALE_K are active; a fixed total of FW_AES_SCALE_OPS random ops
// (enc+dec pairs) is spread over the active ones, the rest are configured
// and idle. The view is `v3` with FW_AES_SCALE_V3 defined, else `rtl`.
// Wall time per block comes from the ops count and the Verilator walltime.
`ifndef FW_AES_SCALE_N
`define FW_AES_SCALE_N 1
`endif
`ifndef FW_AES_SCALE_K
`define FW_AES_SCALE_K 1
`endif
`ifndef FW_AES_SCALE_OPS
`define FW_AES_SCALE_OPS 40000
`endif
module fw_aes_scale_tb;
    import fw_aes_api_pkg::*;

    localparam int N = `FW_AES_SCALE_N;
    localparam int K = `FW_AES_SCALE_K;

    logic clk = 0;
    always #5 clk = ~clk;

    fw_aes_api views[N];
    int        errors = 0;

    for (genvar g = 0; g < N; g++) begin : e
`ifdef FW_AES_SCALE_V3
        fw_aes_clk_if bus(clk);
        initial begin
            fw_aes_v3_pkg::fw_aes_v3 v = new(bus);
            views[g] = v;
        end
`else
        fw_aes_rtl_if bus(clk);
        fw_aes_rtl    dut(bus);
        initial begin
            fw_aes_rtl_pkg::fw_aes_rtl v = new(bus);
            views[g] = v;
            v.reset();
        end
`endif
    end

    task automatic worker(int id, int nops);
        for (int i = 0; i < nops; i += 2) begin
            key_t      key  = {$urandom, $urandom, $urandom, $urandom,
                               $urandom, $urandom, $urandom, $urandom};
            aes_mode_e mode = (i % 4) ? AES_256 : AES_128;
            block_t    pt   = {$urandom, $urandom, $urandom, $urandom};
            block_t    ct, pt2;

            views[id].set_key(key, mode);
            views[id].encrypt(pt, ct);
            views[id].decrypt(ct, pt2);
            if (pt2 !== pt) errors++;
        end
    endtask

    initial begin
        longint t0;
        #100;   // rtl reset is 3 clocks
        // Idle engines are configured, as in a SoC where most blocks wait.
        for (int j = K; j < N; j++)
            views[j].set_key('0, AES_128);
        t0 = $time;
        for (int j = 0; j < K; j++) begin
            automatic int jj = j;
            fork worker(jj, `FW_AES_SCALE_OPS / K); join_none
        end
        wait fork;

`ifdef FW_AES_SCALE_V3
        $display("scale view=v3 N=%0d K=%0d ops=%0d clks=%0d", N, K,
`else
        $display("scale view=rtl N=%0d K=%0d ops=%0d clks=%0d", N, K,
`endif
                 (`FW_AES_SCALE_OPS / K) * K, ($time - t0) / 10);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
