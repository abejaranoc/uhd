module gpio_ctrl #(
  parameter GPIO_REG_WIDTH    = 12,
  parameter CLK_DIV_FAC       = 10,
  parameter [GPIO_REG_WIDTH-1:0] OUT_MASK = 12'hD55,
  parameter [GPIO_REG_WIDTH-1:0] IN_MASK  = 12'h022,
  parameter [GPIO_REG_WIDTH-1:0] IO_DDR   = 12'hD55
)(
  input   clk,
  input   reset,
  
  input  [GPIO_REG_WIDTH-1:0]  fp_gpio_in,
  output [GPIO_REG_WIDTH-1:0]  fp_gpio_out,
  output [GPIO_REG_WIDTH-1:0]  fp_gpio_ddr,

  input  [GPIO_REG_WIDTH-1:0]  gpio_out,
  output [GPIO_REG_WIDTH-1:0]  gpio_in
);

  //wire clk_div;
  wire [GPIO_REG_WIDTH-1:0] D1, Q1;

  regN_ff #(.REG_WIDTH(GPIO_REG_WIDTH))
      R0(.clk(clk), .reset(reset), .ce(1'b1),
         .D(fp_gpio_in), .Q(D1));

  regN_ff #(.REG_WIDTH(GPIO_REG_WIDTH))
      R1(.clk(clk), .reset(reset), .ce(1'b1),
         .D(D1), .Q(Q1));
  /*
  clk_div_dk #(.N(CLK_DIV_FAC))
      CLK_DIV_DK (.clk(clk),
                  .reset(reset),
                  .clk_div(clk_div));
  */
  assign gpio_in     = Q1 & D1 & IN_MASK;
  assign fp_gpio_ddr = IO_DDR;
  assign fp_gpio_out = gpio_out & OUT_MASK; 
  
endmodule

