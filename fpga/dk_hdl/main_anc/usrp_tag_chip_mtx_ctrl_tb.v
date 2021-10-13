module usrp_tag_chip_mtx_ctrl_tb();
    localparam PHASE_WIDTH   = 24;
    localparam DATA_WIDTH    = 16;
    localparam NSYMB_WIDTH   = 16;
    localparam REG_WIDTH     = 12;
    localparam NLOC_PER_SYNC = 3;
    localparam NSIG          = 8192;
    localparam NSYMB         = 24;
    reg reset;
    wire clk, tx_trig, tx_valid;

    wire [DATA_WIDTH-1:0] qmtx, imtx;
    wire [DATA_WIDTH-1:0] itx, qtx;
    wire [PHASE_WIDTH-1:0] mtx_ph, pilot_ph;
    wire [PHASE_WIDTH-1:0] sigN, pilot_sigN;
    wire [NSYMB_WIDTH-1:0] symbN, pilot_symbN;
    wire [REG_WIDTH-1:0] fp_gpio_out, fp_gpio_ddr;
    reg  [REG_WIDTH-1:0] fp_gpio_in;

    usrp_tag_chip_mtx_ctrl #(
      .DATA_WIDTH(DATA_WIDTH),
      .PHASE_WIDTH(PHASE_WIDTH), 
      .NSYMB_WIDTH(NSYMB_WIDTH), 
      .NSIG(NSIG), .PILOT_NSIG(NSIG * 8),
      .NSYMB(NSYMB))
        MTX_ANC(  .clk(clk),
                  .reset(reset),

                  .itx(itx), 
                  .qtx(qtx), 

                  .fp_gpio_out(fp_gpio_out), 
                  .fp_gpio_ddr(fp_gpio_ddr),
                  .fp_gpio_in(fp_gpio_in),

                  .tx_trig(tx_trig),
                  .tx_valid(tx_valid),
                  .mtx_symbN(symbN), .pilot_symbN(pilot_symbN),
                  .mtx_sigN(sigN), .pilot_sigN(pilot_sigN),
                  .mtx_ph(mtx_ph), .pilot_ph(pilot_ph),
                  
                  .qmtx(qmtx), 
                  .imtx(imtx));
    
    reg [2:0] counter;
    assign clk = (counter < 3) ? 1'b1 : 1'b0;

    always #1 counter <= (counter == 4) ? 0 : counter + 1;
    initial begin
        counter = 0;
        reset = 1'b1;
        fp_gpio_in = 12'h000;
        #100 reset = 1'b0; 
        @(posedge clk);
        repeat(16 * NSYMB * NSIG) @(posedge clk);
        $finish();
    end


endmodule