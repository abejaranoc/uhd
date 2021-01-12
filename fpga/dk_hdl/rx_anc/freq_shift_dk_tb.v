module freq_shift_dk_tb();
    localparam PHASEWIDTH = 24;
    localparam DATAWIDTH = 16;
    localparam SIN_COS_WIDTH = 16;
    reg clk, reset;
    reg [DATAWIDTH-1:0]   r1;
    reg [DATAWIDTH-1:0]   r2;
    reg [PHASEWIDTH-1:0]  r3;
    wire [DATAWIDTH-1:0]  iin = r1;
    wire [DATAWIDTH-1:0]  qin = r2;
    wire [PHASEWIDTH-1:0] phase_inc = r3;
    wire [DATAWIDTH-1:0]  iout;
    wire [DATAWIDTH-1:0]  qout;
    wire [SIN_COS_WIDTH-1:0] sin;
    wire [SIN_COS_WIDTH-1:0] cos;
    wire out_tvalid, out_tlast, in_tready, phase_tready;
    wire in_tlast = 1'b0;
    wire in_tvalid = 1'b1;
    wire phase_tlast = 1'b0;
    wire phase_tvalid = 1'b1;
    wire out_tready = 1'b1;
    
    
    
  freq_shift_dk #(.DATA_WIDTH(DATAWIDTH),
                  .SIN_COS_WIDTH(SIN_COS_WIDTH),
                  .PHASE_WIDTH(PHASEWIDTH))
                 DUT(.clk(clk),
                  .reset(reset),
                  .iin(iin),
                  .qin(qin),
                  .in_tready(in_tready),
                  .in_tlast(in_tlast),
                  .in_tvalid(in_tvalid),

                  .phase_inc(phase_inc),
                  .phase_tready(phase_tready),
                  .phase_tlast(phase_tlast),
                  .phase_tvalid(phase_tvalid),

                  .iout(iout),
                  .qout(qout), 
                  .out_tlast(out_tlast), 
                  .out_tvalid(out_tvalid),
                  .out_tready(out_tready),

                  .sin(sin), 
                  .cos(cos));

    always #5 clk = ~clk;
    initial begin
        r1 = 0;
        r2 = 0;
        r3 = 0;
        clk = 1'b0;
        reset = 1'b1;
        #100 reset = 1'b0;
        @(posedge clk);
        r1 = 16384;
        r2 = 0;
        r3 = 16777;
        repeat(10000) @(posedge clk);
        $finish();
    end


endmodule