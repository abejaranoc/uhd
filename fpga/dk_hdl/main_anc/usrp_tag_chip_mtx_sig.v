module usrp_tag_chip_mtx_sig #(
  parameter SIN_COS_WIDTH = 16,
  parameter PHASE_WIDTH   = 24 ,
  parameter NSYMB_WIDTH   = 16,
  parameter NLOC_PER_SYNC = 7,
  parameter [NSYMB_WIDTH-1:0] NSYMB         = 512, 
  parameter [PHASE_WIDTH-1:0] NSIG          = 32768,
  parameter [PHASE_WIDTH-1:0] DPH_INC       = 16384,
  parameter [PHASE_WIDTH-1:0] START_PH_INC  = -4185088,

  parameter [NSYMB_WIDTH-1:0] PILOT_NHOP    = 64,
  parameter [PHASE_WIDTH-1:0] PILOT_NSIG    = 262144,
  parameter [PHASE_WIDTH-1:0] PILOT_DPH_INC = 131072,
  parameter [PHASE_WIDTH-1:0] PILOT_SPH_INC = -4192256,
  parameter [PHASE_WIDTH-1:0] START_PH      = 24'h000000
)(
  input   clk,
  input   reset,
  input   srst,

  /* mtx_phase data*/
  input  phase_tvalid, 
  input  phase_tlast, 
  output phase_tready,

  /* IQ output */
  output  out_tlast,
  output  out_tvalid,
  input   out_tready,
  output [SIN_COS_WIDTH-1:0]  imtx,
  output [SIN_COS_WIDTH-1:0]  qmtx,

  output sync_ready,

  /*debug*/
  output [PHASE_WIDTH-1:0] mtx_ph, pilot_ph,
  output [PHASE_WIDTH-1:0] mtx_sigN, pilot_sigN,
  output [NSYMB_WIDTH-1:0] mtx_symbN, pilot_symbN
);

reg  [PHASE_WIDTH-1:0]  mtx_ncount, pilot_ncount;
reg  [NSYMB_WIDTH-1:0]  symb_count, pilot_nhop;
reg  [PHASE_WIDTH-1:0]  mtx_ph_inc, mtx_phase;
reg  [PHASE_WIDTH-1:0]  pilot_ph_inc,  pilot_phase;
wire [PHASE_WIDTH-1:0]  mtx_phase_tdata   = mtx_phase;
wire [PHASE_WIDTH-1:0]  pilot_phase_tdata = pilot_phase;

reg  [$clog2(NLOC_PER_SYNC)-1:0] num_loc;
assign sync_ready = &num_loc;

assign mtx_ph       = mtx_phase;
assign pilot_ph     = pilot_phase;
assign mtx_sigN     = mtx_ncount;
assign pilot_sigN   = pilot_ncount;
assign mtx_symbN    = symb_count;
assign pilot_symbN  = pilot_nhop;

wire [SIN_COS_WIDTH-1:0] mtx_sin, mtx_cos;
wire [SIN_COS_WIDTH-1:0] pilot_sin, pilot_cos;

add2_and_clip_reg sum_01( .clk(clk), .rst(reset), .strobe_in(1'b1),
                          .in1(mtx_cos), .in2(pilot_cos), .sum(imtx));
add2_and_clip_reg sum_02( .clk(clk), .rst(reset), .strobe_in(1'b1),
                          .in1(mtx_sin), .in2(pilot_sin), .sum(qmtx));

dds_sin_cos_lut_only dds_inst (
    .aclk(clk),                                // input wire aclk
    .aresetn(~reset),            // input wire aresetn active low rst
    .s_axis_phase_tvalid(phase_tvalid),  // input wire s_axis_phase_tvalid
    .s_axis_phase_tready(phase_tready),  // output wire s_axis_phase_tready
    .s_axis_phase_tlast(phase_tlast),    //tlast
    .s_axis_phase_tdata(mtx_phase_tdata),    // input wire [23 : 0] s_axis_phase_tdata
    .m_axis_data_tvalid(out_tvalid),    // output wire m_axis_data_tvalid
    .m_axis_data_tready(out_tready),    // input wire m_axis_data_tready
    .m_axis_data_tlast(out_tlast),      // output wire m_axis_data_tready
    .m_axis_data_tdata({mtx_sin, mtx_cos})      // output wire [31 : 0] m_axis_data_tdata
);

dds_sin_cos_lut_only dds_inst_pilot (
    .aclk(clk),                                // input wire aclk
    .aresetn(~reset),            // input wire aresetn active low rst
    .s_axis_phase_tvalid(phase_tvalid),  // input wire s_axis_phase_tvalid
    .s_axis_phase_tready(),  // output wire s_axis_phase_tready
    .s_axis_phase_tlast(phase_tlast),    //tlast
    .s_axis_phase_tdata(pilot_phase_tdata),    // input wire [23 : 0] s_axis_phase_tdata
    .m_axis_data_tvalid(),    // output wire m_axis_data_tvalid
    .m_axis_data_tready(out_tready),    // input wire m_axis_data_tready
    .m_axis_data_tlast(),      // output wire m_axis_data_tready
    .m_axis_data_tdata({pilot_sin, pilot_cos})      // output wire [31 : 0] m_axis_data_tdata
);

always @(posedge clk) begin
    if (reset || srst) begin
      mtx_phase  <= START_PH;
      mtx_ncount <= 1;
      symb_count <= 1;
      mtx_ph_inc <= START_PH_INC;
      num_loc    <= 0;
    end 
    else if (mtx_ncount == NSIG) begin 
      mtx_ncount <= 1;
      mtx_phase  <= START_PH;
      if (symb_count == NSYMB) begin
        num_loc    <= num_loc + 1;
        symb_count <= 1;
        mtx_ph_inc <= START_PH_INC;
      end else begin
        symb_count <= symb_count + 1;
        mtx_ph_inc <= mtx_ph_inc + DPH_INC;
      end   
    end
    else begin
      mtx_phase  <= mtx_phase + mtx_ph_inc;
      mtx_ncount <= mtx_ncount + 1;
    end
end

always @(posedge clk) begin
  if (reset || srst) begin
    pilot_ncount <= 1;
    pilot_nhop   <= 1;
    pilot_phase  <= START_PH;
    pilot_ph_inc <= PILOT_SPH_INC;
  end
  else if (pilot_ncount == PILOT_NSIG) begin
    pilot_ncount <= 1;
    pilot_phase  <= START_PH;
    if (pilot_nhop == PILOT_NHOP) begin
      pilot_nhop   <= 1;
      pilot_ph_inc <= PILOT_SPH_INC;
    end
    else begin
      pilot_nhop   <= pilot_nhop + 1;
      pilot_ph_inc <= pilot_ph_inc + PILOT_DPH_INC;
    end
  end
  else begin
    pilot_ncount <= pilot_ncount + 1;
    pilot_phase  <= pilot_phase + pilot_ph_inc;
  end
  
end

endmodule