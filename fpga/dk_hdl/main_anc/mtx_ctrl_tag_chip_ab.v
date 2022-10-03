module mtx_ctrl_tag_chip_ab #(
  parameter DATA_WIDTH     = 16,
  parameter SIN_COS_WIDTH  = 16,
  parameter PHASE_WIDTH    = 24,
  parameter NSYMB_WIDTH    = 16,
  parameter GPIO_REG_WIDTH = 12,
  parameter TX_BITS_WIDTH  = 128,
  parameter BIT_CNT_WIDTH  = 7,
  parameter SAMPLE_WIDTH   = 19,

  parameter [NSYMB_WIDTH-1:0] NSYMB        = 9, 
  parameter [PHASE_WIDTH-1:0] NSIG         = 65536,
  parameter [PHASE_WIDTH-1:0] DPH_INC      = 16384,
  parameter [PHASE_WIDTH-1:0] START_PH_INC = 12288,
  parameter [PHASE_WIDTH-1:0] PILOT_PH_INC = 4096,
  parameter [PHASE_WIDTH-1:0] START_PH     = 24'h000000,
  parameter [PHASE_WIDTH-1:0] NPH_SHIFT    = 24'h000000,
  // parameter [SAMPLE_WIDTH-1:0] EST_SAMPLES  = 290000
  parameter [SAMPLE_WIDTH-1:0] EST_SAMPLES = 294912
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

  input  [TX_BITS_WIDTH-1:0] tx_bits,
  output hop_clk,
  output [BIT_CNT_WIDTH-1:0] ntx_bits_cnt,
  output hop_rst,

  /*debug*/
  output [1:0] mtx_state,
  output [2*SIN_COS_WIDTH-1:0] mtx_data,
  output [2*SIN_COS_WIDTH-1:0] pilot_data,
  output [PHASE_WIDTH-1:0] mtx_ph,
  output [PHASE_WIDTH-1:0] pilot_ph,
  output [PHASE_WIDTH-1:0] sigN,
  output [NSYMB_WIDTH-1:0] symbN,
  output [BIT_CNT_WIDTH-1:0] nhop, 
  output [PHASE_WIDTH-1:0] hop_ph_inc,
  output [PHASE_WIDTH-1:0] count_sync
  
);

  localparam GPIO_CLK_DIV_FAC  = 10;
  localparam SYNC_SIG_N        = 16384;
  localparam [GPIO_REG_WIDTH-1:0] SYNC_OUT_MASK = 12'h555;
  localparam [GPIO_REG_WIDTH-1:0] TX_OUT_MASK   = 12'h800;
  localparam [GPIO_REG_WIDTH-1:0] GPIO_OUT_MASK = SYNC_OUT_MASK | TX_OUT_MASK;
  localparam [GPIO_REG_WIDTH-1:0] GPIO_IN_MASK  = 12'h022; 
  localparam [GPIO_REG_WIDTH-1:0] GPIO_IO_DDR   = GPIO_OUT_MASK;



  wire [GPIO_REG_WIDTH-1:0] gpio_out, gpio_in, sync_io_out, tx_io_out;

  wire start_tx;
  reg [1:0] state;
  //wire sync_ready;
  wire sync_sel, csel;

  assign mtx_state = state;


  wire [DATA_WIDTH-1:0]  mtx_qdata, mtx_idata;

  assign tx_io_out   = sync_sel ? {(GPIO_REG_WIDTH){1'b0}} : TX_OUT_MASK ;
  assign gpio_out    = sync_io_out | tx_io_out;

  localparam SCAN_CLK_DIV_FAC  = 20;
  localparam SCAN_WIDTH        = 2;
  localparam NTX_BITS          = 78;


  wire hop_reset;
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
  assign  SYNCH_OUT      = ^state         ? 12'h001 : 12'h000;

  assign sync_io_out  = SCAN_ID | SCAN_PHI | SCAN_PHI_BAR | SCAN_DATA_IN | SCAN_LOAD_CHIP | SYNCH_OUT;
  
  localparam LOC_SYNCH = 2'b01;
  localparam HOP_SYNCH = 2'b10;
  localparam HOP_TX    = 2'b11;
  localparam INIT      = 2'b00;
  localparam NUM_HOPS  = 64;
  localparam [PHASE_WIDTH-1:0] HOP_DPH_INC      = 131072;
  localparam [PHASE_WIDTH-1:0] HOP_START_PH_INC = -24'd4194304;

  reg [PHASE_WIDTH-1:0] synch_count;
  reg [BIT_CNT_WIDTH-1:0] hop_n;
  reg [PHASE_WIDTH-1:0] hop_phase_inc;

  wire hop_done;
  assign nhop = hop_n;
  assign hop_ph_inc = hop_phase_inc;

  assign csel = (synch_count <= SYNC_SIG_N) ? 1'b1 : 1'b0;
  assign sync_sel = (state == HOP_SYNCH) ? 1'b1 : 1'b0;
  assign start_tx  = sync_sel ; 
 // assign itx = start_tx ? 0 : mtx_idata;
  //assign qtx = start_tx ? 0 : mtx_qdata;
 
  reg hop_reset_reg;
  assign hop_reset = hop_reset_reg;
  //assign hop_reset = (synch_count == (SYNC_SIG_N-1)) ? 1'b1 : 1'b0;
  
  assign count_sync = synch_count;

  localparam MEM_WIDTH = 32;
  reg [MEM_WIDTH-1:0] if_hop_codes [0:NUM_HOPS];
  wire [TX_BITS_WIDTH-1:0] hop_code;
  assign hop_code = { {(TX_BITS_WIDTH - MEM_WIDTH){1'b0}}, if_hop_codes[hop_n] };

  initial begin
    $readmemh("/home/user/programs/usrp/uhd/fpga/dk_hdl/main_anc/if_codes.mem", if_hop_codes);
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

  gpio_ctrl_ab #(
    .GPIO_REG_WIDTH(GPIO_REG_WIDTH), .CLK_DIV_FAC(GPIO_CLK_DIV_FAC),             
    .OUT_MASK(GPIO_OUT_MASK), .IN_MASK(GPIO_IN_MASK), 
    .IO_DDR(GPIO_IO_DDR))
      GPIO_CTRL(.clk(clk), .reset(reset),
                .fp_gpio_in(fp_gpio_in), 
                .fp_gpio_out(fp_gpio_out),
                .fp_gpio_ddr(fp_gpio_ddr),
                .gpio_out(gpio_out),
                .gpio_in(gpio_in));

  mtx_sig_tag_chip #(
            .DATA_WIDTH(DATA_WIDTH), .SIN_COS_WIDTH(DATA_WIDTH), .PHASE_WIDTH(PHASE_WIDTH), 
            .NSYMB_WIDTH(NSYMB_WIDTH), .NSIG(NSIG), .NSYMB(NSYMB),
            .DPH_INC(DPH_INC), .PILOT_PH_INC(PILOT_PH_INC), .START_PH_INC(START_PH_INC), 
            .START_PH(START_PH), .NPH_SHIFT(NPH_SHIFT))
      MTX_SIG(.clk(clk),
              .reset(reset),
              .srst(start_tx),

              .phase_tlast(1'b0),
              .phase_tvalid(1'b1),
              .hop_phase_inc(hop_phase_inc),

              .hop_ready(hop_done),
              .out_tready(1'b1),
              .qtx(mtx_qdata), 
              .itx(mtx_idata),

              .symbN(symbN),
              .sigN(sigN),
              .mtx_ph(mtx_ph),
              .pilot_ph(pilot_ph),
              .mtx_data(mtx_data),
              .pilot_data(pilot_data));

  localparam NPRMB_BITS     = 2048;
  localparam PRMB_OS        = 256;
  reg [$clog2(PRMB_OS + 1)-1:0] os_count;
  reg prmb_bits [0:NPRMB_BITS-1];
  reg [$clog2(NPRMB_BITS + 1)-1:0] nbits;
  initial begin
    $readmemb("/home/user/programs/usrp/uhd/fpga/dk_hdl/main_anc/prmb_bits.mem", prmb_bits);
  end
  wire [DATA_WIDTH-1:0]  prmb_mod_tx, itx_out, qtx_out;
  assign prmb_mod_tx = prmb_bits[nbits] ? 16384 : -16384;

  wire out_sel;
  assign out_sel = csel & (state == LOC_SYNCH);
  assign itx_out = out_sel ? prmb_mod_tx : mtx_idata;
  assign qtx_out = out_sel ? prmb_mod_tx : mtx_qdata;

  axi_fifo_flop2 #(
    .WIDTH(2*DATA_WIDTH)) 
      fifo_flop2(
        .clk(clk), .reset(reset), .clear(reset),
        .i_tdata({itx_out, qtx_out}), .i_tvalid(1'b1), .i_tready(),
        .o_tdata({itx, qtx}), .o_tready(1'b1)
      );

  reg [SAMPLE_WIDTH-1:0] usrp_clk_cnt;
  reg [SAMPLE_WIDTH-1:0] dco_clk_cnt;
  reg [SAMPLE_WIDTH-1:0]  est_window;

  wire win_done;

  assign win_done = (est_window == 'b0)? 1'b0: 
                    (est_window == dco_clk_cnt)? 1'b1: 1'b0;

  always @(posedge gpio_in[1]) begin
    if (reset) begin
      dco_clk_cnt <= 0;
    end
    else begin
      case (state)
        INIT: dco_clk_cnt <= 0;
        LOC_SYNCH: dco_clk_cnt <= 0;
        HOP_SYNCH: dco_clk_cnt <= 0;
        HOP_TX: dco_clk_cnt <= dco_clk_cnt + 1;
        default: dco_clk_cnt <= 0;
      endcase
    end
  end

  always @(posedge clk) begin
    if (reset) begin
      usrp_clk_cnt <= 0;
      est_window <= 0;
    end
    else begin
      case (state)
        INIT: begin
          usrp_clk_cnt <= 0;
          est_window <= 0;
        end 
        LOC_SYNCH: begin
          usrp_clk_cnt <= 0;
          est_window <= 0;
        end 
        HOP_SYNCH: begin
          usrp_clk_cnt <= 0;
          est_window <= 0;
        end 
        HOP_TX: begin
          usrp_clk_cnt <= usrp_clk_cnt + 1;
          if (usrp_clk_cnt == EST_SAMPLES) begin
            est_window <= (dco_clk_cnt<<1);
          end
        end
        default: begin
          usrp_clk_cnt <= 0;
          est_window <= 0;
        end 
      endcase
      /*if (state == HOP_TX) begin
        usrp_clk_cnt <= usrp_clk_cnt + 1;
        if (usrp_clk_cnt == EST_SAMPLES) begin
          est_window <= (dco_clk_cnt<<1);
        end
      end
      else begin
        usrp_clk_cnt <= 0;
        est_window <= 0;
      end*/
    end
  end

  always @(posedge clk ) begin
    if (reset) begin
      state <= INIT;
      hop_n <= 0;
      hop_phase_inc <= HOP_START_PH_INC;
      synch_count   <= 2*SYNC_SIG_N;
      hop_reset_reg <= 1'b1;
      nbits    <= 0;
      os_count <= 0;
    end
    else begin
      case (state)
        INIT: begin
          hop_reset_reg <= 1'b1;
          state <= LOC_SYNCH;
          synch_count   <= 2*SYNC_SIG_N - 1;
          hop_n <= 0;
          hop_phase_inc <= HOP_START_PH_INC;
          nbits    <= 0;
          os_count <= 0;
        end 
        LOC_SYNCH: begin
          if (synch_count > SYNC_SIG_N) begin
            hop_reset_reg <= 1'b0;
            synch_count <= synch_count - 1;
          end
          else begin
            if (os_count >= (PRMB_OS-1)) begin
              os_count <= 0;
              if (nbits >= (NPRMB_BITS-1)) begin
                nbits <= 0;
                state <= HOP_SYNCH;
                hop_reset_reg <= 1'b1; 
              end
              else begin
                nbits <= nbits + 1;
              end
            end
            else begin
              os_count <= os_count + 1;
            end 
          end
        end
        HOP_SYNCH: begin
          hop_reset_reg <= 1'b0;
          if (synch_count > 1) begin
            synch_count <= synch_count - 1;
          end
          else begin
            state  <= HOP_TX;
          end 
        end
        HOP_TX: begin
          if (win_done) begin
            hop_reset_reg <= 1'b1;
            if(hop_n < (NUM_HOPS - 1)) begin
              hop_n <= hop_n + 1;
              state <= HOP_SYNCH;
              synch_count <= SYNC_SIG_N;
              hop_phase_inc <= hop_phase_inc + HOP_DPH_INC;
            end
            else begin
              state <= INIT;
              hop_n <= 0;
            end
          end
        end
        default: state <= INIT;
      endcase
    end  
  end

endmodule