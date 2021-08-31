module regN_ff #(
  parameter REG_WIDTH = 16
)(
  input  clk,
  input  reset,
  input  ce,
  input  [REG_WIDTH-1:0] D,
  output reg [REG_WIDTH-1:0] Q
 );

  always @(posedge clk or posedge reset) begin
    if(reset) Q <= 0;
    else if (ce) Q <= D;  
  end
endmodule