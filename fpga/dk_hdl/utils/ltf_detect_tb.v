module ltf_detect_tb ();

localparam NDATA        = 1024*16;
localparam DATA_WIDTH   = 16;
localparam MAX_LEN      = 512;
localparam LEN          = 512;
localparam PMAG_WIDTH   = DATA_WIDTH + $clog2(MAX_LEN+1);

reg reset;
wire clk;
wire in_tvalid, in_tready, in_tlast;
wire out_tvalid, out_tready, out_tlast;
assign in_tvalid = 1'b1;
assign in_tlast  = 1'b0;
assign out_tready = 1'b1;
wire [DATA_WIDTH-1:0] in_itdata, in_qtdata, nrx_after_peak;
wire   peak_stb, peak_thres;
wire [DATA_WIDTH-1:0] zi, zq;
wire [DATA_WIDTH-1:0] ami, amq;
wire [DATA_WIDTH-1:0] pmi, pmq;
wire [PMAG_WIDTH-1:0] pow_mag_tdata, acorr_mag_tdata;
wire [PMAG_WIDTH-1:0] pow_itdata, pow_qtdata, pow;
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

reg [DATA_WIDTH-1:0] scale_reg;
wire [DATA_WIDTH-1:0] irx_scaled, qrx_scaled, scale_tdata;
wire scaled_tlast, scaled_tready, scaled_tvalid;
assign scale_tdata = scale_reg;
reg [2*DATA_WIDTH-1:0] noise_thres;

mult_rc #(
  .WIDTH_REAL(DATA_WIDTH), .WIDTH_CPLX(DATA_WIDTH),
  .WIDTH_P(DATA_WIDTH), .DROP_TOP_P(21)) 
    MULT_RC(
      .clk(clk),
      .reset(reset),

      .real_tlast(in_tlast),
      .real_tvalid(in_tvalid),
      .real_tdata(scale_tdata),
      .real_tready(in_tready),

      .cplx_tlast(in_tlast),
      .cplx_tvalid(in_tvalid),
      .cplx_tdata({in_itdata, in_qtdata}),

      .p_tready(scaled_tready), .p_tlast(scaled_tlast), .p_tvalid(scaled_tvalid),
      .p_tdata({irx_scaled, qrx_scaled}));

ltf_detect #(
  .DATA_WIDTH(DATA_WIDTH), .PMAG_WIDTH(PMAG_WIDTH), 
  .MAX_LEN(MAX_LEN), .LEN(LEN))
    DUT(
      .clk(clk), .reset(reset), .clear(reset),
      .in_tvalid(scaled_tvalid), .in_tlast(scaled_tlast), .in_tready(scaled_tready),
      .in_itdata(irx_scaled), .in_qtdata(qrx_scaled),
      .out_tvalid(out_tvalid), .out_tlast(out_tlast), .out_tready(out_tready),
      .peak_stb(peak_stb), .nrx_after_peak(nrx_after_peak), .pow(pow),
      .peak_thres(peak_thres),
      .zi(zi), .zq(zq),
      .ami(ami), .amq(amq),
      .pmi(pmi), .pmq(pmq),  .noise_thres(noise_thres),
      .pow_tdata(pow_tdata), .acorr_tdata(acorr_tdata), 
      .pow_mag_tdata(pow_mag_tdata), .acorr_mag_tdata(acorr_mag_tdata)
    );


initial begin
  $readmemh("/home/user/programs/usrp/uhd/fpga/dk_hdl/testvec/ltf_test_vec.mem", input_memory);
end

reg stop_write;

initial begin
  counter = 0;
  reset = 1'b1;
  stop_write = 1'b0;
  noise_thres = 0;
  scale_reg  = 1;
  #10 reset = 1'b0; 
  scale_reg = 2;
  noise_thres = 50000;
  repeat(2*NDATA) @(posedge clk);
  @(posedge clk);
  stop_write = 1'b1;
  //$finish();
end

integer file_id;
initial begin
  file_id = $fopen("/home/user/Desktop/data/sim/ltf_detect_out.txt", "wb");
  $display("Opened file ..................");
  @(negedge reset);
  //@(negedge stop_write);
  $display("start writing ................");
  while (!stop_write) begin
    @(negedge clk); 
    $fwrite(file_id, "%d %d %d %d %d %d %d %d %d\n", irx_scaled, qrx_scaled,
            pow_tdata, acorr_tdata, pow_mag_tdata, acorr_mag_tdata, 
            peak_thres, peak_stb, nrx_after_peak);    
  end
  $fclose(file_id);
  $display("File closed ..................");
  $finish();    
end

endmodule