module decimate_and_lpf_iq #(
  parameter DATA_WIDTH    = 16,
  parameter NDEC          = 4, 
  parameter DEC_MAX_RATE  = 255,
  parameter [$clog2(DEC_MAX_RATE+1)-1:0] DEC_RATE = 64,

  parameter COEFF_WIDTH   = 16,
  parameter NUM_COEFFS    = 128,
  parameter [NUM_COEFFS*COEFF_WIDTH-1:0] COEFFS_VEC =
      {{1'b0,{(COEFF_WIDTH-1){1'b1}}},{(COEFF_WIDTH*(NUM_COEFFS-1)){1'b0}}},
  parameter SYMMETRIC_COEFFS  = 1, 
  parameter RELOADABLE_COEFFS = 0
)(
  input   clk,
  input   reset,
  input   clear,

  /* IQ input */
  input in_tvalid,
  input in_tlast, 
  output in_tready,
  input [DATA_WIDTH-1:0]  in_itdata,
  input [DATA_WIDTH-1:0]  in_qtdata,
  
  /* filter coefficients */
  input [COEFF_WIDTH-1:0] coeff_in,
  input reload_tvalid,
  input reload_tlast,

  /*IQ lpf data*/
  output  out_tlast,
  output  out_tvalid,
  input   out_tready,
  output [DATA_WIDTH-1:0]  out_itdata,
  output [DATA_WIDTH-1:0]  out_qtdata
);

  wire [DATA_WIDTH-1:0] iq_idec, iq_qdec;
  wire [2*DATA_WIDTH-1:0] dec_tdata;
  wire dec_tlast, dec_tvalid, dec_tready;
  wire dec_last_in, dec_stb_out, dec_stb_in, dec_last_out;
  assign dec_stb_in  = in_tvalid; 
  assign dec_last_in = in_tlast;
  assign in_tready = ~reset;

  cic_decimate_iq #(
    .DATA_WIDTH(DATA_WIDTH), .N(NDEC), .MAX_RATE(DEC_MAX_RATE))
      DEC_IQ(
        .clk(clk), .reset(reset), 
        .rate_stb(reset), .rate(DEC_RATE),
        .strobe_in(dec_stb_in), .strobe_out(dec_stb_out),
        .last_in(dec_last_in), .last_out(dec_last_out),
        .in_itdata(in_itdata), .in_qtdata(in_qtdata),
        .out_itdata(iq_idec), .out_qtdata(iq_qdec)
      );

  strobed_to_axi #(
    .WIDTH(2*DATA_WIDTH))
      strobed_to_axi (
        .clk(clk), .reset(reset), 
        .clear(clear), .in_stb(dec_stb_out), 
        .in_data({iq_idec, iq_qdec}), .in_last(dec_last_out),
        .o_tdata(dec_tdata), .o_tlast(dec_tlast),
        .o_tvalid(dec_tvalid), .o_tready(dec_tready)
      );

  

  fir_filter_iq #(
    .DATA_WIDTH(DATA_WIDTH), .COEFF_WIDTH(COEFF_WIDTH),
    .COEFFS_VEC(COEFFS_VEC), .NUM_COEFFS(NUM_COEFFS),
    .SYMMETRIC_COEFFS(SYMMETRIC_COEFFS), .RELOADABLE_COEFFS(RELOADABLE_COEFFS)) 
      LPF(
        .clk(clk), .reset(reset), .clear(clear),

        .in_tvalid(dec_tvalid), 
        .in_tlast(dec_tlast),
        .in_tready(dec_tready),
        .in_i(dec_tdata[2*DATA_WIDTH-1:DATA_WIDTH]),
        .in_q(dec_tdata[DATA_WIDTH-1:0]),

        .coeff_in(coeff_in),
        .reload_tvalid(reload_tvalid),
        .reload_tlast(reload_tlast),

        .out_tready(out_tready),
        .out_tlast(out_tlast),
        .out_tvalid(out_tvalid),

        .out_i(out_itdata),
        .out_q(out_qtdata));



endmodule