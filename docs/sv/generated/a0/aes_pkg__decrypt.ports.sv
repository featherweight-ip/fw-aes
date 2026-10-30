// [docs snapshot: ports of rundir/org.fwip.aes.a0-rtl/aes_pkg__decrypt.sv (2318 lines); body left out]
module aes_pkg__decrypt(
  input wire clk,
  input wire rst,
  input wire input_valid,
  input wire [255:0] key,
  input wire [1:0] key_width,
  input wire [127:0] block_,
  output wire output_valid,
  output wire [127:0] out
);
endmodule
