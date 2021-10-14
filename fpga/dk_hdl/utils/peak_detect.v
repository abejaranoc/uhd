module  peak_detect#(
  parameter DATA_WIDTH    = 16,
  parameter NRX_TRIG      = 16 
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
  output  peak_stb_out
);


  reg o_tvalid, o_tlast, peak_stb;
  assign peak_stb_out = peak_stb;
  assign out_tlast = o_tlast;
  assign out_tvalid = o_tvalid;
  assign in_tready = ( out_tready | ~o_tvalid ) & ~reset;

  reg [1:0] state;
  localparam INIT = 2'b00;
  localparam WAIT = 2'b01;
  localparam TRIG = 2'b10;
  localparam IDLE = 2'b11;

  reg [7:0] num_pks;
  reg [$clog2(NRX_TRIG + 1)-1:0] nrx_after_peak;
  reg [DATA_WIDTH-1:0] max_peak;

  always @(posedge clk) begin
    if (reset | clear) begin
      o_tvalid <= 1'b0;
      o_tlast  <= 1'b0;
      state    <= INIT;
      max_peak <= 0;
      nrx_after_peak <= 4'h00;
      peak_stb <= 1'b0;
      num_pks  <= 8'h00;
    end
    else begin
      o_tvalid <= in_tvalid;
      o_tlast  <= in_tlast;
      if (in_tvalid & in_tready) begin
        case (state)
          INIT: begin
            max_peak <= in_tdata;
            nrx_after_peak <= 0;
            num_pks  <= 8'h00;
            peak_stb <= 1'b0;
            if(peak_stb_in) begin
              state <= TRIG;
            end 
          end
          TRIG: begin
            if (nrx_after_peak >= NRX_TRIG) begin
              nrx_after_peak <= 0;
              state <= WAIT;
              peak_stb <= (num_pks == 8'hff) & peak_stb_in;
            end
            else begin
              if( in_tdata == max_peak ) begin
                max_peak   <= in_tdata;
                nrx_after_peak <= 0;
              end
              else if(in_tdata > max_peak ) begin 
                max_peak   <= in_tdata;
                num_pks[0] <= 1'b1;
                num_pks[1] <= num_pks[0];
                num_pks[2] <= num_pks[1];
                num_pks[3] <= num_pks[2];
                num_pks[4] <= num_pks[3];
                num_pks[5] <= num_pks[4];
                num_pks[6] <= num_pks[5];
                num_pks[7] <= num_pks[6];
                nrx_after_peak <= 0;
              end
              else begin
                nrx_after_peak <= nrx_after_peak + 1;
              end
            end
          end
          WAIT: begin
            state <= IDLE;  
          end
          IDLE: begin
            state <= INIT;
          end
          default: state <= INIT;
        endcase
      end
  end
  end


endmodule