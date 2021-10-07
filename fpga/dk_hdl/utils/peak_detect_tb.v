module peak_detect_tb ();

localparam NDATA       = 1024;
localparam DATA_WIDTH  = 16;
localparam NRX_TRIG    = 16;

reg reset;
wire clk;
wire in_tvalid, in_tready, in_tlast;
wire out_tvalid, out_tready, out_tlast;

wire [DATA_WIDTH-1:0] in_tdata;
wire  peak_stb_in, peak_stb_out;


localparam DEC_RATE = 4;
reg [$clog2(NDATA)-1:0] ncount;
reg [$clog2(DEC_RATE)-1:0] ndec;
reg [DATA_WIDTH-1:0] in_data;
reg [DATA_WIDTH-1:0] input_memory [0:NDATA-1];
reg [2:0] counter;

assign in_tvalid = (ndec == 2) ? 1'b1 : 1'b0;
assign in_tlast   = 1'b0;
assign out_tready = 1'b1;
assign peak_stb_in = (in_data > 000 ); 


assign in_tdata = in_data;


assign clk = (counter < 3) ? 1'b1 : 1'b0;
always #1 counter <= (counter == 4) ? 0 : counter + 1;


always @(posedge clk) begin
  if (reset) begin
    in_data <= 0;
    ncount <= 0;
    ndec <= 0;
  end 
  else begin
    if (in_tvalid) begin
      ncount  <= ncount + 1;
      in_data <= input_memory[ncount];
    end
    ndec    <= ndec + 1;
  end 
end

peak_detect #(
  .DATA_WIDTH(DATA_WIDTH), .NRX_TRIG(NRX_TRIG))
    DUT(
      .clk(clk), .reset(reset), .clear(reset),
      .in_tvalid(in_tvalid), .in_tlast(in_tlast), 
      .in_tready(in_tready), .in_tdata(in_tdata), 
      .peak_stb_in(peak_stb_in), .peak_stb_out(peak_stb_out),
      .out_tvalid(out_tvalid), .out_tlast(out_tlast), 
      .out_tready(out_tready)
    );


initial begin
  $readmemh("/home/user/programs/usrp/uhd/fpga/dk_hdl/utils/pk_test_vec.mem", input_memory);
end

reg stop_write;

initial begin
  counter = 0;
  reset = 1'b1;
  stop_write = 1'b0;
  #10 reset = 1'b0; 
  repeat(20000) @(posedge clk);
  @(posedge clk);
  stop_write = 1'b1;
  $finish();
end

/*
integer file_id;
initial begin
  file_id = $fopen("/home/user/Desktop/sim/out_cic_decim.txt", "wb");
  $display("Opened file ..................");
  @(negedge reset);
  $display("start writing ................");
  while (!stop_write) begin
    @(negedge istrobe_out); 
    $fwrite(file_id, "%d %d \n", out_idata, out_qdata);    
  end
  $fclose(file_id);
  $display("File closed ..................");
  $finish();    
end
*/

endmodule