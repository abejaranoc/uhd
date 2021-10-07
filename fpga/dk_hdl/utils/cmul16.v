module cmul16 #(
  parameter DATA_WIDTH    = 16
  )(
  input clk, 
  input reset, 

  input  in_tvalid,
  input  in_tlast, 
  output in_tready,
  
  input [2*DATA_WIDTH-1:0] adata,
  input [2*DATA_WIDTH-1:0] bdata,

  output  out_tlast,
  output  out_tvalid,
  input   out_tready,
  output [2*DATA_WIDTH-1:0] pdata
);


wire [63:0] o_tdata;
wire o_tlast, o_tready, o_tvalid;
cmul cmul_inst ( 
  .clk(clk), .reset(reset), 
  .a_tdata(adata), .a_tlast(in_tlast), .a_tvalid(in_tvalid), .a_tready(in_tready),
  .b_tdata(bdata), .b_tlast(in_tlast), .b_tvalid(in_tvalid),
  .o_tdata(o_tdata), .o_tready(o_tready), .o_tvalid(o_tvalid), .o_tlast(o_tlast));

axi_round_and_clip_complex #(.WIDTH_IN(32), .WIDTH_OUT(DATA_WIDTH) , .CLIP_BITS(8))
  clip_inst ( .clk(clk), .reset(reset),
              .i_tdata(o_tdata), .i_tlast(o_tlast), 
              .i_tvalid(o_tvalid), .i_tready(o_tready),
              .o_tdata(pdata), .o_tready(out_tready), 
              .o_tvalid(out_tvalid), .o_tlast(out_tlast));
  
endmodule