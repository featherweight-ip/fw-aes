module link_v3_v4_tb;
    logic clk = 0;
    always #5 clk = ~clk;
    fw_aes_clk_if v3if0(clk);
    aes_pkg__encrypt_v4_clk_if v4if0(clk);
    initial begin
        begin : pair0
            aes_stage_tlm_pkg::encrypt_stage_tlm v3 = new(v3if0);
            aes_pkg__encrypt_v4_pkg::aes_pkg__encrypt_v4 v4 = new(v4if0);
            int k, c3, c4, fails;
            bit [255:0] f0;
            bit[7:0] a0[0:31];
            bit [1:0] f1;
            aes_pkg::KeyWidth a1;
            bit [127:0] f2;
            bit[7:0] a2[0:3][0:3];
            bit [127:0] r3, r4;
            bit[7:0] o3[0:3][0:3];
            int fd;
            fd = $fopen("encrypt_stage_tlm__aes_pkg__encrypt.trace", "w");
            v4.reset();
            fails = 0;
            for (int op = 0; op < 500; op++) begin
                for (int b = 0; b < 256; b += 32) f0[b +: 32] = $urandom;
                f1 = 2'($urandom);
                for (int b = 0; b < 128; b += 32) f2[b +: 32] = $urandom;
                k = 0;
                for (int i0 = 0; i0 != 32; i0 += 1)
                begin a0[i0] = f0[k*8 +: 8]; k++; end
                a1 = aes_pkg::KeyWidth'(f1);
                k = 0;
                for (int i0 = 0; i0 != 4; i0 += 1)
                for (int i1 = 0; i1 != 4; i1 += 1)
                begin a2[i0][i1] = f2[k*8 +: 8]; k++; end
                c3 = v3.m_clks;
                v3.op(a0, a1, a2, o3);
                c3 = v3.m_clks - c3;
                k = 0;
                for (int i0 = 0; i0 != 4; i0 += 1)
                for (int i1 = 0; i1 != 4; i1 += 1)
                begin r3[k*8 +: 8] = o3[i0][i1]; k++; end
                c4 = v4.m_clks;
                v4.op(f0, f1, f2, r4);
                c4 = v4.m_clks - c4;
                $fdisplay(fd, "op %0d %h %h %h v3=%h/%0dclk v4=%h/%0dclk %s", op, f0, f1, f2, r3, c3, r4, c4, (r3 == r4 && c3 == c4) ? "ok" : "MISMATCH");
                if (r3 != r4 || c3 != c4) begin
                    if (fails == 0) $display("LINK-MISMATCH pair=encrypt_stage_tlm=aes_pkg__encrypt op=%0d inputs=%h %h %h v3=%h/%0d v4=%h/%0d", op, f0, f1, f2, r3, c3, r4, c4);
                    fails++;
                end
            end
            $fclose(fd);
            $display("LINK-RESULT pair=encrypt_stage_tlm=aes_pkg__encrypt ops=500 fails=%0d clks_v3=%0d clks_v4=%0d", fails, c3, c4);
        end
        $finish;
    end
endmodule
