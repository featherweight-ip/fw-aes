// CSR access test: the fw-hdl register model of fw_aes_regs.rdl, accessed
// by address as a bus would (the bus itself comes with the system bench).
module fw_aes_csr_tb;
    import fw_hdl_pkg::*;
    import fw_aes_reg_pkg::*;

    int errors = 0;

    task automatic check(string what, bit [31:0] got, bit [31:0] exp);
        if (got !== exp) begin
            $display("FAIL: %s: got 'h%08h, expected 'h%08h", what, got, exp);
            errors++;
        end
    endtask

    initial begin
        fw_aes_regs regs = new("regs");
        fw_aes_regs__CTRL_t ctrl;
        fw_aes_regs__STATUS_t status;

        // Reset values
        for (int a = 'h00; a <= 'h44; a += 4)
            check($sformatf("reset @'h%02h", a), regs.read_val(a), 0);

        // KEY and DIN are read/write
        for (int i = 0; i < 8; i++)
            regs.write_val(4*i, 32'h01020304 * (i+1));
        for (int i = 0; i < 4; i++)
            regs.write_val('h20 + 4*i, 32'hA5A50000 + i);
        for (int i = 0; i < 8; i++)
            check($sformatf("KEY%0d", i), regs.read_val(4*i), 32'h01020304 * (i+1));
        for (int i = 0; i < 4; i++)
            check($sformatf("DIN%0d", i), regs.read_val('h20 + 4*i), 32'hA5A50000 + i);

        // DOUT is read-only to software, written by hardware
        regs.write_val('h30, 32'hFFFFFFFF);
        check("DOUT0 sw write ignored", regs.read_val('h30), 0);
        regs.DOUT0.update_val(32'h3925841D);
        check("DOUT0 hw write", regs.read_val('h30), 32'h3925841D);

        // CTRL: MODE and DECRYPT hold; START is a single pulse
        ctrl = '0;
        ctrl.MODE = 2;
        ctrl.DECRYPT = 1;
        ctrl.START = 1;
        regs.write_val('h40, ctrl);
        ctrl = regs.read_val('h40);
        check("CTRL.MODE", ctrl.MODE, 2);
        check("CTRL.DECRYPT", ctrl.DECRYPT, 1);

        // STATUS is read-only to software, written by hardware
        regs.write_val('h44, 32'h3);
        check("STATUS sw write ignored", regs.read_val('h44), 0);
        status = '0;
        status.DONE = 1;
        regs.STATUS.update_val(status);
        status = regs.read_val('h44);
        check("STATUS.DONE", status.DONE, 1);
        check("STATUS.BUSY", status.BUSY, 0);

        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
