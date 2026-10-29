// fw-aes through its Wishbone target (transaction level): a host programs
// KEY/DIN/CTRL by bus access, then reads STATUS and DOUT. FIPS-197 C.1, C.3.
module fw_aes_wb_tb;
    import fw_proto_wb_pkg::*;
    import fw_aes_api_pkg::*;
    import fw_aes_wb_pkg::*;

    int errors = 0;
    wb_proto_if #(32, 32) bus;

    task automatic wr(bit [31:0] adr, bit [31:0] dat);
        bit [31:0] r;
        bit e;
        bus.access(adr, dat, 4'hF, 1, r, e);
        if (e) begin $display("FAIL: write err @'h%02h", adr); errors++; end
    endtask

    task automatic rd(bit [31:0] adr, output bit [31:0] dat);
        bit e;
        bus.access(adr, 0, 4'hF, 0, dat, e);
        if (e) begin $display("FAIL: read err @'h%02h", adr); errors++; end
    endtask

    task automatic block(string name, key_t key, bit [1:0] mode, bit decrypt,
                         block_t din, block_t exp);
        bit [31:0] w;
        block_t got;
        for (int i = 0; i < 8; i++) wr(4*i, key[255-32*i -: 32]);
        for (int i = 0; i < 4; i++) wr('h20 + 4*i, din[127-32*i -: 32]);
        wr('h40, {28'b0, mode, decrypt, 1'b1});
        rd('h44, w);
        if (w[1:0] != 2'b10) begin
            $display("FAIL: %s: STATUS 'h%0h, expected DONE", name, w); errors++;
        end
        for (int i = 0; i < 4; i++) begin
            rd('h30 + 4*i, w);
            got[127-32*i -: 32] = w;
        end
        if (got !== exp) begin
            $display("FAIL: %s: got %032h, expected %032h", name, got, exp); errors++;
        end else
            $display("PASS: %s", name);
    endtask

    initial begin
        fw_aes_v0 v0 = new();
        fw_aes_wb_target tgt = new(v0);
        bit [31:0] r;
        bit e;
        bus = tgt;

        block("AES-128 encrypt", {128'h000102030405060708090a0b0c0d0e0f, 128'h0}, 0, 0,
              128'h00112233445566778899aabbccddeeff, 128'h69c4e0d86a7b0430d8cdb78070b4c55a);
        block("AES-128 decrypt", {128'h000102030405060708090a0b0c0d0e0f, 128'h0}, 0, 1,
              128'h69c4e0d86a7b0430d8cdb78070b4c55a, 128'h00112233445566778899aabbccddeeff);
        block("AES-256 encrypt", 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f, 2, 0,
              128'h00112233445566778899aabbccddeeff, 128'h8ea2b7ca516745bfeafc49904b496089);

        bus.access('h48, 0, 4'hF, 0, r, e);
        if (!e) begin $display("FAIL: no err past the map"); errors++; end

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
