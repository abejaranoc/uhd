module key_rx #(
  parameter ADDR_WIDTH = 10, 
  parameter NFFT       = 512, 
  parameter NCP        = 128,
  parameter DATA_WIDTH = 16
)(
  input clk, 
  input reset, 
  input clear, 

  input  in_tvalid,
  input  in_tlast, 
  output in_tready, 
  input [2*DATA_WIDTH-1:0] in_tdata,

  input [2*DATA_WIDTH-1:0] noise_thres,
 
  output out_tvalid, 
  output out_tlast, 
  input  out_tready, 
  output [2*DATA_WIDTH-1:0] out_tdata
  
);


localparam MAX_LEN    = 1023;
localparam LEN        = NFFT; 
localparam NRX_TRIG   = 64;
localparam NRX_WIDTH  = 16;
localparam PMAG_WIDTH = DATA_WIDTH + $clog2(MAX_LEN+1);
localparam NOISE_POW  = 15000;
localparam THRES_SEL  = 2'b10;

wire [NRX_WIDTH-1:0]  nrx_after_peak;
wire pd_peak_stb; 
wire pd_tlast, pd_tready, pd_tvalid;
assign pd_tready = 1'b1;
wire [DATA_WIDTH-1:0] pd_in_itdata, pd_in_qtdata;
wire [PMAG_WIDTH-1:0] pow;
reg [PMAG_WIDTH-1:0] ltf_pow;
assign pd_in_itdata = in_tdata[2*DATA_WIDTH-1:DATA_WIDTH];
assign pd_in_qtdata = in_tdata[DATA_WIDTH-1:0];

ltf_detect #(
  .DATA_WIDTH(DATA_WIDTH), .MAX_LEN(MAX_LEN), .LEN(LEN),
  .THRES_SEL(THRES_SEL), .NRX_TRIG(NRX_TRIG), .NRX_WIDTH(NRX_WIDTH), 
  .PMAG_WIDTH(PMAG_WIDTH), .NOISE_POW(NOISE_POW)) 
  LTF_PD(
    .clk(clk), .reset(reset), .clear(clear),
    .in_tvalid(in_tvalid), .in_tlast(in_tlast), .in_tready(in_tready), 
    .in_itdata(pd_in_itdata), .in_qtdata(pd_in_qtdata),
    .noise_thres(noise_thres), .nrx_after_peak(nrx_after_peak), .pow(pow),
    .peak_stb(pd_peak_stb), .out_tvalid(pd_tvalid),
    .out_tready(pd_tready), .out_tlast(pd_tlast)
  );


reg we, re;
reg [ADDR_WIDTH-1:0] waddr, raddr;
reg [DATA_WIDTH-1:0] nread, nidle;
wire [2*DATA_WIDTH-1:0] rdata, wdata;
assign wdata = in_tdata;

key_mem #(
  .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(2*DATA_WIDTH))
  LTF_BUF(
    .clk(clk), .reset(reset), .clear(clear),
    .read_enable(re), .write_enable(we),
    .write_addr(waddr), .read_addr(raddr),
    .read_data(rdata), .write_data(wdata)
  );

assign out_tdata  = rdata;
assign out_tvalid = re & out_tready;
assign out_tlast  = 1'b0;

localparam INIT = 2'b00;
localparam WLTF = 2'b01;
localparam RLTF = 2'b10;
localparam WAIT = 2'b11;
localparam IDLE_LIM = NFFT + NCP;

reg [1:0] state;

always @(posedge clk ) begin
  if (reset) begin
    state   <= INIT;
    we      <= 1'b0;
    re      <= 1'b0;
    waddr   <= 0;
    raddr   <= 0;
    nread   <= 0;
    nidle   <= 0;
    ltf_pow <= 0;
  end
  else begin
    case (state)
      INIT: begin
        we      <= 1'b1;
        re      <= 1'b0;
        state   <= WLTF;
        waddr   <= 0;
        ltf_pow <= 0; 
      end 
      WLTF: begin
        waddr <= waddr + 1;
        if(pd_peak_stb) begin
          we    <= 1'b0;
          state <= RLTF;
          raddr <= waddr - nrx_after_peak - NFFT;
          ltf_pow <= pow;
          re    <= 1'b1;
          nread <= 0;
        end
      end
      RLTF: begin
        raddr <= raddr + 1;
        if(nread < NFFT) begin 
          nread <= nread + 1;
        end
        else begin 
          re    <= 1'b0;
          state <= WAIT;
        end
      end
      WAIT: begin
        if (nidle < IDLE_LIM) begin
          nidle <= nidle + 1;
        end
        else begin
          state <= INIT;
          nidle <= 0;
        end
      end
      default: state <= INIT;
    endcase
  end
end

endmodule