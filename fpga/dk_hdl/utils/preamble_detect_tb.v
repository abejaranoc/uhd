module preamble_detect_tb ();

localparam NDATA        = 1048576*2;
localparam DATA_WIDTH   = 16;
localparam DEC_MAX_RATE = 255;
localparam DEC_RATE     = 64;
localparam MAX_LEN      = 4095;
localparam LEN          = 4092;
localparam PMAG_WIDTH   = DATA_WIDTH + $clog2(MAX_LEN+1);

reg reset;
wire clk;
wire in_tvalid, in_tready, in_tlast;
wire out_tvalid, out_tready, out_tlast;
assign in_tvalid = 1'b1;
assign in_tlast  = 1'b0;
assign out_tready = 1'b1;
wire [DATA_WIDTH-1:0] in_itdata, in_qtdata;
wire  dec_stb, peak_stb;
wire [DATA_WIDTH-1:0] idec, qdec;
wire [DATA_WIDTH-1:0] zi, zq;
wire [DATA_WIDTH-1:0] ami, amq;
wire [DATA_WIDTH-1:0] pmi, pmq;
wire [PMAG_WIDTH-1:0] pow_mag_tdata, acorr_mag_tdata;
wire [PMAG_WIDTH-1:0] pow_itdata, pow_qtdata;
wire [PMAG_WIDTH-1:0] acorr_itdata, acorr_qtdata;
wire [2*PMAG_WIDTH-1:0] pow_tdata, acorr_tdata;
assign acorr_qtdata = acorr_tdata[PMAG_WIDTH-1:0];
assign acorr_itdata = acorr_tdata[2*PMAG_WIDTH-1:PMAG_WIDTH];
assign pow_qtdata = pow_tdata[DATA_WIDTH-1:0];
assign pow_itdata = pow_tdata[2*DATA_WIDTH-1:DATA_WIDTH];

reg [2*DATA_WIDTH-1:0] in_data;
reg [2*DATA_WIDTH-1:0] input_memory [0:NDATA-1];

assign in_itdata = in_data[2*DATA_WIDTH-1:DATA_WIDTH];
assign in_qtdata = in_data[DATA_WIDTH-1:0];

reg [$clog2(NDATA)-1:0] ncount;


reg [2:0] counter;
assign clk = (counter < 3) ? 1'b1 : 1'b0;

always #1 counter <= (counter == 4) ? 0 : counter + 1;

always @(posedge clk) begin
  if (reset) begin
    in_data <= 0;
    ncount <= 0;
  end 
  else begin
    ncount  <= ncount + 1;
    in_data <= input_memory[ncount];
  end 
end

preamble_detect #(
  .DATA_WIDTH(DATA_WIDTH), .DEC_MAX_RATE(DEC_MAX_RATE),
  .PMAG_WIDTH(PMAG_WIDTH), .DEC_RATE(DEC_RATE), 
  .MAX_LEN(MAX_LEN), .LEN(LEN))
    DUT(
      .clk(clk), .reset(reset), .clear(reset),
      .in_tvalid(in_tvalid), .in_tlast(in_tlast), .in_tready(in_tready),
      .in_itdata(in_itdata), .in_qtdata(in_qtdata),
      .out_tvalid(out_tvalid), .out_tlast(out_tlast), .out_tready(out_tready),
      .peak_stb(peak_stb),
      .dec_stb(dec_stb), 
      .idec(idec), .qdec(qdec), 
      .zi(zi), .zq(zq),
      .ami(ami), .amq(amq),
      .pmi(pmi), .pmq(pmq),
      .pow_tdata(pow_tdata), .acorr_tdata(acorr_tdata), 
      .pow_mag_tdata(pow_mag_tdata), .acorr_mag_tdata(acorr_mag_tdata)
    );


initial begin
  $readmemh("/home/user/programs/usrp/uhd/fpga/dk_hdl/testvec/rx_test_vec.mem", input_memory);
end

reg stop_write;

initial begin
  counter = 0;
  reset = 1'b1;
  stop_write = 1'b0;
  #10 reset = 1'b0; 
  repeat(2*NDATA) @(posedge clk);
  @(posedge clk);
  stop_write = 1'b1;
  $finish();
end

/*
integer file_id;
initial begin
  file_id = $fopen("/home/user/Desktop/sim/out_cic_decim.txt", "wb");
  $display("Opened file ..................");
  @(negedge reset);
  $display("start writing ................");
  while (!stop_write) begin
    @(negedge istrobe_out); 
    $fwrite(file_id, "%d %d \n", out_idata, out_qdata);    
  end
  $fclose(file_id);
  $display("File closed ..................");
  $finish();    
end

*/

endmodule