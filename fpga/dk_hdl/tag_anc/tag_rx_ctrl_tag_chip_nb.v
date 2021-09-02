module tag_rx_ctrl_tag_chip_nb #(
  parameter DATA_WIDTH     = 16,
  parameter GPIO_REG_WIDTH = 12,
  parameter TX_BITS_WIDTH  = 128,
  parameter BIT_CNT_WIDTH  = 7,
  parameter NSIG_WIDTH     = 24, 
  parameter NSYNC_WIDTH    = 16,

  parameter NUM_HOPS       = 64,
  parameter NSIG           = 294912, 
  parameter NSYNC_HOP      = 16384, 
  parameter NSYNC_LOC      = 16384,
  parameter VAL_NSYNC_LOC  = 3 * (NSYNC_LOC/4) 
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

  output hop_clk,
  output [BIT_CNT_WIDTH-1:0] ntx_bits_cnt,
  output hop_rst,

  output [1:0] rx_state,
  output [TX_BITS_WIDTH-1:0] if_code,
  output [BIT_CNT_WIDTH-1:0] nhop, 
  output [NSYNC_WIDTH-1:0] counter_sync, 
  output [NSIG_WIDTH-1:0] nrx_sig
);

  localparam LOC_SYNCH = 2'b01;
  localparam HOP_SYNCH = 2'b10;
  localparam HOP_RX    = 2'b11;
  localparam INIT      = 2'b00;

  reg  [1:0] state;
  reg  [NSYNC_WIDTH-1:0]  sync_count;
  reg  [NSIG_WIDTH-1:0] nsig;
  wire valid_rx;
  

  assign rx_valid     = valid_rx ;
  assign rx_state     = state;
  assign counter_sync = sync_count;
  assign nrx_sig      = nsig;

  reg val_sync;
  wire sync_sel, pp_sync_sel;
  wire  [DATA_WIDTH-1:0] irx_sync, qrx_sync;

  assign valid_rx    = sync_sel;
  assign sync_sel    = ((state == LOC_SYNCH) & val_sync ) ? 1'b1 : 1'b0;
  assign pp_sync_sel = (sync_count < (NSYNC_LOC/2)) ? 1'b1 : 1'b0;
  
  assign irx_sync    = (sync_sel & pp_sync_sel) ? 28672 : -28672 ;
  assign qrx_sync    = 0;
  assign irx_out     = sync_sel ? irx_sync : irx_in;
  assign qrx_out     = sync_sel ? qrx_sync : qrx_in;
  


  localparam GPIO_CLK_DIV_FAC  = 10;
  localparam [GPIO_REG_WIDTH-1:0] SCAN_OUT_MASK = 12'h554;
  localparam [GPIO_REG_WIDTH-1:0] RX_OUT_MASK   = 12'h001;
  localparam [GPIO_REG_WIDTH-1:0] GPIO_OUT_MASK = SCAN_OUT_MASK | RX_OUT_MASK;
  localparam [GPIO_REG_WIDTH-1:0] SYNC_IN_MASK  = 12'h002;
  localparam [GPIO_REG_WIDTH-1:0] GPIO_IN_MASK  = SYNC_IN_MASK;
  localparam [GPIO_REG_WIDTH-1:0] GPIO_IO_DDR   = GPIO_OUT_MASK;


  
  wire [GPIO_REG_WIDTH-1:0] gpio_out, gpio_in, scan_io_out, rx_io_out;

  wire sync_trigger;

  assign gpio_out     = scan_io_out | rx_io_out;
  assign sync_trigger = |(gpio_in & SYNC_IN_MASK);

  localparam SCAN_CLK_DIV_FAC  = 20;
  localparam SCAN_WIDTH        = 2;
  localparam NTX_BITS          = 78;

  reg hop_reset;
  wire scan_clk;
  assign hop_clk = scan_clk;
  assign hop_rst = hop_reset;
  wire scan_id, scan_phi, scan_phi_bar, scan_data_in, scan_load_chip;

  wire [GPIO_REG_WIDTH-1:0] SCAN_ID, SCAN_PHI, SCAN_PHI_BAR;
  wire [GPIO_REG_WIDTH-1:0] SCAN_DATA_IN, SCAN_LOAD_CHIP, SYNCH_OUT;

  assign  SCAN_ID        = scan_id        ? 12'h400 : 12'h000;
  assign  SCAN_PHI       = scan_phi       ? 12'h100 : 12'h000;
  assign  SCAN_PHI_BAR   = scan_phi_bar   ? 12'h040 : 12'h000;
  assign  SCAN_DATA_IN   = scan_data_in   ? 12'h010 : 12'h000;
  assign  SCAN_LOAD_CHIP = scan_load_chip ? 12'h004 : 12'h000;

  assign scan_io_out  = SCAN_ID | SCAN_PHI | SCAN_PHI_BAR | SCAN_DATA_IN | SCAN_LOAD_CHIP ;
  assign rx_io_out    = (state == HOP_RX) ?  RX_OUT_MASK : {(GPIO_REG_WIDTH){1'b0}} ;

  localparam MEM_WIDTH = 32;
  reg [BIT_CNT_WIDTH-1:0] hop_n;
  reg [MEM_WIDTH-1:0] if_hop_codes [0:NUM_HOPS];
  wire [TX_BITS_WIDTH-1:0] hop_code;
  assign hop_code = { {(TX_BITS_WIDTH - MEM_WIDTH){1'b0}}, if_hop_codes[hop_n] };
  assign nhop = hop_n;
  assign if_code = hop_code;
  
  initial begin
    $readmemh("/home/user/programs/usrp/uhd/fpga/dk_hdl/tag_anc/if_codes.mem", if_hop_codes);
  end

  clk_div_dk #(.N(SCAN_CLK_DIV_FAC))
      CLK_DIV_DK (.clk(clk),
                  .reset(reset),
                  .clk_div(scan_clk));
  
  hop_ctrl #(.SCAN_WIDTH(SCAN_WIDTH), 
             .NTX_BITS(NTX_BITS),
             .TX_BITS_WIDTH(TX_BITS_WIDTH),
             .BIT_CNT_WIDTH(BIT_CNT_WIDTH))
      HOP_CTRL(
        .clk(scan_clk), .reset(reset | hop_reset),

        .scan_id(scan_id),
        .scan_phi(scan_phi),
        .scan_phi_bar(scan_phi_bar), 

        .scan_data_in(scan_data_in),
        .scan_load_chip(scan_load_chip),
        .nbits_cnt(ntx_bits_cnt),
        .data_in(hop_code));

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


  always @(posedge clk ) begin
    if (reset) begin
      sync_count <= 1;
      state <= INIT;
      hop_n <= 0;
      hop_reset <= 1'b0;
      val_sync <= 1'b0;
      nsig <= 0;
    end
    else begin
      case (state)
        INIT : begin
          hop_n <= 0;
          hop_reset <= 1'b0;
          val_sync  <= 1'b0;
          if (sync_trigger) begin
            sync_count <= NSYNC_LOC - 1;
            state      <= LOC_SYNCH;
          end
        end
        LOC_SYNCH : begin
          if (sync_count > VAL_NSYNC_LOC) begin
            sync_count <= sync_count - 1;
          end
          else if (sync_count > 0) begin
            sync_count <= sync_count - 1;
            val_sync <= 1'b1;
          end
          else  begin 
            state <= HOP_SYNCH;
            sync_count <= NSYNC_HOP - 1 ;
            hop_reset <= 1'b1;
          end
        end
        HOP_SYNCH : begin
          hop_reset <= 1'b0;
          if (sync_count > 0) begin
            sync_count <= sync_count - 1;
          end
          else begin
            state      <= HOP_RX;
            nsig       <= NSIG - 1;
            sync_count <= NSYNC_HOP - 1;
          end
        end
        HOP_RX : begin
          if (nsig > 0) begin
            nsig <= nsig - 1;
          end
          else if (hop_n < (NUM_HOPS - 1)) begin
            hop_n <= hop_n + 1;
            state <= HOP_SYNCH;
            hop_reset <= 1'b1;
          end
          else begin
            state <= INIT;
          end
        end
        default: state <= INIT;
      endcase
    end
  end



endmodule