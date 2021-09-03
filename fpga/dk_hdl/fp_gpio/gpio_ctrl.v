module gpio_ctrl #(
  parameter GPIO_REG_WIDTH    = 12,
  parameter CLK_DIV_FAC       = 10,
  parameter [GPIO_REG_WIDTH-1:0] OUT_MASK = 12'h011,
  parameter [GPIO_REG_WIDTH-1:0] IN_MASK  = 12'h044,
  parameter [GPIO_REG_WIDTH-1:0] IO_DDR   = 12'h011
)(
  input   clk,
  input   reset,
  
  input  [GPIO_REG_WIDTH-1:0]  fp_gpio_in,
  output [GPIO_REG_WIDTH-1:0]  fp_gpio_out,
  output [GPIO_REG_WIDTH-1:0]  fp_gpio_ddr,

  input  [GPIO_REG_WIDTH-1:0]  gpio_out,
  output [GPIO_REG_WIDTH-1:0]  gpio_in
);

  wire [GPIO_REG_WIDTH-1:0] D1, Q1;
  wire o_tlast, o_tready, o_tvalid;
  delay_fifo #(.MAX_LEN(CLK_DIV_FAC), .WIDTH(GPIO_REG_WIDTH))
    R0( .clk(clk), .reset(reset), .clear(reset), .len(CLK_DIV_FAC),
        .i_tdata(fp_gpio_in), .i_tlast(1'b0), .i_tvalid(1'b1), 
        .o_tdata(D1), .o_tlast(o_tlast), .o_tvalid(o_tvalid), .o_tready(o_tready));

  delay_fifo #(.MAX_LEN(CLK_DIV_FAC), .WIDTH(GPIO_REG_WIDTH))
    R1( .clk(clk), .reset(reset), .clear(reset), .len(CLK_DIV_FAC),
        .i_tdata(D1), .i_tlast(o_tlast), .i_tvalid(o_tvalid), .i_tready(o_tready),
        .o_tdata(Q1), .o_tlast(), .o_tvalid(), .o_tready(1'b1));

  assign gpio_in     = Q1 & D1 & IN_MASK;
  assign fp_gpio_ddr = IO_DDR;
  assign fp_gpio_out = gpio_out & OUT_MASK; 
  
endmodule

