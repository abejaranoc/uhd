module rx_anc_tb();
    localparam PHASEWIDTH = 24;
    localparam SIN_COS_WIDTH = 16;
    localparam NSYMB_WIDTH = 16;
    localparam DATA_WIDTH  = 16;
    localparam DDS_WIDTH   = 16;
    reg reset, srst;
    wire clk;

    wire [SIN_COS_WIDTH-1:0] sin;
    wire [SIN_COS_WIDTH-1:0] cos;
    wire [PHASEWIDTH-1:0] ph;
    wire [DATA_WIDTH-1:0] itx, qtx;
    reg  [DATA_WIDTH-1:0] irx_in, qrx_in;
    
    rx_anc RX_ANC(.clk(clk), .reset(reset), .srst(srst),

                  /* RX IQ input */
                  .irx_in(irx_in), .qrx_in(qrx_in),
                  .in_tvalid(1'b1), .in_tlast(1'b0), 

                  /* phase valid*/
                  .phase_tvalid(1'b1), .phase_tlast(1'b0), 

                  /* IQ BB output */
                  .out_tready(1'b1), .itx(itx), .qtx(qtx),


                  /*debug*/
                  .ph(ph), .sin(sin), .cos(cos));
  

    reg [2:0] counter;
    assign clk = (counter < 3) ? 1'b1 : 1'b0;

    always #1 counter <= (counter == 4) ? 0 : counter + 1;
    initial begin
        counter = 0;
        irx_in = 32767; qrx_in = -32768;
        reset = 1'b1;
        srst  = 1'b0;
        #100 reset = 1'b0; 
        @(posedge clk);
        repeat(100000) @(posedge clk);
        $finish();
    end


endmodule