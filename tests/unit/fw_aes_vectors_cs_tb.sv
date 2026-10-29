// FIPS-197 AES-128 vector (App. C.1) on the `rtl` view with encrypt from the
// co-synthesis pass (a0-cs: X6 = AES-128 only, so the AES-256 vector is out of
// the contract and not run).
module fw_aes_vectors_cs_tb;
    import fw_aes_rtl_pkg::*;
    import fw_aes_api_pkg::*;

    logic clk = 0;
    always #5 clk = ~clk;

    fw_aes_rtl_if bus(clk);
    fw_aes_rtl    dut(bus);

    initial begin
        int errors = 0;
        fw_aes_rtl rtl = new(bus);
        rtl.reset();
        fw_aes_vectors_pkg::check(rtl, errors, "fips197-c1-aes128",
            {128'h000102030405060708090a0b0c0d0e0f, 128'h0}, AES_128,
            128'h00112233445566778899aabbccddeeff,
            128'h69c4e0d86a7b0430d8cdb78070b4c55a);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        begin
            block_t ct; int unsigned c0;
            c0 = rtl.m_clks;
            rtl.encrypt(128'h00112233445566778899aabbccddeeff, ct);
            $display("encrypt clks per op: %0d (ct=%h)", rtl.m_clks - c0, ct);
        end
        $finish;
    end
endmodule
