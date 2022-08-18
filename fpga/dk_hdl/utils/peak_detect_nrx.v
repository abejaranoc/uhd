module  peak_detect_nrx#(
  parameter DATA_WIDTH    = 16,
  parameter NRX_TRIG      = 64,
  parameter NRX_WIDTH     = 16  
)(
  input clk,
  input reset,
  input clear,

  /* IQ input */
  input  in_tvalid,
  input  in_tlast, 
  output in_tready,
  input [DATA_WIDTH-1:0]  in_tdata,

  input peak_stb_in,

  /*output tdata*/
  output  out_tlast,
  output  out_tvalid,
  input   out_tready,
  
  output  peak_stb_out,
  output [NRX_WIDTH-1:0] nrx_after_peak,

  input  [DATA_WIDTH-1:0] pow_in,
  output [DATA_WIDTH-1:0] pow_out
);


  reg o_tvalid, o_tlast, peak_stb;
  assign peak_stb_out = peak_stb;
  assign out_tlast = o_tlast;
  assign out_tvalid = o_tvalid;
  assign in_tready = ( out_tready | ~o_tvalid ) & ~reset;

  reg [1:0] state;
  localparam INIT = 2'b00;
  localparam MAX  = 2'b01;
  localparam WAIT = 2'b10;
  localparam TRIG = 2'b11;

  reg [7:0] num_pks;
  reg [NRX_WIDTH-1:0]  nrx_after_max_peak, nrx_after_trig;
  reg [DATA_WIDTH-1:0] max_peak, pow;

  assign pow_out = pow;
  assign nrx_after_peak = nrx_after_max_peak;

  always @(posedge clk) begin
    if (reset | clear) begin
      o_tvalid <= 1'b0;
      o_tlast  <= 1'b0;
      state    <= INIT;
      max_peak <= 0;
      nrx_after_max_peak <= 0;
      pow       <= 0;
      nrx_after_trig <= 0;
      peak_stb <= 1'b0;
      num_pks  <= 8'h00;
    end
    else begin
      o_tvalid <= in_tvalid;
      o_tlast  <= in_tlast;
      if (in_tvalid) begin
        case (state)
          INIT: begin
            max_peak <= in_tdata;
            pow      <= pow_in;
            nrx_after_max_peak <= 0;
            nrx_after_trig <= 0;
            peak_stb       <= 1'b0;
            num_pks        <= 8'h00;
            if(peak_stb_in) begin
              state <= MAX;
            end
          end
          MAX: begin
            if(peak_stb_in) begin
              nrx_after_trig <= nrx_after_trig + 1;
              if(in_tdata > max_peak ) begin
                pow      <= pow_in;
                max_peak <= in_tdata;
                nrx_after_max_peak <= 0;
                num_pks[0] <= 1'b1;
                num_pks[1] <= num_pks[0];
                num_pks[2] <= num_pks[1];
                num_pks[3] <= num_pks[2];
                num_pks[4] <= num_pks[3];
                num_pks[5] <= num_pks[4];
                num_pks[6] <= num_pks[5];
                num_pks[7] <= num_pks[6];
              end
              else begin
                nrx_after_max_peak <= nrx_after_max_peak + 1;
              end
            end
            else begin
              state          <= TRIG;
              nrx_after_max_peak <= nrx_after_max_peak + 1;
            end
          end
          TRIG: begin
            if(nrx_after_trig >= NRX_TRIG) begin
              peak_stb <= (num_pks == 8'hff);
              state    <= WAIT;
            end
            else begin
              state    <= INIT;
            end
          end
          WAIT : begin
            state <= INIT;
          end
          default: state <= INIT;
        endcase
        
      end 
    end
  end


endmodule