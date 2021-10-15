module mult_rc_tb ();

localparam DATA_WIDTH    = 16;
localparam NWIDTH = 14;



reg reset;
wire clk;
reg [DATA_WIDTH-1:0] in_itdata, in_qtdata, scale_tdata;
wire [DATA_WIDTH-1:0] out_itdata, out_qtdata;



reg [2:0] counter;
assign clk = (counter < 3) ? 1'b1 : 1'b0;

always #1 counter <= (counter == 4) ? 0 : counter + 1;

mult_rc #(
  .WIDTH_REAL(DATA_WIDTH), .WIDTH_CPLX(DATA_WIDTH),
  .WIDTH_P(DATA_WIDTH), .DROP_TOP_P(21)) 
    CMUL_DUT(
      .clk(clk),
      .reset(reset),

      .real_tlast(1'b0),
      .real_tvalid(1'b1),
      .real_tdata(scale_tdata),

      .cplx_tlast(1'b0),
      .cplx_tvalid(1'b1),
      .cplx_tdata({in_itdata, in_qtdata}),

      .p_tready(1'b1),
      .p_tdata({out_itdata, out_qtdata}));



initial begin
  counter = 0;
  reset = 1'b1;
  scale_tdata = 0;
  in_itdata = 0; in_qtdata = 0;
  #100 reset = 1'b0; 
  repeat(50) @(posedge clk);
  scale_tdata = 1;
  in_itdata = 16384; in_qtdata = -16384;
  repeat(50) @(posedge clk);
  scale_tdata = 2;
  in_itdata = 16384; in_qtdata = -16384;
  repeat(50) @(posedge clk);
  scale_tdata = 2;
  in_itdata = 8192; in_qtdata = -2047;
  repeat(50) @(posedge clk);
  scale_tdata = 3;
  in_itdata = 8000; in_qtdata = -6000;
  repeat(50) @(posedge clk);
  scale_tdata = 4;
  in_itdata = -8000; in_qtdata = 3000;
  repeat(50) @(posedge clk);
  scale_tdata = 1;
  in_itdata = -64; in_qtdata = 128;
  repeat(50) @(posedge clk);
  
  $finish();
end



endmodule