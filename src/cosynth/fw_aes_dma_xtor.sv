// Hand-written, synthesizable transactor side of fw-aes-dma (item 14d3):
// the CSR block (fw_aes_dma_regs.rdl subset) and the DMA Wishbone master
// loop of src/dma/fw_aes_dma.sv (sched 0: fetch 4, op, store 4), driving
// the pins of an AES core (aes_pkg__encrypt / its co-synthesized form).
// The contracts of docs/design/contracts.md (records: contracts.yaml) are
// proved on this module by SBY; it *implements* C1, C3 and C4 and keeps
// C2's consumer side (store only after the result).
//
// GATE_BUSY = 1: KEY/SRC/DST/LEN/CTRL writes are dropped while BUSY (C3, C4).
// LOCK_MODE = 1: CTRL.MODE is locked at the first START (C3 "MODE fixed").
// GATE_BUSY = 0 is the mutation used to show the proofs can fail.
module fw_aes_dma_xtor #(
    parameter bit GATE_BUSY = 1,
    parameter bit LOCK_MODE = 1
) (
    input  logic         clk,
    input  logic         rst,
    // host CSR port (one access per cycle; read data combinational)
    input  logic         csr_we,
    input  logic [5:0]   csr_adr,
    input  logic [31:0]  csr_wdat,
    output logic [31:0]  csr_rdat,
    // DMA Wishbone classic master (C4)
    output logic         m_cyc,
    output logic         m_stb,
    output logic         m_we,
    output logic [31:0]  m_adr,
    output logic [31:0]  m_dat_o,
    input  logic [31:0]  m_dat_i,
    input  logic         m_ack,
    input  logic         m_err,
    // AES core pins (C1 in, C2 out, C3 key)
    output logic         aes_in_valid,
    output logic [255:0] aes_key,       // KEY0 in [255:224] (API order)
    output logic [1:0]   aes_key_width,
    output logic [127:0] aes_block,     // the DMA channel buffer (X1)
    input  logic         aes_out_valid,
    input  logic [127:0] aes_out,
    // status / configuration, visible to the contract checkers
    output logic         busy,
    output logic         done,
    output logic [31:0]  cfg_src,
    output logic [31:0]  cfg_dst,
    output logic [15:0]  cfg_len
);
    typedef enum logic [2:0] {IDLE, FETCH, OP, WAIT, STORE} st_e;
    st_e          st;
    logic [31:0]  key_r [8];
    logic [1:0]   mode_r;
    logic         mode_locked;
    logic         err_r;
    logic [127:0] res_r;
    logic [1:0]   beat;
    logic [15:0]  blk;

    wire wr_ok    = csr_we && (!GATE_BUSY || !busy);
    wire start    = wr_ok && csr_adr == 6'h2C && csr_wdat[0] && !busy;

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 8; i++) key_r[i] <= '0;
            cfg_src <= '0; cfg_dst <= '0; cfg_len <= '0;
            mode_r <= '0; mode_locked <= 1'b0;
            done <= 1'b0; err_r <= 1'b0;
            st <= IDLE; beat <= '0; blk <= '0; aes_block <= '0; res_r <= '0;
        end else begin
            if (wr_ok && csr_adr < 6'h20) key_r[csr_adr[4:2]] <= csr_wdat;
            if (wr_ok && csr_adr == 6'h20) cfg_src <= csr_wdat;
            if (wr_ok && csr_adr == 6'h24) cfg_dst <= csr_wdat;
            if (wr_ok && csr_adr == 6'h28) cfg_len <= csr_wdat[15:0];
            if (wr_ok && csr_adr == 6'h2C && !(LOCK_MODE && mode_locked)) mode_r <= csr_wdat[3:2];
            case (st)
            IDLE: if (start) begin
                done <= 1'b0; err_r <= 1'b0; mode_locked <= 1'b1;
                blk <= '0; beat <= '0;
                st <= (cfg_len == 0) ? IDLE : FETCH;
                if (cfg_len == 0) begin done <= 1'b1; end
            end
            FETCH: if (m_ack || m_err) begin
                case (beat)
                2'd0: aes_block[127:96] <= m_dat_i;
                2'd1: aes_block[95:64]  <= m_dat_i;
                2'd2: aes_block[63:32]  <= m_dat_i;
                default: aes_block[31:0] <= m_dat_i;
                endcase
                beat <= beat + 1'b1;
                if (m_err) begin st <= IDLE; err_r <= 1'b1; end
                else if (beat == 2'd3) st <= OP;
            end
            OP:   st <= WAIT;
            WAIT: if (aes_out_valid) begin res_r <= aes_out; st <= STORE; beat <= '0; end
            STORE: if (m_ack || m_err) begin
                beat <= beat + 1'b1;
                if (m_err) begin st <= IDLE; err_r <= 1'b1; end
                else if (beat == 2'd3) begin
                    blk <= blk + 1'b1;
                    if (blk + 1'b1 == cfg_len) begin st <= IDLE; done <= 1'b1; end
                    else st <= FETCH;
                end
            end
            default: st <= IDLE;
            endcase
        end
    end

    assign busy          = (st != IDLE);   // BUSY = the block loop is running
    assign aes_in_valid  = (st == OP);
    assign aes_key_width = mode_r;
    always_comb for (int i = 0; i < 8; i++) aes_key[255-32*i -: 32] = key_r[i];

    assign m_cyc   = (st == FETCH) || (st == STORE);
    assign m_stb   = m_cyc;
    assign m_we    = (st == STORE);
    assign m_adr   = (st == STORE ? cfg_dst : cfg_src) + {blk, 4'b0} + {beat, 2'b0};
    assign m_dat_o = 32'(res_r >> (7'd96 - {beat, 5'b0}));

    always_comb begin
        csr_rdat = '0;
        if (csr_adr == 6'h30) csr_rdat = {29'b0, err_r, done, busy};
        else if (csr_adr == 6'h2C) csr_rdat = {28'b0, mode_r, 2'b0};
    end
endmodule
