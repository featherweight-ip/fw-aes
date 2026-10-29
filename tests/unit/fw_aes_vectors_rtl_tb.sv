// FIPS-197 vectors (fw_aes_vectors_pkg) on the `rtl` view, the A0 XLS RTL.
module fw_aes_vectors_rtl_tb;
    import fw_aes_rtl_pkg::*;

    logic clk = 0;
    always #5 clk = ~clk;

    fw_aes_rtl_if bus(clk);
    fw_aes_rtl    dut(bus);

    initial begin
        fw_aes_rtl rtl = new(bus);
        rtl.reset();
        fw_aes_vectors_pkg::run(rtl);
        $display("rtl clks per op: %0d", rtl.m_clks / 4);
        $finish;
    end
endmodule
