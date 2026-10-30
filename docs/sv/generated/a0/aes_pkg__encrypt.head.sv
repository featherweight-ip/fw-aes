// [docs snapshot: first 150 of 5347 lines of rundir/org.fwip.aes.a0-rtl/aes_pkg__encrypt.sv]
module aes_pkg__encrypt(
  input wire clk,
  input wire rst,
  input wire input_valid,
  input wire [255:0] key,
  input wire [1:0] key_width,
  input wire [127:0] block_,
  output wire output_valid,
  output wire [127:0] out
);
  wire [7:0] key__input_flop_init[32];
  assign key__input_flop_init = '{8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00};
  wire [7:0] block___input_flop_init[4][4];
  assign block___input_flop_init = '{'{8'h00, 8'h00, 8'h00, 8'h00}, '{8'h00, 8'h00, 8'h00, 8'h00}, '{8'h00, 8'h00, 8'h00, 8'h00}, '{8'h00, 8'h00, 8'h00, 8'h00}};
  wire [7:0] literal_50285[256];
  assign literal_50285 = '{8'h63, 8'h7c, 8'h77, 8'h7b, 8'hf2, 8'h6b, 8'h6f, 8'hc5, 8'h30, 8'h01, 8'h67, 8'h2b, 8'hfe, 8'hd7, 8'hab, 8'h76, 8'hca, 8'h82, 8'hc9, 8'h7d, 8'hfa, 8'h59, 8'h47, 8'hf0, 8'had, 8'hd4, 8'ha2, 8'haf, 8'h9c, 8'ha4, 8'h72, 8'hc0, 8'hb7, 8'hfd, 8'h93, 8'h26, 8'h36, 8'h3f, 8'hf7, 8'hcc, 8'h34, 8'ha5, 8'he5, 8'hf1, 8'h71, 8'hd8, 8'h31, 8'h15, 8'h04, 8'hc7, 8'h23, 8'hc3, 8'h18, 8'h96, 8'h05, 8'h9a, 8'h07, 8'h12, 8'h80, 8'he2, 8'heb, 8'h27, 8'hb2, 8'h75, 8'h09, 8'h83, 8'h2c, 8'h1a, 8'h1b, 8'h6e, 8'h5a, 8'ha0, 8'h52, 8'h3b, 8'hd6, 8'hb3, 8'h29, 8'he3, 8'h2f, 8'h84, 8'h53, 8'hd1, 8'h00, 8'hed, 8'h20, 8'hfc, 8'hb1, 8'h5b, 8'h6a, 8'hcb, 8'hbe, 8'h39, 8'h4a, 8'h4c, 8'h58, 8'hcf, 8'hd0, 8'hef, 8'haa, 8'hfb, 8'h43, 8'h4d, 8'h33, 8'h85, 8'h45, 8'hf9, 8'h02, 8'h7f, 8'h50, 8'h3c, 8'h9f, 8'ha8, 8'h51, 8'ha3, 8'h40, 8'h8f, 8'h92, 8'h9d, 8'h38, 8'hf5, 8'hbc, 8'hb6, 8'hda, 8'h21, 8'h10, 8'hff, 8'hf3, 8'hd2, 8'hcd, 8'h0c, 8'h13, 8'hec, 8'h5f, 8'h97, 8'h44, 8'h17, 8'hc4, 8'ha7, 8'h7e, 8'h3d, 8'h64, 8'h5d, 8'h19, 8'h73, 8'h60, 8'h81, 8'h4f, 8'hdc, 8'h22, 8'h2a, 8'h90, 8'h88, 8'h46, 8'hee, 8'hb8, 8'h14, 8'hde, 8'h5e, 8'h0b, 8'hdb, 8'he0, 8'h32, 8'h3a, 8'h0a, 8'h49, 8'h06, 8'h24, 8'h5c, 8'hc2, 8'hd3, 8'hac, 8'h62, 8'h91, 8'h95, 8'he4, 8'h79, 8'he7, 8'hc8, 8'h37, 8'h6d, 8'h8d, 8'hd5, 8'h4e, 8'ha9, 8'h6c, 8'h56, 8'hf4, 8'hea, 8'h65, 8'h7a, 8'hae, 8'h08, 8'hba, 8'h78, 8'h25, 8'h2e, 8'h1c, 8'ha6, 8'hb4, 8'hc6, 8'he8, 8'hdd, 8'h74, 8'h1f, 8'h4b, 8'hbd, 8'h8b, 8'h8a, 8'h70, 8'h3e, 8'hb5, 8'h66, 8'h48, 8'h03, 8'hf6, 8'h0e, 8'h61, 8'h35, 8'h57, 8'hb9, 8'h86, 8'hc1, 8'h1d, 8'h9e, 8'he1, 8'hf8, 8'h98, 8'h11, 8'h69, 8'hd9, 8'h8e, 8'h94, 8'h9b, 8'h1e, 8'h87, 8'he9, 8'hce, 8'h55, 8'h28, 8'hdf, 8'h8c, 8'ha1, 8'h89, 8'h0d, 8'hbf, 8'he6, 8'h42, 8'h68, 8'h41, 8'h99, 8'h2d, 8'h0f, 8'hb0, 8'h54, 8'hbb, 8'h16};
  wire [7:0] out__output_flop_init[4][4];
  assign out__output_flop_init = '{'{8'h00, 8'h00, 8'h00, 8'h00}, '{8'h00, 8'h00, 8'h00, 8'h00}, '{8'h00, 8'h00, 8'h00, 8'h00}, '{8'h00, 8'h00, 8'h00, 8'h00}};
  wire [7:0] key_unflattened[32];
  assign key_unflattened[0] = key[7:0];
  assign key_unflattened[1] = key[15:8];
  assign key_unflattened[2] = key[23:16];
  assign key_unflattened[3] = key[31:24];
  assign key_unflattened[4] = key[39:32];
  assign key_unflattened[5] = key[47:40];
  assign key_unflattened[6] = key[55:48];
  assign key_unflattened[7] = key[63:56];
  assign key_unflattened[8] = key[71:64];
  assign key_unflattened[9] = key[79:72];
  assign key_unflattened[10] = key[87:80];
  assign key_unflattened[11] = key[95:88];
  assign key_unflattened[12] = key[103:96];
  assign key_unflattened[13] = key[111:104];
  assign key_unflattened[14] = key[119:112];
  assign key_unflattened[15] = key[127:120];
  assign key_unflattened[16] = key[135:128];
  assign key_unflattened[17] = key[143:136];
  assign key_unflattened[18] = key[151:144];
  assign key_unflattened[19] = key[159:152];
  assign key_unflattened[20] = key[167:160];
  assign key_unflattened[21] = key[175:168];
  assign key_unflattened[22] = key[183:176];
  assign key_unflattened[23] = key[191:184];
  assign key_unflattened[24] = key[199:192];
  assign key_unflattened[25] = key[207:200];
  assign key_unflattened[26] = key[215:208];
  assign key_unflattened[27] = key[223:216];
  assign key_unflattened[28] = key[231:224];
  assign key_unflattened[29] = key[239:232];
  assign key_unflattened[30] = key[247:240];
  assign key_unflattened[31] = key[255:248];
  wire [7:0] block__unflattened[4][4];
  assign block__unflattened[0][0] = block_[7:0];
  assign block__unflattened[0][1] = block_[15:8];
  assign block__unflattened[0][2] = block_[23:16];
  assign block__unflattened[0][3] = block_[31:24];
  assign block__unflattened[1][0] = block_[39:32];
  assign block__unflattened[1][1] = block_[47:40];
  assign block__unflattened[1][2] = block_[55:48];
  assign block__unflattened[1][3] = block_[63:56];
  assign block__unflattened[2][0] = block_[71:64];
  assign block__unflattened[2][1] = block_[79:72];
  assign block__unflattened[2][2] = block_[87:80];
  assign block__unflattened[2][3] = block_[95:88];
  assign block__unflattened[3][0] = block_[103:96];
  assign block__unflattened[3][1] = block_[111:104];
  assign block__unflattened[3][2] = block_[119:112];
  assign block__unflattened[3][3] = block_[127:120];

  // ===== Pipe stage 0:

  // Registers for pipe stage 0:
  reg input_valid__input_flop;
  reg [7:0] key__input_flop[32];
  reg [1:0] key_width__input_flop;
  reg [7:0] block___input_flop[4][4];
  always_ff @ (posedge clk) begin
    if (rst) begin
      input_valid__input_flop <= 1'h0;
      key__input_flop <= key__input_flop_init;
      key_width__input_flop <= 2'h0;
      block___input_flop <= block___input_flop_init;
    end else begin
      input_valid__input_flop <= input_valid;
      key__input_flop <= input_valid ? key_unflattened : key__input_flop;
      key_width__input_flop <= input_valid ? key_width : key_width__input_flop;
      block___input_flop <= input_valid ? block__unflattened : block___input_flop;
    end
  end

  // ===== Pipe stage 1:
  wire [7:0] p1_array_index_50286_comb;
  wire [7:0] p1_array_index_50292_comb;
  wire [7:0] p1_array_index_50293_comb;
  wire [4:0] p1_r_con__65_squeezed__1_comb;
  wire [7:0] p1_array_index_50309_comb;
  wire [7:0] p1_array_index_50311_comb;
  wire [7:0] p1_array_index_50313_comb;
  wire [4:0] p1_r_con__67_squeezed_comb;
  wire [7:0] p1_array_index_50318_comb;
  wire [7:0] p1_array_index_50323_comb;
  wire [7:0] p1_array_index_50326_comb;
  wire [7:0] p1_array_index_50329_comb;
  wire [7:0] p1_array_index_50333_comb;
  wire [6:0] p1_xor_50335_comb;
  wire [7:0] p1_array_index_50339_comb;
  wire [7:0] p1_xor_50340_comb;
  wire [7:0] p1_array_index_50342_comb;
  wire [7:0] p1_xor_50343_comb;
  wire [7:0] p1_array_index_50345_comb;
  wire [7:0] p1_xor_50346_comb;
  wire [6:0] p1_word__37_comb;
  wire p1_word__36_comb;
  wire [7:0] p1_array_index_50354_comb;
  wire [7:0] p1_word__33_comb;
  wire [7:0] p1_array_index_50356_comb;
  wire [7:0] p1_word__32_comb;
  wire [7:0] p1_array_index_50358_comb;
  wire [7:0] p1_word__31_comb;
  wire [4:0] p1_lit_28_shift_bits_comb;
  wire [6:0] p1_word__46_comb;
  wire p1_word__44_comb;
  wire [7:0] p1_word__43_comb;
  wire [7:0] p1_word__40_comb;
  wire [7:0] p1_word__39_comb;
  wire [6:0] p1_word__54_comb;
  wire p1_word__53_comb;
  wire [7:0] p1_word__51_comb;
  wire [7:0] p1_word__50_comb;
  wire [7:0] p1_word__47_comb;
  wire p1_b__17_comb;
  wire [31:0] p1_word__49_comb;
  wire [31:0] p1_word__52_comb;
  wire [31:0] p1_word__55_comb;
  wire [31:0] p1_word_comb;
  wire [31:0] p1_word__29_comb;
  wire [5:0] p1_r_con__8_squeezed_const_msb_bits_comb;
  wire p1_or_50425_comb;
  wire [23:0] p1_r_con__8_squeezed_const_lsb_bits_comb;
  wire [31:0] p1_word__7_comb;
  wire [31:0] p1_word__38_comb;
  wire [31:0] p1_r_con__8_comb;
  wire [31:0] p1_word__14_comb;
  wire [31:0] p1_word__45_comb;
  wire [31:0] p1_word__56_comb;
  wire [31:0] p1_word__21_comb;
  wire [31:0] p1_word__64_comb;
  wire [31:0] p1_word__70_comb;
  wire [1:0] p1_r_con__24_squeezed_const_msb_bits_comb;
  wire [1:0] p1_r_con__60_squeezed_comb;
