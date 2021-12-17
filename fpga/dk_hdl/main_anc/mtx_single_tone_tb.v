module mtx_single_tone_tb();
    localparam PHASEWIDTH = 24;
    localparam SIN_COS_WIDTH = 16;
    localparam NSYMB_WIDTH = 16;
    reg reset, srst;
    wire clk;

    wire [SIN_COS_WIDTH-1:0] sin;
    wire [SIN_COS_WIDTH-1:0] cos;
    wire [PHASEWIDTH-1:0] ph;
    wire [PHASEWIDTH-1:0] sig_count;
    wire [PHASEWIDTH-1:0] st_ph;
    //wire [NSYMB_WIDTH-1:0] scount;
 
    mtx_single_tone #(.SIN_COS_WIDTH(16),
             .PHASE_WIDTH(24), 
             .NSYMB_WIDTH(16))
        MTX_ANC(  .clk(clk),
                  .reset(reset),

                  .phase_tlast(1'b0),
                  .phase_tvalid(1'b1),

                  .out_tready(1'b1),
                  .sigN(sig_count),
                  .ph(ph),
                  
                  .sin(sin), 
                  .cos(cos));
    
    reg [2:0] counter;
    assign clk = (counter < 3) ? 1'b1 : 1'b0;

    always #1 counter <= (counter == 4) ? 0 : counter + 1;
    initial begin
        counter = 0;
        reset = 1'b1;
        srst  = 1'b0;
        #100 reset = 1'b0; 
        @(posedge clk);
        repeat(10000000) @(posedge clk);
        $finish();
    end


endmodule