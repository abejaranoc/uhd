module  cmoving_avg #(
  parameter DATA_WIDTH = 16,
  parameter MAX_LEN    = 2047,
  parameter [$clog2(MAX_LEN+1)-1:0] LEN = 2046 
)(
  input clk,
  input reset,
  input clear,

  /* IQ input */
  input  in_tvalid,
  input  in_tlast, 
  output in_tready,
  input [DATA_WIDTH-1:0]  in_itdata,
  input [DATA_WIDTH-1:0]  in_qtdata,

  /*output average*/
  output  out_tlast,
  output  out_tvalid,
  input   out_tready,
  output [DATA_WIDTH-1:0]  out_itdata,
  output [DATA_WIDTH-1:0]  out_qtdata
);

wire iin_tready, iout_tlast, iout_tvalid, iout_tready;
wire qin_tready, qout_tlast, qout_tvalid, qout_tready;
wire [DATA_WIDTH+$clog2(MAX_LEN+1)-1:0] i_mov_sum, q_mov_sum;

wire  o_irc_tlast, o_irc_tvalid;
wire  o_qrc_tlast, o_qrc_tvalid;

assign in_tready  = iin_tready ;
assign out_tlast  = o_irc_tlast ;
assign out_tvalid = o_irc_tvalid;


moving_sum #(
  .MAX_LEN(MAX_LEN), .WIDTH(DATA_WIDTH))
    I_MOVING_SUM(
      .clk(clk), .reset(reset), 
      .clear(clear), .len(LEN), 
      .i_tdata(in_itdata), .i_tlast(in_tlast), 
      .i_tvalid(in_tvalid), .i_tready(iin_tready),
      .o_tdata(i_mov_sum), .o_tlast(iout_tlast), 
      .o_tvalid(iout_tvalid), .o_tready(iout_tready)
    );

moving_sum #(
  .MAX_LEN(MAX_LEN), .WIDTH(DATA_WIDTH))
    Q_MOVING_SUM(
      .clk(clk), .reset(reset), 
      .clear(clear), .len(LEN), 
      .i_tdata(in_qtdata), .i_tlast(in_tlast), 
      .i_tvalid(in_tvalid), .i_tready(qin_tready),
      .o_tdata(q_mov_sum), .o_tlast(qout_tlast), 
      .o_tvalid(qout_tvalid), .o_tready(qout_tready)
    );

axi_round_and_clip #(
  .WIDTH_IN(DATA_WIDTH + $clog2(MAX_LEN+1)), .WIDTH_OUT(DATA_WIDTH),
  .CLIP_BITS($clog2(MAX_LEN+1) - $clog2(LEN)), .FIFOSIZE(1))
    IRC(
      .clk(clk), .reset(reset),
      .i_tdata(i_mov_sum), .i_tlast(iout_tlast),
      .i_tvalid(iout_tvalid), .i_tready(iout_tready),
      .o_tdata(out_itdata), .o_tlast(o_irc_tlast),
      .o_tvalid(o_irc_tvalid), .o_tready(out_tready)
    );

axi_round_and_clip #(
  .WIDTH_IN(DATA_WIDTH + $clog2(MAX_LEN+1)), .WIDTH_OUT(DATA_WIDTH),
  .CLIP_BITS($clog2(MAX_LEN+1) - $clog2(LEN)), .FIFOSIZE(1))
    QRC(
      .clk(clk), .reset(reset),
      .i_tdata(q_mov_sum), .i_tlast(qout_tlast),
      .i_tvalid(qout_tvalid), .i_tready(qout_tready),
      .o_tdata(out_qtdata), .o_tlast(o_qrc_tlast),
      .o_tvalid(o_qrc_tvalid), .o_tready(out_tready)
    );

endmodule