module usrp_tag_chip_tag_rx_ctrl #(
  parameter DATA_WIDTH     = 16,
  parameter DDS_WIDTH      = 24,
  parameter SIN_COS_WIDTH  = 16,
  parameter PHASE_WIDTH    = 24,
  parameter NSYMB_WIDTH    = 16,
  parameter SCALING_WIDTH  = 18,
  parameter GPIO_REG_WIDTH = 12,
  parameter NSYNCP         = 16384,
  parameter NSYNCN         = 16384,
  parameter NLOC_PER_SYNC  = 7,
  parameter [NSYMB_WIDTH-1:0] NSYMB        = 64, 
  parameter [PHASE_WIDTH-1:0] NSIG         = 32768 * 8,
  parameter [PHASE_WIDTH-1:0] DPH_INC      = -131072, 
  parameter [PHASE_WIDTH-1:0] START_PH_INC = 24'd4194304,
  parameter [PHASE_WIDTH-1:0] START_PH     = 24'h000000,
  parameter [PHASE_WIDTH-1:0] NPH_SHIFT    = 24'h000000
)(
  input   clk,
  input   reset,
  input   run_rx, 

  /* RX IQ input */
  input [DATA_WIDTH-1:0]  irx_in,
  input [DATA_WIDTH-1:0]  qrx_in,
  input [DATA_WIDTH-1:0]  scale_val,
  input [2*DATA_WIDTH-1:0] noise_thres,
  /*GPIO IO Registers*/
  input  [GPIO_REG_WIDTH-1:0] fp_gpio_in,
  output [GPIO_REG_WIDTH-1:0] fp_gpio_out,
  output [GPIO_REG_WIDTH-1:0] fp_gpio_ddr,

  output  rx_valid, 

  /* IQ output */
  output [DATA_WIDTH-1:0]  irx_out_bb,
  output [DATA_WIDTH-1:0]  qrx_out_bb, 

  /*debug*/
  output [PHASE_WIDTH-1:0]   ph,
  output [NSYMB_WIDTH-1:0] symbN,
  output [SIN_COS_WIDTH-1:0] cos, 
  output [SIN_COS_WIDTH-1:0] sin, 
  output [PHASE_WIDTH-1:0]  sigN,
  output [$clog2(NSYNCP + NSYNCN + 1)-1:0] nsync_count,

  output peak_detect_stb,
  /*
  output [2*DATA_WIDTH-1:0]  pow_mag_tdata,
  output [2*DATA_WIDTH-1:0]  acorr_mag_tdata,
  */
  output rx_trig, 
  output rx_out_mux,
  output [1:0] rx_state

);

  wire clear;
  assign clear = reset | ~run_rx;
  reg  [1:0] state;
  localparam LOC_SYNC = 2'b01;
  localparam RX_START = 2'b10;
  localparam LOC_RX   = 2'b11;
  localparam INIT     = 2'b00;
  
  wire rx_sync_ready;
  reg start_rx, valid_rx;
  assign rx_valid    = valid_rx;
  assign rx_trig     = start_rx;
  assign rx_state    = state;

  wire [DATA_WIDTH-1:0] irx_bb, qrx_bb, irx_out, qrx_out;
  wire [DATA_WIDTH-1:0] irx_sync;// qrx_sync;

  reg  [$clog2(NSYNCP + NSYNCN + 1)-1:0] ncount;
  assign nsync_count = ncount;


  wire out_sel;
  assign out_sel    = (state == LOC_SYNC) & (ncount < NSYNCP);
  assign irx_sync   = out_sel ? 16384 : -16384;
  assign irx_out    = (state == LOC_SYNC) ? irx_sync : irx_bb;
  assign qrx_out    = (state == LOC_SYNC) ? 0        : qrx_bb;
  assign rx_out_mux = (state == LOC_SYNC);

  wire in_tvalid, in_tlast, out_tready;
  assign in_tvalid  = 1'b1;
  assign in_tlast   = 1'b0;
  assign out_tready = 1'b1;

  axi_fifo_flop2 #(
    .WIDTH(2*DATA_WIDTH)) 
      fifo_flop2(
        .clk(clk), .reset(reset), .clear(clear),
        .i_tdata({irx_out, qrx_out}), .i_tvalid(in_tvalid), .i_tready(),
        .o_tdata({irx_out_bb, qrx_out_bb}), .o_tready(out_tready)
      );

  reg  [DATA_WIDTH-1:0] scale_reg;
  wire [DATA_WIDTH-1:0] scale_tdata;
  wire [DATA_WIDTH-1:0] irx_scaled, qrx_scaled;
  wire scaled_tlast, scaled_tready, scaled_tvalid;
  assign scale_tdata = scale_reg;

  mult_rc #(
  .WIDTH_REAL(DATA_WIDTH), .WIDTH_CPLX(DATA_WIDTH),
  .WIDTH_P(DATA_WIDTH), .DROP_TOP_P(21)) 
    MULT_RC(
      .clk(clk),
      .reset(reset),

      .real_tlast(in_tlast),
      .real_tvalid(in_tvalid),
      .real_tdata(scale_tdata),

      .cplx_tlast(in_tlast),
      .cplx_tvalid(in_tvalid),
      .cplx_tdata({irx_in, qrx_in}),

      .p_tready(scaled_tready), .p_tlast(scaled_tlast), .p_tvalid(scaled_tvalid),
      .p_tdata({irx_scaled, qrx_scaled}));
  
  wire [PHASE_WIDTH-1:0]  win_sigN;
  wire [NSYMB_WIDTH-1:0]  win_symbN;
  assign sigN = win_sigN;
  assign symbN = win_symbN;
  usrp_tag_chip_tag_rx #(
    .DATA_WIDTH(DATA_WIDTH), .DDS_WIDTH(DDS_WIDTH), 
    .SIN_COS_WIDTH(SIN_COS_WIDTH), .PHASE_WIDTH(PHASE_WIDTH),
    .NSYMB_WIDTH(NSYMB_WIDTH), .SCALING_WIDTH(SCALING_WIDTH),
    .NSYMB(NSYMB), .NSIG(NSIG), .DPH_INC(DPH_INC), 
    .START_PH_INC(START_PH_INC), .START_PH(START_PH),
    .NPH_SHIFT(NPH_SHIFT), .NLOC_PER_SYNC(NLOC_PER_SYNC))
      TAG_RXB(
        .clk(clk), .reset(reset), .srst(start_rx),
            /* RX IQ input */
        .irx_in(irx_scaled), .qrx_in(qrx_scaled),
        .in_tvalid(scaled_tvalid), .in_tlast(scaled_tlast), 
              /* phase valid*/
        .phase_tvalid(scaled_tvalid), .phase_tlast(scaled_tlast), 
              /* IQ BB output */
        .out_tready(out_tready), .irx_bb(irx_bb), .qrx_bb(qrx_bb),
              /*toggle for symbol transmission*/
        .sync_ready(rx_sync_ready),
              /*debug*/
        .ph(ph), .symbN(win_symbN), .sigN(win_sigN), .sin(sin), .cos(cos)
      );

  localparam DEC_RATE        = 64;
  localparam DEC_MAX_RATE    = 255;
  localparam MAX_LEN         = 4095;
  localparam LEN             = 4092;
  localparam NRX_TRIG        = 16;
  localparam NOISE_POW       = 51000;
  localparam NRX_TRIG_DELAY  = (NRX_TRIG - 1) * DEC_RATE;
  localparam PMAG_WIDTH      = DATA_WIDTH + $clog2(MAX_LEN+1);
  localparam [1:0] THRES_SEL = 2'b00;
  wire peak_tvalid, peak_tlast, peak_stb, peak_thres;
  assign peak_detect_stb  = peak_stb;

  wire [PMAG_WIDTH-1:0] pmag_tdata, acmag_tdata;

  preamble_detect #(
    .DATA_WIDTH(DATA_WIDTH), .DEC_MAX_RATE(DEC_MAX_RATE), 
    .DEC_RATE(DEC_RATE), .MAX_LEN(MAX_LEN), .LEN(LEN),
    .THRES_SEL(THRES_SEL), .NOISE_POW(NOISE_POW), 
    .PMAG_WIDTH(PMAG_WIDTH), .NRX_TRIG(NRX_TRIG))
      PRMB(
        .clk(clk), .reset(reset), .clear(clear),
        .in_tvalid(scaled_tvalid), .in_tlast(scaled_tlast), .in_tready(scaled_tready), 
        .in_itdata(irx_scaled), .in_qtdata(qrx_scaled),
        .out_tvalid(peak_tvalid), .out_tlast(peak_tlast), 
        .out_tready(out_tready), .peak_stb(peak_stb), 
        .noise_thres(noise_thres), .peak_thres(peak_thres),
        .pow_mag_tdata(pmag_tdata), .acorr_mag_tdata(acmag_tdata)
      );

  /*
  localparam SYNC_OUT   = 12'h0001;
  localparam THRES_TRIG = 12'h0010;
  localparam DDR_GPIO   = SYNC_OUT | THRES_TRIG;

  wire [GPIO_REG_WIDTH-1:0] gpio_sync_out, gpio_thres_trig, gpio_out;
  assign gpio_sync_out   = (state == LOC_SYNC) ? SYNC_OUT   : 12'h0000;
  assign gpio_thres_trig = peak_thres          ? THRES_TRIG : 12'h0000;

  assign fp_gpio_ddr = DDR_GPIO;
  assign gpio_out    = gpio_thres_trig | gpio_sync_out;

  */

  localparam GPIO_CLK_DIV_FAC  = 10;
  localparam [GPIO_REG_WIDTH-1:0] SCAN_OUT_MASK = 12'h554;
  localparam [GPIO_REG_WIDTH-1:0] SYNC_OUT_MASK = 12'h001;
  localparam [GPIO_REG_WIDTH-1:0] GPIO_OUT_MASK = SCAN_OUT_MASK | SYNC_OUT_MASK;
  //localparam [GPIO_REG_WIDTH-1:0] SYNC_IN_MASK  = 12'h002;
  localparam [GPIO_REG_WIDTH-1:0] GPIO_IN_MASK  = 12'h0000;
  localparam [GPIO_REG_WIDTH-1:0] GPIO_IO_DDR   = GPIO_OUT_MASK;

  wire [GPIO_REG_WIDTH-1:0] gpio_out, gpio_in, gpio_sync_out, scan_io_out;
  assign gpio_sync_out   = (state == LOC_SYNC) ? SYNC_OUT_MASK   : 12'h0000;
  assign gpio_out    = scan_io_out | gpio_sync_out;

  
  localparam SCAN_CLK_DIV_FAC  = 20;
  localparam SCAN_WIDTH        = 2;
  localparam NTX_BITS          = 78;
  //localparam HOP_RESET_VAL     = NSYNC_HOP - 2;
  localparam MEM_WIDTH         = 32;
  localparam BIT_CNT_WIDTH     = 7;
  localparam TX_BITS_WIDTH     = 128;
  localparam USRP_CLK_NSCAN    = 12640;
  localparam NUM_HOPS          = 64;

  //reg hop_reset;
  wire hop_reset;
  assign hop_reset = (win_sigN > (NSIG - USRP_CLK_NSCAN)) & 
                     (win_sigN < (NSIG - USRP_CLK_NSCAN + 40)) ;
  wire scan_clk;
  //assign hop_clk = scan_clk;
  //assign hop_rst = hop_reset;
  wire scan_id, scan_phi, scan_phi_bar, scan_data_in, scan_load_chip;

  wire [GPIO_REG_WIDTH-1:0] SCAN_ID, SCAN_PHI, SCAN_PHI_BAR;
  wire [GPIO_REG_WIDTH-1:0] SCAN_DATA_IN, SCAN_LOAD_CHIP;

  assign  SCAN_ID        = scan_id        ? 12'h400 : 12'h000;
  assign  SCAN_PHI       = scan_phi       ? 12'h100 : 12'h000;
  assign  SCAN_PHI_BAR   = scan_phi_bar   ? 12'h040 : 12'h000;
  assign  SCAN_DATA_IN   = scan_data_in   ? 12'h010 : 12'h000;
  assign  SCAN_LOAD_CHIP = scan_load_chip ? 12'h004 : 12'h000;

  assign scan_io_out  = SCAN_ID | SCAN_PHI | SCAN_PHI_BAR | SCAN_DATA_IN | SCAN_LOAD_CHIP ;
 

  

  reg [BIT_CNT_WIDTH-1:0] hop_n;
  reg [MEM_WIDTH-1:0] if_hop_codes [0:NUM_HOPS];
  wire [TX_BITS_WIDTH-1:0] hop_code;
  assign hop_code = { {(TX_BITS_WIDTH - MEM_WIDTH){1'b0}}, if_hop_codes[hop_n] };
  //assign nhop = hop_n;
  //assign if_code = hop_code;
  
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
        /*.nbits_cnt(ntx_bits_cnt), */
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

/*
  axi_fifo_flop2 #(
    .WIDTH(GPIO_REG_WIDTH)) 
      gpio_flop2(
        .clk(clk), .reset(reset), .clear(reset),
        .i_tdata({gpio_out}), .i_tvalid(in_tvalid), .i_tready(),
        .o_tdata(fp_gpio_out), .o_tready(out_tready)
      );
*/
  always @(posedge clk) begin
    if (reset | ~run_rx) begin
      valid_rx   <= 1'b0;
      start_rx   <= 1'b0;
      state      <= INIT;
      ncount     <= 0;
      scale_reg  <= 1;
      hop_n      <= 0;
    end
    else  begin
      case (state)
        INIT: begin
          if (peak_tvalid) begin
            if (peak_stb) begin
              state    <= LOC_SYNC;
              valid_rx <= 1'b1;
              ncount   <= 0;
            end
            else begin
              valid_rx <= 1'b0;
            end
          end
          scale_reg <= (scale_val == 0) ? 1 : scale_val;
          hop_n <= 0;
        end 
        LOC_SYNC: begin
          if ( ncount < ( NSYNCP + NSYNCN - NRX_TRIG_DELAY - 1 ) ) begin
            ncount   <= ncount + 1;
            start_rx <= 1'b1;
          end
          else begin
            start_rx <= 1'b0;
            state    <= LOC_RX;
          end
        end
        LOC_RX : begin
          if (rx_sync_ready & peak_tvalid) begin
            state    <= INIT;
          end
          hop_n <= win_symbN[BIT_CNT_WIDTH-1:0];
        end
        default: state <= INIT;
      endcase
    end
  end

endmodule