// CSR access test: the fw-hdl register model of fw_aes_dma_regs.rdl
// (fw-aes-dma variant), accessed by address as a bus would.
module fw_aes_dma_csr_tb;
    import fw_hdl_pkg::*;
    import fw_aes_dma_reg_pkg::*;

    int errors = 0;

    task automatic check(string what, bit [31:0] got, bit [31:0] exp);
        if (got !== exp) begin
            $display("FAIL: %s: got 'h%08h, expected 'h%08h", what, got, exp);
            errors++;
        end
    endtask

    initial begin
        fw_aes_dma_regs regs = new("regs");
        fw_aes_dma_regs__CTRL_t ctrl;
        fw_aes_dma_regs__STATUS_t status;

        // Reset values
        for (int a = 'h00; a <= 'h30; a += 4)
            check($sformatf("reset @'h%02h", a), regs.read_val(a), 0);

        // KEY, SRC, DST are read/write
        for (int i = 0; i < 8; i++)
            regs.write_val(4*i, 32'h01020304 * (i+1));
        for (int i = 0; i < 8; i++)
            check($sformatf("KEY%0d", i), regs.read_val(4*i), 32'h01020304 * (i+1));
        regs.write_val('h20, 32'h0000_1000);
        regs.write_val('h24, 32'h0000_2000);
        check("SRC", regs.read_val('h20), 32'h0000_1000);
        check("DST", regs.read_val('h24), 32'h0000_2000);

        // LEN holds 16 bits
        regs.write_val('h28, 32'hFFFF_0008);
        check("LEN", regs.read_val('h28), 32'h0000_0008);

        // CTRL: MODE, DECRYPT, IRQ_EN hold; START is a single pulse
        ctrl = '0;
        ctrl.MODE = 2;
        ctrl.DECRYPT = 1;
        ctrl.IRQ_EN = 1;
        ctrl.START = 1;
        regs.write_val('h2C, ctrl);
        ctrl = regs.read_val('h2C);
        check("CTRL.MODE", ctrl.MODE, 2);
        check("CTRL.DECRYPT", ctrl.DECRYPT, 1);
        check("CTRL.IRQ_EN", ctrl.IRQ_EN, 1);

        // STATUS is read-only to software, written by hardware
        regs.write_val('h30, 32'hFFFF_FFFF);
        check("STATUS sw write ignored", regs.read_val('h30), 0);
        status = '0;
        status.DONE = 1;
        status.COUNT = 8;
        regs.STATUS.update_val(status);
        status = regs.read_val('h30);
        check("STATUS.DONE", status.DONE, 1);
        check("STATUS.BUSY", status.BUSY, 0);
        check("STATUS.ERROR", status.ERROR, 0);
        check("STATUS.COUNT", status.COUNT, 8);

        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
