// fw-aes behind a Wishbone target, transaction level (plan §7.3): the CSR
// block (fw_aes_regs, by address) in front of any fw_aes_api view. A write of
// CTRL.START runs one block; DOUT0-3 and STATUS.DONE then hold the result.
package fw_aes_wb_pkg;
    import fw_proto_wb_pkg::*;
    import fw_aes_api_pkg::*;
    import fw_aes_reg_pkg::*;

    class fw_aes_wb_target implements wb_proto_if #(32, 32);
        fw_aes_regs  m_regs;
        fw_aes_api   m_aes;

        function new(fw_aes_api aes);
            m_regs = new("regs");
            m_aes  = aes;
        endfunction

        virtual task access(
                input  [31:0] adr,
                input  [31:0] dat_w,
                input  [3:0]  sel,
                input         we,
                output [31:0] dat_r,
                output        err);
            err   = (adr[1:0] != 0 || adr > 'h44);
            dat_r = 32'h0;
            if (err) return;
            if (we) begin
                m_regs.write_val(adr, dat_w);
                if (adr == 'h40 && dat_w[0]) run(dat_w);
            end else begin
                dat_r = m_regs.read_val(adr);
            end
        endtask

        // One block, byte 0 of each register in [31:24] (fw_aes_regs.rdl).
        protected task run(fw_aes_regs__CTRL_t ctrl);
            fw_aes_regs__STATUS_t status = '0;
            key_t   key;
            block_t din, dout;
            for (int i = 0; i < 8; i++) key[255-32*i -: 32] = m_regs.read_val(4*i);
            for (int i = 0; i < 4; i++) din[127-32*i -: 32] = m_regs.read_val('h20 + 4*i);
            status.BUSY = 1;
            m_regs.STATUS.update_val(status);
            m_aes.set_key(key, aes_mode_e'(ctrl.MODE));
            if (ctrl.DECRYPT) m_aes.decrypt(din, dout);
            else              m_aes.encrypt(din, dout);
            m_regs.DOUT0.update_val(dout[127:96]);
            m_regs.DOUT1.update_val(dout[95:64]);
            m_regs.DOUT2.update_val(dout[63:32]);
            m_regs.DOUT3.update_val(dout[31:0]);
            status.BUSY = 0;
            status.DONE = 1;
            m_regs.STATUS.update_val(status);
        endtask
    endclass
endpackage
