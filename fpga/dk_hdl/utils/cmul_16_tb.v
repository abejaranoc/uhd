module cmul_16_tb ();

//`include "coeffs.vh"

localparam DATA_WIDTH  = 16;

localparam NDATA       = 16384;



reg reset;
wire clk;
wire [DATA_WIDTH-1:0] ain_idata, ain_qdata, bin_idata, bin_qdata;
reg [2*DATA_WIDTH-1:0] ain_data;
reg [2*DATA_WIDTH-1:0] bin_data;
reg [2*DATA_WIDTH-1:0] input_memory [0:NDATA-1];
reg [2*DATA_WIDTH-1:0] input_memory2 [0:NDATA-1];
wire [2*DATA_WIDTH-1:0] prod_data;
wire [DATA_WIDTH-1:0] out_idata, out_qdata;
assign out_idata = prod_data[2*DATA_WIDTH-1:DATA_WIDTH];
assign out_qdata = prod_data[DATA_WIDTH-1:0];
assign ain_idata = ain_data[2*DATA_WIDTH-1:DATA_WIDTH];
assign ain_qdata = ain_data[DATA_WIDTH-1:0];
assign bin_idata = bin_data[2*DATA_WIDTH-1:DATA_WIDTH];
assign bin_qdata = bin_data[DATA_WIDTH-1:0];
reg [13:0] ncount;

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


cmul_16 CMUL_DUT(
      .clk(clk),
      .reset(reset),
      .adata(ain_data),
      .bdata(bin_data),
      .pdata(prod_data));

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



endmodule