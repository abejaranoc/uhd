module cmul_tb ();



localparam DATA_WIDTH    = 16;
localparam SCALING_WIDTH = 18;
localparam NDATA         = 4096;
localparam NWIDTH = 14;



reg reset;
wire clk;
wire [DATA_WIDTH-1:0] ain_idata, ain_qdata, bin_idata, bin_qdata;
reg [2*DATA_WIDTH-1:0] ain_data;
reg [2*DATA_WIDTH-1:0] bin_data;
reg [2*DATA_WIDTH-1:0] input_memory [0:NDATA-1];
reg [2*DATA_WIDTH-1:0] input_memory2 [0:NDATA-1];
wire [4*DATA_WIDTH-1:0] prod_data;
wire [2*DATA_WIDTH-1:0] out_idata, out_qdata;

wire [SCALING_WIDTH-1:0] scale_val = {10'h0, {(SCALING_WIDTH-10){1'b1}}};
assign out_idata = prod_data[4*DATA_WIDTH-1:2*DATA_WIDTH];
assign out_qdata = prod_data[2*DATA_WIDTH-1:0];
assign ain_idata = ain_data[2*DATA_WIDTH-1:DATA_WIDTH];
assign ain_qdata = ain_data[DATA_WIDTH-1:0];
assign bin_idata = bin_data[2*DATA_WIDTH-1:DATA_WIDTH];
assign bin_qdata = bin_data[DATA_WIDTH-1:0];
reg [$clog2(NDATA)-1:0] ncount;

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

wire out_tvalid;
reg  in_tvalid;

cmul CMUL_DUT(
      .clk(clk),
      .reset(reset),

      .a_tlast(1'b0),
      .a_tvalid(in_tvalid),
      .a_tdata(ain_data),

      .b_tlast(1'b0),
      .b_tvalid(in_tvalid),
      .b_tdata(bin_data),

      .o_tready(1'b1),
      .o_tvalid(out_tvalid),
      .o_tdata(prod_data));

reg stop_write;
initial begin
  $readmemh("/home/user/programs/usrp/uhd/fpga/dk_hdl/testvec/atest_vec.mem", input_memory);
end

initial begin
  $readmemh("/home/user/programs/usrp/uhd/fpga/dk_hdl/testvec/btest_vec.mem", input_memory2);
end

initial begin
  counter = 0;
  reset = 1'b1;
  stop_write = 1'b0;
  in_tvalid = 0;
  #10 reset = 1'b0; 
  in_tvalid = 1'b1;
  repeat(20000) @(posedge clk);
  @(posedge clk);
  stop_write = 1'b1;
  //$finish();
end

integer file_id;
initial begin
  file_id = $fopen("/home/user/Desktop/data/sim/out_data_cmul_tb.txt", "wb");
  $display("Opened file ..................");
  @(negedge reset);
  $display("start writing ................");
  while (!stop_write) begin
    @(negedge clk); 
    $fwrite(file_id, "%d %d %d %d %d %d %d %d\n", in_tvalid, ain_idata, ain_qdata, bin_idata, bin_qdata, out_tvalid, out_idata, out_qdata);    
  end
  $fclose(file_id);
  $display("File closed ..................");
  $finish();    
end



endmodule