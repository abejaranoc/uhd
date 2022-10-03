module gpio_ctrl_ab_tb();
    localparam GPIO_WIDTH = 12;

    localparam [GPIO_WIDTH-1:0] SYNC_OUT_MASK = 12'h535; 
    localparam [GPIO_WIDTH-1:0] TX_OUT_MASK   = 12'h800;
    localparam [GPIO_WIDTH-1:0] GPIO_OUT_MASK = SYNC_OUT_MASK | TX_OUT_MASK;
    localparam [GPIO_WIDTH-1:0] GPIO_IN_MASK  = 12'h002; 
    localparam [GPIO_WIDTH-1:0] GPIO_IO_DDR   = GPIO_OUT_MASK;

    reg clk, reset;

    reg [GPIO_WIDTH-1:0] fp_gpio_in;
    wire [GPIO_WIDTH-1:0] fp_gpio_out;
    wire [GPIO_WIDTH-1:0] fp_gpio_ddr;
    wire [GPIO_WIDTH-1:0] gpio_out;
    wire [GPIO_WIDTH-1:0] gpio_in;

    gpio_ctrl_ab #(.GPIO_REG_WIDTH(GPIO_WIDTH),
                .CLK_DIV_FAC(10),
                .OUT_MASK(GPIO_OUT_MASK),
                .IN_MASK(GPIO_IN_MASK),
                .IO_DDR(GPIO_IO_DDR))
        GPIO_CTRL(  .clk(clk),
                    .reset(reset),
                    .fp_gpio_in(fp_gpio_in),
                    .fp_gpio_out(fp_gpio_out),
                    .fp_gpio_ddr(fp_gpio_ddr),
                    .gpio_out(gpio_out),
                    .gpio_in(gpio_in));

    always #5 clk = ~clk;
    initial begin
        clk = 1'b0;
        reset = 1'b1;
        #100 reset = 1'b0; 
        @(posedge clk);
        fp_gpio_in = 12'h002;
        @(posedge clk);
        fp_gpio_in = 12'h000;
        @(posedge clk);
        fp_gpio_in = 12'h002;
        @(posedge clk);
        fp_gpio_in = 12'h000;
        @(posedge clk);
        fp_gpio_in = 12'h002;
        @(posedge clk);
        fp_gpio_in = 12'h000;
        @(posedge clk);
        fp_gpio_in = 12'h020;
        repeat(1000000) @(posedge clk);
        $finish();
    end


endmodule