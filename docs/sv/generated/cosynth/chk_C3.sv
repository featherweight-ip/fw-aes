module chk_C3(
    input logic  clk,
    input logic  rst,
    input logic  csr_we,
    input logic [5:0] csr_adr,
    input logic [31:0] csr_wdat,
    input logic [31:0] m_dat_i,
    input logic  m_ack,
    input logic  m_err,
    input logic  aes_out_valid,
    input logic [127:0] aes_out
);
    logic [31:0] csr_rdat;
    logic  m_cyc;
    logic  m_stb;
    logic  m_we;
    logic [31:0] m_adr;
    logic [31:0] m_dat_o;
    logic  aes_in_valid;
    logic [255:0] aes_key;
    logic [1:0] aes_key_width;
    logic [127:0] aes_block;
    logic  busy;
    logic  done;
    logic [31:0] cfg_src;
    logic [31:0] cfg_dst;
    logic [15:0] cfg_len;
    fw_aes_dma_xtor #(.GATE_BUSY(0), .LOCK_MODE(1)) dut(.clk(clk), .rst(rst), .csr_we(csr_we), .csr_adr(csr_adr), .csr_wdat(csr_wdat), .csr_rdat(csr_rdat), .m_cyc(m_cyc), .m_stb(m_stb), .m_we(m_we), .m_adr(m_adr), .m_dat_o(m_dat_o), .m_dat_i(m_dat_i), .m_ack(m_ack), .m_err(m_err), .aes_in_valid(aes_in_valid), .aes_key(aes_key), .aes_key_width(aes_key_width), .aes_block(aes_block), .aes_out_valid(aes_out_valid), .aes_out(aes_out), .busy(busy), .done(done), .cfg_src(cfg_src), .cfg_dst(cfg_dst), .cfg_len(cfg_len));
logic        inflight;      // AES ops started and not finished (0/1 by C1)
logic [127:0] blk_q;        // block presented at the last aes_in_valid
logic [255:0] key_q;
logic [2:0]  rd_beats, wr_beats;
logic        result_seen, first_op;
logic [127:0] res_q;
logic [31:0] src_q, dst_q;
logic [15:0] nblk;
always_ff @(posedge clk) begin
  if (rst) begin
    inflight <= 0; blk_q <= 0; key_q <= 0; rd_beats <= 0; wr_beats <= 0;
    result_seen <= 0; first_op <= 1; res_q <= 0; src_q <= 0; dst_q <= 0; nblk <= 0;
  end else begin
    if (!busy) begin src_q <= cfg_src; dst_q <= cfg_dst; nblk <= 0; rd_beats <= 0; wr_beats <= 0; first_op <= 1; result_seen <= 0; end
    if (aes_in_valid) begin inflight <= 1; blk_q <= aes_block; key_q <= aes_key; rd_beats <= 0; result_seen <= 0; first_op <= 0; wr_beats <= 0; end
    if (aes_out_valid && inflight) begin inflight <= 0; result_seen <= 1; res_q <= aes_out; end
    if (m_cyc && m_stb && m_ack && !m_we) rd_beats <= rd_beats + 1;
    if (m_cyc && m_stb && m_ack && m_we) begin
      wr_beats <= wr_beats + 1;
      if (wr_beats == 3) nblk <= nblk + 1;
    end
  end
end

    logic past_valid = 1'b0;
    always_ff @(posedge clk) past_valid <= 1'b1;
    always @(*) if (!past_valid) assume(rst); else assume(!rst);
    // env E.wb_ack: Wishbone slave acks only an active strobe, and one of ack/err
    always @(posedge clk) if (past_valid && !rst) E_wb_ack: assume(!((m_ack || m_err)) || ((m_cyc && m_stb) && !(m_ack && m_err)));
    // env E.aes_core: AES core (C2 implementer): one result per started op, not in the start cycle
    always @(posedge clk) if (past_valid && !rst) E_aes_core: assume(!(aes_out_valid) || ((inflight && !aes_in_valid)));
    // C3.key_stable_busy: key at the core is not changed while BUSY (KEY writes dropped)
    always @(posedge clk) if (past_valid && !rst && !$past(rst)) C3_key_stable_busy: assert(!((busy && $past(busy))) || ($stable(aes_key)));
    // C3.key_stable_op: key at the core equals the key at op start for the whole op
    always @(posedge clk) if (past_valid && !rst) C3_key_stable_op: assert(!(inflight) || (aes_key == key_q));
    // C3.mode_fixed: MODE is fixed after the first START
    always @(posedge clk) if (past_valid && !rst && !$past(rst)) C3_mode_fixed: assert(!(($past(busy) || $past(done))) || ($stable(aes_key_width)));
endmodule
