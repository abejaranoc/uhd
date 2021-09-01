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
    wire [PHASEWIDTH-1:0] ph, rx_in_ph_tdata, sigN;
    reg [PHASEWIDTH-1:0] rx_ph;
    wire [DATA_WIDTH-1:0] itx, qtx;
    wire  signed [DATA_WIDTH-1:0] irx_in, qrx_in, rx_cos, rx_sin;
    assign irx_in = rx_cos >>> 1;
    assign qrx_in = rx_sin >>> 1;
    rx_anc RX_ANC(.clk(clk), .reset(reset), .srst(srst),

                  /* RX IQ input */
                  .irx_in(irx_in), .qrx_in(qrx_in),
                  .in_tvalid(1'b1), .in_tlast(1'b0), 

                  /* phase valid*/
                  .phase_tvalid(1'b1), .phase_tlast(1'b0), 

                  /* IQ BB output */
                  .out_tready(1'b1), .itx(itx), .qtx(qtx),


                  /*debug*/
                  .sigN(sigN),
                  .ph(ph), .sin(sin), .cos(cos));
  
    localparam [PHASEWIDTH-1:0] RX_DPH_INC = 12228;
    assign rx_in_ph_tdata = rx_ph;

    dds_sin_cos_lut_only dds_inst (
        .aclk(clk),                                // input wire aclk
        .aresetn(~reset),            // input wire aresetn active low rst
        .s_axis_phase_tvalid(1'b1),  // input wire s_axis_phase_tvalid
        .s_axis_phase_tready(),  // output wire s_axis_phase_tready
        .s_axis_phase_tlast(1'b0),    //tlast
        .s_axis_phase_tdata(rx_in_ph_tdata),    // input wire [23 : 0] s_axis_phase_tdata
        .m_axis_data_tvalid(),    // output wire m_axis_data_tvalid
        .m_axis_data_tready(1'b1),    // input wire m_axis_data_tready
        .m_axis_data_tlast(),      // output wire m_axis_data_tready
        .m_axis_data_tdata({rx_sin, rx_cos})      // output wire [31 : 0] m_axis_data_tdata
    );

    reg [2:0] counter;
    assign clk = (counter < 3) ? 1'b1 : 1'b0;

    always #1 counter <= (counter == 4) ? 0 : counter + 1;
    initial begin
        counter = 0;
        reset = 1'b1;
        srst  = 1'b0;
        #100 reset = 1'b0; 
        @(posedge clk);
        repeat(100000) @(posedge clk);
        $finish();
    end
    
    always @(posedge clk ) begin
        if (reset) begin
            rx_ph <= 0;
        end
        else begin
            rx_ph = rx_ph + RX_DPH_INC; 
        end
        
    end


endmodule