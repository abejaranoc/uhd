module resample_iq_tb ();

//`include "coeffs.vh"

localparam DATA_WIDTH  = 16;

localparam NDATA       = 512;



reg reset;
wire clk;
reg rate_stb, strobe_in;
wire  strobe_out;
wire [DATA_WIDTH-1:0] in_itdata, in_qtdata;
reg [2*DATA_WIDTH-1:0] in_data;
reg [2*DATA_WIDTH-1:0] input_memory [0:NDATA-1];
wire [DATA_WIDTH-1:0] out_itdata, out_qtdata;
assign in_itdata = in_data[2*DATA_WIDTH-1:DATA_WIDTH];
assign in_qtdata = in_data[DATA_WIDTH-1:0];

reg [$clog2(NDATA)-1:0] ncount;

reg [8:0] rate_dec, rate_int;

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

reg stop_write;
initial begin
  $readmemh("/home/user/programs/usrp/uhd/fpga/dk_hdl/testvec/resample_test_vec.mem", input_memory);
end


resample_iq #(
  .DATA_WIDTH(DATA_WIDTH)
)
  CIC_INTERP(
    .clk(clk),
    .reset(reset),
    .rate_stb(rate_stb),
    .rate_dec(rate_dec),
    .rate_int(rate_int),
    .strobe_in(strobe_in),
    .strobe_out(strobe_out),
    .in_itdata(in_itdata),
    .in_qtdata(in_qtdata),
    .out_itdata(out_itdata),
    .out_qtdata(out_qtdata)
  );

initial begin
  counter = 0;
  reset = 1'b1;
  rate_dec  = 4;
  rate_int  = 4;
  rate_stb = 1'b1;  strobe_in = 1'b0;
  stop_write = 1'b0;
  #10 reset = 1'b0; 
  rate_stb = 1'b0;  strobe_in = 1'b1;
  repeat(20000) @(posedge clk);
  @(posedge clk);
  stop_write = 1'b1;
  //$finish();
end

integer file_id;
initial begin
  file_id = $fopen("/home/user/Desktop/data/sim/out_resample.txt", "wb");
  $display("Opened file ..................");
  @(negedge reset);
  $display("start writing ................");
  while (!stop_write) begin
    @(negedge strobe_out); 
    $fwrite(file_id, "%d %d \n", out_itdata, out_qtdata);    
  end
  $fclose(file_id);
  $display("File closed ..................");
  $finish();    
end



endmodule