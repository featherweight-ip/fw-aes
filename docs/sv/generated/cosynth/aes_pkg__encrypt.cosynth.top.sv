// [docs snapshot: top module of the a0-cs co-synthesis output (X6+X2+X1+X3); copied from the cosynth pass, not in rundir/]
module aes_pkg__encrypt(
    input   wire clk,
    input   wire rst,
    input   wire input_valid,
    input   wire [255:0] key,
    input   wire [1:0] key_width,
    input   wire [127:0] block_,
    output  wire output_valid,
    output  wire [127:0] out
);
    // no input flops remain: stage 0 runs in the input_valid cycle (v0 folded, latency -1)
    wire v0 = input_valid;
    wire [0:0] n1_b__17;
    wire [0:0] n1_or_50186;
    wire [31:0] n1_word__172;
    wire [7:0] n1_word__15;
    wire [7:0] n1_word__13;
    wire [7:0] n1_word__12;
    wire [7:0] n1_word__11;
    wire [31:0] n1_word__184;
    wire [31:0] n1_word__190;
    wire [31:0] n1_word__196;
    wire [31:0] n1_sel_31603;
    wire [31:0] n1_sel_31606;
    wire [31:0] n1_sel_31608;
    wire [7:0] n1_array_index_33517;
    wire [7:0] n1_array_index_33506;
    wire [7:0] n1_array_index_33510;
    wire [7:0] n1_array_index_33515;
    wire [7:0] n1_array_index_33505;
    wire [7:0] n1_array_index_33512;
    wire [7:0] n1_array_index_33511;
    wire [7:0] n1_array_index_33516;
    wire [7:0] n1_xor_35796;
    wire [7:0] n1_xor_35797;
    wire [7:0] n1_xor_35798;
    wire [7:0] n1_xor_35795;
    wire [7:0] n1_array_index_33772;
    wire [7:0] n1_array_index_33774;
    wire [7:0] n1_array_index_33773;
    wire [7:0] n1_array_index_33775;
    logic v1;
    logic [0:0] p1_b__17;
    logic [0:0] p1_or_50186;
    logic [31:0] p1_word__172;
    logic [7:0] p1_word__15;
    logic [7:0] p1_word__13;
    logic [7:0] p1_word__12;
    logic [7:0] p1_word__11;
    logic [31:0] p1_word__184;
    logic [31:0] p1_word__190;
    logic [31:0] p1_word__196;
    logic [31:0] p1_sel_31603;
    logic [31:0] p1_sel_31606;
    logic [31:0] p1_sel_31608;
    logic [7:0] p1_array_index_33517;
    logic [7:0] p1_array_index_33506;
    logic [7:0] p1_array_index_33510;
    logic [7:0] p1_array_index_33515;
    logic [7:0] p1_array_index_33505;
    logic [7:0] p1_array_index_33512;
    logic [7:0] p1_array_index_33511;
    logic [7:0] p1_array_index_33516;
    logic [7:0] p1_xor_35796;
    logic [7:0] p1_xor_35797;
    logic [7:0] p1_xor_35798;
    logic [7:0] p1_xor_35795;
    logic [7:0] p1_array_index_33772;
    logic [7:0] p1_array_index_33774;
    logic [7:0] p1_array_index_33773;
    logic [7:0] p1_array_index_33775;
    wire [127:0] n2_b__16;
    logic v2;
    logic [127:0] out_flop;
    aes_pkg__encrypt__stage0 u_stage0(
        .r_key({128'b0, key[127:0]}),
        .r_key_width(2'b0),
        .r_block_(block_[127:0]),
        .n_b__17(n1_b__17),
        .n_or_50186(n1_or_50186),
        .n_word__172(n1_word__172),
        .n_word__15(n1_word__15),
        .n_word__13(n1_word__13),
        .n_word__12(n1_word__12),
        .n_word__11(n1_word__11),
        .n_word__184(n1_word__184),
        .n_word__190(n1_word__190),
        .n_word__196(n1_word__196),
        .n_sel_31603(n1_sel_31603),
        .n_sel_31606(n1_sel_31606),
        .n_sel_31608(n1_sel_31608),
        .n_array_index_33517(n1_array_index_33517),
        .n_array_index_33506(n1_array_index_33506),
        .n_array_index_33510(n1_array_index_33510),
        .n_array_index_33515(n1_array_index_33515),
        .n_array_index_33505(n1_array_index_33505),
        .n_array_index_33512(n1_array_index_33512),
        .n_array_index_33511(n1_array_index_33511),
        .n_array_index_33516(n1_array_index_33516),
        .n_xor_35796(n1_xor_35796),
        .n_xor_35797(n1_xor_35797),
        .n_xor_35798(n1_xor_35798),
        .n_xor_35795(n1_xor_35795),
        .n_array_index_33772(n1_array_index_33772),
        .n_array_index_33774(n1_array_index_33774),
        .n_array_index_33773(n1_array_index_33773),
        .n_array_index_33775(n1_array_index_33775));
    aes_pkg__encrypt__stage1 u_stage1(
        .r_b__17(p1_b__17),
        .r_or_50186(p1_or_50186),
        .r_word__172(p1_word__172),
        .r_word__15(p1_word__15),
        .r_word__13(p1_word__13),
        .r_word__12(p1_word__12),
        .r_word__11(p1_word__11),
        .r_word__184(p1_word__184),
        .r_word__190(p1_word__190),
        .r_word__196(p1_word__196),
        .r_sel_31603(p1_sel_31603),
        .r_sel_31606(p1_sel_31606),
        .r_sel_31608(p1_sel_31608),
        .r_array_index_33517(p1_array_index_33517),
        .r_array_index_33506(p1_array_index_33506),
        .r_array_index_33510(p1_array_index_33510),
        .r_array_index_33515(p1_array_index_33515),
        .r_array_index_33505(p1_array_index_33505),
        .r_array_index_33512(p1_array_index_33512),
        .r_array_index_33511(p1_array_index_33511),
        .r_array_index_33516(p1_array_index_33516),
        .r_xor_35796(p1_xor_35796),
        .r_xor_35797(p1_xor_35797),
        .r_xor_35798(p1_xor_35798),
        .r_xor_35795(p1_xor_35795),
        .r_array_index_33772(p1_array_index_33772),
        .r_array_index_33774(p1_array_index_33774),
        .r_array_index_33773(p1_array_index_33773),
        .r_array_index_33775(p1_array_index_33775),
        .n_b__16(n2_b__16));
    always_ff @(posedge clk) begin
        if (rst) begin
            v1 <= 1'b0;
            v2 <= 1'b0;
        end else begin
            v1 <= v0;
            v2 <= v1;
        end
    end
    // data registers: no reset (X3)
    always_ff @(posedge clk) begin
        p1_b__17 <= n1_b__17;
        p1_or_50186 <= n1_or_50186;
        p1_word__172 <= n1_word__172;
        p1_word__15 <= n1_word__15;
        p1_word__13 <= n1_word__13;
        p1_word__12 <= n1_word__12;
        p1_word__11 <= n1_word__11;
        p1_word__184 <= n1_word__184;
        p1_word__190 <= n1_word__190;
        p1_word__196 <= n1_word__196;
        p1_sel_31603 <= n1_sel_31603;
        p1_sel_31606 <= n1_sel_31606;
        p1_sel_31608 <= n1_sel_31608;
        p1_array_index_33517 <= n1_array_index_33517;
        p1_array_index_33506 <= n1_array_index_33506;
        p1_array_index_33510 <= n1_array_index_33510;
        p1_array_index_33515 <= n1_array_index_33515;
        p1_array_index_33505 <= n1_array_index_33505;
        p1_array_index_33512 <= n1_array_index_33512;
        p1_array_index_33511 <= n1_array_index_33511;
        p1_array_index_33516 <= n1_array_index_33516;
        p1_xor_35796 <= n1_xor_35796;
        p1_xor_35797 <= n1_xor_35797;
        p1_xor_35798 <= n1_xor_35798;
        p1_xor_35795 <= n1_xor_35795;
        p1_array_index_33772 <= n1_array_index_33772;
        p1_array_index_33774 <= n1_array_index_33774;
        p1_array_index_33773 <= n1_array_index_33773;
        p1_array_index_33775 <= n1_array_index_33775;
        if (v1) out_flop <= n2_b__16;
    end
    assign output_valid = v2;
    assign out = out_flop;
endmodule
