module resample_iq #(
  parameter DATA_WIDTH = 16,
  parameter N = 4, 
  parameter MAX_RATE_DEC = 256,
  parameter MAX_RATE_INT = 128
)(
  input clk,
  input reset,

  input rate_stb,
  input [$clog2(MAX_RATE_DEC+1)-1:0] rate_dec, // +1 due to $clog2() rounding
  input [$clog2(MAX_RATE_INT+1)-1:0] rate_int, // +1 due to $clog2() rounding
  input  strobe_in,
  output strobe_out,
  input [DATA_WIDTH-1:0] in_itdata,
  input [DATA_WIDTH-1:0] in_qtdata,

  output [DATA_WIDTH-1:0] out_itdata,
  output [DATA_WIDTH-1:0] out_qtdata
);

  wire int_istrobe, int_qstrobe;
  wire [DATA_WIDTH-1:0] dec_itdata, dec_qtdata;
  wire idec_strobe_out, qdec_strobe_out;
  //assign last_out = ilast_out & qlast_out;
  assign strobe_out = idec_strobe_out & qdec_strobe_out;
  cic_interpolate #(.WIDTH(DATA_WIDTH),
                    .N(N), .MAX_RATE(MAX_RATE_INT))
    iICIC(
          .clk(clk),
          .reset(reset),
          .rate_stb(rate_stb),

          .rate(rate_int),
          .strobe_in(strobe_in),
          .strobe_out(int_istrobe),

          .signal_in(in_itdata),
          .signal_out(dec_itdata));

  cic_interpolate #(.WIDTH(DATA_WIDTH),
                    .N(N), .MAX_RATE(MAX_RATE_INT))
    qICIC(
          .clk(clk),
          .reset(reset),
          .rate_stb(rate_stb),

          .rate(rate_int),
          .strobe_in(strobe_in),
          .strobe_out(int_qstrobe),

          .signal_in(in_qtdata),
          .signal_out(dec_qtdata));

 
  cic_decimate #( .WIDTH(DATA_WIDTH),
                  .N(N), .MAX_RATE(MAX_RATE_DEC))
    iDCIC(
          .clk(clk),
          .reset(reset),
          .rate_stb(rate_stb),

          .rate(rate_dec),
          .strobe_in(int_istrobe),
          .strobe_out(idec_strobe_out),
          .last_in(1'b0),
          .last_out(),

          .signal_in(dec_itdata),
          .signal_out(out_itdata));

  cic_decimate #( .WIDTH(DATA_WIDTH),
                  .N(N), .MAX_RATE(MAX_RATE_DEC))
    qDCIC(
          .clk(clk),
          .reset(reset),
          .rate_stb(rate_stb),

          .rate(rate_dec),
          .strobe_in(int_qstrobe),
          .strobe_out(qdec_strobe_out),
          .last_in(1'b0),
          .last_out(),

          .signal_in(dec_qtdata),
          .signal_out(out_qtdata));

endmodule