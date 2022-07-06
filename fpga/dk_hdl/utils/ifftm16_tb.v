module ifftm16_tb ();

localparam DATA_WIDTH  = 16;
localparam NDATA       = 512;

reg reset;
wire clk;
wire [DATA_WIDTH-1:0]  in_itdata, in_qtdata;
reg [2*DATA_WIDTH-1:0] input_memory [0:NDATA-1];
wire [DATA_WIDTH-1:0] out_itdata, out_qtdata;
wire [2*DATA_WIDTH-1:0] in_data;

wire in_tready, in_tvalid, in_tlast, out_tready, out_tvalid, out_tlast;

assign in_tlast  = 1'b0;
assign out_tready = 1'b1;
assign in_itdata = in_data[2*DATA_WIDTH-1:DATA_WIDTH];
assign in_qtdata = in_data[DATA_WIDTH-1:0];

reg [$clog2(NDATA)-1:0] ncount;
assign in_data = input_memory[ncount];


reg [2:0] counter;
assign clk = (counter < 3) ? 1'b1 : 1'b0;

always #1 counter <= (counter == 4) ? 0 : counter + 1;

localparam VAL  = 2'b01;
localparam INIT = 2'b00;
localparam IDLE = 2'b10; 
localparam NFFT = 512;
localparam IDLE_LIM = 100;
reg [15:0] idle_count;
reg [1:0] state;
reg val_in;
assign in_tvalid = val_in & in_tready;

always @(posedge clk) begin
  if (reset) begin
    ncount <= 0;
    val_in <= 1'b0;
    state  <= INIT;
    idle_count <= 0;
  end 
  else begin
    case (state)
      INIT: begin
        ncount <= 0; 
        idle_count <= 0;
        if (in_tready) begin
          val_in <= 1'b1;
          state  <= VAL;
        end
      end
      VAL : begin
        if(ncount < (NFFT - 1)) begin
          ncount <= ncount + 1;
        end
        else begin
          ncount <= 0;
          val_in <= 1'b0;
          state  <= IDLE;
        end
      end
      IDLE : begin
        if (idle_count < IDLE_LIM) begin
          idle_count <= idle_count + 1;
        end
        else begin
          state <= INIT;
        end
      end
      default: state <= INIT;
    endcase
  end 
end



initial begin
  $readmemh("/home/user/programs/usrp/uhd/fpga/dk_hdl/testvec/ifftm16_test_vec.mem", input_memory);
end

ifftm16 #(.DATA_WIDTH(16), .CLIP_BITS(9))
  DUT(
    .clk(clk), .reset(reset),
    .in_tvalid(in_tvalid), .in_tlast(in_tlast), .in_tready(in_tready), 
    .in_itdata(in_itdata), .in_qtdata(in_qtdata), 
    .out_tvalid(out_tvalid), .out_tlast(out_tlast), .out_tready(out_tready),
    .out_itdata(out_itdata), .out_qtdata(out_qtdata)
  );


reg stop_write;
initial begin
  counter = 0;
  reset = 1'b1;
  stop_write = 1'b1;
  #50 stop_write = 1'b0;
  #50 reset = 1'b0; 
  repeat(10000) @(posedge clk);
  @(posedge clk);
  stop_write = 1'b1;
  //$finish();
end

integer file_id;
initial begin
  file_id = $fopen("/home/user/Desktop/data/sim/ifft_out.txt", "wb");
  $display("Opened file ..................");
  //@(negedge reset);
  @(negedge stop_write);
  $display("start writing ................");
  while (!stop_write) begin
    @(negedge clk); 
    $fwrite(file_id, "%d %d %d %d %d %d %d %d \n", in_tready, in_tvalid,
            in_itdata, in_qtdata, out_tready, out_tvalid, out_itdata, out_qtdata);    
  end
  $fclose(file_id);
  $display("File closed ..................");
  $finish();    
end



endmodule