module fir_filter_iq_tb ();

//`include "coeffs.vh"

localparam DATA_WIDTH  = 16;
localparam COEFF_WIDTH = 16;
localparam NUM_COEFFS  = 4096;
localparam NDATA       = 65536;



reg reset;
wire clk;
wire [DATA_WIDTH-1:0] in_idata, in_qdata, out_idata, out_qdata; 
reg [2*DATA_WIDTH-1:0] input_data;
reg [2*DATA_WIDTH-1:0] input_memory [0:NDATA-1];
reg [COEFF_WIDTH-1:0] coeffs_memory [0:NUM_COEFFS/2-1];
reg [COEFF_WIDTH-1:0] coeff_in;
reg [15:0] ncount;
reg [15:0] ccount;
reg [2:0] counter;
assign clk = (counter < 3) ? 1'b1 : 1'b0;

always #1 counter <= (counter == 4) ? 0 : counter + 1;

assign in_idata = input_data[2*DATA_WIDTH-1:DATA_WIDTH];
assign in_qdata = input_data[DATA_WIDTH-1:0];
wire reload_coeff = (ccount >= NUM_COEFFS/2) ? 1'b1 : 1'b0;
always @(posedge clk) begin
  if (reset) begin
    input_data <= 0;
    ncount <= 0;
    ccount <= 0;
    coeff_in <= 0;
  end 
  else begin
    ncount <= ncount + 1;
    input_data <= input_memory[ncount];
    
    if (ccount < NUM_COEFFS/2) begin
      ccount <= ccount + 1;
      coeff_in <= coeffs_memory[ccount];
    end
  end 
end

fir_filter_iq #(.DATA_WIDTH(DATA_WIDTH),
                .COEFF_WIDTH(COEFF_WIDTH),
                .NUM_COEFFS(NUM_COEFFS)) 
  FIR_DUT(
      .clk(clk),
      .reset(reset),

      .in_tvalid(1'b1),
      .in_tlast(1'b0),
      .in_i(in_idata),
      .in_q(in_qdata),
      .coeff_in(coeff_in),
      .reload_coeff(reload_coeff),
      .out_tready(1'b1),
      .out_i(out_idata),
      .out_q(out_qdata) );

reg stop_write;
initial begin
  $readmemh("/home/user/programs/usrp/uhd/fpga/dk_hdl/utils/input_data.mem", input_memory);
end
initial begin
  $readmemh("/home/user/programs/usrp/uhd/fpga/dk_hdl/utils/coeffs_data.mem", coeffs_memory);
end
initial begin
  counter = 0;
  reset = 1'b1;
  stop_write = 1'b0;
  #10 reset = 1'b0; 
  repeat(500000) @(posedge clk);
  @(posedge clk);
  stop_write = 1'b1;
  //$finish();
end

integer file_id;
initial begin
  file_id = $fopen("/home/user/Desktop/sim/out_data_full.txt", "wb");
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