module freq_shift_iq_tb();
    localparam PHASE_WIDTH = 24;
    localparam DATA_WIDTH = 16;
    localparam SIN_COS_WIDTH = 16;
    localparam SCALING_WIDTH = 18;
    localparam [PHASE_WIDTH-1:0] PH_INC = 8192;

    localparam NDATA       = 32768;
    localparam NWIDTH      = 15;

    reg  reset;
    wire clk ;

    wire [SIN_COS_WIDTH-1:0] sin, cos;
    wire [SCALING_WIDTH-1:0] scaling_tdata = {{2{1'b0}}, {(SCALING_WIDTH-2){1'b1}}};

    reg [PHASE_WIDTH-1:0] phase; 
    wire [PHASE_WIDTH-1:0] phase_tdata;
    assign phase_tdata = phase;

    wire [DATA_WIDTH-1:0] in_idata, in_qdata, out_idata, out_qdata; 
    reg [2*DATA_WIDTH-1:0] input_data;
    reg [2*DATA_WIDTH-1:0] input_memory [0:NDATA-1];

    reg [NWIDTH-1:0] ncount;

    reg [2:0] counter;
    assign clk = (counter < 3) ? 1'b1 : 1'b0;
    always #1 counter <= (counter == 4) ? 0 : counter + 1;
    assign in_idata = input_data[2*DATA_WIDTH-1:DATA_WIDTH];
    assign in_qdata = input_data[DATA_WIDTH-1:0];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            input_data <= 0;
            ncount <= 0;
            phase <= 0;
        end 
        else begin
            ncount <= ncount + 1;
            input_data <= input_memory[ncount];
            phase <= phase + PH_INC;
        end 
    end

    freq_shift_iq #(.DATA_WIDTH(DATA_WIDTH),
                    .SIN_COS_WIDTH(SIN_COS_WIDTH),
                    .PHASE_WIDTH(PHASE_WIDTH), 
                    .SCALING_WIDTH(SCALING_WIDTH))
                 DUT(   .clk(clk),
                        .reset(reset),

                        .iin(in_idata),
                        .qin(in_qdata),

                        .in_tlast(1'b0),
                        .in_tvalid(1'b1),

                        .phase_tdata(phase_tdata),
                        .scaling_tdata(scaling_tdata),

                        .phase_tlast(1'b0),
                        .phase_tvalid(1'b1),

                        .iout(out_idata),
                        .qout(out_qdata), 
                        
                        .out_tready(1'b1),

                        .sin(sin), 
                        .cos(cos));

    reg stop_write;
    initial begin
    $readmemh("/home/user/programs/usrp/uhd/fpga/dk_hdl/utils/test_vec.mem", input_memory);
    end

    initial begin
        counter = 0;
        reset <= 1'b1;
        stop_write = 1'b0;
        #10 reset = 1'b0; 
        repeat(20000) @(posedge clk);
        @(posedge clk);
        stop_write = 1'b1;
        //$finish(); 
    end
integer file_id;
initial begin
    file_id = $fopen("/home/user/Desktop/sim/fshift_mix.txt", "wb");
    $display("Opened file ..................");
    @(negedge reset);
    $display("start writing ................");
    while (!stop_write) begin
        @(negedge clk); 
        $fwrite(file_id, "%d %d \n", out_idata, out_qdata);    
    end
    $fclose(file_id);
    $display("File closed ..................");
    $finish();    
end

endmodule