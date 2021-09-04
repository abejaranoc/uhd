module mtx_ctrl_tag_chip_nb #(
  parameter DATA_WIDTH     = 16,
  parameter SIN_COS_WIDTH  = 16,
  parameter PHASE_WIDTH    = 24,
  parameter NSYMB_WIDTH    = 16,
  parameter GPIO_REG_WIDTH = 12,
  parameter NHOP_WIDTH     = 8,

  parameter [NHOP_WIDTH-1:0] NUM_HOPS      = 64,
  parameter [NHOP_WIDTH-1:0] NSYMB_PER_HOP = 8,
  parameter [NSYMB_WIDTH-1:0] NSYMB        = 512, 
  parameter [PHASE_WIDTH-1:0] NSIG         = 16384,

  parameter [PHASE_WIDTH-1:0] START_PH_INC = -24'd4194304,
  parameter [PHASE_WIDTH-1:0] MTX_DPH_INC  = 16384,
  parameter [PHASE_WIDTH-1:0] MTX_PH_INC   = 12288,
  parameter [PHASE_WIDTH-1:0] PILOT_PH_INC = 4096,
  parameter [PHASE_WIDTH-1:0] HOP_DPH_INC  = 131072,
  parameter [PHASE_WIDTH-1:0] START_PH     = 24'h000000,
  parameter [PHASE_WIDTH-1:0] NPH_SHIFT    = 24'h000000
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

  /*debug*/
  wire hop_done,
  output [1:0] mtx_state,
  output [2*SIN_COS_WIDTH-1:0] mtx_data,
  output [2*SIN_COS_WIDTH-1:0] pilot_data,
  output [PHASE_WIDTH-1:0] mtx_ph,
  output [PHASE_WIDTH-1:0] pilot_ph,
  output [PHASE_WIDTH-1:0] sigN,
  output [NSYMB_WIDTH-1:0] symbN,
  output [NHOP_WIDTH-1:0] nhop, 
  output [PHASE_WIDTH-1:0] hop_ph_inc,
  output [PHASE_WIDTH-1:0] count_sync
  
);

  localparam GPIO_CLK_DIV_FAC  = 10;
  localparam SYNC_SIG_N        = NSIG;
  localparam [GPIO_REG_WIDTH-1:0] SYNC_OUT_MASK = 12'h001;
  localparam [GPIO_REG_WIDTH-1:0] TX_OUT_MASK   = 12'h010;
  localparam [GPIO_REG_WIDTH-1:0] GPIO_OUT_MASK = SYNC_OUT_MASK | TX_OUT_MASK;
  localparam [GPIO_REG_WIDTH-1:0] GPIO_IN_MASK  = 12'h022;
  localparam [GPIO_REG_WIDTH-1:0] GPIO_IO_DDR   = GPIO_OUT_MASK;



  wire [GPIO_REG_WIDTH-1:0] gpio_out, gpio_in, sync_io_out, tx_io_out;

  wire start_tx;
  reg [1:0] state;
  wire sync_ready;
  wire sync_sel, csel, hop_ready;

  assign mtx_state = state;


  wire [DATA_WIDTH-1:0]  mtx_qdata, mtx_idata;

  

  localparam LOC_SYNCH = 2'b01;
  localparam HOP_SYNCH = 2'b10;
  localparam HOP_TX    = 2'b11;
  localparam INIT      = 2'b00;
  
  assign tx_io_out   = (state == HOP_TX)    ? TX_OUT_MASK : {(GPIO_REG_WIDTH){1'b0}} ;
  assign sync_io_out = (state == LOC_SYNCH) ? SYNC_OUT_MASK : {(GPIO_REG_WIDTH){1'b0}};
  assign gpio_out    = sync_io_out | tx_io_out;



  reg [PHASE_WIDTH-1:0] synch_count;
  assign hop_done = hop_ready;

  assign csel = (synch_count <= (SYNC_SIG_N/4)) ? 1'b1 : 1'b0;
  assign sync_sel = (state == LOC_SYNCH) ? 1'b1 : 1'b0;
  assign start_tx  = csel & sync_sel ; 
  assign itx = start_tx ? 0 : mtx_idata;
  assign qtx = start_tx ? 0 : mtx_qdata;

  assign count_sync = synch_count;


  gpio_ctrl #(
    .GPIO_REG_WIDTH(GPIO_REG_WIDTH), .CLK_DIV_FAC(GPIO_CLK_DIV_FAC),             
    .OUT_MASK(GPIO_OUT_MASK), .IN_MASK(GPIO_IN_MASK), 
    .IO_DDR(GPIO_IO_DDR))
      GPIO_CTRL(.clk(clk), .reset(reset),
                .fp_gpio_in(fp_gpio_in), 
                .fp_gpio_out(fp_gpio_out),
                .fp_gpio_ddr(fp_gpio_ddr),
                .gpio_out(gpio_out),
                .gpio_in(gpio_in));

  mtx_sig_tag_chip_nb #(
            .DATA_WIDTH(DATA_WIDTH), .SIN_COS_WIDTH(DATA_WIDTH), .PHASE_WIDTH(PHASE_WIDTH), 
            .NSYMB_WIDTH(NSYMB_WIDTH), .NHOP_WIDTH(NHOP_WIDTH), .NUM_HOPS(NUM_HOPS),
            .NSIG(NSIG), .NSYMB(NSYMB), .NSYMB_PER_HOP(NSYMB_PER_HOP), 
            
            .MTX_DPH_INC(MTX_DPH_INC), .MTX_PH_INC(MTX_PH_INC), .PILOT_PH_INC(PILOT_PH_INC), 
            .START_PH_INC(START_PH_INC), .HOP_DPH_INC(HOP_DPH_INC),
            .START_PH(START_PH), .NPH_SHIFT(NPH_SHIFT))
      MTX_SIG(.clk(clk),
              .reset(reset),
              .srst(start_tx),

              .phase_tlast(1'b0),
              .phase_tvalid(1'b1),

              .hop_ready(hop_ready),
              .out_tready(1'b1),
              .qtx(mtx_qdata), 
              .itx(mtx_idata),

              .symbN(symbN),
              .nhop(nhop),
              .hop_ph_inc(hop_ph_inc),
              .sigN(sigN),
              .mtx_ph(mtx_ph),
              .pilot_ph(pilot_ph),
              .mtx_data(mtx_data),
              .pilot_data(pilot_data));



  always @(posedge clk ) begin
    if (reset) begin
      state <= INIT;
      synch_count   <= SYNC_SIG_N - 1;
    end
    else begin
      case (state)
        INIT: begin
          state <= LOC_SYNCH;
          synch_count   <= SYNC_SIG_N - 1;
        end 
        LOC_SYNCH: begin
          if (synch_count > 0) begin
            synch_count <= synch_count - 1;
          end
          else begin
            synch_count  <= SYNC_SIG_N - 1;
            state        <= HOP_TX;
          end
        end
        HOP_TX: begin
          if (hop_ready) begin
            synch_count   <= SYNC_SIG_N - 1;
            state <= LOC_SYNCH;
          end
        end
        default: state <= INIT;
      endcase
    end  
  end

endmodule