module cmul_16 #(DATA_WIDTH = 16) (
  input clk, 
  input reset, 
  input [2*DATA_WIDTH-1:0] adata,
  input [2*DATA_WIDTH-1:0] bdata,
  output [2*DATA_WIDTH-1:0] pdata
);

localparam SCALING_WIDTH = 18;
localparam CWIDTH        = 24;
wire [2*CWIDTH-1:0] cm_tdata;
wire [CWIDTH+SCALING_WIDTH-1:0] scaled_i_tdata, scaled_q_tdata;
wire scaled_tlast, scaled_tvalid, scaled_tready;
wire [SCALING_WIDTH-1:0] scaling_tdata = {4'h0, {(SCALING_WIDTH-4){1'b1}}};


wire [63:0] o_tdata;
wire o_tlast, o_tready, o_tvalid;
cmul cmul_inst ( 
  .clk(clk), .reset(reset), 
  .a_tdata(adata), .a_tlast(1'b0), .a_tvalid(1'b1),
  .b_tdata(bdata), .b_tlast(1'b0), .b_tvalid(1'b1),
  .o_tdata(o_tdata), .o_tready(o_tready), .o_tvalid(o_tvalid), .o_tlast(o_tlast));

axi_round_and_clip_complex #(.WIDTH_IN(32), .WIDTH_OUT(CWIDTH) , .CLIP_BITS(4))
  clip_inst ( .clk(clk), .reset(reset),
              .i_tdata(o_tdata), .i_tlast(o_tlast), .i_tvalid(o_tvalid), .i_tready(o_tready),
              .o_tdata(cm_tdata), .o_tready(scaled_tready), .o);


  
endmodule