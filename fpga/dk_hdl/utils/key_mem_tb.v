module key_mem_tb ();

  reg reset;
  reg [2:0] counter;
  wire clk;
  assign clk = (counter < 3) ? 1'b1 : 1'b0;
  always #1 counter <= (counter == 4) ? 0 : counter + 1;

  localparam ADDR_WIDTH = 10;
  localparam DATA_WIDTH = 32;

  reg [DATA_WIDTH-1:0] write_data;
  reg [ADDR_WIDTH-1:0] write_addr, read_addr;
  wire [DATA_WIDTH-1:0] read_data;
  reg read_en, write_en, clear;

  key_mem #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH))
    DUT (
      .clk(clk), 
      .reset(reset), 
      .clear(clear),
      .read_enable(read_en), 
      .write_enable(write_en),
      .write_addr(write_addr),
      .write_data(write_data),
      .read_addr(read_addr),
      .read_data(read_data)
    );

  always @(posedge clk ) begin
    if (reset) begin
      read_addr   <= 0;
      write_addr  <= 0;
      write_data  <= 2000;
    end
    else begin
      if (read_en) begin
        read_addr <= read_addr + 1;
      end
      if (write_en) begin
        write_addr  <= write_addr + 1;
        write_data  <= write_data + 4;
      end
    end
  end

  initial begin
    counter = 0;
    reset = 1'b1;
    clear = 1'b0; 
    write_en = 1'b0; read_en = 1'b0;
    #10 reset = 1'b0;
    write_en = 1'b1;
    repeat(512) @(posedge clk);
    read_en = 1'b1;
    repeat(2000) @(posedge clk);
    $finish();
  end

endmodule