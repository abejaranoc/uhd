module hop_ctrl_tb();
    
    reg reset, srst;
    wire clk;
    localparam TX_BITS_WIDTH = 128;
    localparam BIT_CNT_WIDTH  = 7;

    wire scan_id, scan_phi, scan_phi_bar, scan_data_in, scan_load_chip;
    reg [TX_BITS_WIDTH-1:0] data_in;

    
    wire [1:0] scan_cnt;
    wire [BIT_CNT_WIDTH - 1:0] nbits_tx;

    reg [2:0] counter;
    assign clk = (counter < 3) ? 1'b1 : 1'b0;

    hop_ctrl DUT(
        .clk(clk), .reset(reset), 

        .scan_id(scan_id),
        .scan_phi(scan_phi),
        .scan_phi_bar(scan_phi_bar), 

        .scan_data_in(scan_data_in),
        .scan_load_chip(scan_load_chip),

        .nbits_cnt(nbits_tx),
        .scan_chk(scan_cnt),

        .data_in(data_in));
    

    always #1 counter <= (counter == 4) ? 0 : counter + 1;
    initial begin
        counter = 0;
        srst   = 1'b0;
        reset = 1'b1;
        data_in = { {(TX_BITS_WIDTH - 80){1'b0}}, 80'h0AAAAAAAAAAAAAAAAAAA };
        #100 reset = 1'b0; 
        @(posedge clk);
        repeat(1000) @(posedge clk);
        reset = 1'b1; 
        data_in = 0;
        #100 reset = 1'b0; 
        repeat(1000) @(posedge clk);
        reset = 1'b1; 
        data_in = { {(TX_BITS_WIDTH - 80){1'b0}}, 80'h0AAAAAAAAAAAAAAAAAAA};
        #100 reset = 1'b0; 
        repeat(1000) @(posedge clk);
        $finish();
    end


endmodule