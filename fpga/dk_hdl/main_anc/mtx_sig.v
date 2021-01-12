module mtx_sig #(
  parameter SIN_COS_WIDTH = 16,
  parameter PHASE_WIDTH = 24 
)(
  input   clk,
  input   reset,

  /* phase data*/
  
  input  phase_tvalid, 
  input  phase_tlast, 
  output phase_tready,

  /* IQ output */
  output  out_tlast,
  output  out_tvalid,
  input   out_tready,
  output [SIN_COS_WIDTH-1:0]  sin,
  output [SIN_COS_WIDTH-1:0]  cos,

  /*debug*/
  output [PHASE_WIDTH-1:0] ph,
  output [PHASE_WIDTH-1:0] sig_count,
  output [PHASE_WIDTH-1:0] st_ph,
  output [15:0] scount
);

localparam [15:0] NSYMB        = 16;
localparam [PHASE_WIDTH-1:0] NSIG         = 1280;
localparam [PHASE_WIDTH-1:0] DPH_INC      = 16384;
localparam [PHASE_WIDTH-1:0] START_PH_INC = 16384;

localparam [PHASE_WIDTH-1:0] START_PH =  (1 << (PHASE_WIDTH - 1)) 
                                        + (1 << (PHASE_WIDTH - 2));
localparam [PHASE_WIDTH-1:0] NPH_SHIFT = (1 << (PHASE_WIDTH - 2));
reg  [PHASE_WIDTH-1:0] ncount;

reg  [15:0] symb_count;
reg  [PHASE_WIDTH-1:0]  phase_inc, start_phase, phase, ph_inc;
wire [PHASE_WIDTH-1:0] phase_tdata = phase;

assign ph = phase;
assign st_ph = start_phase;
assign sig_count = ncount;
assign scount  = symb_count;
dds_sin_cos_lut_only dds_inst (
    .aclk(clk),                                // input wire aclk
    .aresetn(~reset),            // input wire aresetn active low rst
    .s_axis_phase_tvalid(phase_tvalid),  // input wire s_axis_phase_tvalid
    .s_axis_phase_tready(phase_tready),  // output wire s_axis_phase_tready
    .s_axis_phase_tlast(phase_tlast),    //tlast
    .s_axis_phase_tdata(phase_tdata),    // input wire [23 : 0] s_axis_phase_tdata
    .m_axis_data_tvalid(out_tvalid),    // output wire m_axis_data_tvalid
    .m_axis_data_tready(out_tready),    // input wire m_axis_data_tready
    .m_axis_data_tlast(out_tlast),      // output wire m_axis_data_tready
    .m_axis_data_tdata({sin, cos})      // output wire [31 : 0] m_axis_data_tdata
);

always @(posedge clk) begin
    if (reset ) begin
      phase  <= START_PH;
      ncount <= NSIG;
      symb_count <= NSYMB;
      ph_inc <= START_PH_INC;
      start_phase <= START_PH;
    end 
    /*
    else if (symb_count == NSYMB) begin
      phase  <= START_PH;
      ncount <= 0;
      symb_count <= 0;
      ph_inc <= START_PH_INC;
      start_phase <= START_PH - NPH_SHIFT;
    end 
    */
    else if (ncount == NSIG) begin 
      ncount <= 1;
      if (symb_count == NSYMB) begin
        symb_count <= 1;
        phase  <= START_PH;
        ph_inc <= START_PH_INC;
        start_phase <= START_PH - NPH_SHIFT;
      end else begin
        phase  <= start_phase;
        symb_count <= symb_count + 1;
        ph_inc <= ph_inc + DPH_INC;
        start_phase <= start_phase - NPH_SHIFT;
      end   
    end
    else begin
      phase  <= phase + ph_inc;
      ncount <= ncount + 1;
    end
end

endmodule