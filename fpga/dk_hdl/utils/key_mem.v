module key_mem #(
  parameter ADDR_WIDTH = 10, 
  parameter DATA_WIDTH = 32
)(
  input clk, 
  input reset, 

  input  clear, 
  input  read_enable,
  input  write_enable, 
 
  input  [ADDR_WIDTH-1:0] write_addr, 
  input  [DATA_WIDTH-1:0] write_data,
  input  [ADDR_WIDTH-1:0] read_addr, 
  output [DATA_WIDTH-1:0] read_data 
  
);

  reg  [ADDR_WIDTH-1:0] addra; 
  wire [ADDR_WIDTH-1:0] addrb; 
  reg  [DATA_WIDTH-1:0] data_in, data_out;
  wire [DATA_WIDTH-1:0] dia, dob;
  reg wea;

  assign read_data = data_out;
  assign addrb = read_addr;
  assign dia  = data_in;


  ram_2port #(.DWIDTH(DATA_WIDTH),.AWIDTH(ADDR_WIDTH))
     ram (
      .clka(clk),
      .ena(1'b1),
      .wea(wea),
      .addra(addra),
      .dia(dia),
      .doa(),

      .clkb(clk),
      .enb(read_enable),
      .web(1'b0),
      .addrb(addrb),
      .dib({DATA_WIDTH{1'b1}}),
      .dob(dob));

  always @(posedge clk) begin
    if(reset | clear) begin
      addra  <= 0;
      data_in  <= 0;
      data_out <= 0;
      wea <= 1'b0;
    end
    else begin
      if (read_enable) begin
        data_out  <= dob;
      end
      if (write_enable) begin
        data_in <= write_data;
        addra   <= write_addr;
        wea     <= write_enable;
      end
    end
    
  end
endmodule