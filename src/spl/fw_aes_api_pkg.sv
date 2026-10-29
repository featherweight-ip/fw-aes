// The fw-aes API (plan §7): one interface class every view implements, and
// V0, the zero-time implementation over aes_pkg's functions.
package fw_aes_api_pkg;
    import aes_pkg::*;

    // Block and key are byte streams, byte 0 first (FIPS-197 order).
    typedef bit [127:0] block_t;
    typedef bit [255:0] key_t;

    typedef enum bit [1:0] {
        AES_128 = 0,
        AES_256 = 2
    } aes_mode_e;

    interface class fw_aes_api;
        // key: byte 0 in bits [255:248]; AES_128 uses the upper 128 bits.
        pure virtual task set_key(key_t key, aes_mode_e mode);
        pure virtual task encrypt(block_t pt, output block_t ct);
        pure virtual task decrypt(block_t ct, output block_t pt);
    endclass

    function automatic Block to_block(block_t b);
        Block r;
        for (int i = 0; i < 16; i++) r[i/4][i%4] = b[127-8*i -: 8];
        return r;
    endfunction

    function automatic block_t from_block(Block b);
        block_t r;
        for (int i = 0; i < 16; i++) r[127-8*i -: 8] = b[i/4][i%4];
        return r;
    endfunction

    // V0: the whole cipher in zero simulated time.
    class fw_aes_v0 implements fw_aes_api;
        Key        m_key;
        KeyWidth   m_width;

        virtual task set_key(key_t key, aes_mode_e mode);
            for (int i = 0; i < MAX_KEY_BYTES; i++) m_key[i] = key[255-8*i -: 8];
            m_width = KeyWidth'(mode);
        endtask

        virtual task encrypt(block_t pt, output block_t ct);
            ct = from_block(aes_pkg::encrypt(m_key, m_width, to_block(pt)));
        endtask

        virtual task decrypt(block_t ct, output block_t pt);
            pt = from_block(aes_pkg::decrypt(m_key, m_width, to_block(ct)));
        endtask
    endclass
endpackage
