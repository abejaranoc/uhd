module cmul_16 (
  input clk, 
  input reset, 
  input [31:0] adata,
  input [31:0] bdata,
  output [31:0] pdata
);

wire [63:0] o_tdata;
wire o_tlast, o_tready, o_tvalid;
cmul cmul_inst ( 
  .clk(clk), .reset(reset), 
  .a_tdata(adata), .a_tlast(1'b0), .a_tvalid(1'b1),
  .b_tdata(bdata), .b_tlast(1'b0), .b_tvalid(1'b1),
  .o_tdata(o_tdata), .o_tready(o_tready), .o_tvalid(o_tvalid), .o_tlast(o_tlast));

axi_round_complex #(.WIDTH_IN(32), .WIDTH_OUT(16)) /*, .CLIP_BITS(10))*/
  clip_inst ( .clk(clk), .reset(reset),
              .i_tdata(o_tdata), .i_tlast(o_tlast), .i_tvalid(o_tvalid), .i_tready(o_tready),
              .o_tdata(pdata), .o_tready(1'b1));
  
endmodule