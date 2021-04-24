module tag_rx_ctrl #(
  parameter DATA_WIDTH     = 16,
  parameter DDS_WIDTH      = 24,
  parameter SIN_COS_WIDTH  = 16,
  parameter PHASE_WIDTH    = 24,
  parameter NSYMB_WIDTH    = 16,
  parameter SCALING_WIDTH  = 18,
  
  parameter [NSYMB_WIDTH-1:0] NSYMB        = 512, 
  parameter [PHASE_WIDTH-1:0] NSIG         = 40960,
  parameter [PHASE_WIDTH-1:0] DPH_INC      = -16384, 
  parameter [PHASE_WIDTH-1:0] START_PH_INC = -4096,
  parameter [PHASE_WIDTH-1:0] START_PH     = 24'h000000,
  parameter [PHASE_WIDTH-1:0] NPH_SHIFT    = 24'h000000
)(
  input   clk,
  input   reset,

  /* RX IQ input */
  input [DATA_WIDTH-1:0]  irx_in,
  input [DATA_WIDTH-1:0]  qrx_in,
  
  /*GPIO IO Registers*/
  input  [GPIO_REG_WIDTH-1:0] fp_gpio_in,
  output [GPIO_REG_WIDTH-1:0] fp_gpio_out,
  output [GPIO_REG_WIDTH-1:0] fp_gpio_ddr,

  output  rx_valid, 

  /* IQ output */
  output [DATA_WIDTH-1:0]  irx_out_bb,
  output [DATA_WIDTH-1:0]  qrx_out_bb, 
/*
  output [DATA_WIDTH-1:0]  irx_out,
  output [DATA_WIDTH-1:0]  qrx_out, 
*/
  /*debug*/
  output [PHASE_WIDTH-1:0]   ph,
  output [NSYMB_WIDTH-1:0] symbN,
  output [SIN_COS_WIDTH-1:0] cos, 
  output [SIN_COS_WIDTH-1:0] sin, 

 
  output rx_sync_en, 
  output rx_trig, 
  output rx_out_mux,
  output [1:0] rx_state

);

  localparam GPIO_REG_WIDTH    = 12;
  localparam GPIO_CLK_DIV_FAC  = 10;
  localparam SYNC_SIG_N        = 8192;
  localparam [GPIO_REG_WIDTH-1:0] SYNC_OUT_MASK = 12'h001;
  localparam [GPIO_REG_WIDTH-1:0] RX_OUT_MASK   = 12'h010;
  localparam [GPIO_REG_WIDTH-1:0] GPIO_OUT_MASK = SYNC_OUT_MASK | RX_OUT_MASK;
  localparam [GPIO_REG_WIDTH-1:0] SYNC_IN_MASK  = 12'h004;
  localparam [GPIO_REG_WIDTH-1:0] RX_IN_MASK    = 12'h040;
  localparam [GPIO_REG_WIDTH-1:0] GPIO_IN_MASK  = SYNC_IN_MASK | RX_IN_MASK;
  localparam [GPIO_REG_WIDTH-1:0] GPIO_IO_DDR   = GPIO_OUT_MASK;

reg sync_en, start_rx, valid_rx;
reg  [1:0] sync_state;
wire rx_sync_ready, tx_trigger;
wire [GPIO_REG_WIDTH-1:0] gpio_out, gpio_in, sync_io_out, rx_io_out;
assign rx_valid = valid_rx;

assign rx_sync_en  = sync_en;
assign rx_trig     = start_rx;
assign rx_state    = sync_state;

wire [DATA_WIDTH-1:0] irx_bb, qrx_bb;
reg  [DATA_WIDTH-1:0] irx_sync, qrx_sync;

reg  [PHASE_WIDTH-1:0]  ncnt;

assign sync_io_out = rx_sync_ready ? SYNC_OUT_MASK : {(GPIO_REG_WIDTH){1'b0}};
assign rx_io_out   = valid_rx ? RX_OUT_MASK : {(GPIO_REG_WIDTH){1'b0}};
assign gpio_out    = sync_io_out | rx_io_out;
assign tx_trigger  = |(gpio_in & SYNC_IN_MASK);

wire out_sel = ^sync_state ;
assign irx_out_bb = out_sel ? irx_sync : irx_bb;
assign qrx_out_bb = out_sel ? qrx_sync : qrx_bb;

assign rx_out_mux  = out_sel;

/*
assign irx_out =  irx_bb;
assign qrx_out =  qrx_bb;
*/
gpio_ctrl #(
  .GPIO_REG_WIDTH(GPIO_REG_WIDTH), .CLK_DIV_FAC(GPIO_CLK_DIV_FAC),             
  .OUT_MASK(GPIO_OUT_MASK), .IN_MASK(GPIO_IN_MASK), 
  .IO_DDR(GPIO_IO_DDR))
    GPIO_CTRL(.clk(clk),.reset(reset),
              .fp_gpio_in(fp_gpio_in), 
              .fp_gpio_out(fp_gpio_out),
              .fp_gpio_ddr(fp_gpio_ddr),
              .gpio_out(gpio_out),
              .gpio_in(gpio_in));

tag_rx #(
  .DATA_WIDTH(DATA_WIDTH), .DDS_WIDTH(DDS_WIDTH), 
  .SIN_COS_WIDTH(SIN_COS_WIDTH), .PHASE_WIDTH(PHASE_WIDTH),
  .NSYMB_WIDTH(NSYMB_WIDTH), .SCALING_WIDTH(SCALING_WIDTH),
  .NSYMB(NSYMB), .NSIG(NSIG), .DPH_INC(DPH_INC), 
  .START_PH_INC(START_PH_INC), .START_PH(START_PH),
  .NPH_SHIFT(NPH_SHIFT))
    TAG_RXB(.clk(clk), .reset(reset), .srst(start_rx),

            /* RX IQ input */
            .irx_in(irx_in), .qrx_in(qrx_in),
            .in_tvalid(1'b1), .in_tlast(1'b0), 

            /* phase valid*/
            .phase_tvalid(1'b1), .phase_tlast(1'b0), 

            /* IQ BB output */
            .out_tready(1'b1), .irx_bb(irx_bb), .qrx_bb(qrx_bb),

            /*toggle for symbol transmission*/
            .sync_ready(rx_sync_ready),

            /*debug*/
            .ph(ph), .symbN(symbN), .sin(sin), .cos(cos));

always @(posedge clk) begin
  if (reset) begin
    sync_en    <= 1'b0;
    valid_rx   <= 1'b0;
    start_rx   <= 1'b0;
    sync_state <= 2'b11;
    ncnt <= 0;
    irx_sync <= 0; qrx_sync <= 0;
  end
  else if (tx_trigger & ~sync_en) begin
    sync_en    <= 1'b1;
    start_rx   <= 1'b0;
    valid_rx   <= 1'b1;
    sync_state <= 2'b11;
    ncnt       <= SYNC_SIG_N;
    irx_sync   <= 16384;
  end
  else if (sync_en && (ncnt == SYNC_SIG_N)) begin
    ncnt    <= 1;
    case (sync_state)
      2'b00: begin
        sync_en   <= 1'b0;
        start_rx  <= 1'b0;
      end
      2'b11:begin
        sync_state <= 2'b10;
        start_rx   <= 1'b1;
        irx_sync   <= 16384;
      end
      2'b10:begin
        sync_state <= 2'b01;
        start_rx   <= 1'b1;
        irx_sync   <= -16384;
      end
      2'b01:begin
        start_rx   <= 1'b0;
        sync_state <= 2'b00;
      end
    endcase
  end
  else if(sync_en) begin
    ncnt <= ncnt + 1;
  end 
  else if (~sync_en && rx_sync_ready) begin
    valid_rx <= 1'b0;
  end
end

endmodule