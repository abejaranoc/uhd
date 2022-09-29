module mult_rc_tb ();

localparam DATA_WIDTH    = 16;
localparam NDATA         = 32768;
/*DROP_TOP_P = 6 for Inputs FP(16, 15) -> Output FP(16, 15)*/
localparam DROP_TOP_P    = 6; 

reg reset;
wire clk;
wire [DATA_WIDTH-1:0] in_itdata, in_qtdata;
reg [DATA_WIDTH-1:0] scale_tdata, scale;
wire [DATA_WIDTH-1:0] out_itdata, out_qtdata;

reg [2*DATA_WIDTH-1:0] in_data;
reg [2*DATA_WIDTH-1:0] input_memory [0:NDATA-1];

assign in_itdata = in_data[2*DATA_WIDTH-1:DATA_WIDTH];
assign in_qtdata = in_data[DATA_WIDTH-1:0];



reg [2:0] counter;
assign clk = (counter < 3) ? 1'b1 : 1'b0;

always #1 counter <= (counter == 4) ? 0 : counter + 1;

reg [$clog2(NDATA)-1:0] ncount;

always @(posedge clk) begin
  if (reset) begin
    in_data <= 0;
    ncount <= 0;
  end 
  else begin
    ncount  <= ncount + 1;
    in_data <= input_memory[ncount];
  end 
  scale_tdata <= scale;
end

mult_rc #(
  .WIDTH_REAL(DATA_WIDTH), .WIDTH_CPLX(DATA_WIDTH),
  .WIDTH_P(DATA_WIDTH), .DROP_TOP_P(DROP_TOP_P)) 
    CMUL_DUT(
      .clk(clk),
      .reset(reset),

      .real_tlast(1'b0),
      .real_tvalid(1'b1),
      .real_tdata(scale_tdata),

      .cplx_tlast(1'b0),
      .cplx_tvalid(1'b1),
      .cplx_tdata({in_itdata, in_qtdata}),

      .p_tready(1'b1),
      .p_tdata({out_itdata, out_qtdata}));


initial begin
  $readmemh("/home/user/programs/usrp/uhd/fpga/dk_hdl/testvec/mult_rc.mem", input_memory);
end
reg stop_write;

initial begin
  counter = 0;
  reset = 1'b1;
  stop_write = 1'b0;
  scale = 32767;
  #100 reset = 1'b0; 
  repeat(NDATA) @(posedge clk);
  scale = 24576;
  repeat(NDATA) @(posedge clk);
  scale = -24576;
  repeat(NDATA) @(posedge clk);
  scale = -2048;
  repeat(NDATA) @(posedge clk);
  @(posedge clk)
  stop_write = 1'b1;
  //$finish();
end

integer file_id;
initial begin
  file_id = $fopen("/home/user/Desktop/data/sim/mult_rc.txt", "wb");
  $display("Opened file ..................");
  @(negedge reset);
  //@(negedge stop_write);
  $display("start writing ................");
  while (!stop_write) begin
    @(negedge clk); 
    $fwrite(file_id, "%d %d %d %d %d\n", in_itdata, in_qtdata,
            scale_tdata, out_itdata, out_qtdata);    
  end
  $fclose(file_id);
  $display("File closed ..................");
  $finish();    
end

endmodule