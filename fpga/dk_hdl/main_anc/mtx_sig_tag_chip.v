module mtx_sig_tag_chip #(
  parameter DATA_WIDTH    = 16,
  parameter SIN_COS_WIDTH = 16,
  parameter PHASE_WIDTH   = 24,
  parameter NSYMB_WIDTH   = 16,
  parameter TX_SYNC_BITS  = 3,
  parameter [NSYMB_WIDTH-1:0] NSYMB        = 9, 
  parameter [PHASE_WIDTH-1:0] NSIG         = 32768,
  parameter [PHASE_WIDTH-1:0] DPH_INC      = 16384,
  parameter [PHASE_WIDTH-1:0] START_PH_INC = 12288,
  parameter [PHASE_WIDTH-1:0] PILOT_PH_INC = 4096,
  parameter [PHASE_WIDTH-1:0] START_PH     = 24'h000000,
  parameter [PHASE_WIDTH-1:0] NPH_SHIFT    = 24'h000000
)(
  input   clk,
  input   reset,
  input   srst,

  /* mtx_phase data*/
  input  phase_tvalid, 
  input  phase_tlast, 
  input [PHASE_WIDTH-1:0] hop_phase_inc,
  output phase_tready,

  /* IQ output */
  output  out_tlast,
  output  out_tvalid,
  input   out_tready,
  output [DATA_WIDTH-1:0]  itx,
  output [DATA_WIDTH-1:0]  qtx,

  output hop_ready,

  /*debug*/
  output [PHASE_WIDTH-1:0] mtx_ph,
  output [PHASE_WIDTH-1:0] pilot_ph,
  output [PHASE_WIDTH-1:0] sigN,
  output [NSYMB_WIDTH-1:0] symbN,
  output [2*SIN_COS_WIDTH-1:0] mtx_data,
  output [2*SIN_COS_WIDTH-1:0] pilot_data
);


reg  [PHASE_WIDTH-1:0]  ncount;
reg  [NSYMB_WIDTH-1:0]  symb_count;
reg  [PHASE_WIDTH-1:0]  tx_freq_ph_inc, mtx_phase, pilot_ph_inc, pilot_phase;
wire [PHASE_WIDTH-1:0]  mtx_ph_tdata = mtx_phase;

wire [PHASE_WIDTH-1:0]  pilot_ph_tdata = pilot_phase;

reg  [TX_SYNC_BITS-1:0] tx_symb_per_synch;
reg   hop_done;

//assign hop_ready = hop_done;
assign hop_ready = (symb_count == NSYMB) & (ncount == NSIG);

wire [SIN_COS_WIDTH-1:0]  mtx_sin, pilot_sin, mtx_cos, pilot_cos, itx, qtx;

add2_and_clip sum_01(.in1(mtx_cos), .in2(pilot_cos), .sum(itx));
add2_and_clip sum_02(.in1(mtx_sin), .in2(pilot_sin), .sum(qtx));

assign mtx_data   = {mtx_cos, mtx_sin};
assign pilot_data = {pilot_cos, pilot_sin};

assign mtx_ph   = mtx_phase;
assign pilot_ph = pilot_phase;
assign sigN     = ncount;
assign symbN    = symb_count;

dds_sin_cos_lut_only dds_inst (
    .aclk(clk),                                // input wire aclk
    .aresetn(~reset),            // input wire aresetn active low rst
    .s_axis_phase_tvalid(phase_tvalid),  // input wire s_axis_phase_tvalid
    .s_axis_phase_tready(phase_tready),  // output wire s_axis_phase_tready
    .s_axis_phase_tlast(phase_tlast),    //tlast
    .s_axis_phase_tdata(mtx_ph_tdata),    // input wire [23 : 0] s_axis_phase_tdata
    .m_axis_data_tvalid(out_tvalid),    // output wire m_axis_data_tvalid
    .m_axis_data_tready(out_tready),    // input wire m_axis_data_tready
    .m_axis_data_tlast(out_tlast),      // output wire m_axis_data_tready
    .m_axis_data_tdata({mtx_sin, mtx_cos})      // output wire [31 : 0] m_axis_data_tdata
);

dds_sin_cos_lut_only dds_inst2 (
    .aclk(clk),                                // input wire aclk
    .aresetn(~reset),            // input wire aresetn active low rst
    .s_axis_phase_tvalid(phase_tvalid),  // input wire s_axis_phase_tvalid
    .s_axis_phase_tready(),  // output wire s_axis_phase_tready
    .s_axis_phase_tlast(phase_tlast),    //tlast
    .s_axis_phase_tdata(pilot_ph_tdata),    // input wire [23 : 0] s_axis_phase_tdata
    .m_axis_data_tvalid(),    // output wire m_axis_data_tvalid
    .m_axis_data_tready(out_tready),    // input wire m_axis_data_tready
    .m_axis_data_tlast(),      // output wire m_axis_data_tready
    .m_axis_data_tdata({pilot_sin, pilot_cos})      // output wire [31 : 0] m_axis_data_tdata
);

always @(posedge clk) begin
    if (reset || srst) begin
      mtx_phase  <= START_PH;
      pilot_phase <= START_PH; 
      ncount <= 1;
      symb_count <= 1;
      tx_freq_ph_inc  <= hop_phase_inc + START_PH_INC;
      pilot_ph_inc    <= hop_phase_inc + PILOT_PH_INC;
      hop_done <= 1'b0;
    end 
    else if (ncount == NSIG) begin 
      ncount <= 1;
      pilot_phase <= START_PH;
      mtx_phase   <= START_PH;
      if (symb_count == NSYMB) begin
        symb_count  <= 1;
        tx_freq_ph_inc   <= hop_phase_inc + START_PH_INC;
        pilot_ph_inc     <= hop_phase_inc + PILOT_PH_INC;
        hop_done         <= 1'b1;
      end else begin
        symb_count     <= symb_count + 1;
        tx_freq_ph_inc  <= tx_freq_ph_inc + DPH_INC;
      end   
    end
    else begin
      mtx_phase   <= mtx_phase + tx_freq_ph_inc;
      pilot_phase <= pilot_phase + pilot_ph_inc;
      ncount <= ncount + 1;
    end
end

endmodule