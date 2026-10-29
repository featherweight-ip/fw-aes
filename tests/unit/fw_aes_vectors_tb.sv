// FIPS-197 vectors (fw_aes_vectors_pkg) on V0, the zero-time class model.
module fw_aes_vectors_tb;
    import fw_aes_api_pkg::*;

    initial begin
        fw_aes_v0 v0 = new();
        fw_aes_vectors_pkg::run(v0);
        $finish;
    end
endmodule
