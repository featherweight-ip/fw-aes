// fw-aes-dma (docs/design/dma-integrated.md), transaction level: the CSR
// block fw_aes_dma_regs behind a Wishbone target, and a Wishbone master that
// runs the block loop itself. A write of CTRL.START runs LEN.BLOCKS x
// (fetch 4 words @SRC+16i -> AES op -> store 4 words @DST+16i); STATUS.COUNT
// counts stored blocks, then DONE (or ERROR on a bus error) is set.
package fw_aes_dma_pkg;
    import fw_proto_wb_pkg::*;
    import fw_aes_api_pkg::*;
    import fw_aes_dma_reg_pkg::*;

    class fw_aes_dma implements wb_proto_if #(32, 32);
        fw_aes_dma_regs        m_regs;
        fw_aes_api             m_aes;
        wb_proto_if #(32, 32)  m_master;
        // Block-loop schedule: 0 serial; 1 overlap fetch i+1 with AES op i
        // (item 14b); 2 pipeline: op i beside (store i-1; fetch i+1) (item 14c).
        int unsigned           m_sched;
        // Contract checks (contracts.md "Checks to add"): C1/C3/C4 env
        // invariants that X1/X2/X3/X6 rely on. X2/X3/X6 save FFs, not
        // clocks, so at TL they are these checks only (zero-cycle).
        bit                    m_busy;
        bit                    m_started;
        bit [1:0]              m_mode;
        int unsigned           m_contract_errs;

        function new(fw_aes_api aes, wb_proto_if #(32, 32) master, int unsigned sched = 0);
            m_regs    = new("regs");
            m_aes     = aes;
            m_master  = master;
            m_sched   = sched;
        endfunction

        virtual task access(
                input  [31:0] adr,
                input  [31:0] dat_w,
                input  [3:0]  sel,
                input         we,
                output [31:0] dat_r,
                output        err);
            err   = (adr[1:0] != 0 || adr > 'h30);
            dat_r = 32'h0;
            if (err) return;
            if (we) begin
                // KEY/SRC/DST/LEN/CTRL (0x00-0x2C) not written while BUSY.
                if (m_busy && adr <= 'h2C) begin
                    $display("CONTRACT: write 'h%02h while BUSY", adr);
                    m_contract_errs++;
                end
                if (adr == 'h2C && dat_w[0]) begin
                    fw_aes_dma_regs__CTRL_t c = dat_w;
                    // C3/X6: MODE fixed after the first START.
                    if (m_started && c.MODE != m_mode) begin
                        $display("CONTRACT: MODE changed after first START");
                        m_contract_errs++;
                    end
                    m_started = 1;
                    m_mode    = c.MODE;
                end
                m_regs.write_val(adr, dat_w);
                if (adr == 'h2C && dat_w[0]) run(dat_w);
            end else begin
                dat_r = m_regs.read_val(adr);
            end
        endtask

        // The block loop; byte 0 of each word in [31:24] (fw_aes_dma_regs.rdl).
        protected task run(fw_aes_dma_regs__CTRL_t ctrl);
            fw_aes_dma_regs__STATUS_t status = '0;
            key_t        key;
            block_t      din, dout;
            bit [31:0]   src = m_regs.read_val('h20);
            bit [31:0]   dst = m_regs.read_val('h24);
            int unsigned n   = m_regs.read_val('h28) & 'hFFFF;
            bit [31:0]   rd;
            bit          err;
            for (int i = 0; i < 8; i++) key[255-32*i -: 32] = m_regs.read_val(4*i);
            status.BUSY = 1;
            m_busy      = 1;
            m_regs.STATUS.update_val(status);
            m_aes.set_key(key, aes_mode_e'(ctrl.MODE));
            if (m_sched == 1)      run_overlap(ctrl, src, dst, n, status);
            else if (m_sched == 2) run_pipe(ctrl, src, dst, n, status);
            else
            for (int b = 0; b < n && !status.ERROR; b++) begin
                for (int w = 0; w < 4 && !status.ERROR; w++) begin
                    m_master.access(src + 16*b + 4*w, 0, 4'hF, 0, rd, err);
                    din[127-32*w -: 32] = rd;
                    status.ERROR = err;
                end
                if (status.ERROR) break;
                if (ctrl.DECRYPT) m_aes.decrypt(din, dout);
                else              m_aes.encrypt(din, dout);
                for (int w = 0; w < 4 && !status.ERROR; w++) begin
                    m_master.access(dst + 16*b + 4*w, dout[127-32*w -: 32], 4'hF, 1, rd, err);
                    status.ERROR = err;
                end
                if (status.ERROR) break;
                status.COUNT = 16'(b + 1);
                m_regs.STATUS.update_val(status);
            end
            status.BUSY = 0;
            m_busy      = 0;
            status.DONE = !status.ERROR;
            m_regs.STATUS.update_val(status);
        endtask

        protected task fetch(bit [31:0] adr, output block_t din, output bit err);
            bit [31:0] rd;
            err = 0;
            for (int w = 0; w < 4 && !err; w++) begin
                m_master.access(adr + 4*w, 0, 4'hF, 0, rd, err);
                din[127-32*w -: 32] = rd;
            end
        endtask

        // Hand-scheduled overlap: fetch b+1 runs beside the AES op on b, then
        // b is stored. A fetch error on b+1 is reported after b is stored.
        protected task run_overlap(
                fw_aes_dma_regs__CTRL_t ctrl, bit [31:0] src, bit [31:0] dst,
                int unsigned n, inout fw_aes_dma_regs__STATUS_t status);
            block_t    cur, nxt, dout;
            bit [31:0] rd;
            bit        err, nerr;
            if (n == 0) return;
            fetch(src, cur, err);
            status.ERROR = err;
            for (int b = 0; b < n && !status.ERROR; b++) begin
                nerr = 0;
                fork
                    begin
                        if (ctrl.DECRYPT) m_aes.decrypt(cur, dout);
                        else              m_aes.encrypt(cur, dout);
                    end
                    if (b + 1 < n) fetch(src + 16*(b+1), nxt, nerr);
                join
                for (int w = 0; w < 4 && !status.ERROR; w++) begin
                    m_master.access(dst + 16*b + 4*w, dout[127-32*w -: 32], 4'hF, 1, rd, err);
                    status.ERROR = err;
                end
                if (status.ERROR) break;
                status.COUNT = 16'(b + 1);
                status.ERROR = nerr;
                m_regs.STATUS.update_val(status);
                cur = nxt;
            end
        endtask

        protected task store(bit [31:0] adr, block_t dout, output bit err);
            bit [31:0] rd;
            err = 0;
            for (int w = 0; w < 4 && !err; w++)
                m_master.access(adr + 4*w, dout[127-32*w -: 32], 4'hF, 1, rd, err);
        endtask

        // 3-stage pipeline: the AES op on b runs beside store b-1 then fetch
        // b+1 (one master, so store and fetch stay in sequence). A fetch error
        // on b+1 is reported after b is stored, as in run_overlap.
        protected task run_pipe(
                fw_aes_dma_regs__CTRL_t ctrl, bit [31:0] src, bit [31:0] dst,
                int unsigned n, inout fw_aes_dma_regs__STATUS_t status);
            block_t    cur, nxt, dout, prev;
            bit        err, serr, nerr, ferr = 0;
            if (n == 0) return;
            fetch(src, cur, err);
            status.ERROR = err;
            if (err) return;
            for (int b = 0; b <= n; b++) begin
                serr = 0;
                nerr = 0;
                fork
                    if (b < n && !ferr) begin
                        if (ctrl.DECRYPT) m_aes.decrypt(cur, dout);
                        else              m_aes.encrypt(cur, dout);
                    end
                    begin
                        if (b > 0) store(dst + 16*(b-1), prev, serr);
                        if (!serr && !ferr && b + 1 < n) fetch(src + 16*(b+1), nxt, nerr);
                    end
                join
                if (serr) begin
                    status.ERROR = 1;
                    break;
                end
                if (b > 0) begin
                    status.COUNT = 16'(b);
                    m_regs.STATUS.update_val(status);
                end
                if (ferr) begin
                    status.ERROR = 1;
                    break;
                end
                ferr = nerr;
                prev = dout;
                cur  = nxt;
            end
        endtask
    endclass
endpackage
