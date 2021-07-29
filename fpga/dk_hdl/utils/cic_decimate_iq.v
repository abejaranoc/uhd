module cic_decimate_iq #(
  parameter DATA_WIDTH = 16,
  parameter N = 4, 
  parameter MAX_RATE = 256
)(
  input clk,
  input reset,

  input rate_stb,
  input [$clog2(MAX_RATE+1)-1:0] rate, // +1 due to $clog2() rounding
  input  strobe_in,
  output strobe_out,
  input  last_in,
  output last_out,
  input [DATA_WIDTH-1:0] in_itdata,
  input [DATA_WIDTH-1:0] in_qtdata,

  output [DATA_WIDTH-1:0] out_itdata
  output [DATA_WIDTH-1:0] out_qtdata
);

  wire istrobe_out, qstrobe_out, ilast_out, qlast_out;
  assign last_out = ilast_out & qlast_out;
  assign strobe_out = istrobe_out & qstrobe_out;
  cic_decimate #( .WIDTH(DATA_WIDTH),
                  .N(N), MAX_RATE(MAX_RATE))
    iDCIC(
          .clk(clk),
          .reset(reset),
          .rate_stb(rate_stb),

          .rate(rate),
          .strobe_in(strobe_in),
          .strobe_out(istrobe_out),
          .last_in(last_in),
          .last_out(ilast_out),

          .signal_in(in_itdata),
          .signal_out(out_itdata));

  cic_decimate #( .WIDTH(DATA_WIDTH),
                  .N(N), MAX_RATE(MAX_RATE))
    qDCIC(
          .clk(clk),
          .reset(reset),
          .rate_stb(rate_stb),

          .rate(rate),
          .strobe_in(strobe_in),
          .strobe_out(qstrobe_out),
          .last_in(last_in),
          .last_out(qlast_out),

          .signal_in(in_qtdata),
          .signal_out(out_qtdata));

endmodule