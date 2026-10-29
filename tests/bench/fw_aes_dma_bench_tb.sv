// System bench for fw-aes-dma (item 14a3, Q4 variant), transaction level:
// the same 8 blocks and bus timing as fw_aes_bench_tb, but no external
// fw-wb-dma. The host loads the key and SRC/DST/LEN and writes CTRL.START once;
// fw-aes-dma's own master fetches, encrypts (v3 view) and stores every block.
//
//   host, aesdma master --wb_proto_if--> dec: 0x0xxx_xxxx mem, 0x1xxx_xxxx aesdma
//
// Sweep knobs as fw_aes_bench_tb: FW_AES_NB blocks, FW_AES_BUS_PS ps per access.
`ifndef FW_AES_NB
`define FW_AES_NB 8
`endif
`ifndef FW_AES_BUS_PS
`define FW_AES_BUS_PS 7000
`endif
module fw_aes_dma_bench_tb;
    import fw_proto_wb_pkg::*;
    import fw_aes_api_pkg::*;
    import fw_aes_v3_pkg::*;
    import fw_aes_dma_pkg::*;

    typedef logic [31:0] addr_t;
    typedef logic [31:0] data_t;

    localparam addr_t AES = 32'h1000_0000;
    localparam addr_t SRC = 32'h0000_1000;
    localparam addr_t DST = 32'h0000_2000;
    localparam int    NB  = `FW_AES_NB;         // blocks
    localparam key_t  KEY = {128'h000102030405060708090a0b0c0d0e0f, 128'h0};

    int unsigned clks = 0;
    int unsigned first_clk = 0;     // clks when block 0's last word lands in DST
    logic clk = 1'b0;
    always #5ns clk = ~clk;
    always @(posedge clk) clks++;
    fw_aes_clk_if u_v3_if(clk);

    // Address decoder: memory + fw-aes-dma; each access costs 7 ns, as in
    // fw_aes_bench_tb's bus_dec.
    class bus_dec implements wb_proto_if #(32, 32);
        data_t mem [addr_t];
        fw_aes_dma aes;
        int unsigned n_acc;

        virtual task access(input [31:0] adr, input [31:0] dat_w, input [3:0] sel,
                            input we, output [31:0] dat_r, output err);
            #(`FW_AES_BUS_PS * 1ps);
            n_acc++;
            if (we && adr == DST + 'hC && first_clk == 0) first_clk = clks;
            if (adr[31:28] == AES[31:28]) aes.access({4'b0, adr[27:0]}, dat_w, sel, we, dat_r, err);
            else begin
                if (we) mem[adr] = dat_w;
                dat_r = mem.exists(adr) ? mem[adr] : 32'h0;
                err = 1'b0;
            end
        endtask
    endclass

    int unsigned errors = 0;

    task automatic wr(bus_dec b, addr_t a, data_t d);
        bit err;
        bit [31:0] r;
        b.access(a, d, 4'hf, 1, r, err);
        if (err) begin $display("FAIL: write err @'h%08h", a); errors++; end
    endtask

    initial begin
        bus_dec    dec   = new();
        fw_aes_v3  v3    = new(u_v3_if);
        fw_aes_v0  ref_m = new();
        block_t    pt [NB], exp [NB], got;
        int unsigned c0, a0, t0;
        bit        err;
        data_t     w;

`ifdef FW_AES_DMA_PIPE
        dec.aes = new(v3, dec, 2);
        `define AESDMA_VIEW "aesdma-pipe"
`elsif FW_AES_DMA_OVERLAP
        dec.aes = new(v3, dec, 1);
        `define AESDMA_VIEW "aesdma-ov"
`else
        dec.aes = new(v3, dec);
        `define AESDMA_VIEW "aesdma"
`endif
`ifdef FW_AES_X1
        // X1 (contracts.md, C1/C4): fetched words load the state register
        // directly (round-0 AddRoundKey folded), so the input flop goes: -1 clk/op.
        v3.m_enc.clks_per_op--; v3.m_dec.clks_per_op--;
`endif

        pt[0] = 128'h00112233445566778899aabbccddeeff;
        for (int i = 1; i < NB; i++) pt[i] = {4{32'hA5A5_0000 + i}} ^ pt[0];
        ref_m.set_key(KEY, AES_128);
        for (int i = 0; i < NB; i++) begin
            ref_m.encrypt(pt[i], exp[i]);
            for (int j = 0; j < 4; j++) wr(dec, SRC + 16*i + 4*j, pt[i][127-32*j -: 32]);
        end
        for (int j = 0; j < 8; j++) wr(dec, AES + 4*j, KEY[255-32*j -: 32]);

        // Timed region: descriptor, START, STATUS read (as the baseline times
        // its per-block DMA programming + CTRL writes).
        c0 = clks;
        t0 = clks;
        a0 = dec.n_acc;
        wr(dec, AES + 'h20, SRC);
        wr(dec, AES + 'h24, DST);
        wr(dec, AES + 'h28, NB);
        wr(dec, AES + 'h2C, 32'h1);                 // START, encrypt, 128
        dec.access(AES + 'h30, 0, 4'hf, 0, w, err);
        c0 = clks - c0;
        a0 = dec.n_acc - a0;
        if (w !== {16'(NB), 13'h0, 3'b010}) begin
            $display("FAIL: STATUS 'h%08h", w); errors++;
        end

        for (int i = 0; i < NB; i++) begin
            for (int j = 0; j < 4; j++) got[127-32*j -: 32] = dec.mem[DST + 16*i + 4*j];
            if (got !== exp[i]) begin
                $display("FAIL: block %0d: got %032h, expected %032h", i, got, exp[i]);
                errors++;
            end
        end
        if (exp[0] !== 128'h69c4e0d86a7b0430d8cdb78070b4c55a) begin
            $display("FAIL: reference C.1 mismatch"); errors++;
        end

        $display("BENCH: view=%s blocks=%0d clks=%0d bus accesses=%0d blocks/clk=%f first=%0d bus_ps=%0d",
                 `AESDMA_VIEW, NB, c0, a0, real'(NB) / real'(c0), first_clk - t0, `FW_AES_BUS_PS);
        errors += dec.aes.m_contract_errs;
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end

    initial begin
        #5ms;
        $display("TEST FAILED: timeout");
        $fatal(1, "[fw_aes_dma_bench] TIMEOUT");
    end
endmodule
