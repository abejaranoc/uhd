module freq_shift_and_lpf_iq #(
  parameter DATA_WIDTH    = 16,
  parameter DDS_WIDTH     = 24,
  parameter SIN_COS_WIDTH = 16,
  parameter PHASE_WIDTH   = 24, 
  parameter SCALING_WIDTH = 18, 

  parameter COEFF_WIDTH   = 16,
  parameter NUM_COEFFS    = 128,
  parameter [NUM_COEFFS*COEFF_WIDTH-1:0] COEFFS_VEC =
      {{1'b0,{(COEFF_WIDTH-1){1'b1}}},{(COEFF_WIDTH*(NUM_COEFFS-1)){1'b0}}},
  parameter SYMMETRIC_COEFFS = 1, 
  parameter RELOADABLE_COEFFS = 1
)(
  input   clk,
  input   reset,

  /* IQ input */
  input [DATA_WIDTH-1:0]  in_itdata,
  input [DATA_WIDTH-1:0]  in_qtdata,
  input in_tvalid,
  input in_tlast, 
  output in_tready,

  input [SCALING_WIDTH-1:0] scaling_tdata,
  
  /* phase increment */  
  input [PHASE_WIDTH-1:0]  phase_tdata,
  input phase_tvalid,
  input phase_tlast, 
  output phase_tready,

  /* filter coefficients */
  input [COEFF_WIDTH-1:0] coeff_in,
  input reload_tvalid,
  input reload_tlast,

  /*IQ baseband output */
  output [DATA_WIDTH-1:0]  out_itdata,
  output [DATA_WIDTH-1:0]  out_qtdata,
  output  out_tlast,
  output  out_tvalid,
  input   out_tready,

  /* debug signals */
  output [SIN_COS_WIDTH-1:0]  sin,
  output [SIN_COS_WIDTH-1:0]  cos
);

  wire [DATA_WIDTH-1:0] fshift_out_itdata, fshift_out_qtdata;
  wire fshift_out_tlast, fshift_out_tvalid, fshift_out_tready;
  assign fshift_out_tready = 1'b1;


  freq_shift_iq #(  .DATA_WIDTH(DATA_WIDTH),
                    .DDS_WIDTH(DDS_WIDTH),
                    .SIN_COS_WIDTH(SIN_COS_WIDTH),
                    .PHASE_WIDTH(PHASE_WIDTH), 
                    .SCALING_WIDTH(SCALING_WIDTH))

              MIXER(  .clk(clk),
                      .reset(reset),

                      .iin(in_itdata),
                      .qin(in_qtdata),

                      .in_tlast(in_tlast),
                      .in_tvalid(in_tvalid),
                      .in_tready(in_tready),

                      .phase_tdata(phase_tdata),
                      .scaling_tdata(scaling_tdata),

                      .phase_tlast(phase_tlast),
                      .phase_tvalid(phase_tvalid),
                      .phase_tready(phase_tready),

                      .iout(fshift_out_itdata),
                      .qout(fshift_out_qtdata), 
                        
                      .out_tready(fshift_out_tready),
                      .out_tvalid(fshift_out_tvalid),
                      .out_tlast(fshift_out_tlast),

                      .sin(sin), 
                      .cos(cos));

  localparam DCIC_MAX_RATE = 256;
  localparam ICIC_MAX_RATE = 128;
  localparam [$clog2(DCIC_MAX_RATE+1)-1:0] DRATE = 64;
  localparam [$clog2(ICIC_MAX_RATE+1)-1:0] IRATE = 64;
  localparam N = 4;

  wire dcic_strobe_out, dcic_last_out;
  wire [DATA_WIDTH-1:0] dcic_itdata, dcic_qtdata;
  wire rate_stb = 1'b0;

  cic_decimate_iq #(.DATA_WIDTH(DATA_WIDTH),
                    .N(N), .MAX_RATE(DCIC_MAX_RATE))
    DCIC(
          .clk(clk),
          .reset(reset),
          .rate_stb(rate_stb),

          .rate(DRATE),
          .strobe_in(fshift_out_tvalid),
          .strobe_out(dcic_strobe_out),
          
          .last_in(fshift_out_tlast),
          .last_out(dcic_last_out),

          .in_itdata(fshift_out_itdata),
          .in_qtdata(fshift_out_qtdata),

          .out_itdata(dcic_itdata),
          .out_qtdata(dcic_qtdata));

  
  wire [DATA_WIDTH-1:0] lpf_out_itdata, lpf_out_qtdata;
  wire lpf_out_tvalid, lpf_out_tready, lpf_out_tlast; 
  assign lpf_out_tready = 1'b1;

  fir_filter_iq #(.DATA_WIDTH(DATA_WIDTH),
                  .COEFF_WIDTH(COEFF_WIDTH),
                  .NUM_COEFFS(NUM_COEFFS),
                  .SYMMETRIC_COEFFS(SYMMETRIC_COEFFS),
                  .RELOADABLE_COEFFS(RELOADABLE_COEFFS)) 
      LPF(
          .clk(clk),
          .reset(reset),

          .in_tvalid(dcic_strobe_out),
          .in_tlast(dcic_last_out),
          .in_i(dcic_itdata),
          .in_q(dcic_qtdata),

          .coeff_in(coeff_in),
          .reload_tvalid(reload_tvalid),
          .reload_tlast(reload_tlast),

          .out_tready(lpf_out_tready),
          .out_tlast(lpf_out_tlast),
          .out_tvalid(lpf_out_tvalid),

          .out_i(lpf_out_itdata),
          .out_q(lpf_out_qtdata) );

  wire icic_strobe_out;
  assign out_tvalid = icic_strobe_out;
  assign out_tlast  = 1'b0;
  cic_interpolate_iq #(.DATA_WIDTH(DATA_WIDTH),
                       .N(N), .MAX_RATE(ICIC_MAX_RATE))
    ICIC(
          .clk(clk),
          .reset(reset),
          .rate_stb(rate_stb),

          .rate(IRATE),
          .strobe_in(lpf_out_tvalid),
          .strobe_out(icic_strobe_out),

          .in_itdata(lpf_out_itdata),
          .in_qtdata(lpf_out_qtdata),

          .out_itdata(out_itdata),
          .out_qtdata(out_qtdata));


endmodule