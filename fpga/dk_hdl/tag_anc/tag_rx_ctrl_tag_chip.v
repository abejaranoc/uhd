module tag_rx_ctrl_tag_chip #(
  parameter DATA_WIDTH     = 16,
  parameter GPIO_REG_WIDTH = 12
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
  output [DATA_WIDTH-1:0]  irx_out,
  output [DATA_WIDTH-1:0]  qrx_out, 

  output [1:0] rx_state,
  output [DATA_WIDTH-1:0] counter_sync
);

  localparam GPIO_CLK_DIV_FAC  = 10;
  localparam SYNC_SIG_N        = 8192;
  localparam [GPIO_REG_WIDTH-1:0] SYNC_OUT_MASK = 12'h001;
  localparam [GPIO_REG_WIDTH-1:0] RX_OUT_MASK   = 12'h010;
  localparam [GPIO_REG_WIDTH-1:0] GPIO_OUT_MASK = SYNC_OUT_MASK | RX_OUT_MASK;
  localparam [GPIO_REG_WIDTH-1:0] SYNC_IN_MASK  = 12'h004;
  localparam [GPIO_REG_WIDTH-1:0] SCAN_IN_MASK  = 12'h040;
  localparam [GPIO_REG_WIDTH-1:0] GPIO_IN_MASK  = SYNC_IN_MASK | SCAN_IN_MASK;
  localparam [GPIO_REG_WIDTH-1:0] GPIO_IO_DDR   = GPIO_OUT_MASK;


  reg  [1:0] state;
  assign rx_state    = state;
  wire [GPIO_REG_WIDTH-1:0] gpio_out, gpio_in, sync_io_out, rx_io_out;

  wire  [DATA_WIDTH-1:0] irx_sync, qrx_sync;

  reg  [DATA_WIDTH-1:0]  sync_count;
  assign counter_sync = sync_count;

  wire sync_ready, sync_trigger, scan_trigger;
  assign sync_io_out = sync_ready ? SYNC_OUT_MASK : {(GPIO_REG_WIDTH){1'b0}};
  assign rx_io_out   = valid_rx   ? RX_OUT_MASK : {(GPIO_REG_WIDTH){1'b0}};
  assign gpio_out    = sync_io_out | rx_io_out;
  assign scan_trigger    = |(gpio_in & SCAN_IN_MASK);
  assign sync_trigger    = |(gpio_in & SYNC_IN_MASK);

  wire out_sel = ^state ;
  assign sync_ready = out_sel;
  assign irx_sync = out_sel & state[0] ? -32000 : 32000 ;
  assign qrx_sync = 0;
  assign irx_out = out_sel ? irx_sync : irx_in;
  assign qrx_out = out_sel ? qrx_sync : qrx_in;

  localparam LOC_SYNCH = 2'b01;
  localparam HOP_SYNCH = 2'b10;
  localparam HOP_RX    = 2'b11;
  localparam INIT      = 2'b00;

  localparam NUM_HOPS  = 64;
  localparam IDLE_LIMIT = 32768;
  reg  [DATA_WIDTH-1:0] idle_count;
  
  
  reg valid_rx;
  assign rx_valid   = valid_rx  & out_sel;
  
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

  always @(posedge clk ) begin
    if (reset) begin
      sync_count <= SYNC_SIG_N - 1;
      state <= INIT;
      valid_rx <= 1'b0;
      idle_count <= 0;
    end
    else begin
      case (state)
        INIT : begin
          if (sync_trigger) begin
            sync_count <= SYNC_SIG_N - 1;
            state    <= LOC_SYNCH;
            valid_rx <= 1'b1;
          end
          else if (idle_count < IDLE_LIMIT)begin
            idle_count <= idle_count + 1;
          end
          else begin
            valid_rx <= 1'b0;
          end
        end
        LOC_SYNCH : begin
          if (sync_count > 0) begin
            sync_count <= sync_count - 1;
          end
          else  begin 
            state <= HOP_SYNCH;
            sync_count <= scan_trigger ? (SYNC_SIG_N - 1): (3*SYNC_SIG_N - 1) ;
          end
        end
        HOP_SYNCH : begin
          if (sync_count > 0) begin
            sync_count <= sync_count - 1;
          end
          else begin
            sync_count <= SYNC_SIG_N * 2;
            state      <= HOP_RX;
          end
        end
        HOP_RX : begin
          if (sync_count > 0) begin
            sync_count <= sync_count - 1;
          end
          else begin
            state <= INIT;
            idle_count <= 0;
          end
        end
        default: state <= INIT;
      endcase
    end
  end



endmodule