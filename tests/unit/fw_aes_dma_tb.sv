// fw-aes-dma (TL) unit test: CSR writes through the target port start the
// block loop; the master port fetches and stores over a word memory. View: v3.
module fw_aes_dma_tb;
    import fw_proto_wb_pkg::*;
    import fw_aes_api_pkg::*;
    import fw_aes_v3_pkg::*;
    import fw_aes_dma_pkg::*;

    // Word memory; addresses at or above 'h8000 answer with a bus error.
    class mem_t implements wb_proto_if #(32, 32);
        bit [31:0]   m[bit [31:0]];
        int unsigned n_acc;
        virtual task access(input [31:0] adr, input [31:0] dat_w, input [3:0] sel,
                            input we, output [31:0] dat_r, output err);
            n_acc++;
            err   = (adr >= 'h8000);
            dat_r = 0;
            if (err) return;
            if (we) m[adr] = dat_w;
            else    dat_r = m.exists(adr) ? m[adr] : 0;
        endtask
    endclass

    logic clk = 0;
    always #5 clk = ~clk;
    fw_aes_clk_if bus(clk);

    int errors = 0;

    task automatic wr(fw_aes_dma d, bit [31:0] a, bit [31:0] v);
        bit [31:0] r; bit e;
        d.access(a, v, 4'hF, 1, r, e);
        if (e) begin $display("FAIL: write err @'h%02h", a); errors++; end
    endtask

    function automatic bit [31:0] rd(fw_aes_dma d);
        return d.m_regs.read_val('h30);
    endfunction

    // Run n blocks src->dst with key/mode, check each output block and STATUS.
    task automatic run(fw_aes_dma d, mem_t mem, string name, key_t key, aes_mode_e mode,
                       bit dec, block_t din, block_t exp, int n, bit [31:0] src, bit [31:0] dst);
        bit [31:0] status;
        for (int i = 0; i < 8; i++) wr(d, 4*i, key[255-32*i -: 32]);
        for (int b = 0; b < n; b++)
            for (int w = 0; w < 4; w++) mem.m[src + 16*b + 4*w] = din[127-32*w -: 32];
        wr(d, 'h20, src); wr(d, 'h24, dst); wr(d, 'h28, n);
        wr(d, 'h2C, {28'h0, 2'(mode), dec, 1'b1});
        status = rd(d);
        if (status !== {16'(n), 13'h0, 3'b010}) begin
            $display("FAIL: %s: STATUS 'h%08h", name, status); errors++;
        end
        for (int b = 0; b < n; b++) begin
            block_t got;
            for (int w = 0; w < 4; w++) got[127-32*w -: 32] = mem.m[dst + 16*b + 4*w];
            if (got !== exp) begin
                $display("FAIL: %s block %0d: 'h%032h", name, b, got); errors++;
            end
        end
        $display("%s: blocks=%0d", name, n);
    endtask

    initial begin
        mem_t      mem = new();
        fw_aes_v3  v3  = new(bus);
`ifdef FW_AES_DMA_PIPE
        fw_aes_dma d   = new(v3, mem, 2);
`elsif FW_AES_DMA_OVERLAP
        fw_aes_dma d   = new(v3, mem, 1);
`else
        fw_aes_dma d   = new(v3, mem);
`endif
        bit [31:0] status;
        run(d, mem, "fips197-c1-aes128-x4", {128'h000102030405060708090a0b0c0d0e0f, 128'h0},
            AES_128, 0, 128'h00112233445566778899aabbccddeeff,
            128'h69c4e0d86a7b0430d8cdb78070b4c55a, 4, 'h1000, 'h2000);
        run(d, mem, "fips197-c3-aes256-dec-x2",
            256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f,
            AES_256, 1, 128'h8ea2b7ca516745bfeafc49904b496089,
            128'h00112233445566778899aabbccddeeff, 2, 'h3000, 'h4000);
        // Bus error on the store of block 1: COUNT=1, ERROR, no DONE.
        wr(d, 'h20, 'h1000); wr(d, 'h24, 'h7FF0); wr(d, 'h28, 3);
        wr(d, 'h2C, 1);
        status = rd(d);
        if (status !== {16'd1, 13'h0, 3'b100}) begin
            $display("FAIL: bus error: STATUS 'h%08h", status); errors++;
        end
        $display("aesdma v3 clks=%0d mem accesses=%0d", v3.m_clks, mem.n_acc);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
