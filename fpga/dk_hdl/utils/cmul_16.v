module cmul_16 #(
  parameter DATA_WIDTH    = 16, 
  parameter SCALING_WIDTH = 18
  )(
  input clk, 
  input reset, 

  input  in_tvalid,
  input  in_tlast, 
  output in_tready,
  
  input [2*DATA_WIDTH-1:0] adata,
  input [2*DATA_WIDTH-1:0] bdata,

  input [SCALING_WIDTH-1:0] scale_val,

  output  out_tlast,
  output  out_tvalid,
  input   out_tready,
  output [2*DATA_WIDTH-1:0] pdata
);

localparam CWIDTH        = 24;
wire [2*CWIDTH-1:0] cm_tdata;
wire [CWIDTH+SCALING_WIDTH-1:0] scaled_i_tdata, scaled_q_tdata;
wire clip_tlast, clip_tvalid, clip_tready;
wire scaled_tlast, scaled_tvalid, scaled_tready;



wire [63:0] o_tdata;
wire o_tlast, o_tready, o_tvalid;
cmul cmul_inst ( 
  .clk(clk), .reset(reset), 
  .a_tdata(adata), .a_tlast(in_tlast), .a_tvalid(in_tvalid), .a_tready(in_tready),
  .b_tdata(bdata), .b_tlast(in_tlast), .b_tvalid(in_tvalid),
  .o_tdata(o_tdata), .o_tready(o_tready), .o_tvalid(o_tvalid), .o_tlast(o_tlast));

axi_round_and_clip_complex #(.WIDTH_IN(32), .WIDTH_OUT(CWIDTH) , .CLIP_BITS(4))
  clip_inst ( .clk(clk), .reset(reset),
              .i_tdata(o_tdata), .i_tlast(o_tlast), 
              .i_tvalid(o_tvalid), .i_tready(o_tready),
              .o_tdata(cm_tdata), .o_tready(clip_tready), 
              .o_tvalid(clip_tvalid), .o_tlast(clip_tlast));

mult #(
    .WIDTH_A(CWIDTH),
    .WIDTH_B(SCALING_WIDTH),
    .WIDTH_P(CWIDTH+SCALING_WIDTH),
    .DROP_TOP_P(4),
    .LATENCY(3),
    .CASCADE_OUT(0))
    i_mult (
      .clk(clk), .reset(reset),
      .a_tdata(cm_tdata[2*CWIDTH-1:CWIDTH]), .a_tlast(clip_tlast), 
      .a_tvalid(clip_tvalid), .a_tready(clip_tready),
      .b_tdata(scale_val), .b_tlast(clip_tlast), 
      .b_tvalid(clip_tvalid), .b_tready(clip_tready),
      .p_tdata(scaled_i_tdata), .p_tlast(scaled_tlast), 
      .p_tvalid(scaled_tvalid), .p_tready(scaled_tready));

mult #(
    .WIDTH_A(CWIDTH),
    .WIDTH_B(SCALING_WIDTH),
    .WIDTH_P(CWIDTH+SCALING_WIDTH),
    .DROP_TOP_P(4),
    .LATENCY(3),
    .CASCADE_OUT(0))
    q_mult (
      .clk(clk), .reset(reset),
      .a_tdata(cm_tdata[CWIDTH-1:0]), .a_tlast(clip_tlast), 
      .a_tvalid(clip_tvalid), .a_tready(clip_tready),
      .b_tdata(scale_val), .b_tlast(clip_tlast), 
      .b_tvalid(clip_tvalid), .b_tready(clip_tready),
      .p_tdata(scaled_q_tdata), .p_tlast(scaled_tlast), 
      .p_tvalid(scaled_tvalid), .p_tready(scaled_tready));

axi_round_and_clip_complex #(.WIDTH_IN(CWIDTH+SCALING_WIDTH), 
                             .WIDTH_OUT(DATA_WIDTH), 
                             .CLIP_BITS(12))
    axi_round_and_clip_complex (
        .clk(clk), .reset(reset),
        .i_tdata({scaled_i_tdata, scaled_q_tdata}), 
        .i_tlast(scaled_tlast), .i_tvalid(scaled_tvalid), .i_tready(scaled_tready),
        .o_tdata(pdata), .o_tlast(out_tlast), 
        .o_tvalid(out_tvalid), .o_tready(out_tready));
  
endmodule