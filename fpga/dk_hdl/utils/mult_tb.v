module mult_tb ();

localparam DATA_WIDTH    = 16;
localparam SCALING_WIDTH = 18;
localparam NDATA         = 16384;
localparam NWIDTH = 14;



reg reset;
wire clk;
wire [DATA_WIDTH-1:0] a_tdata, b_tdata, p_tdata;
reg [2*DATA_WIDTH-1:0] ain_data;
reg [2*DATA_WIDTH-1:0] bin_data;
reg [2*DATA_WIDTH-1:0] input_memory [0:NDATA-1];
reg [2*DATA_WIDTH-1:0] input_memory2 [0:NDATA-1];



assign a_tdata = ain_data[2*DATA_WIDTH-1:DATA_WIDTH];
assign b_tdata = ain_data[DATA_WIDTH-1:0];

reg [NWIDTH-1:0] ncount;

reg [2:0] counter;
assign clk = (counter < 3) ? 1'b1 : 1'b0;

always #1 counter <= (counter == 4) ? 0 : counter + 1;

always @(posedge clk) begin
  if (reset) begin
    ain_data <= 0;
    bin_data <= 0;
    ncount <= 0;
  end 
  else begin
    ncount <= ncount + 1;
    ain_data <= input_memory[ncount];
    bin_data <= input_memory2[ncount];
  end 
end


mult #(
   .WIDTH_A(DATA_WIDTH),
   .WIDTH_B(DATA_WIDTH),
   .WIDTH_P(DATA_WIDTH),
   .DROP_TOP_P(0),
   .LATENCY(3),       // NOTE: If using CASCADE_OUT, set to 3
   .CASCADE_OUT(0)) 
MUL_DUT(
      .clk(clk),
      .reset(reset),

      .a_tlast(1'b0),
      .a_tvalid(1'b1),
      .a_tdata(a_tdata),

      .b_tlast(1'b0),
      .b_tvalid(1'b1),
      .b_tdata(b_tdata),


      .p_tready(1'b1),
      .p_tdata(p_tdata));

reg stop_write;
initial begin
  $readmemh("/home/user/programs/usrp/uhd/fpga/dk_hdl/utils/atest_vec.mem", input_memory);
end

initial begin
  $readmemh("/home/user/programs/usrp/uhd/fpga/dk_hdl/utils/btest_vec.mem", input_memory2);
end

initial begin
  counter = 0;
  reset = 1'b1;
  stop_write = 1'b0;
  #10 reset = 1'b0; 
  repeat(20000) @(posedge clk);
  @(posedge clk);
  stop_write = 1'b1;
  //$finish();
end

/*
integer file_id;
initial begin
  file_id = $fopen("/home/user/Desktop/sim/out_data_cmul_16.txt", "wb");
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

*/

endmodule