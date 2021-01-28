module clk_div_dk #(
  parameter N = 100
)(
  input  clk, 
  input  reset,
  output reg clk_div

);


reg [15:0] count;

always @(posedge clk) begin
  if(reset) begin
    clk_div <= 0;
    count    <= 1;
  end
  else if (count == N) begin
    clk_div  <= ~clk_div;
    count    <= 1;
  end
  else begin
    count <= count + 1;
  end 
end

endmodule