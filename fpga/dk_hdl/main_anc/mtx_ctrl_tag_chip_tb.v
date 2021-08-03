module mtx_ctrl_tag_chip_tb();
    localparam PHASEWIDTH  = 24;
    localparam DATA_WIDTH  = 16;
    localparam NSYMB_WIDTH = 16;
    localparam REG_WIDTH   = 12;
    localparam TX_BITS_WIDTH = 128;
    localparam BIT_CNT_WIDTH  = 7;
    reg reset;
    wire clk, tx_trig, tx_valid;

    wire [DATA_WIDTH-1:0] sin, cos;
    wire [DATA_WIDTH-1:0] itx, qtx;
    wire [PHASEWIDTH-1:0] ph;
    wire [PHASEWIDTH-1:0] sig_count;
    wire [PHASEWIDTH-1:0] st_ph;
    wire [NSYMB_WIDTH-1:0] scount;
    wire [REG_WIDTH-1:0] fp_gpio_out, fp_gpio_ddr;
    reg  [REG_WIDTH-1:0] fp_gpio_in;

    reg [TX_BITS_WIDTH-1:0] tx_bits;
    wire [BIT_CNT_WIDTH-1:0] ntx_bits_cnt;
    wire hop_clk, hop_rst;

    mtx_ctrl_tag_chip #(
              .DATA_WIDTH(DATA_WIDTH),
              .PHASE_WIDTH(PHASEWIDTH), 
              .NSYMB_WIDTH(NSYMB_WIDTH), 
              .NSIG(8192),
              .FREQ_SHIFT(4096),
              .NSYMB(9))
        MTX_ANC(  .clk(clk),
                  .reset(reset),

                  .itx(itx), 
                  .qtx(qtx), 
                  .hop_rst(hop_rst),

                  .fp_gpio_out(fp_gpio_out), 
                  .fp_gpio_ddr(fp_gpio_ddr),
                  .fp_gpio_in(fp_gpio_in),

                  .tx_bits(tx_bits),
                  .hop_clk(hop_clk),
                  .ntx_bits_cnt(ntx_bits_cnt),


                  .tx_trig(tx_trig),
                  .tx_valid(tx_valid),
                  .symbN(scount),
                  .sigN(sig_count),
                  .ph(ph),
                  .ph_start(st_ph),
                  
                  .sin(sin), 
                  .cos(cos));
    
    reg [2:0] counter;
    assign clk = (counter < 3) ? 1'b1 : 1'b0;

    always #1 counter <= (counter == 4) ? 0 : counter + 1;
    initial begin
        counter = 0;
        reset = 1'b1;
        tx_bits = { {(TX_BITS_WIDTH - 80){1'b0}}, 80'h0AAAAAAAAAAAAAAAAAAA };
        fp_gpio_in = 12'h000;
        #100 reset = 1'b0; 
        @(posedge clk);
        repeat(1000000) @(posedge clk);
        tx_bits = 0;
        //repeat(100000) @(posedge clk);
        $finish();
    end


endmodule