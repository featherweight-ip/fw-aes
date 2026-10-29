// FIPS-197 known-answer tests (App. C.1 AES-128, C.3 AES-256) through the
// fw_aes_api; each view's top binds an implementation and calls run().
package fw_aes_vectors_pkg;
    import fw_aes_api_pkg::*;

    task automatic check(fw_aes_api api, ref int errors, input string name,
                         key_t key, aes_mode_e mode, block_t pt, block_t ct_exp);
        block_t ct, pt2;
        api.set_key(key, mode);
        api.encrypt(pt, ct);
        api.decrypt(ct, pt2);
        if (ct !== ct_exp || pt2 !== pt) begin
            errors++;
            $display("FAIL %s: ct=%h (exp %h) pt=%h", name, ct, ct_exp, pt2);
        end else
            $display("PASS %s: ct=%h", name, ct);
    endtask

    task automatic run(fw_aes_api api);
        int errors = 0;
        check(api, errors, "fips197-c1-aes128",
              {128'h000102030405060708090a0b0c0d0e0f, 128'h0}, AES_128,
              128'h00112233445566778899aabbccddeeff,
              128'h69c4e0d86a7b0430d8cdb78070b4c55a);
        check(api, errors, "fips197-c3-aes256",
              256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f, AES_256,
              128'h00112233445566778899aabbccddeeff,
              128'h8ea2b7ca516745bfeafc49904b496089);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
    endtask
endpackage
