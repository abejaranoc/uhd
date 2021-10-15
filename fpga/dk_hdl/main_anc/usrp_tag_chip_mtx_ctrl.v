module usrp_tag_chip_mtx_ctrl #(
  parameter DATA_WIDTH     = 16,
  parameter PHASE_WIDTH    = 24,
  parameter NSYMB_WIDTH    = 16,
  parameter GPIO_REG_WIDTH = 12,
  parameter NLOC_PER_SYNC  = 7,
  parameter NPRMB_BITS     = 2046,
  parameter PRMB_OS        = 256,
  parameter NSYMB          = 512, 
  parameter NSIG           = 32768,
  parameter DDS_DELAY      = 32,
  parameter [PHASE_WIDTH-1:0] DPH_INC      = 16384,
  parameter [PHASE_WIDTH-1:0] START_PH_INC = -4185088,

  parameter [NSYMB_WIDTH-1:0] PILOT_NHOP    = 64,
  parameter [PHASE_WIDTH-1:0] PILOT_NSIG    = 262144,
  parameter [PHASE_WIDTH-1:0] PILOT_DPH_INC = 131072,
  parameter [PHASE_WIDTH-1:0] PILOT_SPH_INC = -4192256,
  parameter [PHASE_WIDTH-1:0] START_PH      = 24'h000000
)(
  input   clk,
  input   reset,

  /* IQ output */
  output [DATA_WIDTH-1:0]  itx,
  output [DATA_WIDTH-1:0]  qtx,

   /*GPIO IO Registers*/
  input  [GPIO_REG_WIDTH-1:0] fp_gpio_in,
  output [GPIO_REG_WIDTH-1:0] fp_gpio_out,
  output [GPIO_REG_WIDTH-1:0] fp_gpio_ddr,

  output tx_valid,

  /*debug*/
  output [1:0] tx_state,
  output [DATA_WIDTH-1:0]  imtx,
  output [DATA_WIDTH-1:0]  qmtx,
  output tx_trig,
  output [PHASE_WIDTH-1:0] mtx_ph, pilot_ph,
  output [PHASE_WIDTH-1:0] mtx_sigN, pilot_sigN,
  output [NSYMB_WIDTH-1:0] mtx_symbN, pilot_symbN
);

  reg [1:0] state;
  localparam INIT     = 2'b00;
  localparam LOC_SYNC = 2'b01;
  localparam LOC_IDLE = 2'b10;
  localparam LOC_TX   = 2'b11;

  assign tx_state = state;

  localparam NIDLE    = NSIG;

  reg start_tx;
  reg [$clog2(NSIG + 1)-1:0] nidle;
  wire sync_ready, out_sel;

  wire [DATA_WIDTH-1:0]  qmtx_out, imtx_out;
  wire [DATA_WIDTH-1:0]  itx_out, qtx_out;

  assign tx_trig  = start_tx;
  assign qmtx     = qmtx_out;
  assign imtx     = imtx_out;
  
  assign out_sel  = (state == LOC_SYNC);
  assign tx_valid = ~(state == LOC_IDLE);

  assign fp_gpio_ddr =  12'h0001;
  assign fp_gpio_out = out_sel ? 12'h0001 : 12'h0000;

  reg [$clog2(PRMB_OS + 1)-1:0] os_count;
  reg prmb_bits [0:NPRMB_BITS-1];
  reg [$clog2(NPRMB_BITS + 1)-1:0] nbits;
  initial begin
    $readmemb("/home/user/programs/usrp/uhd/fpga/dk_hdl/main_anc/prmb_bits.mem", prmb_bits);
  end
  
  //wire [DATA_WIDTH-1:0]  prmb_mod_tx;
  //assign prmb_mod_tx = prmb_bits[nbits] ? 16384 : -16384; 
  assign itx_out = out_sel ? ( prmb_bits[nbits] ? 16384 : -16384 ) : imtx_out;
  assign qtx_out = out_sel ? ( prmb_bits[nbits] ? 16384 : -16384 ) : qmtx_out;

  axi_fifo_flop2 #(
    .WIDTH(2*DATA_WIDTH)) 
      fifo_flop2(
        .clk(clk), .reset(reset), .clear(reset),
        .i_tdata({itx_out, qtx_out}), .i_tvalid(phase_tvalid), .i_tready(),
        .o_tdata({itx, qtx}), .o_tready(out_tready)
      );

  wire phase_tlast, phase_tvalid, out_tready;
  assign phase_tlast  = 1'b0;
  assign phase_tvalid = 1'b1;
  assign out_tready   = 1'b1;

  usrp_tag_chip_mtx_sig #(
    .SIN_COS_WIDTH(DATA_WIDTH),.PHASE_WIDTH(PHASE_WIDTH), 
    .NSYMB_WIDTH(NSYMB_WIDTH), .NSIG(NSIG), 
    .NSYMB(NSYMB), .DPH_INC(DPH_INC), 
    .START_PH_INC(START_PH_INC),   .START_PH(START_PH), 
    .PILOT_DPH_INC(PILOT_DPH_INC), .PILOT_SPH_INC(PILOT_SPH_INC),
    .PILOT_NHOP(PILOT_NHOP), .PILOT_NSIG(PILOT_NSIG),
    .NLOC_PER_SYNC(NLOC_PER_SYNC))
      MTX_SIG(
        .clk(clk),
        .reset(reset),
        .srst(start_tx),

        .phase_tlast(phase_tlast),
        .phase_tvalid(phase_tvalid),

        .sync_ready(sync_ready),
        .out_tready(out_tready),
        .imtx(imtx_out), 
        .qmtx(qmtx_out),

        .mtx_symbN(mtx_symbN), .pilot_symbN(pilot_symbN),
        .mtx_sigN(mtx_sigN), .pilot_sigN(pilot_sigN),
        .mtx_ph(mtx_ph), .pilot_ph(pilot_ph)
      );

  always @(posedge clk) begin
      if(reset) begin
        start_tx <= 1'b0;
        state    <= INIT;
        nidle    <= 0;
        nbits    <= 0;
        os_count <= 0;
      end 
      else begin
        case (state)
          INIT: begin
            if (nidle < DDS_DELAY) begin
              nidle <= nidle + 1;
            end
            else begin
              nidle <= 0;
              state <= LOC_SYNC;
            end
          end 
          LOC_SYNC : begin
            if (os_count >= (PRMB_OS-1)) begin
              os_count <= 0;
              if (nbits >= (NPRMB_BITS-1)) begin
                nbits <= 0;
                state <= LOC_IDLE;
              end
              else begin
                nbits <= nbits + 1;
              end
            end
            else begin
              os_count <= os_count + 1;
            end
          end
          LOC_IDLE: begin
            if (nidle < (NIDLE - 1)) begin
              nidle    <= nidle + 1;
              start_tx <= 1'b1;
            end
            else begin
              nidle    <= 0;
              start_tx <= 1'b0;
              state    <= LOC_TX;
            end
          end
          LOC_TX: begin
            if(sync_ready) begin
              state <= INIT;
            end
          end
          default: state <= INIT;
        endcase
      end 
  end

endmodule