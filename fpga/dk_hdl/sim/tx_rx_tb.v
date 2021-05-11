module tx_rx_tb();
  localparam PHASEWIDTH    = 24;
  localparam SIN_COS_WIDTH = 16;
  localparam NSYMB_WIDTH = 16;
  localparam DATA_WIDTH  = 16;
  localparam DDS_WIDTH   = 16;
  localparam REG_WIDTH   = 12;
  localparam SYNC_SIG_N = 32678;
  localparam RX_NSYMB   = 8;
  localparam TX_NSIG    = 2048;
  localparam RX_SYMBS_PER_HOP = 8;
  reg reset;
  wire clk;
  localparam [REG_WIDTH-1:0] MTX_SYNC_OUT_MASK = 12'h001;
  wire [SIN_COS_WIDTH-1:0] rx_sin, tx_sin;
  wire [SIN_COS_WIDTH-1:0] rx_cos, tx_cos;
  wire [PHASEWIDTH-1:0] rx_ph, tx_ph;
    
  wire [NSYMB_WIDTH-1:0] rx_symbN, tx_symbN;
  wire [PHASEWIDTH-1:0] rx_sigN, tx_sigN;
  wire [DATA_WIDTH-1:0] irx_bb, qrx_bb;// itx, qtx;
  wire  [DATA_WIDTH-1:0] irx_in, qrx_in;

  wire rx_sync_en, rx_trig, rx_out_mux, tx_trig, tx_valid,rx_valid;

  wire[1:0] rx_state;

  wire [REG_WIDTH-1:0] rx_fp_gpio_out, rx_fp_gpio_ddr, rx_fp_gpio_in;
  wire [REG_WIDTH-1:0] tx_fp_gpio_out, tx_fp_gpio_ddr, tx_fp_gpio_in;
  assign tx_fp_gpio_in = 0;
  wire tx_rx_sync = |(tx_fp_gpio_out & MTX_SYNC_OUT_MASK);
  assign rx_fp_gpio_in = tx_rx_sync ? 12'h044 : 12'h000;

  
  mtx_ctrl #(.DATA_WIDTH(DATA_WIDTH),
             .PHASE_WIDTH(PHASEWIDTH), 
             .NSYMB_WIDTH(NSYMB_WIDTH), 
             /*.NSIG(TX_NSIG), */
             .NSYMB(RX_SYMBS_PER_HOP * RX_NSYMB))
        MTX_ANC(  .clk(clk),
                  .reset(reset),

                  .itx(irx_in), 
                  .qtx(qrx_in), 

                  .fp_gpio_out(tx_fp_gpio_out), 
                  .fp_gpio_ddr(tx_fp_gpio_ddr),
                  .fp_gpio_in(tx_fp_gpio_in),

                  .tx_trig(tx_trig),
                  .tx_valid(tx_valid),
                  .symbN(tx_symbN),
                  .sigN(tx_sigN),
                  .ph(tx_ph),
                  
                  .sin(tx_sin), 
                  .cos(tx_cos));

  tag_rx_ctrl #(.SIN_COS_WIDTH(SIN_COS_WIDTH),
            .PHASE_WIDTH(PHASEWIDTH), 
            .NSYMB_WIDTH(NSYMB_WIDTH),
           /* .NSIG(TX_NSIG * RX_SYMBS_PER_HOP), */
            .NSYMB(RX_SYMBS_PER_HOP * RX_NSYMB))
   TAG_RX_CTRL(   .clk(clk),
                  .reset(reset),

                  .irx_in(irx_in), 
                  .qrx_in(qrx_in),

                  .fp_gpio_out(rx_fp_gpio_out), 
                  .fp_gpio_ddr(rx_fp_gpio_ddr),
                  .fp_gpio_in(rx_fp_gpio_in),

                  .rx_valid(rx_valid),

                  .irx_out_bb(irx_bb),
                  .qrx_out_bb(qrx_bb),
                  
                  /*.irx_out(irx_out), 
                  .qrx_out(qrx_out),
                  */
                  .rx_state(rx_state), .rx_sync_en(rx_sync_en), 
                  .rx_trig(rx_trig), .rx_out_mux(rx_out_mux),

                  .ph(rx_ph),
                  .symbN(rx_symbN),
                  .sigN(rx_sigN),
                  .sin(rx_sin), 
                  .cos(rx_cos));

    reg [2:0] counter;
    assign clk = (counter < 3) ? 1'b1 : 1'b0;

    reg stop_write;
    reg [3:0] sync_count; 
    always #1 counter <= (counter == 4) ? 0 : counter + 1;
    initial begin
        counter = 0;
        sync_count = 0;
        reset = 1'b1;
        stop_write = 1'b0;
        #100 reset = 1'b0; 
        repeat(2) begin
            sync_count = sync_count + 1;
            @(negedge rx_sync_en);
            $display("[%0t]: Synchronization %d", $time, sync_count);  
        end 
        @(posedge clk);
        stop_write = 1'b1;
        //$finish();
    end

    wire [2*DATA_WIDTH-1:0] tag_iq_data;
    wire signed [DATA_WIDTH-1:0] idat, qdat;
    assign idat = irx_bb;
    assign qdat = qrx_bb;
    assign tag_iq_data = {irx_bb, qrx_bb};
    integer file_id;
    initial begin
        file_id = $fopen("/home/user/Desktop/sim/out_data.txt", "wb");
        $display("Opened file ..................");
        @(negedge reset);
        $display("start writing ................");
        while (!stop_write) begin
            @(negedge clk); 
            $fwrite(file_id, "%d %d \n", idat, qdat);    
        end
        $fclose(file_id);
        $display("File closed ..................");
        $finish();    
    end

endmodule