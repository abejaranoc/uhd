module cic_interpolate_tb ();

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

reg [8:0] rate;

reg [2:0] counter, strobe_count;
assign clk = (counter < 3) ? 1'b1 : 1'b0;

always #1 counter <= (counter == 4) ? 0 : counter + 1;

always @(posedge clk) begin
  if (reset) begin
    in_data <= 0;
    ncount  <= 0;
  end 
  else if (strobe_in) begin
    ncount  <= ncount + 1;
    in_data <= input_memory[ncount];
  end 
end

always @(posedge clk) begin
  if (reset) begin
    strobe_count  <= 0;
    strobe_in     <= 1'b0;
  end 
  else begin
    if (strobe_count == 4) begin
      strobe_in <= 1'b1;
      strobe_count  <= 0;
    end
    else begin
      strobe_count <= strobe_count + 1;
      strobe_in    <= 1'b0;
    end
  end 
end

reg stop_write;
initial begin
  $readmemh("/home/user/programs/usrp/uhd/fpga/dk_hdl/testvec/interp_test_vec.mem", input_memory);
end


cic_interpolate_iq #(
  .DATA_WIDTH(DATA_WIDTH)
)
  CIC_INTERP(
    .clk(clk),
    .reset(reset),
    .rate_stb(rate_stb),
    .rate(rate),
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
  rate  = 5;
  rate_stb = 1'b1;  //strobe_in = 1'b0;
  stop_write = 1'b0;
  #10 reset = 1'b0; 
  rate_stb = 1'b0;  //strobe_in = 1'b1;
  repeat(20000) @(posedge clk);
  @(posedge clk);
  stop_write = 1'b1;
  //$finish();
end

integer file_id;
initial begin
  file_id = $fopen("/home/user/Desktop/data/sim/out_cic_interpolate.txt", "wb");
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