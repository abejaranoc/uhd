module cic_dec_int_tb ();

//`include "coeffs.vh"

localparam DATA_WIDTH  = 16;
localparam NDATA       = 16384;



reg reset;
wire clk;
reg rate_stb, strobe_in,  last_in;
wire  istrobe_out, qstrobe_out, ilast_out, qlast_out, out_istrobe, out_qstrobe;
wire [DATA_WIDTH-1:0] in_idata, in_qdata;
reg [2*DATA_WIDTH-1:0] in_data;
reg [2*DATA_WIDTH-1:0] input_memory [0:NDATA-1];
wire [DATA_WIDTH-1:0] dec_idata, dec_qdata, int_idata, int_qdata;
assign in_idata = in_data[2*DATA_WIDTH-1:DATA_WIDTH];
assign in_qdata = in_data[DATA_WIDTH-1:0];

reg [13:0] ncount;

reg [8:0] rate;

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


cic_decimate iDCIC(
      .clk(clk),
      .reset(reset),
      .rate_stb(rate_stb),

      .rate(rate),
      .strobe_in(strobe_in),
      .strobe_out(istrobe_out),
      .last_in(last_in),
      .last_out(ilast_out),

      .signal_in(in_idata),
      .signal_out(dec_idata));

cic_decimate qDCIC(
      .clk(clk),
      .reset(reset),
      .rate_stb(rate_stb),

      .rate(rate),
      .strobe_in(strobe_in),
      .strobe_out(qstrobe_out),
      .last_in(last_in),
      .last_out(qlast_out),

      .signal_in(in_qdata),
      .signal_out(dec_qdata));

cic_interpolate iICIC(
      .clk(clk),
      .reset(reset),
      .rate_stb(rate_stb),

      .rate(rate),
      .strobe_in(istrobe_out),
      .strobe_out(out_istrobe),

      .signal_in(dec_idata),
      .signal_out(int_idata));

cic_interpolate qICIC(
      .clk(clk),
      .reset(reset),
      .rate_stb(rate_stb),

      .rate(rate),
      .strobe_in(qstrobe_out),
      .strobe_out(out_qstrobe),

      .signal_in(dec_qdata),
      .signal_out(int_qdata));

reg stop_write;
initial begin
  $readmemh("/home/user/programs/usrp/uhd/fpga/dk_hdl/utils/test_vec.mem", input_memory);
end


initial begin
  counter = 0;
  reset = 1'b1;
  rate  = 32;
  rate_stb = 1'b1;  strobe_in = 1'b0;  last_in = 1'b0;
  stop_write = 1'b0;
  #10 reset = 1'b0; 
  rate_stb = 1'b0;  strobe_in = 1'b1;  last_in = 1'b0;
  repeat(20000) @(posedge clk);
  @(posedge clk);
  stop_write = 1'b1;
  //$finish();
end

integer file_id1, file_id2;
initial begin
  file_id1 = $fopen("/home/user/Desktop/sim/out_cic_decim.txt", "wb");
  $display("Opened decim file ..................");
  @(negedge reset);
  $display("start writing decim file................");
  while (!stop_write) begin
    @(negedge istrobe_out); 
    $fwrite(file_id1, "%d %d \n", dec_idata, dec_qdata);    
  end
  $fclose(file_id1);
  $display("File closed decim..................");
  $finish();    
end
initial begin
  file_id2 = $fopen("/home/user/Desktop/sim/out_cic_interp.txt", "wb");
  $display("Opened interp file ..................");
  @(negedge reset);
  $display("start writing interp file ................");
  while (!stop_write) begin
    @(negedge clk); 
    $fwrite(file_id2, "%d %d \n", int_idata, int_qdata);    
  end
  $fclose(file_id2);
  $display("File closed interp..................");
  //$finish();    
end


endmodule