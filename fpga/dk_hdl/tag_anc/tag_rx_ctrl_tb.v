module tag_rx_ctrl_tb();
    localparam PHASEWIDTH = 24;
    localparam SIN_COS_WIDTH = 16;
    localparam NSYMB_WIDTH = 16;
    localparam DATA_WIDTH  = 16;
    localparam DDS_WIDTH   = 16;
    localparam REG_WIDTH   = 12;
    localparam SYNC_SIG_N = 32678;
    reg reset;
    wire clk;

    wire [SIN_COS_WIDTH-1:0] sin;
    wire [SIN_COS_WIDTH-1:0] cos;
    wire [PHASEWIDTH-1:0] ph;
    
    wire [NSYMB_WIDTH-1:0] scount;
    wire [DATA_WIDTH-1:0] irx_bb, qrx_bb; //, irx_out, qrx_out;
    reg  [DATA_WIDTH-1:0] irx_in, qrx_in;

    wire rx_sync_en, rx_trig, out_mux;

    wire[1:0] rx_state;

    wire rx_valid;
    wire [REG_WIDTH-1:0] fp_gpio_out, fp_gpio_ddr;
    reg  [REG_WIDTH-1:0] fp_gpio_in;

  tag_rx_ctrl #(.SIN_COS_WIDTH(SIN_COS_WIDTH),
            .PHASE_WIDTH(PHASEWIDTH), 
            .NSYMB_WIDTH(NSYMB_WIDTH),
            .NSIG(1024), 
            .NSYMB(16))
   TAG_RX_CTRL(   .clk(clk),
                  .reset(reset),

                  .irx_in(irx_in), 
                  .qrx_in(qrx_in),

                  .fp_gpio_out(fp_gpio_out), 
                  .fp_gpio_ddr(fp_gpio_ddr),
                  .fp_gpio_in(fp_gpio_in),

                  .rx_valid(rx_valid),

                  .irx_out_bb(irx_bb),
                  .qrx_out_bb(qrx_bb),
                  
                  /*.irx_out(irx_out), 
                  .qrx_out(qrx_out),
                  */
                  .rx_state(rx_state), .rx_sync_en(rx_sync_en), 
                  .rx_trig(rx_trig), .rx_out_mux(out_mux),

                  .ph(ph),
                  .symbN(scount),
                  .sin(sin), 
                  .cos(cos));

    reg [2:0] counter;
    assign clk = (counter < 3) ? 1'b1 : 1'b0;

    always #1 counter <= (counter == 4) ? 0 : counter + 1;
    initial begin
        counter = 0;
        irx_in = 32767; qrx_in = -32768;
        fp_gpio_in = 12'h000;
        reset = 1'b1;
        #100 reset = 1'b0; 
        @(posedge clk);fp_gpio_in = 12'h044; 
        repeat(SYNC_SIG_N) @(posedge clk);
        @(posedge clk);fp_gpio_in = 12'h000; 
        repeat(750000) @(posedge clk); 
        @(posedge clk);fp_gpio_in = 12'h044; 
        repeat(SYNC_SIG_N) @(posedge clk);
        @(posedge clk);fp_gpio_in = 12'h000; 
        repeat(750000) @(posedge clk);
        $finish();
    end

endmodule