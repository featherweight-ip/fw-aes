// FIPS-197 vectors (fw_aes_vectors_pkg) on the `v3` view (stage-TLM).
module fw_aes_vectors_v3_tb;
    import fw_aes_v3_pkg::*;

    logic clk = 0;
    always #5 clk = ~clk;

    fw_aes_clk_if bus(clk);

    initial begin
        fw_aes_v3 v3 = new(bus);
        fw_aes_vectors_pkg::run(v3);
        $display("v3 clks per op: %0d", v3.m_clks / 4);
        $finish;
    end
endmodule
