module decimate_and_lpf_iq_tb ();

localparam NDATA       = 65536*1;
localparam DATA_WIDTH  = 16;
localparam COEFF_WIDTH = 16;
localparam NUM_COEFFS  = 128;
localparam DEC_RATE    = 128;
localparam RELOADABLE_COEFFS = 0;
localparam SYMMETRIC_COEFFS = 1;
localparam NUM_SLICES       = SYMMETRIC_COEFFS ?
                                    NUM_COEFFS/2 + NUM_COEFFS[0] :  // Manual round up, Vivado complains when using $ceil()
                                    NUM_COEFFS;

reg reset;
wire clk, clear;
assign clear = reset;
wire [DATA_WIDTH-1:0]  in_itdata, in_qtdata, out_itdata, out_qtdata; 
reg [2*DATA_WIDTH-1:0] input_data;
reg [2*DATA_WIDTH-1:0] input_memory [0:NDATA-1];
reg [COEFF_WIDTH-1:0]  coeff_in;
reg [$clog2(NDATA)-1:0] ncount;

reg [2:0] counter;
assign clk = (counter < 3) ? 1'b1 : 1'b0;

always #1 counter <= (counter == 4) ? 0 : counter + 1;

assign in_itdata = input_data[2*DATA_WIDTH-1:DATA_WIDTH];
assign in_qtdata = input_data[DATA_WIDTH-1:0];

wire reload_coeff = 1'b0;
wire reload_tlast = 1'b0;
wire reload_tvalid = reload_coeff;

always @(posedge clk) begin
  if (reset) begin
    input_data <= 0;
    ncount <= 0;
  end 
  else begin
    ncount <= ncount + 1;
    input_data <= input_memory[ncount];
  end 
end




wire out_tlast, out_tready, out_tvalid;
wire in_tlast, in_tvalid, in_tready;
assign in_tvalid  = 1'b1;
assign in_tlast   = 1'b0;
assign out_tready = 1'b1;


`include "coeffs.vh"
decimate_and_lpf_iq#(
  .DATA_WIDTH(DATA_WIDTH),  .DEC_RATE(DEC_RATE),
  .COEFF_WIDTH(COEFF_WIDTH), .NUM_COEFFS(NUM_COEFFS), .SYMMETRIC_COEFFS(SYMMETRIC_COEFFS),
  .COEFFS_VEC(COEFFS_VEC), .RELOADABLE_COEFFS(RELOADABLE_COEFFS)) 
  DLPF_DUT(
      .clk(clk),
      .reset(reset),
      .clear(clear),

      .in_tvalid(in_tvalid),
      .in_tlast(in_tlast), .in_tready(in_tready), 
      .in_itdata(in_itdata), .in_qtdata(in_qtdata),

      .coeff_in(coeff_in),
      .reload_tvalid(reload_tvalid),
      .reload_tlast(reload_tlast),

      .out_tready(out_tready),
      .out_tlast(out_tlast),
      .out_tvalid(out_tvalid),
      
      .out_itdata(out_itdata),
      .out_qtdata(out_qtdata) );

reg stop_write;
initial begin
  $readmemh("/home/user/programs/usrp/uhd/fpga/dk_hdl/testvec/rf_input_data.mem", input_memory);
end
initial begin
  counter = 0;
  reset <= 1'b1;
  coeff_in = 0;
  stop_write = 1'b0;
  #10 reset = 1'b0; 
  repeat(NDATA * 8) @(posedge clk);
  @(posedge clk);
  stop_write = 1'b1;
  $finish();
end

endmodule