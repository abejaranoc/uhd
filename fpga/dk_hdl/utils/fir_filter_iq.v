module fir_filter_iq #(
  parameter DATA_WIDTH    = 16,
  parameter COEFF_WIDTH   = 16,
  parameter NUM_COEFFS    = 1024,
  parameter [NUM_COEFFS*COEFF_WIDTH-1:0] COEFFS_VEC =
      {{1'b0,{(COEFF_WIDTH-1){1'b1}}},{(COEFF_WIDTH*(NUM_COEFFS-1)){1'b0}}}, 
  parameter RELOADABLE_COEFFS = 1
      
)(
  input   clk,
  input   reset,

  /* IQ input */
  input  in_tvalid,
  input  in_tlast, 
  output in_tready,
  input [DATA_WIDTH-1:0]  in_i,
  input [DATA_WIDTH-1:0]  in_q,

  input [COEFF_WIDTH-1:0] coeff_in,
  input reload_tvalid,
  input reload_tlast,

  /* IQ output */
  output  out_tlast,
  output  out_tvalid,
  input   out_tready,
  output [DATA_WIDTH-1:0]  out_i,
  output [DATA_WIDTH-1:0]  out_q

);

axi_fir_filter #(.IN_WIDTH(DATA_WIDTH), .COEFF_WIDTH(COEFF_WIDTH), 
                 .OUT_WIDTH(DATA_WIDTH), .NUM_COEFFS(NUM_COEFFS), 
                 .COEFFS_VEC(COEFFS_VEC), .RELOADABLE_COEFFS(RELOADABLE_COEFFS), 
                 .BLANK_OUTPUT(0), .SYMMETRIC_COEFFS(1), .SKIP_ZERO_COEFFS(0), 
                 .USE_EMBEDDED_REGS_COEFFS(1)
) fir_real(
  .clk(clk), .reset(reset), .clear(reset),
  .s_axis_data_tdata(in_i), .s_axis_data_tlast(in_tlast), 
  .s_axis_data_tvalid(in_tvalid), .s_axis_data_tready(in_tready),
  .m_axis_data_tdata(out_i), .m_axis_data_tlast(out_tlast), 
  .m_axis_data_tvalid(out_tvalid), .m_axis_data_tready(out_tready),
  .s_axis_reload_tdata(coeff_in), .s_axis_reload_tvalid(reload_tvalid),
  .s_axis_reload_tlast(reload_tlast), .s_axis_reload_tready());

axi_fir_filter #(.IN_WIDTH(DATA_WIDTH), .COEFF_WIDTH(COEFF_WIDTH), 
                 .OUT_WIDTH(DATA_WIDTH), .NUM_COEFFS(NUM_COEFFS), 
                 .COEFFS_VEC(COEFFS_VEC), .RELOADABLE_COEFFS(RELOADABLE_COEFFS), 
                 .BLANK_OUTPUT(0), .SYMMETRIC_COEFFS(1), .SKIP_ZERO_COEFFS(0), 
                 .USE_EMBEDDED_REGS_COEFFS(1)
) fir_imag(
  .clk(clk), .reset(reset), .clear(reset),
  .s_axis_data_tdata(in_q), .s_axis_data_tlast(in_tlast), 
  .s_axis_data_tvalid(in_tvalid), .s_axis_data_tready(in_tready),
  .m_axis_data_tdata(out_q), .m_axis_data_tlast(), 
  .m_axis_data_tvalid(), .m_axis_data_tready(out_tready),
  .s_axis_reload_tdata(coeff_in), .s_axis_reload_tvalid(reload_tvalid),
  .s_axis_reload_tlast(reload_tlast), .s_axis_reload_tready());

endmodule