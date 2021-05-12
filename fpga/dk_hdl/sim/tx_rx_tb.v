module tx_rx_tb();
  localparam PHASEWIDTH    = 24;
  localparam SIN_COS_WIDTH = 16;
  localparam NSYMB_WIDTH = 16;
  localparam DATA_WIDTH  = 16;
  localparam DDS_WIDTH   = 16;
  localparam REG_WIDTH   = 12;
  localparam SYNC_SIG_N = 32678;
  localparam RX_NSYMB   = 4;
  localparam TX_NSIG    = 2048;
  localparam RX_SYMBS_PER_HOP = 8;
  reg reset;
  wire clk;
  localparam [REG_WIDTH-1:0] MTX_SYNC_OUT_MASK = 12'h001;
  wire [SIN_COS_WIDTH-1:0] rx_sin, tx_sin, rf_sin, rf_cos;
  wire [SIN_COS_WIDTH-1:0] rx_cos, tx_cos;
  wire [PHASEWIDTH-1:0] rx_ph, tx_ph, rf_ph;
    
  wire [NSYMB_WIDTH-1:0] rx_symbN, tx_symbN;
  wire [PHASEWIDTH-1:0] rx_sigN, tx_sigN, rf_sigN;
  wire [DATA_WIDTH-1:0] irx_bb, qrx_bb;// itx, qtx;
  wire  [DATA_WIDTH-1:0] irx_in, qrx_in;

  wire  [DATA_WIDTH-1:0] itx_ma, qtx_ma;

  wire  [DATA_WIDTH-1:0] itx_rf, qtx_rf;

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

                  .itx(itx_ma), 
                  .qtx(qtx_ma), 

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

wire [DATA_WIDTH-1:0] id1, id2, id3, id4, id5, id6, id7, id8, id9, id10, id11, id12;
wire [DATA_WIDTH-1:0] qd1, qd2, qd3, qd4, qd5, qd6, qd7, qd8, qd9, qd10, qd11, qd12;
regN_ff R0(.clk(clk), .reset(reset), .ce(1'b1), .D(itx_ma), .Q(id1));
regN_ff R1(.clk(clk), .reset(reset), .ce(1'b1), .D(id1), .Q(id2));
regN_ff R2(.clk(clk), .reset(reset), .ce(1'b1), .D(id2), .Q(id3));
regN_ff R3(.clk(clk), .reset(reset), .ce(1'b1), .D(id3), .Q(id4));
regN_ff R4(.clk(clk), .reset(reset), .ce(1'b1), .D(id4), .Q(id5));
regN_ff R5(.clk(clk), .reset(reset), .ce(1'b1), .D(id5), .Q(id6));
regN_ff R6(.clk(clk), .reset(reset), .ce(1'b1), .D(id6), .Q(id7));
regN_ff R7(.clk(clk), .reset(reset), .ce(1'b1), .D(id7), .Q(id8));
regN_ff R8(.clk(clk), .reset(reset), .ce(1'b1), .D(id8), .Q(id9));
regN_ff R9(.clk(clk), .reset(reset), .ce(1'b1), .D(id9), .Q(id10));
regN_ff R10(.clk(clk), .reset(reset), .ce(1'b1), .D(id10), .Q(id11));
regN_ff R11(.clk(clk), .reset(reset), .ce(1'b1), .D(id11), .Q(id12));

regN_ff QR0(.clk(clk), .reset(reset), .ce(1'b1), .D(qtx_ma), .Q(qd1));
regN_ff QR1(.clk(clk), .reset(reset), .ce(1'b1), .D(qd1), .Q(qd2));
regN_ff QR2(.clk(clk), .reset(reset), .ce(1'b1), .D(qd2), .Q(qd3));
regN_ff QR3(.clk(clk), .reset(reset), .ce(1'b1), .D(qd3), .Q(qd4));
regN_ff QR4(.clk(clk), .reset(reset), .ce(1'b1), .D(qd4), .Q(qd5));
regN_ff QR5(.clk(clk), .reset(reset), .ce(1'b1), .D(qd5), .Q(qd6));
regN_ff QR6(.clk(clk), .reset(reset), .ce(1'b1), .D(qd6), .Q(qd7));
regN_ff QR7(.clk(clk), .reset(reset), .ce(1'b1), .D(qd7), .Q(qd8));
regN_ff QR8(.clk(clk), .reset(reset), .ce(1'b1), .D(qd8), .Q(qd9));
regN_ff QR9(.clk(clk), .reset(reset), .ce(1'b1), .D(qd9), .Q(qd10));
regN_ff QR10(.clk(clk), .reset(reset), .ce(1'b1), .D(qd10), .Q(qd11));
regN_ff QR11(.clk(clk), .reset(reset), .ce(1'b1), .D(qd11), .Q(qd12));


 rx_anc RX_ANC(.clk(clk), .reset(reset), .srst(1'b0),

                  /* RX IQ input */
                  .irx_in(id6), .qrx_in(qd6),
                  .in_tvalid(1'b1), .in_tlast(1'b0), 

                  /* phase valid*/
                  .phase_tvalid(1'b1), .phase_tlast(1'b0), 

                  /* IQ BB output */
                  .out_tready(1'b1), .itx(itx_rf), .qtx(qtx_rf),


                  /*debug*/
                  .ph(rf_ph), .sigN(rf_sigN), .sin(rf_sin), .cos(rf_cos));

wire [DATA_WIDTH-1:0] rid1, rid2, rid3, rid4, rid5, rid6, rid7, rid8, rid9, rid10, rid11, rid12;
wire [DATA_WIDTH-1:0] rqd1, rqd2, rqd3, rqd4, rqd5, rqd6, rqd7, rqd8, rqd9, rqd10, rqd11, rqd12;
regN_ff RR0(.clk(clk), .reset(reset), .ce(1'b1), .D(itx_rf), .Q(rid1));
regN_ff RR1(.clk(clk), .reset(reset), .ce(1'b1), .D(rid1), .Q(rid2));
regN_ff RR2(.clk(clk), .reset(reset), .ce(1'b1), .D(rid2), .Q(rid3));
regN_ff RR3(.clk(clk), .reset(reset), .ce(1'b1), .D(rid3), .Q(rid4));
regN_ff RR4(.clk(clk), .reset(reset), .ce(1'b1), .D(rid4), .Q(rid5));
regN_ff RR5(.clk(clk), .reset(reset), .ce(1'b1), .D(rid5), .Q(rid6));
regN_ff RR6(.clk(clk), .reset(reset), .ce(1'b1), .D(rid6), .Q(rid7));
regN_ff RR7(.clk(clk), .reset(reset), .ce(1'b1), .D(rid7), .Q(rid8));
regN_ff RR8(.clk(clk), .reset(reset), .ce(1'b1), .D(rid8), .Q(rid9));
regN_ff RR9(.clk(clk), .reset(reset), .ce(1'b1), .D(rid9), .Q(rid10));
regN_ff RR10(.clk(clk), .reset(reset), .ce(1'b1), .D(rid10), .Q(rid11));
regN_ff RR11(.clk(clk), .reset(reset), .ce(1'b1), .D(rid11), .Q(rid12));

regN_ff RQR0(.clk(clk), .reset(reset), .ce(1'b1), .D(qtx_rf), .Q(rqd1));
regN_ff RQR1(.clk(clk), .reset(reset), .ce(1'b1), .D(rqd1), .Q(rqd2));
regN_ff RQR2(.clk(clk), .reset(reset), .ce(1'b1), .D(rqd2), .Q(rqd3));
regN_ff RQR3(.clk(clk), .reset(reset), .ce(1'b1), .D(rqd3), .Q(rqd4));
regN_ff RQR4(.clk(clk), .reset(reset), .ce(1'b1), .D(rqd4), .Q(rqd5));
regN_ff RQR5(.clk(clk), .reset(reset), .ce(1'b1), .D(rqd5), .Q(rqd6));
regN_ff RQR6(.clk(clk), .reset(reset), .ce(1'b1), .D(rqd6), .Q(rqd7));
regN_ff RQR7(.clk(clk), .reset(reset), .ce(1'b1), .D(rqd7), .Q(rqd8));
regN_ff RQR8(.clk(clk), .reset(reset), .ce(1'b1), .D(rqd8), .Q(rqd9));
regN_ff RQR9(.clk(clk), .reset(reset), .ce(1'b1), .D(rqd9), .Q(rqd10));
regN_ff RQR10(.clk(clk), .reset(reset), .ce(1'b1), .D(rqd10), .Q(rqd11));
regN_ff RQR11(.clk(clk), .reset(reset), .ce(1'b1), .D(rqd11), .Q(rqd12));
  
  
  assign irx_in = id12 + rid12;
  assign qrx_in = qd12 + rqd12;
  
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
        repeat(3) begin
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
        file_id = $fopen("/home/user/Desktop/sim/out_data_full.txt", "wb");
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