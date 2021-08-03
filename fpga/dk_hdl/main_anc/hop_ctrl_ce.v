module hop_ctrl_ce #(
  parameter SCAN_WIDTH     = 2,
  parameter NTX_BITS       = 78,
  parameter TX_BITS_WIDTH  = 128,
  parameter CLK_DIV_FAC    = 40,
  parameter BIT_CNT_WIDTH  = 7
)(
  input   clk,
  input   reset,
  output  scan_clk,
  /* */
  output scan_id,
  output scan_phi,
  output scan_phi_bar, 
  output scan_data_in,
  output scan_load_chip,

   /**/
  input  [TX_BITS_WIDTH-1:0] data_in,
 
  /* debug */
  output [BIT_CNT_WIDTH-1:0]  nbits_cnt,
  output [SCAN_WIDTH-1:0]     scan_chk
);

  
  reg [SCAN_WIDTH-1:0]     scan_cnt;
  reg [BIT_CNT_WIDTH-1:0]  nbits_tx;
  reg [TX_BITS_WIDTH-1:0]  input_data;
  reg hop_ctrl_valid;
  assign nbits_cnt = nbits_tx;
  assign scan_chk  = scan_cnt;
  wire scan_ce;
  assign scan_clk = scan_ce;
  

  assign scan_id        = hop_ctrl_valid && nbits_tx <= NTX_BITS; 
  assign scan_phi       = (scan_cnt == 2'b00  && nbits_tx < NTX_BITS) ? 1'b1 : 1'b0;
  assign scan_phi_bar   = (scan_cnt == 2'b10  && nbits_tx < NTX_BITS) ? 1'b1 : 1'b0;
  assign scan_data_in   = input_data[nbits_tx];
  assign scan_load_chip = (scan_cnt == 2'b11 && nbits_tx == NTX_BITS) ? 1'b1 : 1'b0;

  always @(posedge clk) begin
    if(reset) begin
      nbits_tx <= {(BIT_CNT_WIDTH){1'b1}};
      input_data <= |data_in[3:0] ? data_in : { {(TX_BITS_WIDTH - 32){1'b0}}, 32'h15428193 };
      hop_ctrl_valid <= 1'b1;
    end 
    else if (scan_ce) begin
      if (hop_ctrl_valid && scan_cnt == 2'b11) begin
        if(nbits_tx == NTX_BITS) begin
          hop_ctrl_valid <= 1'b0;
          nbits_tx <= {(BIT_CNT_WIDTH){1'b1}};
        end
      end
      else begin
        nbits_tx <= nbits_tx + 1;
      end
    end
  end

  always @(posedge clk) begin
    if(reset) begin
      scan_cnt <= 0;
    end 
    else if(scan_ce) begin 
      scan_cnt <= scan_cnt + 1;
    end     
  end

  reg [7:0] clk_count;
  assign scan_ce = (clk_count == 0) ? 1'b1 : 1'b0;
  always @(posedge clk) begin
    if (reset) begin
      clk_count <= 0;
    end
    else if (clk_count >= (CLK_DIV_FAC - 1)) begin
      clk_count <= 0;
    end
    else begin
      clk_count <= clk_count + 1;
    end
    
  end

endmodule