module mtx_ctrl_tb();
    localparam PHASEWIDTH  = 24;
    localparam DATA_WIDTH  = 16;
    localparam NSYMB_WIDTH = 16;
    localparam REG_WIDTH   = 12;
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

    mtx_ctrl #(.DATA_WIDTH(DATA_WIDTH),
              .PHASE_WIDTH(PHASEWIDTH), 
              .NSYMB_WIDTH(NSYMB_WIDTH), 
              .NSIG(8192),
              .NSYMB(16))
        MTX_ANC(  .clk(clk),
                  .reset(reset),

                  .itx(itx), 
                  .qtx(qtx), 

                  .fp_gpio_out(fp_gpio_out), 
                  .fp_gpio_ddr(fp_gpio_ddr),
                  .fp_gpio_in(fp_gpio_in),

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
        fp_gpio_in = 12'h000;
        #100 reset = 1'b0; 
        @(posedge clk);
        repeat(2000000) @(posedge clk);
        $finish();
    end


endmodule