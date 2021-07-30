module freq_shift_and_lpf_iq_tb();
    localparam PHASE_WIDTH = 24;
    localparam DATA_WIDTH = 16;
    localparam SIN_COS_WIDTH = 16;
    localparam SCALING_WIDTH = 18;
    localparam [PHASE_WIDTH-1:0] PH_INC = 1024;

    localparam COEFF_WIDTH = 16;
    localparam NUM_COEFFS  = 128;
    localparam SYMMETRIC_COEFFS = 1;
    localparam RELOADABLE_COEFFS = 1;

    localparam NDATA       = 32768;
    localparam NWIDTH      = 15;

    reg  reset;
    wire clk ;

    wire [SIN_COS_WIDTH-1:0] sin, cos;
    wire [SCALING_WIDTH-1:0] scaling_tdata = {{2{1'b0}}, {(SCALING_WIDTH-2){1'b1}}};

    reg [PHASE_WIDTH-1:0] phase; 
    wire [PHASE_WIDTH-1:0] phase_tdata;
    assign phase_tdata = phase;

    wire [DATA_WIDTH-1:0] in_itdata, in_qtdata, out_itdata, out_qtdata; 
    wire in_tready, in_tlast, in_tvalid;
    wire phase_tready, phase_tlast, phase_tvalid;
    wire out_tready, out_tlast, out_tvalid;
    wire reload_tlast;
    reg reload_tvalid;

    reg [2*DATA_WIDTH-1:0] input_data;
    reg [2*DATA_WIDTH-1:0] input_memory [0:NDATA-1];
    reg [COEFF_WIDTH-1:0] coeffs_memory [0:NUM_COEFFS/2-1];
    reg [COEFF_WIDTH-1:0] coeff_in;

    reg [NWIDTH-1:0] ncount;
    reg [NWIDTH-1:0] ccount;

    reg [2:0] counter;
    assign clk = (counter < 3) ? 1'b1 : 1'b0;
    always #1 counter <= (counter == 4) ? 0 : counter + 1;
    assign in_itdata = input_data[2*DATA_WIDTH-1:DATA_WIDTH];
    assign in_qtdata = input_data[DATA_WIDTH-1:0];

    always @(posedge clk) begin
        if (reset) begin
            input_data <= 0;
            ncount <= 0;
            phase <= 0;
            ccount <= 0;
            reload_tvalid = 1'b0;
        end 
        else begin
            ncount <= ncount + 1;
            input_data <= input_memory[ncount];
            phase <= phase - PH_INC;
            if (ccount < NUM_COEFFS/2) begin
                ccount <= ccount + 1;
                coeff_in <= coeffs_memory[ccount];
                reload_tvalid = 1'b1;
            end
            else begin
                reload_tvalid = 1'b0;
            end
        end 
    end

    assign in_tvalid    = 1'b1;
    assign in_tlast     = 1'b0;
    assign phase_tvalid = 1'b1;
    assign phase_tlast  = 1'b0;
    assign out_tready   = 1'b1;
    assign reload_tlast = 1'b0;
   

    freq_shift_and_lpf_iq #(.DATA_WIDTH(DATA_WIDTH),
                            .SIN_COS_WIDTH(SIN_COS_WIDTH),
                            .PHASE_WIDTH(PHASE_WIDTH), 
                            .SCALING_WIDTH(SCALING_WIDTH), 
                            
                            .COEFF_WIDTH(COEFF_WIDTH),
                            .NUM_COEFFS(NUM_COEFFS),
                            .SYMMETRIC_COEFFS(SYMMETRIC_COEFFS),
                            .RELOADABLE_COEFFS(RELOADABLE_COEFFS))
                 DUT(   .clk(clk),
                        .reset(reset),

                        .in_itdata(in_itdata),
                        .in_qtdata(in_qtdata),

                        .in_tlast(in_tlast),
                        .in_tvalid(in_tvalid),
                        .in_tready(in_tready),

                        .scaling_tdata(scaling_tdata),
                        .phase_tdata(phase_tdata),
                        
                        .phase_tvalid(phase_tvalid),
                        .phase_tlast(phase_tlast),
                        .phase_tready(phase_tready),

                        .coeff_in(coeff_in),
                        .reload_tlast(reload_tlast),
                        .reload_tvalid(reload_tvalid),

                        .out_itdata(out_itdata),
                        .out_qtdata(out_qtdata), 
                        
                        .out_tvalid(out_tvalid),
                        .out_tready(out_tready),
                        .out_tlast(out_tlast),

                        .sin(sin), 
                        .cos(cos));

    reg stop_write;
    initial begin
        $readmemh("/home/user/programs/usrp/uhd/fpga/dk_hdl/utils/input_data.mem", input_memory);
    end
    initial begin
        $readmemh("/home/user/programs/usrp/uhd/fpga/dk_hdl/utils/coeffs_data.mem", coeffs_memory);
    end

    initial begin
        counter = 0;
        reset <= 1'b1;
        stop_write = 1'b0;
        #10 reset = 1'b0; 
        repeat(50000) @(posedge clk);
        @(posedge clk);
        stop_write = 1'b1;
        //$finish(); 
    end
integer file_id;
initial begin
    file_id = $fopen("/home/user/Desktop/sim/fshift_lpf.txt", "wb");
    $display("Opened file ..................");
    @(negedge reset);
    $display("start writing ................");
    while (!stop_write) begin
        @(negedge clk); 
        $fwrite(file_id, "%d %d \n", out_itdata, out_qtdata);    
    end
    $fclose(file_id);
    $display("File closed ..................");
    $finish();    
end

endmodule