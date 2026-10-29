// The `v3` view (stage-TLM): fw_aes_api over the classes that
// fw.hdl.xls.StageTLM generates from the A0 schedule (aes_stage_tlm_pkg:
// computed at zero time, then a clock per pipeline register).
// clks_per_op (ctor arg, default `FW_AES_V3_CLKS, 0 = the A0 schedule) stands
// in for other architectures (src/arch: A1 11, A2 44).
`ifndef FW_AES_V3_CLKS
`define FW_AES_V3_CLKS 0
`endif
package fw_aes_v3_pkg;
    import aes_pkg::*;
    import fw_aes_api_pkg::*;
    import aes_stage_tlm_pkg::*;

    class fw_aes_v3 implements fw_aes_api;
        encrypt_stage_tlm m_enc;
        decrypt_stage_tlm m_dec;
        Key               m_key;
        KeyWidth          m_width;

        function new(virtual fw_aes_clk_if vif,
                     int unsigned clks_per_op = `FW_AES_V3_CLKS);
            m_enc = new(vif, clks_per_op);
            m_dec = new(vif, clks_per_op);
        endfunction

        // Clocks spent in encrypt/decrypt.
        function int unsigned m_clks();
            return m_enc.m_clks + m_dec.m_clks;
        endfunction

        virtual task set_key(key_t key, aes_mode_e mode);
            for (int i = 0; i < MAX_KEY_BYTES; i++) m_key[i] = key[255-8*i -: 8];
            m_width = KeyWidth'(mode);
        endtask

        virtual task encrypt(block_t pt, output block_t ct);
            Block r;
            m_enc.op(m_key, m_width, to_block(pt), r);
            ct = from_block(r);
        endtask

        virtual task decrypt(block_t ct, output block_t pt);
            Block r;
            m_dec.op(m_key, m_width, to_block(ct), r);
            pt = from_block(r);
        endtask
    endclass
endpackage
