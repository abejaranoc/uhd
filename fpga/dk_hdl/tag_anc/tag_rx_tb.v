module tag_rx_tb();
    localparam PHASEWIDTH = 24;
    localparam SIN_COS_WIDTH = 16;
    localparam NSYMB_WIDTH = 16;
    localparam DATA_WIDTH  = 16;
    localparam DDS_WIDTH   = 16;
    reg reset, srst;
    wire clk, sync_ready;

    wire [SIN_COS_WIDTH-1:0] sin;
    wire [SIN_COS_WIDTH-1:0] cos;
    wire [PHASEWIDTH-1:0] ph;
    wire [PHASEWIDTH-1:0] sig_count;
    wire [NSYMB_WIDTH-1:0] scount;
    wire [DATA_WIDTH-1:0] irx_bb, qrx_bb;
    reg  [DATA_WIDTH-1:0] irx_in, qrx_in;
    
   
  tag_rx #(.SIN_COS_WIDTH(SIN_COS_WIDTH),
            .PHASE_WIDTH(PHASEWIDTH), 
            .NSYMB_WIDTH(NSYMB_WIDTH),
            .NSIG(1024), 
            .NSYMB(64))
        TAG_RX(  .clk(clk),
                  .reset(reset),
                  .srst(srst),

                  .irx_in(irx_in), 
                  .qrx_in(qrx_in),

                  .in_tlast(1'b0),
                  .in_tvalid(1'b1),

                  .phase_tlast(1'b0),
                  .phase_tvalid(1'b1),

                  .irx_bb(irx_bb),
                  .qrx_bb(qrx_bb),

                  .sync_ready(sync_ready),

                  .out_tready(1'b1),
                  
                  .ph(ph),
                  .sigN(sig_count),
                  .symbN(scount),

                  .sin(sin), 
                  .cos(cos));

    reg [2:0] counter;
    assign clk = (counter < 3) ? 1'b1 : 1'b0;

    always #1 counter <= (counter == 4) ? 0 : counter + 1;
    initial begin
        counter = 0;
        irx_in = 32767; qrx_in = -32768 ;
        reset = 1'b1;
        srst  = 1'b0;
        #100 reset = 1'b0; 
        @(posedge clk);
        repeat(5000000) @(posedge clk);
        $finish();
    end


endmodule