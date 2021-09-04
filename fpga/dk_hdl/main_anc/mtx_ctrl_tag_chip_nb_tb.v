module mtx_ctrl_tag_chip_nb_tb();
    localparam PHASEWIDTH  = 24;
    localparam DATA_WIDTH  = 16;
    localparam NSYMB_WIDTH = 16;
    localparam REG_WIDTH   = 12;
    localparam TX_BITS_WIDTH = 128;
    localparam BIT_CNT_WIDTH  = 7;
    localparam NHOP_WIDTH     = 8;
    reg reset;
    wire clk;

    wire [DATA_WIDTH-1:0] mtx_cos, mtx_sin, pilot_cos, pilot_sin;
    wire [DATA_WIDTH-1:0] itx, qtx;
    wire [PHASEWIDTH-1:0] mtx_ph, pilot_ph;
    wire [PHASEWIDTH-1:0] sig_count, count_sync;
    wire [PHASEWIDTH-1:0] hop_ph_inc;
    wire [NHOP_WIDTH-1:0] nhop;
    wire [NSYMB_WIDTH-1:0] scount;
    wire [REG_WIDTH-1:0] fp_gpio_out, fp_gpio_ddr;
    reg  [REG_WIDTH-1:0] fp_gpio_in;
    wire [1:0] mtx_state;

 
    wire hop_done;

    mtx_ctrl_tag_chip_nb #(
              .DATA_WIDTH(DATA_WIDTH),
              .PHASE_WIDTH(PHASEWIDTH), 
              .NSYMB_WIDTH(NSYMB_WIDTH), 
              .NSIG(8192),
              .NUM_HOPS(4), 
              .PILOT_PH_INC(4096),
              .NSYMB(16))
        MTX_ANC(  .clk(clk),
                  .reset(reset),

                  .itx(itx), 
                  .qtx(qtx), 

                  .fp_gpio_out(fp_gpio_out), 
                  .fp_gpio_ddr(fp_gpio_ddr),
                  .fp_gpio_in(fp_gpio_in),

                  .hop_done(hop_done),
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
    
    reg [2:0] counter;
    assign clk = (counter < 3) ? 1'b1 : 1'b0;

    always #1 counter <= (counter == 4) ? 0 : counter + 1;
    reg stop_write;
    initial begin
        counter = 0;
        reset = 1'b1;
        stop_write = 1'b0;
        fp_gpio_in = 12'h000;
        #100 reset = 1'b0; 
        @(posedge clk);
        repeat(8000000) @(posedge clk);
        stop_write = 1'b1;
        $finish();
    end

    integer file_id;
    wire signed [DATA_WIDTH-1:0] itx_signed, qtx_signed;
    assign itx_signed = itx;
    assign qtx_signed = qtx;
    initial begin
        file_id = $fopen("/home/user/Desktop/sim/mtx_data_nb.txt", "wb");
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
    end


endmodule