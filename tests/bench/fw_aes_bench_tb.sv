// System bench (plan §7.3), transaction level: host -> address decoder ->
// {memory, fw-aes}, and fw-wb-dma moving each block mem -> DIN and
// DOUT -> mem. The DMA runs in software mode (no handshake); the host starts
// each block. Checks every result against fw_aes_v0 and reports blocks/clk.
//
//   host --regs--> dma.rf.host
//   host, dma.de.mif0/mif1 --wb_proto_if--> dec: 0x0xxx_xxxx mem, 0x1xxx_xxxx aes
module fw_aes_bench_tb;
    import fw_hdl_pkg::*;
    import fw_std_pkg::*;
    import fw_proto_wb_pkg::*;
    import wb_dma_spl_pkg::*;
    import fw_aes_api_pkg::*;
    import fw_aes_wb_pkg::*;

    typedef logic [31:0] addr_t;
    typedef logic [31:0] data_t;
    typedef logic [3:0]  strb_t;

    localparam addr_t AES = 32'h1000_0000;
    localparam addr_t SRC = 32'h0000_1000;
    localparam addr_t DST = 32'h0000_2000;
    localparam int    NB  = 8;                  // blocks
    localparam key_t  KEY = {128'h000102030405060708090a0b0c0d0e0f, 128'h0};

    // DMA channel registers (0x20 base, 0x20 stride per channel); CSR DONE is bit 11.
    localparam addr_t CH_CSR = 'h0, CH_SZ = 'h4, CH_ADR0 = 'h8, CH_ADR1 = 'h10;

    int unsigned clks = 0;
    logic clk = 1'b0;
    logic rst = 1'b0;

    // The api view under test, made before the root builds the env.
`ifdef FW_AES_BENCH_RTL
    localparam string VIEW = "rtl";     // A0 XLS RTL
    fw_aes_rtl_if u_rtl_if(clk);
    fw_aes_rtl    u_rtl(u_rtl_if);
`elsif FW_AES_BENCH_V3
    localparam string VIEW = "v3";      // stage-TLM, clocked on the bench clock
    fw_aes_clk_if u_v3_if(clk);
`else
    localparam string VIEW = "v0";
`endif
    fw_aes_api aes_view;

    // ---- address decoder: memory + fw-aes behind one wb_proto_if ------------
    class bus_dec extends fw_component;
        data_t mem [addr_t];
        fw_aes_wb_target aes;
        `FW_WB_PROTO_IMP(32, 32, bus_dec, m);

        function new(string name, fw_component parent); super.new(name, parent); endfunction
        function void build(); m = new(this); endfunction

        virtual task m_access(input [31:0] adr, input [31:0] dat_w, input [3:0] sel,
                              input we, output [31:0] dat_r, output err);
            #7ns;
            if (adr[31:28] == AES[31:28]) aes.access({4'b0, adr[27:0]}, dat_w, sel, we, dat_r, err);
            else begin
                if (we) mem[adr] = dat_w;
                dat_r = mem.exists(adr) ? mem[adr] : 32'h0;
                err = 1'b0;
            end
        endtask
    endclass

    // ---- host: loads blocks, runs the DMA per block, checks -----------------
    class host extends fw_component implements fw_runnable;
        fw_port #(wb_proto_if #(32, 32)) regs;   // -> dma.rf.host
        fw_port #(wb_proto_if #(32, 32)) bus;    // -> dec
        int unsigned errors;

        function new(string name, fw_component parent);
            super.new(name, parent);
            parent.add_runnable(this);
        endfunction
        function void build(); regs = new("regs", this); bus = new("bus", this); endfunction

        task wr(wb_proto_if #(32, 32) i, addr_t a, data_t d);
            bit err;
            bit [31:0] r;
            i.access(a, d, 4'hf, 1, r, err);
            if (err) begin $display("FAIL: write err @'h%08h", a); errors++; end
        endtask

        // Copy nw words src -> dst on channel ch and wait for DONE.
        task dma(int ch, addr_t src, addr_t dst, int nw, bit inc_src, bit inc_dst);
            wb_proto_if #(32, 32) rf = regs.get_if();
            addr_t base = 'h20 + 'h20 * ch;
            bit err;
            data_t csr;
            wr(rf, base + CH_ADR0, src);
            wr(rf, base + CH_ADR1, dst);
            wr(rf, base + CH_SZ, nw);
            wr(rf, base + CH_CSR, (1<<0) | (inc_dst << 3) | (inc_src << 4));
            for (int t = 0; t < 1000; t++) begin
                rf.access(base + CH_CSR, 0, 4'hf, 0, csr, err);
                if (csr[11]) break;
                #10ns;
            end
            if (!csr[11]) begin $display("FAIL: ch%0d never completed", ch); errors++; end
        endtask

        virtual task run();
            wb_proto_if #(32, 32) b = bus.get_if();
            fw_aes_v0 ref_m = new();
            block_t pt [NB], exp [NB], got;
            int unsigned c0;
            bit err;
            data_t w;
            errors = 0;

            // Load plaintext: block 0 is FIPS-197 C.1, the rest a pattern.
            pt[0] = 128'h00112233445566778899aabbccddeeff;
            for (int i = 1; i < NB; i++) pt[i] = {4{32'hA5A5_0000 + i}} ^ pt[0];
            ref_m.set_key(KEY, AES_128);
            for (int i = 0; i < NB; i++) begin
                ref_m.encrypt(pt[i], exp[i]);
                for (int j = 0; j < 4; j++) wr(b, SRC + 16*i + 4*j, pt[i][127-32*j -: 32]);
            end
            for (int j = 0; j < 8; j++) wr(b, AES + 4*j, KEY[255-32*j -: 32]);

            c0 = clks;
            for (int i = 0; i < NB; i++) begin
                dma(0, SRC + 16*i, AES + 'h20, 4, 1, 1);    // mem -> DIN0-3
                wr(b, AES + 'h40, 32'h1);                   // CTRL: start, encrypt, 128
                dma(1, AES + 'h30, DST + 16*i, 4, 1, 1);    // DOUT0-3 -> mem
            end
            c0 = clks - c0;

            for (int i = 0; i < NB; i++) begin
                for (int j = 0; j < 4; j++) begin
                    b.access(DST + 16*i + 4*j, 0, 4'hf, 0, w, err);
                    got[127-32*j -: 32] = w;
                end
                if (got !== exp[i]) begin
                    $display("FAIL: block %0d: got %032h, expected %032h", i, got, exp[i]);
                    errors++;
                end
            end
            if (exp[0] !== 128'h69c4e0d86a7b0430d8cdb78070b4c55a) begin
                $display("FAIL: reference C.1 mismatch"); errors++;
            end

            $display("BENCH: view=%s blocks=%0d clks=%0d blocks/clk=%f",
                     VIEW, NB, c0, real'(NB) / real'(c0));
            if (errors == 0) $display("TEST PASSED");
            else             $display("TEST FAILED: %0d errors", errors);
            $finish;
        endtask
    endclass

    class bench_env extends fw_component;
        wb_dma  dma;
        bus_dec dec;
        host    h;

        function new(string name, fw_component parent); super.new(name, parent); endfunction

        function void build();
            dma = new("dma", this, 4);
            dec = new("dec", this);
            dec.aes = new(aes_view);
            h   = new("h", this);
        endfunction

        function void connect();
            h.regs.connect(dma.rf.host);
            h.bus.connect(dec.m);
            dma.de.mif0.connect(dec.m);
            dma.de.mif1.connect(dec.m);
        endfunction
    endclass

    // The model is delay-driven; the clock seats the root domain and counts
    // cycles for the blocks/clk figure.
    always #5ns clk = ~clk;
    always @(posedge clk) clks++;
    fw_clock_xtor_if u_clk(.clock(clk), .reset(rst));

    initial begin
        automatic fw_component_root #(bench_env) root;
        automatic fw_clock_xtor_bridge clk_dom;
`ifdef FW_AES_BENCH_RTL
        automatic fw_aes_rtl_pkg::fw_aes_rtl rtl = new(u_rtl_if);
        rtl.reset();
        aes_view = rtl;
`elsif FW_AES_BENCH_V3
        automatic fw_aes_v3_pkg::fw_aes_v3 v3 = new(u_v3_if);
        aes_view = v3;
`else
        automatic fw_aes_v0 v0 = new();
        aes_view = v0;
`endif
        root = new("root");
        clk_dom = new("clock", root, u_clk);
        root.clock.connect(clk_dom);
        root.start();
    end

    initial begin
        #5ms;
        $display("TEST FAILED: timeout");
        $fatal(1, "[fw_aes_bench] TIMEOUT");
    end
endmodule
