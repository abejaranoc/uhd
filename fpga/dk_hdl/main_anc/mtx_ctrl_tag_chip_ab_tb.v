`timescale 1ps/1ps 
module mtx_ctrl_tag_chip_ab_tb();
    localparam PHASEWIDTH  = 24;
    localparam DATA_WIDTH  = 16;
    localparam NSYMB_WIDTH = 16;
    localparam REG_WIDTH   = 12;
    localparam TX_BITS_WIDTH = 128;
    localparam BIT_CNT_WIDTH  = 7;
    reg reset;
    reg clk;
    reg dco_clk; 

    wire [DATA_WIDTH-1:0] mtx_cos, mtx_sin, pilot_cos, pilot_sin;
    wire [DATA_WIDTH-1:0] itx, qtx;
    wire [PHASEWIDTH-1:0] mtx_ph, pilot_ph;
    wire [PHASEWIDTH-1:0] sig_count, count_sync;
    wire [PHASEWIDTH-1:0] hop_ph_inc;
    wire [BIT_CNT_WIDTH-1:0] nhop;
    wire [NSYMB_WIDTH-1:0] scount;
    wire [REG_WIDTH-1:0] fp_gpio_out, fp_gpio_ddr;
    // reg  [REG_WIDTH-1:0] fp_gpio_in;
    wire [1:0] mtx_state;

    reg [TX_BITS_WIDTH-1:0] tx_bits;
    wire [BIT_CNT_WIDTH-1:0] ntx_bits_cnt;
    wire hop_clk, hop_rst;


    mtx_ctrl_tag_chip_ab #(
              .DATA_WIDTH(DATA_WIDTH),
              .PHASE_WIDTH(PHASEWIDTH), 
              .NSYMB_WIDTH(NSYMB_WIDTH), 
              .NSIG(8192), 
              .PILOT_PH_INC(4096),
              .NSYMB(9))
        MTX_ANC(  .clk(clk),
                  .reset(reset),

                  .itx(itx), 
                  .qtx(qtx), 
                  .hop_rst(hop_rst),

                  .fp_gpio_out(fp_gpio_out), 
                  .fp_gpio_ddr(fp_gpio_ddr),
                  .fp_gpio_in({10'b0, dco_clk, 1'b0}),

                  .tx_bits(tx_bits),
                  .hop_clk(hop_clk),
                  .ntx_bits_cnt(ntx_bits_cnt),


                  .symbN(scount),
                  .sigN(sig_count),
                  .count_sync(count_sync),
                  .mtx_ph(mtx_ph),
                  .pilot_ph(pilot_ph),
                  .hop_ph_inc(hop_ph_inc),
                  .nhop(nhop),
                  .mtx_state(mtx_state),
                  .mtx_data({mtx_cos, mtx_sin}), 
                  .pilot_data({pilot_cos, pilot_sin}));
    

    always #2500 clk = ~clk;

    always #24000 dco_clk = ~dco_clk;

    initial begin
        clk = 1'b0;
        dco_clk = 1'b0;
        reset = 1'b1;
        #10000 reset = 1'b0; 
        repeat(2000000000) @(posedge clk);
        $finish();
    end
    /*reg [2:0] counter;
    assign clk = (counter < 3) ? 1'b1 : 1'b0;

    always #1 counter <= (counter == 4) ? 0 : counter + 1;
    reg stop_write;
    initial begin
        counter = 0;
        reset = 1'b1;
        stop_write = 1'b0;
        tx_bits = { {(TX_BITS_WIDTH - 80){1'b0}}, 80'h0AAAAAAAAAAAAAAAAAAA };
        fp_gpio_in = 12'h000;
        #100 reset = 1'b0; 
        @(posedge clk);
        repeat(25000000) @(posedge clk);
        tx_bits = 0;
        stop_write = 1'b1;
        $finish();
    end

    integer file_id;
    wire signed [DATA_WIDTH-1:0] itx_signed, qtx_signed;
    assign itx_signed = itx;
    assign qtx_signed = qtx;
    initial begin
        file_id = $fopen("/home/user/Desktop/sim/mtx_data.txt", "wb");
        $display("Opened file ..................");
        @(negedge reset);
        $display("start writing ................");
        while (!stop_write) begin
            @(negedge clk); 
            $fwrite(file_id, "%d %d \n", itx_signed, qtx_signed);    
        end
        $fclose(file_id);
        $display("File closed ..................");
        $finish();    
    end*/


endmodule