module tag_rx_ctrl_tb();
    localparam PHASE_WIDTH   = 24;
    localparam SIN_COS_WIDTH = 16;
    localparam NSYMB_WIDTH   = 16;
    localparam DATA_WIDTH    = 16;
    localparam DDS_WIDTH     = 16;
    localparam REG_WIDTH     = 12;
    localparam NSYNCN        = 16384;
    localparam NSYNCP        = 16384;
    localparam NSIG          = 32768 * 8;
    localparam NSYMB         = 1;
    localparam NLOC_PER_SYNC = 3;

    localparam NDATA        = 1048576*2;
    reg reset;
    wire clk;
    reg run_rx;

    wire [SIN_COS_WIDTH-1:0] sin;
    wire [SIN_COS_WIDTH-1:0] cos;
    wire [PHASE_WIDTH-1:0] ph;
    
    wire [NSYMB_WIDTH-1:0] scount;
    wire [PHASE_WIDTH-1:0]  sigN;
    wire [$clog2(NSYNCP + NSYNCN + 1)-1:0] nsync_count;

    reg  [DATA_WIDTH-1:0] scale_val;
    wire [DATA_WIDTH-1:0] irx_bb, qrx_bb; //, irx_out, qrx_out;
    wire [DATA_WIDTH-1:0] irx_in, qrx_in;
    //wire [DATA_WIDTH-1:0] pow_mag_tdata, acorr_mag_tdata;
    wire peak_stb;
    wire rx_trig, out_mux;

    wire[1:0] rx_state;

    wire rx_valid;
    wire [REG_WIDTH-1:0] fp_gpio_out, fp_gpio_ddr;
    reg  [REG_WIDTH-1:0] fp_gpio_in;

  tag_rx_ctrl #(
    .SIN_COS_WIDTH(SIN_COS_WIDTH),
    .PHASE_WIDTH(PHASE_WIDTH), 
    .NSYMB_WIDTH(NSYMB_WIDTH),
    .NSIG(NSIG), .NSYMB(NSYMB),
    .NLOC_PER_SYNC(NLOC_PER_SYNC))
      TAG_RX_CTRL(
        .clk(clk),
        .reset(reset),
        .run_rx(run_rx),

        .irx_in(irx_in), .qrx_in(qrx_in),
        .scale_val(scale_val),

        .fp_gpio_out(fp_gpio_out), 
        .fp_gpio_ddr(fp_gpio_ddr),
        .fp_gpio_in(fp_gpio_in),

        .rx_valid(rx_valid),

        .irx_out_bb(irx_bb),
        .qrx_out_bb(qrx_bb),
                  
        .rx_state(rx_state),  
        .rx_trig(rx_trig), .rx_out_mux(out_mux),
        .peak_detect_stb(peak_stb),

        /*
        .pow_mag_tdata(pow_mag_tdata), 
        .acorr_mag_tdata(acorr_mag_tdata),
        */

        .ph(ph), .symbN(scount), 
        .sigN(sigN), .nsync_count(nsync_count),
        .sin(sin), .cos(cos)
      );

    reg [2:0] counter;
    assign clk = (counter < 3) ? 1'b1 : 1'b0;
    always #1 counter <= (counter == 4) ? 0 : counter + 1;

    reg [2*DATA_WIDTH-1:0] in_data;
    reg [2*DATA_WIDTH-1:0] input_memory [0:NDATA-1];
    assign irx_in  = in_data[2*DATA_WIDTH-1:DATA_WIDTH];
    assign qrx_in = in_data[DATA_WIDTH-1:0];
    reg [$clog2(NDATA)-1:0] ncount;

    initial begin
        $readmemh("/home/user/programs/usrp/uhd/fpga/dk_hdl/testvec/rx_test_vec.mem", input_memory);
    end

    always @(posedge clk) begin
      if (reset) begin
        in_data <= 0;
        ncount  <= 0;
      end 
      else begin
        ncount  <= ncount + 1;
        in_data <= input_memory[ncount];
      end 
    end

    reg stop_write;
    initial begin
        counter = 0;
        run_rx = 0;
        reset   = 1'b1;
        fp_gpio_in = 12'h000;
        stop_write = 1'b0;
        scale_val  = 0;
        reset = 1'b1;
        #100 reset = 1'b0; 
        repeat(1000) @(posedge clk);
        run_rx = 1'b1;
        scale_val  = 1;
        repeat(4*NDATA) @(posedge clk);
        @(posedge clk);
        stop_write = 1'b1;
        $finish();
    end

endmodule