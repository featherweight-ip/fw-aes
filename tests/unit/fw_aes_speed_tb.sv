// Sim speed (item 10): one view runs FW_AES_SPEED_OPS random ops (enc+dec
// pairs). The view is `v3` with FW_AES_SPEED_V3 defined, else `rtl`.
// Blocks/s and kclk/s come from these counts and the Verilator walltime.
`ifndef FW_AES_SPEED_OPS
`define FW_AES_SPEED_OPS 400000
`endif
module fw_aes_speed_tb;
    import fw_aes_api_pkg::*;

    logic clk = 0;
    always #5 clk = ~clk;

`ifdef FW_AES_SPEED_V3
    fw_aes_clk_if                 vbus(clk);
`else
    fw_aes_rtl_if                 rbus(clk);
    fw_aes_rtl                    dut(rbus);
`endif

    initial begin
`ifdef FW_AES_SPEED_V3
        fw_aes_v3_pkg::fw_aes_v3   view = new(vbus);
        string name = "v3";
`else
        fw_aes_rtl_pkg::fw_aes_rtl view = new(rbus);
        string name = "rtl";
`endif
        int errors = 0, ops = 0;
`ifndef FW_AES_SPEED_V3
        view.reset();
`endif

        for (int i = 0; ops < `FW_AES_SPEED_OPS; i++) begin
            key_t      key  = {$urandom, $urandom, $urandom, $urandom,
                               $urandom, $urandom, $urandom, $urandom};
            aes_mode_e mode = (i % 2) ? AES_256 : AES_128;
            block_t    pt   = {$urandom, $urandom, $urandom, $urandom};
            block_t    ct, pt2;

            view.set_key(key, mode);
            view.encrypt(pt, ct);
            view.decrypt(ct, pt2);
            ops += 2;
            if (pt2 !== pt) errors++;
        end

        $display("speed view=%s ops=%0d clks=%0d", name, ops, view.m_clks);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
