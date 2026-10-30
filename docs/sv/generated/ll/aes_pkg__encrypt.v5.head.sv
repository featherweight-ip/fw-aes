// [docs snapshot: first 150 of 6667 lines of rundir/org.fwip.aes.a0-ll/aes_pkg__encrypt.v5.sv]
// V5: aes_pkg__encrypt, lowered from the XLS schedule of aes_pkg__encrypt by
// dv_flow.libsynth.xls.lower (synth.xls.Lower). Ports and latency as
// XLS codegen_main (pipeline, flop_inputs/outputs, valid): latency 3.

// Stage 0 of aes_pkg__encrypt: 1612 nodes, 3 input registers, 29 output registers
module aes_pkg__encrypt__stage0(
    input  wire [255:0] r_key,
    input  wire [1:0] r_key_width,
    input  wire [127:0] r_block_,
    output wire [0:0] n_b__17,
    output wire [0:0] n_or_50186,
    output wire [31:0] n_word__172,
    output wire [7:0] n_word__15,
    output wire [7:0] n_word__13,
    output wire [7:0] n_word__12,
    output wire [7:0] n_word__11,
    output wire [31:0] n_word__184,
    output wire [31:0] n_word__190,
    output wire [31:0] n_word__196,
    output wire [31:0] n_sel_31603,
    output wire [31:0] n_sel_31606,
    output wire [31:0] n_sel_31608,
    output wire [7:0] n_array_index_33517,
    output wire [7:0] n_array_index_33506,
    output wire [7:0] n_array_index_33510,
    output wire [7:0] n_array_index_33515,
    output wire [7:0] n_array_index_33505,
    output wire [7:0] n_array_index_33512,
    output wire [7:0] n_array_index_33511,
    output wire [7:0] n_array_index_33516,
    output wire [7:0] n_xor_35796,
    output wire [7:0] n_xor_35797,
    output wire [7:0] n_xor_35798,
    output wire [7:0] n_xor_35795,
    output wire [7:0] n_array_index_33772,
    output wire [7:0] n_array_index_33774,
    output wire [7:0] n_array_index_33773,
    output wire [7:0] n_array_index_33775
);
    localparam logic [4:0] L_literal_31350 = 5'hd;
    localparam logic [4:0] L_literal_31335 = 5'h0;
    localparam logic [2047:0] L_literal_31379 = 2048'h16bb54b00f2d99416842e6bf0d89a18cdf2855cee9871e9b948ed9691198f8e19e1dc186b95735610ef6034866b53e708a8bbd4b1f74dde8c6b4a61c2e2578ba08ae7a65eaf4566ca94ed58d6d37c8e779e4959162acd3c25c2406490a3a32e0db0b5ede14b8ee4688902a22dc4f816073195d643d7ea7c41744975fec130ccdd2f3ff1021dab6bcf5389d928f40a351a89f3c507f02f94585334d43fbaaefd0cf584c4a39becb6a5bb1fc20ed00d153842fe329b3d63b52a05a6e1b1a2c830975b227ebe28012079a059618c323c7041531d871f1e5a534ccf73f362693fdb7c072a49cafa2d4adf04759fa7dc982ca76abd7fe2b670130c56f6bf27b777c63;
    localparam logic [4:0] L_literal_31351 = 5'he;
    localparam logic [4:0] L_literal_31352 = 5'hf;
    localparam logic [4:0] L_literal_31349 = 5'hc;
    localparam logic [4:0] L_literal_31341 = 5'h4;
    localparam logic [4:0] L_r_con__65_squeezed__1 = 5'h1;
    localparam logic [4:0] L_literal_31339 = 5'h2;
    localparam logic [4:0] L_literal_31340 = 5'h3;
    localparam logic [4:0] L_r_con__67_squeezed = 5'h8;
    localparam logic [4:0] L_literal_31342 = 5'h5;
    localparam logic [4:0] L_literal_31343 = 5'h6;
    localparam logic [4:0] L_literal_31344 = 5'h7;
    localparam logic [4:0] L_literal_31346 = 5'h9;
    localparam logic [4:0] L_literal_31347 = 5'ha;
    localparam logic [4:0] L_literal_31348 = 5'hb;
    localparam logic [4:0] L_lit_28_shift_bits = 5'h1c;
    localparam logic [4:0] L_literal_31393 = 5'h1d;
    localparam logic [4:0] L_literal_31416 = 5'h1e;
    localparam logic [4:0] L_literal_31435 = 5'h1f;
    localparam logic [5:0] L_r_con__8_squeezed_const_msb_bits = 6'h0;
    localparam logic [23:0] L_r_con__8_squeezed_const_lsb_bits = 24'h0;
    localparam logic [4:0] L_lit_16_shift_bits = 5'h10;
    localparam logic [4:0] L_literal_31395 = 5'h11;
    localparam logic [4:0] L_literal_31396 = 5'h12;
    localparam logic [4:0] L_literal_31397 = 5'h13;
    localparam logic [4:0] L_lit_20_shift_bits = 5'h14;
    localparam logic [4:0] L_literal_31418 = 5'h15;
    localparam logic [4:0] L_literal_31419 = 5'h16;
    localparam logic [4:0] L_literal_31420 = 5'h17;
    localparam logic [4:0] L_lit_24_shift_bits = 5'h18;
    localparam logic [4:0] L_literal_31437 = 5'h19;
    localparam logic [4:0] L_literal_31438 = 5'h1a;
    localparam logic [4:0] L_r_con__77_squeezed = 5'h1b;
    localparam logic [3:0] L_r_con__16_squeezed_const_msb_bits = 4'h0;
    localparam logic [0:0] L_a__8 = 1'h0;
    localparam logic [24:0] L_r_con__16_squeezed_const_lsb_bits = 25'h0;
    localparam logic [1:0] L_r_con__24_squeezed_const_msb_bits = 2'h0;
    localparam logic [1:0] L_r_con__60_squeezed = 2'h1;
    localparam logic [1:0] L_r_con__61_squeezed = 2'h2;
    localparam logic [1:0] L_literal_31817 = 2'h3;
    localparam logic [25:0] L_r_con__24_squeezed_const_lsb_bits = 26'h0;
    wire [7:0] s_array_index_31368;
    wire [7:0] s_array_index_31355;
    wire [7:0] s_array_index_31384;
    wire [0:0] s_bit_slice_40315;
    wire [0:0] s_bit_slice_40317;
    wire [7:0] s_array_index_31369;
    wire [7:0] s_array_index_31370;
    wire [7:0] s_array_index_31367;
    wire [7:0] s_array_index_31359;
    wire [6:0] s_bit_slice_40319;
    wire [6:0] s_bit_slice_40321;
    wire [0:0] s_xor_36274;
    wire [7:0] s_array_index_31356;
    wire [7:0] s_array_index_31385;
    wire [7:0] s_array_index_31357;
    wire [7:0] s_array_index_31386;
    wire [7:0] s_array_index_31358;
    wire [7:0] s_array_index_31383;
    wire [7:0] s_array_index_31363;
    wire [6:0] s_bit_slice_43995;
    wire [6:0] s_xor_36278;
    wire [0:0] s_bit_slice_43992;
    wire [0:0] s_not_36275;
    wire [7:0] s_array_index_31360;
    wire [7:0] s_xor_43911;
    wire [7:0] s_array_index_31361;
    wire [7:0] s_xor_43908;
    wire [7:0] s_array_index_31362;
    wire [7:0] s_xor_43905;
    wire [6:0] s_bit_slice_44007;
    wire [6:0] s_word__37;
    wire [0:0] s_bit_slice_44004;
    wire [0:0] s_word__36;
    wire [7:0] s_array_index_31364;
    wire [7:0] s_word__33;
    wire [7:0] s_array_index_31365;
    wire [7:0] s_word__32;
    wire [7:0] s_array_index_31366;
    wire [7:0] s_word__31;
    wire [6:0] s_bit_slice_44019;
    wire [6:0] s_word__46;
    wire [0:0] s_bit_slice_44016;
    wire [0:0] s_word__44;
    wire [7:0] s_word__43;
    wire [7:0] s_word__40;
    wire [7:0] s_word__39;
    wire [0:0] s_bit_slice_31325;
    wire [0:0] s_bit_slice_31326;
    wire [7:0] s_array_index_31455;
    wire [7:0] s_array_index_31456;
    wire [7:0] s_array_index_31457;
    wire [7:0] s_array_index_31458;
    wire [6:0] s_word__54;
    wire [0:0] s_word__53;
    wire [7:0] s_word__51;
    wire [7:0] s_word__50;
    wire [7:0] s_word__47;
    wire [0:0] s_b__17;
    wire [31:0] s_word__49;
    wire [31:0] s_word__52;
    wire [31:0] s_word__55;
    wire [7:0] s_bit_slice_31463;
    wire [7:0] s_bit_slice_31464;
    wire [7:0] s_bit_slice_31465;
    wire [7:0] s_bit_slice_31466;
    wire [31:0] s_word;
    wire [31:0] s_word__29;
    wire [7:0] s_array_index_31467;
