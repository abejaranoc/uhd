module tag_rx_ctrl_tag_chip_nb_tb();

    localparam DATA_WIDTH  = 16;
    localparam GPIO_REG_WIDTH   = 12;
    localparam SYNC_SIG_N = 8192;
    localparam BIT_CNT_WIDTH  = 7;
    localparam NSIG_WIDTH = 24;
    reg reset;
    wire clk;
    
    wire [NSIG_WIDTH-1:0] sync_count;
    wire [DATA_WIDTH-1:0] irx_out, qrx_out; //, irx_out, qrx_out;
    reg  [DATA_WIDTH-1:0] irx_in, qrx_in;
    wire [BIT_CNT_WIDTH-1:0] ntx_bits_cnt;
    wire [NSIG_WIDTH-1:0] nrx_sig;
    wire [BIT_CNT_WIDTH-1:0] nhop;
    wire hop_clk, hop_reset;
    wire [127:0] if_code;
    wire[1:0] rx_state;

    wire rx_valid;
    wire [GPIO_REG_WIDTH-1:0] fp_gpio_out, fp_gpio_ddr;
    reg  [GPIO_REG_WIDTH-1:0] fp_gpio_in;

  tag_rx_ctrl_tag_chip_nb #(
    .DATA_WIDTH(DATA_WIDTH), .NUM_HOPS(8),
    .GPIO_REG_WIDTH(GPIO_REG_WIDTH))
   TAG_RX_CTRL(   .clk(clk),
                  .reset(reset),

                  .irx_in(irx_in), 
                  .qrx_in(qrx_in),

                  .fp_gpio_out(fp_gpio_out), 
                  .fp_gpio_ddr(fp_gpio_ddr),
                  .fp_gpio_in(fp_gpio_in),

                  .rx_valid(rx_valid),

                  .irx_out(irx_out),
                  .qrx_out(qrx_out),
                  
                  .rx_state(rx_state), 
                  .counter_sync(sync_count),
                  
                  .hop_rst(hop_reset), .hop_clk(hop_clk), .nhop(nhop),
                  .ntx_bits_cnt(ntx_bits_cnt), .if_code(if_code),
                  .nrx_sig(nrx_sig));

    reg [2:0] counter;
    assign clk = (counter < 3) ? 1'b1 : 1'b0;

    always #1 counter <= (counter == 4) ? 0 : counter + 1;
    initial begin
        counter = 0;
        irx_in = 16000; qrx_in = -16000;
        fp_gpio_in = 12'h000;
        reset = 1'b1;
        #100 reset = 1'b0; 
        @(posedge clk); fp_gpio_in = 12'h022; 
        repeat(4000000) @(posedge clk);
        @(posedge clk); fp_gpio_in = 12'h000; 
        repeat(4000000) @(posedge clk);
        $finish();
    end

endmodule