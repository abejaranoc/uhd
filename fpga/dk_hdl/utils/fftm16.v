module  fftm16#(
  parameter DATA_WIDTH    = 16,
  parameter FFT_OUT_WIDTH = 25, 
  parameter CLIP_BITS     = 0
)(
  input clk,
  input reset,

  /* Time Domain Input */
  input  in_tvalid,
  input  in_tlast, 
  output in_tready,
  input [DATA_WIDTH-1:0]  in_itdata,
  input [DATA_WIDTH-1:0]  in_qtdata,


  /*output FFT*/
  output  out_tlast,
  output  out_tvalid,
  input   out_tready,
  output [DATA_WIDTH-1:0] out_itdata, 
  output [DATA_WIDTH-1:0] out_qtdata
);

wire [FFT_OUT_WIDTH-1:0] fft_out_re, fft_out_im;
wire valid_out;


FFT_Burst FFTM (
  .clk(clk),
  .reset(reset),
  .DataIn_re(in_itdata),  
  .DataIn_im(in_qtdata), 
  .ValidIn(in_tvalid),
  .DataOut_re(fft_out_re),  
  .DataOut_im(fft_out_im),  
  .ValidOut(valid_out),
  .Ready(in_tready));


axi_round_and_clip #( 
  .WIDTH_IN(FFT_OUT_WIDTH), .WIDTH_OUT(DATA_WIDTH), .CLIP_BITS(CLIP_BITS))
    RE_RNC(
      .clk(clk),
      .reset(reset),
      .i_tdata(fft_out_re),
      .i_tlast(in_tlast), 
      .i_tvalid(valid_out), 
      .i_tready(),
      .o_tdata(out_itdata), 
      .o_tvalid(out_tvalid), 
      .o_tready(out_tready), 
      .o_tlast(out_tlast)
    );

  axi_round_and_clip #( 
  .WIDTH_IN(FFT_OUT_WIDTH), .WIDTH_OUT(DATA_WIDTH), .CLIP_BITS(CLIP_BITS))
    IM_RNC(
      .clk(clk),
      .reset(reset),
      .i_tdata(fft_out_im),
      .i_tlast(in_tlast), 
      .i_tvalid(valid_out), 
      .i_tready(),
      .o_tdata(out_qtdata), 
      .o_tvalid(), 
      .o_tready(out_tready), 
      .o_tlast()
    );

endmodule