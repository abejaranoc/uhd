module mtx_ctrl #(
  parameter DATA_WIDTH    = 16,
  parameter PHASE_WIDTH   = 24,
  parameter NSYMB_WIDTH   = 16,

  parameter [NSYMB_WIDTH-1:0] NSYMB        = 256, 
  parameter [PHASE_WIDTH-1:0] NSIG         = 4096,
  parameter [PHASE_WIDTH-1:0] DPH_INC      = 16384,
  parameter [PHASE_WIDTH-1:0] START_PH_INC = 8192,
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

  output tx_valid,
  /*debug*/
  output [DATA_WIDTH-1:0]  cos,
  output [DATA_WIDTH-1:0]  sin,
  output tx_trig,
  output [PHASE_WIDTH-1:0] ph,
  output [PHASE_WIDTH-1:0] ph_start,
  output [PHASE_WIDTH-1:0] sigN,
  output [NSYMB_WIDTH-1:0] symbN
);

  localparam GPIO_REG_WIDTH    = 12;
  localparam GPIO_CLK_DIV_FAC  = 10;
  localparam SYNC_SIG_N        = 8256;
  localparam [GPIO_REG_WIDTH-1:0] SYNC_OUT_MASK = 12'h001;
  localparam [GPIO_REG_WIDTH-1:0] TX_OUT_MASK   = 12'h010;
  localparam [GPIO_REG_WIDTH-1:0] GPIO_OUT_MASK = SYNC_OUT_MASK | TX_OUT_MASK;
  localparam [GPIO_REG_WIDTH-1:0] GPIO_IN_MASK  = 12'h044;
  localparam [GPIO_REG_WIDTH-1:0] GPIO_IO_DDR   = GPIO_OUT_MASK;
  


  wire [GPIO_REG_WIDTH-1:0] gpio_out, gpio_in, sync_io_out, tx_io_out;
  reg start_tx, sync_en;
  reg [1:0] sync_state;
  reg [PHASE_WIDTH-1:0] ncnt;
  wire sync_ready;

  assign tx_trig = start_tx;
  wire [DATA_WIDTH-1:0]  sin_tx, cos_tx;
  assign sin = sin_tx;
  assign cos = cos_tx;

  wire out_sel = (sync_state == 2'b10);
  assign itx = out_sel ? 0 : cos_tx;
  assign qtx = out_sel ? 0 : sin_tx;
  assign tx_valid = ~out_sel;

  assign sync_io_out = ^sync_state ? SYNC_OUT_MASK : {(GPIO_REG_WIDTH){1'b0}};
  assign tx_io_out   = out_sel ? {(GPIO_REG_WIDTH){1'b0}} : TX_OUT_MASK ;
  assign gpio_out = sync_io_out | tx_io_out;

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

  mtx_sig #(.SIN_COS_WIDTH(DATA_WIDTH),.PHASE_WIDTH(PHASE_WIDTH), 
            .NSYMB_WIDTH(NSYMB_WIDTH), .NSIG(NSIG), .NSYMB(NSYMB),
            .DPH_INC(DPH_INC), .START_PH_INC(START_PH_INC), 
            .START_PH(START_PH), .NPH_SHIFT(NPH_SHIFT))
      MTX_SIG(.clk(clk),
              .reset(reset),
              .srst(start_tx),

              .phase_tlast(1'b0),
              .phase_tvalid(1'b1),

              .sync_ready(sync_ready),
              .out_tready(1'b1),
              .sin(sin_tx), 
              .cos(cos_tx),

              .symbN(symbN),
              .sigN(sigN),
              .ph(ph),
              .ph_start(ph_start));


  always @(posedge clk) begin
      if(reset) begin
        start_tx <= 1'b1;
        sync_en <= 1'b0;
        sync_state <= 1'b00;
        ncnt   <= 0;
      end 
      else if (sync_ready && ~sync_en) begin 
        sync_en <= 1'b1;
        start_tx <= 1'b1;
        ncnt <= SYNC_SIG_N;
        sync_state <= 2'b00;
      end
      else if (sync_en && (ncnt == SYNC_SIG_N)) begin
        ncnt <= 1;
        case (sync_state)
        2'b00: begin
          sync_state <= 2'b01;
        end 
        2'b01: begin
          sync_state <= 2'b10;
        end
        2'b10: begin
          sync_state <= 2'b11;
          start_tx <= 1'b0;
        end
        2'b11: begin
          sync_en <= 1'b0; 
        end
        endcase
      end
      else if (sync_en) begin
        ncnt <= ncnt + 1;
      end
  end

endmodule