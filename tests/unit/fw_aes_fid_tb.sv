// Cycle fidelity (item 9): the `v3` view against the A0 `rtl` view on one
// clock. Each op runs on both views; the results and the clocks each op
// takes must be equal.
module fw_aes_fid_tb;
    import fw_aes_api_pkg::*;

    logic clk = 0;
    always #5 clk = ~clk;

    fw_aes_rtl_if                 rbus(clk);
    fw_aes_rtl                    dut(rbus);
    fw_aes_clk_if                 vbus(clk);

    initial begin
        fw_aes_rtl_pkg::fw_aes_rtl rtl = new(rbus);
        fw_aes_v3_pkg::fw_aes_v3   v3  = new(vbus);
        int errors = 0, ops = 0;
        rtl.reset();

        for (int i = 0; i < 16; i++) begin
            automatic key_t      key  = {$urandom, $urandom, $urandom, $urandom,
                               $urandom, $urandom, $urandom, $urandom};
            automatic aes_mode_e mode = (i % 2) ? AES_256 : AES_128;
            automatic block_t    pt   = {$urandom, $urandom, $urandom, $urandom};
            block_t    ct_r, ct_v, pt_r, pt_v;
            int unsigned c_r, c_v;

            rtl.set_key(key, mode);
            v3.set_key(key, mode);

            c_r = rtl.m_clks; c_v = v3.m_clks;
            rtl.encrypt(pt, ct_r);
            v3.encrypt(pt, ct_v);
            c_r = rtl.m_clks - c_r; c_v = v3.m_clks - c_v;
            ops++;
            if (ct_r !== ct_v || c_r != c_v) begin
                errors++;
                $display("FAIL enc %0d: rtl ct=%h clks=%0d v3 ct=%h clks=%0d",
                         i, ct_r, c_r, ct_v, c_v);
            end

            c_r = rtl.m_clks; c_v = v3.m_clks;
            rtl.decrypt(ct_r, pt_r);
            v3.decrypt(ct_r, pt_v);
            c_r = rtl.m_clks - c_r; c_v = v3.m_clks - c_v;
            ops++;
            if (pt_r !== pt || pt_v !== pt || c_r != c_v) begin
                errors++;
                $display("FAIL dec %0d: rtl pt=%h clks=%0d v3 pt=%h clks=%0d",
                         i, pt_r, c_r, pt_v, c_v);
            end
        end

        $display("fid ops=%0d rtl clks=%0d v3 clks=%0d", ops, rtl.m_clks, v3.m_clks);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
