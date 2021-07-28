module fir_filter_iq_tb ();

//`include "coeffs.vh"

localparam DATA_WIDTH  = 16;
localparam COEFF_WIDTH = 16;
localparam NUM_COEFFS  = 128;
localparam NDATA       = 2048;
localparam NWIDTH      = 11;
localparam DECFAC      = 64;
localparam DECWIDTH    = 6;



reg reset;
wire clk;
wire [DATA_WIDTH-1:0] in_idata, in_qdata, out_idata, out_qdata; 
reg [2*DATA_WIDTH-1:0] input_data;
reg [2*DATA_WIDTH-1:0] input_memory [0:NDATA-1];
reg [COEFF_WIDTH-1:0] coeffs_memory [0:NUM_COEFFS/2-1];
reg [COEFF_WIDTH-1:0] coeff_in;
reg [NWIDTH-1:0] ncount;
reg [NWIDTH-1:0] ccount;
reg [DECWIDTH-1:0] dcount;
reg [2:0] counter;
assign clk = (counter < 3) ? 1'b1 : 1'b0;
wire ce_clk   = &dcount;
always #1 counter <= (counter == 4) ? 0 : counter + 1;

assign in_idata = input_data[2*DATA_WIDTH-1:DATA_WIDTH];
assign in_qdata = input_data[DATA_WIDTH-1:0];
wire reload_coeff = (ccount >= NUM_COEFFS/2) ? 1'b0 : 1'b1;
wire reload_tlast = 1'b0;

wire reload_tvalid = reload_coeff & ce_clk;

always @(posedge ce_clk or posedge reset) begin
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

always @(posedge clk) begin
  if (reset) begin
    dcount <= 0;
  end
  else begin 
    dcount <= dcount + 1;
  end

end

localparam RELOADABLE_COEFFS = 1;
localparam [(NUM_COEFFS/2)*COEFF_WIDTH-1:0] COEFFS_VEC = 
1024'h0013001300140014001500160018001A001C001E002100230026002A002D003100350039003D00420046004B00500055005B00600066006B00710077007D00820088008E0094009A00A000A500AB00B100B600BC00C100C600CB00D000D500D900DD00E100E500E900EC00EF00F200F500F700F900FB00FD00FE00FF00FF00FF;

fir_filter_iq #(.DATA_WIDTH(DATA_WIDTH),
                .COEFF_WIDTH(COEFF_WIDTH),
                .NUM_COEFFS(NUM_COEFFS),
                .RELOADABLE_COEFFS(RELOADABLE_COEFFS)) 
  FIR_DUT(
      .clk(clk),
      .reset(reset),

      .in_tvalid(ce_clk),
      .in_tlast(1'b0),
      .in_i(in_idata),
      .in_q(in_qdata),
      .coeff_in(coeff_in),
      .reload_tvalid(reload_tvalid),
      .reload_tlast(reload_tlast),
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
  reset <= 1'b1;
  stop_write = 1'b0;
  #10 reset = 1'b0; 
  repeat(400000) @(posedge clk);
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
    @(negedge ce_clk); 
    $fwrite(file_id, "%d %d \n", out_idata, out_qdata);    
  end
  $fclose(file_id);
  $display("File closed ..................");
  $finish();    
end



endmodule