module  cmoving_sum #(
  parameter DATA_WIDTH = 16,
  parameter MAX_LEN    = 4095,
  parameter OUT_WIDTH  = DATA_WIDTH + $clog2(MAX_LEN+1),
  parameter [$clog2(MAX_LEN+1)-1:0] LEN = 4092 
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
  output [OUT_WIDTH-1:0]  out_itdata,
  output [OUT_WIDTH-1:0]  out_qtdata
);



moving_sum #(
  .MAX_LEN(MAX_LEN), .WIDTH(DATA_WIDTH))
    I_MOVING_SUM(
      .clk(clk), .reset(reset), 
      .clear(clear), .len(LEN), 
      .i_tdata(in_itdata), .i_tlast(in_tlast), 
      .i_tvalid(in_tvalid), .i_tready(in_tready),
      .o_tdata(out_itdata), .o_tlast(out_tlast), 
      .o_tvalid(out_tvalid), .o_tready(out_tready)
    );

moving_sum #(
  .MAX_LEN(MAX_LEN), .WIDTH(DATA_WIDTH))
    Q_MOVING_SUM(
      .clk(clk), .reset(reset), 
      .clear(clear), .len(LEN), 
      .i_tdata(in_qtdata), .i_tlast(in_tlast), 
      .i_tvalid(in_tvalid), .i_tready(),
      .o_tdata(out_qtdata), .o_tlast(), 
      .o_tvalid(), .o_tready(out_tready)
    );


endmodule