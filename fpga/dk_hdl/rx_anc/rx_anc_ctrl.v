module rx_anc_ctrl #(
  parameter DATA_WIDTH    = 16,
  parameter DDS_WIDTH     = 24,
  parameter SIN_COS_WIDTH = 16,
  parameter PHASE_WIDTH   = 24,
  parameter NSYMB_WIDTH   = 16,
  parameter SCALING_WIDTH = 18,

  parameter [NSYMB_WIDTH-1:0] NSYMB        = 512,
  parameter [PHASE_WIDTH-1:0] NSIG         = 16384,
  parameter [PHASE_WIDTH-1:0] DPH_INC      = 16384, 
  parameter [PHASE_WIDTH-1:0] START_PH_INC = 4096,
  parameter [PHASE_WIDTH-1:0] NHT_PH_INC   = 12288,
  parameter [PHASE_WIDTH-1:0] ANC_PH_INC   = 2048,
  parameter [PHASE_WIDTH-1:0] START_PH     = 0
  
)(
  input   clk,
  input   reset,

  /* RX IQ input */
  input [DATA_WIDTH-1:0]  irx_in,
  input [DATA_WIDTH-1:0]  qrx_in,
  input in_tvalid, 
  input in_tlast, 
  output in_tready, 
  
  /*GPIO IO Registers*/
  input  [GPIO_REG_WIDTH-1:0] fp_gpio_in,
  output [GPIO_REG_WIDTH-1:0] fp_gpio_out,
  output [GPIO_REG_WIDTH-1:0] fp_gpio_ddr,

  output  rx_valid, 

  /* IQ output */
  output [DATA_WIDTH-1:0]  itx,
  output [DATA_WIDTH-1:0]  qtx, 

  /*debug*/
  output [PHASE_WIDTH-1:0]   ph,
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
  wire tx_trigger;
  wire [GPIO_REG_WIDTH-1:0] gpio_out, gpio_in, sync_io_out, rx_io_out;
  assign rx_valid = valid_rx;

  assign rx_sync_en  = sync_en;
  assign rx_trig     = start_rx;
  assign rx_state    = sync_state;
  assign rx_out_mux  = out_sel;


  assign sync_io_out = valid_rx ? SYNC_OUT_MASK : {(GPIO_REG_WIDTH){1'b0}};
  assign rx_io_out   = valid_rx ? RX_OUT_MASK : {(GPIO_REG_WIDTH){1'b0}};
  assign gpio_out    = sync_io_out | rx_io_out;
  assign tx_trigger  = |(gpio_in & SYNC_IN_MASK);

  wire out_sel = ^sync_state ;

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

  reg  [PHASE_WIDTH-1:0]  sync_ncount, symb_count, loc_count, sig_count;
  reg [PHASE_WIDTH-1:0] ph_nht, ph_bb, ph_fshift;
  wire [PHASE_WIDTH-1:0] phase_nht_tdata, phase_bb_tdata, phase_fshift_tdata;
  wire [PHASE_WIDTH-1:0] ph_nht_inc,  ph_fshift_inc;
  reg  [PHASE_WIDTH-1:0] ph_bb_inc;
  assign ph_nht_inc = NHT_PH_INC;
  assign ph_fshift_inc = ANC_PH_INC + ph_bb_inc;
  assign phase_nht_tdata = ph_nht;
  assign phase_bb_tdata  = ph_bb;
  assign phase_fshift_tdata = ph_fshift;

  always @(posedge clk ) begin
    if (reset | start_rx) begin
      ph_nht <= START_PH;
      ph_bb  <= START_PH;
      ph_fshift <= START_PH;
      ph_bb_inc <= START_PH_INC;
      sig_count  <= NSIG;
      symb_count <= NSYMB;
    end
    else if (sig_count == NSIG) begin
      sig_count <= 1;
      if (symb_count == NSYMB) begin
        symb_count <= 1;
        ph_bb_inc <= START_PH_INC;
      end
      else begin
        symb_count <= symb_count + 1;
        ph_bb_inc <= ph_bb_inc + DPH_INC;
      end
      ph_nht    <= START_PH;
      ph_bb     <= START_PH;
      ph_fshift <= START_PH;
    end
    else begin
      ph_nht <= ph_nht - ph_nht_inc;
      ph_bb  <= ph_bb - ph_bb_inc;
      ph_fshift <= ph_fshift + ph_fshift_inc;
    end 
  end

  localparam COEFF_WIDTH = 16;
  localparam NUM_COEFFS  = 128;
  localparam SYMMETRIC_COEFFS = 1;
  localparam RELOADABLE_COEFFS = 1;

  reg [COEFF_WIDTH-1:0] coeffs_memory [0:NUM_COEFFS/2-1];
  reg [COEFF_WIDTH-1:0] coeff_in;
  reg [COEFF_WIDTH-1:0] coeff_count;

  wire [SCALING_WIDTH-1:0] lpf_scale_tdata = {{2{1'b0}}, {(SCALING_WIDTH-2){1'b1}}};
  wire [SCALING_WIDTH-1:0] fshift_scale_tdata = {{2{1'b0}}, {(SCALING_WIDTH-2){1'b1}}};
  wire [SCALING_WIDTH-1:0] scale_val = {10'h0, {(SCALING_WIDTH-10){1'b1}}};

  wire phase_tready, phase_tlast, phase_tvalid;
  assign phase_tvalid = in_tvalid;
  assign phase_tlast  = in_tlast;

  wire pnfo_tlast, pnfo_tready, pnfo_tlast, pnfo_in_tready;
  wire [DATA_WIDTH-1:0] pnfo_itdata, pnfo_qtdata;

  wire bb_tlast, bb_tready, bb_tlast, bb_in_tready;
  wire [DATA_WIDTH-1:0] bb_itdata, bb_qtdata;
  assign in_tready = pnfo_in_tready | bb_in_tready;

  wire reload_tlast;
  reg reload_tvalid;

  initial begin
    $readmemh("/home/user/programs/usrp/uhd/fpga/dk_hdl/rx_anc/coeffs_data.mem", coeffs_memory);
  end

  always @(posedge clk ) begin
    if (reset | start_rx) begin
      coeff_count <= 0;
      reload_tvalid <= 1'b1;
      coeff_in <= 0;
    end
    else if (coeff_count < NUM_COEFFS/2) begin
      coeff_count <= coeff_count + 1;
      coeff_in <= coeffs_memory[coeff_count];
      reload_tvalid <= 1'b1;
    end
    else begin
      reload_tvalid <= 1'b0;
    end
  end
  
  freq_shift_and_lpf_iq #(.DATA_WIDTH(DATA_WIDTH), .DDS_WIDTH(DDS_WIDTH),
                          .SIN_COS_WIDTH(SIN_COS_WIDTH), .PHASE_WIDTH(PHASE_WIDTH), 
                          .SCALING_WIDTH(SCALING_WIDTH), 
                            
                          .COEFF_WIDTH(COEFF_WIDTH), .NUM_COEFFS(NUM_COEFFS),
                          .SYMMETRIC_COEFFS(SYMMETRIC_COEFFS),
                          .RELOADABLE_COEFFS(RELOADABLE_COEFFS))

        PNFO( .clk(clk), .reset(reset),
              .in_itdata(irx_in), .in_qtdata(qrx_in),
              .in_tlast(in_tlast), .in_tvalid(in_tvalid), .in_tready(pnfo_in_tready),
              .scaling_tdata(lpf_scale_tdata), .phase_tdata(phase_nht_tdata),
                        
              .phase_tvalid(phase_tvalid), .phase_tlast(phase_tlast),
              .phase_tready(phase_tready),

              .coeff_in(coeff_in),
              .reload_tlast(reload_tlast), .reload_tvalid(reload_tvalid),

              .out_itdata(pnfo_itdata), .out_qtdata(pnfo_qtdata), 
                 
              .out_tvalid(pnfo_tvalid), .out_tready(pnfo_tready),
              .out_tlast(pnfo_tlast),
              .sin(), .cos());

  freq_shift_and_lpf_iq #(.DATA_WIDTH(DATA_WIDTH), .DDS_WIDTH(DDS_WIDTH),
                          .SIN_COS_WIDTH(SIN_COS_WIDTH), .PHASE_WIDTH(PHASE_WIDTH), 
                          .SCALING_WIDTH(SCALING_WIDTH), 
                            
                          .COEFF_WIDTH(COEFF_WIDTH), .NUM_COEFFS(NUM_COEFFS),
                          .SYMMETRIC_COEFFS(SYMMETRIC_COEFFS),
                          .RELOADABLE_COEFFS(RELOADABLE_COEFFS))

          BB( .clk(clk), .reset(reset),
              .in_itdata(irx_in),  .in_qtdata(qrx_in),
              .in_tlast(in_tlast), .in_tvalid(in_tvalid), .in_tready(bb_in_tready),
              .scaling_tdata(lpf_scale_tdata), .phase_tdata(phase_bb_tdata),
                        
              .phase_tvalid(phase_tvalid), .phase_tlast(phase_tlast),
              .phase_tready(),

              .coeff_in(coeff_in),
              .reload_tlast(reload_tlast), .reload_tvalid(reload_tvalid),

              .out_itdata(bb_itdata), .out_qtdata(bb_qtdata), 
                 
              .out_tvalid(bb_tvalid), .out_tready(bb_tready),
              .out_tlast(bb_tlast),
              .sin(), .cos());
  
  localparam PNFO_DELAY = 12;
  wire [2*DATA_WIDTH-1:0] pnfoc_tdata;
  wire [2*DATA_WIDTH-1:0] pnfoc_delay_tdata;
  wire pnfoc_delay_tready, pnfoc_delay_tvalid, pnfoc_delay_tlast;
  assign pnfoc_tdata = {pnfo_itdata, -pnfo_qtdata};

  
  axi_fifo #(
    .SIZE(PNFO_DELAY),
    .WIDTH(2*DATA_WIDTH))
    PNFOC_DELAY(
    .clk(clk), .reset(reset), .clear(start_rx),
    .i_tdata(pnfoc_tdata), .i_tvalid(pnfo_tvalid), .i_tready(pnfo_tready),
    .o_tdata(pnfoc_delay_tdata), .o_tvalid(pnfoc_delay_tvalid), 
    .o_tready(pnfoc_delay_tready));
  
  wire [DATA_WIDTH-1:0] fshift_itdata, fshift_qtdata;
  wire fshift_tready, fshift_tvalid, fshift_tlast;
  freq_shift_iq #(.DATA_WIDTH(DATA_WIDTH), .DDS_WIDTH(DDS_WIDTH),
                  .SIN_COS_WIDTH(SIN_COS_WIDTH), .PHASE_WIDTH(PHASE_WIDTH), 
                  .SCALING_WIDTH(SCALING_WIDTH))
      FSHIFT( 
        .clk(clk), .reset(reset),

        .iin(bb_itdata), .qin(bb_qtdata),
        .in_tlast(bb_tlast), .in_tvalid(bb_tvalid), .in_tready(bb_tready),

        .phase_tdata(phase_fshift_tdata), .scaling_tdata(fshift_scale_tdata),

        .phase_tlast(bb_tlast), .phase_tvalid(bb_tvalid),
        .phase_tready(),

        .iout(fshift_itdata), .qout(fshift_qtdata), 
                        
        .out_tready(fshift_tready), .out_tvalid(fshift_tvalid),
        .out_tlast(fshift_tlast),
        .sin(), .cos());
  
  assign pnfoc_delay_tready = fshift_tready;
  wire [2*DATA_WIDTH-1:0] cm_tdata;
  cmul_16 #(.DATA_WIDTH(DATA_WIDTH), .SCALING_WIDTH(SCALING_WIDTH))
    CMIX(
      .clk(clk), .reset(reset),

      .in_tlast(fshift_tlast),
      .in_tvalid(fshift_tvalid | pnfoc_delay_tvalid),
      .in_tready(fshift_tready),

      .adata({fshift_itdata, fshift_qtdata}), 
      .bdata({pnfoc_delay_tdata}),

      .scale_val(scale_val),

      .pdata(cm_tdata)
      .out_tready(out_tready), .out_tvalid(out_tvalid),
      .out_tlast(out_tlast));
  
  assign itx = cm_tdata[2*DATA_WIDTH-1:DATA_WIDTH];
  assign qtx = cm_tdata[DATA_WIDTH-1:0];


  always @(posedge clk) begin
    if (reset) begin
      sync_en    <= 1'b0;
      valid_rx   <= 1'b0;
      start_rx   <= 1'b0;
      sync_state <= 2'b11;
      sync_ncount <= 0;
    end
    else if (tx_trigger & ~sync_en) begin
      sync_en    <= 1'b1;
      start_rx   <= 1'b0;
      valid_rx   <= 1'b1;
      sync_state <= 2'b11;
      sync_ncount       <= SYNC_SIG_N;
    end
    else if (sync_en && (sync_ncount == SYNC_SIG_N)) begin
      sync_ncount    <= 1;
      case (sync_state)
        2'b00: begin
          sync_en   <= 1'b0;
          start_rx  <= 1'b0;
        end
        2'b11:begin
          sync_state <= 2'b10;
          start_rx   <= 1'b1;
        end
        2'b10:begin
          sync_state <= 2'b01;
          start_rx   <= 1'b1;
        end
        2'b01:begin
          start_rx   <= 1'b0;
          sync_state <= 2'b00;
        end
      endcase
    end
    else if(sync_en) begin
      sync_ncount <= sync_ncount + 1;
    end 
  end

endmodule