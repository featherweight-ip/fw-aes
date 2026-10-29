// FIPS-197 AES-128 vectors on the `rtl` view with a V5 encrypt (src/v5: an
// arch's folded datapath, AES-128 only) and the XLS decrypt. Encrypt clocks
// are counted separately (decrypt is the A0 pipeline).
module fw_aes_vectors_v5_tb;
    import fw_aes_api_pkg::*;
    import fw_aes_rtl_pkg::*;

    logic clk = 0;
    always #5 clk = ~clk;

    fw_aes_rtl_if bus(clk);
    fw_aes_rtl    dut(bus);

    class fw_aes_rtl_enc_clks extends fw_aes_rtl;
        int unsigned m_enc_clks, m_enc_ops;
        function new(virtual fw_aes_rtl_if vif);
            super.new(vif);
        endfunction
        virtual task encrypt(block_t pt, output block_t ct);
            int unsigned c0 = m_clks;
            op(0, pt, ct);
            m_enc_clks += m_clks - c0;
            m_enc_ops++;
        endtask
    endclass

    initial begin
        int errors = 0;
        fw_aes_rtl_enc_clks rtl = new(bus);
        rtl.reset();
        fw_aes_vectors_pkg::check(rtl, errors, "fips197-c1-aes128",
            {128'h000102030405060708090a0b0c0d0e0f, 128'h0}, AES_128,
            128'h00112233445566778899aabbccddeeff,
            128'h69c4e0d86a7b0430d8cdb78070b4c55a);
        fw_aes_vectors_pkg::check(rtl, errors, "fips197-b-aes128",
            {128'h2b7e151628aed2a6abf7158809cf4f3c, 128'h0}, AES_128,
            128'h3243f6a8885a308d313198a2e0370734,
            128'h3925841d02dc09fbdc118597196a0b32);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $display("v5 encrypt clks per op: %0d", rtl.m_enc_clks / rtl.m_enc_ops);
        $finish;
    end
endmodule
