// The `rtl` view: fw_aes_api over the A0 XLS RTL (aes_pkg__encrypt,
// aes_pkg__decrypt; src/ref a0-rtl). The class drives the pins of
// fw_aes_rtl_if a clock at a time and waits for output_valid.
// XLS flattens arrays element 0 at the LSB; fw_aes_api puts byte 0 at the
// MSB, so blocks and keys are byte-reversed at the boundary.
interface fw_aes_rtl_if(input logic clk);
    logic         rst;
    logic         enc_valid, dec_valid;
    logic [255:0] key;
    logic [1:0]   key_width;
    logic [127:0] block_in;
    logic         enc_out_valid, dec_out_valid;
    logic [127:0] enc_out, dec_out;
endinterface

module fw_aes_rtl(fw_aes_rtl_if bus);
    aes_pkg__encrypt u_enc(.clk(bus.clk), .rst(bus.rst), .input_valid(bus.enc_valid),
        .key(bus.key), .key_width(bus.key_width), .block_(bus.block_in),
        .output_valid(bus.enc_out_valid), .out(bus.enc_out));
    aes_pkg__decrypt u_dec(.clk(bus.clk), .rst(bus.rst), .input_valid(bus.dec_valid),
        .key(bus.key), .key_width(bus.key_width), .block_(bus.block_in),
        .output_valid(bus.dec_out_valid), .out(bus.dec_out));
endmodule

package fw_aes_rtl_pkg;
    import fw_aes_api_pkg::*;

    function automatic bit [127:0] rev16(bit [127:0] v);
        bit [127:0] r;
        for (int i = 0; i < 16; i++) r[8*i +: 8] = v[127-8*i -: 8];
        return r;
    endfunction

    function automatic bit [255:0] rev32(bit [255:0] v);
        bit [255:0] r;
        for (int i = 0; i < 32; i++) r[8*i +: 8] = v[255-8*i -: 8];
        return r;
    endfunction

    class fw_aes_rtl implements fw_aes_api;
        virtual fw_aes_rtl_if vif;
        int unsigned          m_clks;   // clocks spent in encrypt/decrypt

        function new(virtual fw_aes_rtl_if vif);
            this.vif = vif;
        endfunction

        task reset();
            vif.enc_valid <= 0;
            vif.dec_valid <= 0;
            vif.rst <= 1;
            repeat (2) @(posedge vif.clk);
            vif.rst <= 0;
            @(posedge vif.clk);
        endtask

        virtual task set_key(key_t key, aes_mode_e mode);
            vif.key <= rev32(key);
            vif.key_width <= 2'(mode);
        endtask

        task op(bit dec, block_t din, output block_t dout);
            vif.block_in <= rev16(din);
            if (dec) vif.dec_valid <= 1; else vif.enc_valid <= 1;
            @(posedge vif.clk);
            m_clks++;
            vif.enc_valid <= 0;
            vif.dec_valid <= 0;
            while (!(dec ? vif.dec_out_valid : vif.enc_out_valid)) begin
                @(posedge vif.clk);
                m_clks++;
            end
            dout = rev16(dec ? vif.dec_out : vif.enc_out);
        endtask

        virtual task encrypt(block_t pt, output block_t ct);
            op(0, pt, ct);
        endtask

        virtual task decrypt(block_t ct, output block_t pt);
            op(1, ct, pt);
        endtask
    endclass
endpackage
