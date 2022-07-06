module  ifftm16#(
  parameter DATA_WIDTH    = 16,
  parameter FFT_OUT_WIDTH = 25, 
  parameter CLIP_BITS     = 9
)(
  input clk,
  input reset,

  /*Freq domain Input */
  input  in_tvalid,
  input  in_tlast, 
  output in_tready,
  input [DATA_WIDTH-1:0]  in_itdata,
  input [DATA_WIDTH-1:0]  in_qtdata,


  /*output IFFT*/
  output  out_tlast,
  output  out_tvalid,
  input   out_tready,
  output [DATA_WIDTH-1:0] out_itdata, 
  output [DATA_WIDTH-1:0] out_qtdata
);

wire [FFT_OUT_WIDTH-1:0] fft_out_re, fft_out_im;
reg [DATA_WIDTH-1:0] fft_in_re, fft_in_im;

wire fft_ready, fft_out_valid;
reg fft_in_valid, ready_in;
assign in_tready  = ready_in;

wire [DATA_WIDTH-1:0] ifft_out_re, ifft_out_im;
wire ifft_out_tvalid, ifft_out_tready, ifft_out_tlast;


FFT_Burst FFTM (
  .clk(clk),
  .reset(reset),
  .DataIn_re(fft_in_re), 
  .DataIn_im(fft_in_im),  
  .ValidIn(fft_in_valid),
  .DataOut_re(fft_out_re),  
  .DataOut_im(fft_out_im),  
  .ValidOut(fft_out_valid),
  .Ready(fft_ready));



axi_round_and_clip #( 
  .WIDTH_IN(FFT_OUT_WIDTH), .WIDTH_OUT(DATA_WIDTH), .CLIP_BITS(CLIP_BITS))
    RE_RNC(
      .clk(clk),
      .reset(reset),
      .i_tdata(fft_out_re),
      .i_tlast(in_tlast), 
      .i_tvalid(fft_out_valid), 
      .i_tready(),
      .o_tdata(ifft_out_re), 
      .o_tvalid(ifft_out_tvalid), 
      .o_tready(ifft_out_tready), 
      .o_tlast(ifft_out_tlast)
    );

axi_round_and_clip #( 
  .WIDTH_IN(FFT_OUT_WIDTH), .WIDTH_OUT(DATA_WIDTH), .CLIP_BITS(CLIP_BITS))
    IM_RNC(
      .clk(clk),
      .reset(reset),
      .i_tdata(fft_out_im),
      .i_tlast(in_tlast), 
      .i_tvalid(fft_out_valid), 
      .i_tready(),
      .o_tdata(ifft_out_im), 
      .o_tvalid(), 
      .o_tready(ifft_out_tready), 
      .o_tlast()
    );

conj_flop #(.WIDTH(DATA_WIDTH), .FIFOSIZE(1))
  OUT_CONJ(
    .clk(clk), .reset(reset), .clear(1'b0),
    .i_tdata({ifft_out_re, ifft_out_im}), .i_tlast(ifft_out_tlast), 
    .i_tready(ifft_out_tready), .i_tvalid(ifft_out_tvalid), 
    .o_tdata({out_itdata, out_qtdata}), .o_tlast(out_tlast), 
    .o_tready(out_tready), .o_tvalid(out_tvalid)
  );

always @(posedge clk ) begin
  if (reset) begin
    fft_in_valid <= 1'b0;
    fft_in_im    <= 0;
    fft_in_re    <= 0;
    ready_in     <= 1'b0;
  end
  else begin
    fft_in_valid <= in_tvalid;
    fft_in_re    <= in_itdata;
    fft_in_im    <= -in_qtdata;
    ready_in     <= fft_ready;
  end 
end
endmodule