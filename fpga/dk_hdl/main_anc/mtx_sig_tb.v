module mtx_sig_tb();
    localparam PHASEWIDTH = 24;
    localparam SIN_COS_WIDTH = 16;
    localparam NSYMB_WIDTH = 16;
    reg clk, reset, srst;

    wire [SIN_COS_WIDTH-1:0] sin;
    wire [SIN_COS_WIDTH-1:0] cos;
    wire [PHASEWIDTH-1:0] ph;
    wire [PHASEWIDTH-1:0] sig_count;
    wire [PHASEWIDTH-1:0] st_ph;
    wire [NSYMB_WIDTH-1:0] scount;
    wire out_tvalid, out_tlast, phase_tready;
    wire phase_tlast = 1'b0;
    wire phase_tvalid = 1'b1;
    wire out_tready = 1'b1;
    
    
    
  mtx_sig #(.SIN_COS_WIDTH(SIN_COS_WIDTH),
            .PHASE_WIDTH(PHASEWIDTH), 
            .NSYMB_WIDTH(NSYMB_WIDTH), 
            .NSYMB(16))
            DUT(  .clk(clk),
                  .reset(reset),
                  .srst(srst),

                  .phase_tready(phase_tready),
                  .phase_tlast(phase_tlast),
                  .phase_tvalid(phase_tvalid),

                  .out_tlast(out_tlast), 
                  .out_tvalid(out_tvalid),
                  .out_tready(out_tready),
                  
                  .ph(ph),
                  .ph_start(st_ph),
                  .sigN(sig_count),
                  .symbN(scount),

                  .sin(sin), 
                  .cos(cos));

    always #5 clk = ~clk;
    initial begin
        clk = 1'b0;
        reset = 1'b1;
        srst  = 1'b0;
        #100 reset = 1'b0; 
        @(posedge clk);
        repeat(100000) @(posedge clk);
        $finish();
    end


endmodule