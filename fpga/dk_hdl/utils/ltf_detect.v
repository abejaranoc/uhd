module  ltf_detect#(
  parameter DATA_WIDTH    = 16,
  parameter MAX_LEN       = 1023,
  parameter [$clog2(MAX_LEN+1)-1:0] LEN = 512,
  parameter [1:0] THRES_SEL = 2'b10,
  parameter NRX_TRIG        = 64, 
  parameter NRX_WIDTH       = 16, 
  parameter PMAG_WIDTH      = DATA_WIDTH + $clog2(MAX_LEN+1),
  parameter [DATA_WIDTH-1:0] NOISE_POW = 15000 
)(
  input clk,
  input reset,
  input clear,

  /* IQ input of RX Data*/
  input  in_tvalid,
  input  in_tlast, 
  output in_tready,
  input [DATA_WIDTH-1:0]  in_itdata,
  input [DATA_WIDTH-1:0]  in_qtdata,

  input [2*DATA_WIDTH-1:0] noise_thres,

  /*output peak detect strobe*/
  output  out_tlast,
  output  out_tvalid,
  input   out_tready,
  output  peak_stb, 
  output [NRX_WIDTH-1:0] nrx_after_peak,
  output [PMAG_WIDTH-1:0] pow,

  /*debug*/
  output peak_thres,
  output [DATA_WIDTH-1:0] zi, zq,
  output [DATA_WIDTH-1:0] ami, amq,
  output [DATA_WIDTH-1:0] pmi, pmq, 
  output [2*PMAG_WIDTH-1:0]  pow_tdata,
  output [2*PMAG_WIDTH-1:0]  acorr_tdata,
  output [PMAG_WIDTH-1:0]  pow_mag_tdata,
  output [PMAG_WIDTH-1:0]  acorr_mag_tdata
);

wire [DATA_WIDTH-1:0] iq_idec, iq_qdec;
wire [2*DATA_WIDTH-1:0] in_tdata = {in_itdata, in_qtdata};


wire [DATA_WIDTH-1:0] ziq_itdata, ziq_qtdata;
wire [2*DATA_WIDTH-1:0] ziq_tdata;
wire ziq_tlast, ziq_tvalid, ziq_tready;


assign ziq_qtdata = ziq_tdata[DATA_WIDTH-1:0];
assign ziq_itdata = ziq_tdata[2*DATA_WIDTH-1:DATA_WIDTH];

assign zi = ziq_itdata;
assign zq = ziq_qtdata;

delay_fifo #(
  .MAX_LEN(MAX_LEN), .WIDTH(2*DATA_WIDTH))
    ZIQ (
      .clk(clk), .reset(reset), 
      .clear(clear), .len(LEN),
      .i_tdata(in_tdata), .i_tlast(in_tlast),
      .i_tvalid(in_tvalid), .i_tready(),
      .o_tdata(ziq_tdata), .o_tlast(ziq_tlast),
      .o_tvalid(ziq_tvalid), .o_tready(ziq_tready)
    );

wire [2*DATA_WIDTH-1:0] aziq_tdata;
wire aziq_tlast, aziq_tvalid, aziq_tready;

axi_fifo #(.WIDTH(2*DATA_WIDTH+1), .SIZE(1)) 
  FLOP_ZIQ(
    .clk(clk), .reset(reset), .clear(clear),
    .i_tdata({ziq_tlast, ziq_tdata}), 
    .i_tvalid(ziq_tvalid), .i_tready(ziq_tready),
    .o_tdata({aziq_tlast, aziq_tdata}), .o_tvalid(aziq_tvalid), .o_tready(aziq_tready),
    .occupied(), .space());

wire [2*DATA_WIDTH-1:0] a_tdata;
wire a_tlast, a_tvalid, a_tready;


wire [2*DATA_WIDTH-1:0] b_tdata;
wire b_tlast, b_tvalid, b_tready;

assign a_tready = b_tready;

axi_fifo #(.WIDTH(2*DATA_WIDTH+1), .SIZE(1)) 
  FLOP_IN(
    .clk(clk), .reset(reset), .clear(clear),
    .i_tdata({in_tlast, in_tdata}), 
    .i_tvalid(in_tvalid), .i_tready(),
    .o_tdata({a_tlast, a_tdata}), .o_tvalid(a_tvalid), .o_tready(a_tready),
    .occupied(), .space());



conj_flop #(
  .WIDTH(DATA_WIDTH), .FIFOSIZE(1))
    CFLOP_IN(
      .clk(clk), .reset(reset), .clear(clear),
      .i_tdata(in_tdata), .i_tvalid(in_tvalid), 
      .i_tlast(in_tlast), .i_tready(),
      .o_tdata(b_tdata), .o_tvalid(b_tvalid),
      .o_tlast(b_tlast), .o_tready(b_tready)
    );

wire [2*DATA_WIDTH-1:0] p_tdata;
wire [DATA_WIDTH-1:0] p_itdata, p_qtdata;
wire p_tlast, p_tvalid, p_tready;
assign p_qtdata = p_tdata[DATA_WIDTH-1:0];
assign p_itdata = p_tdata[2*DATA_WIDTH-1:DATA_WIDTH];

assign pmi = p_itdata;
assign pmq = p_qtdata;

cmul16 #(
  .DATA_WIDTH(DATA_WIDTH))
  PMUL(
    .clk(clk), .reset(reset),
    .in_tvalid(b_tvalid), .in_tlast(b_tlast), .in_tready(b_tready),
    .adata(a_tdata), .bdata(b_tdata), 
    .pdata(p_tdata), .out_tvalid(p_tvalid), 
    .out_tlast(p_tlast), .out_tready(p_tready)
  );

wire [2*DATA_WIDTH-1:0] ac_tdata;
wire [DATA_WIDTH-1:0] ac_itdata, ac_qtdata;
wire ac_tlast, ac_tvalid, ac_tready;
assign ac_qtdata = ac_tdata[DATA_WIDTH-1:0];
assign ac_itdata = ac_tdata[2*DATA_WIDTH-1:DATA_WIDTH];

assign ami = ac_itdata;
assign amq = ac_qtdata;

cmul16 #(
  .DATA_WIDTH(DATA_WIDTH))
  ACMUL(
    .clk(clk), .reset(reset),
    .in_tvalid(aziq_tvalid), .in_tlast(aziq_tlast), .in_tready(aziq_tready),
    .adata(aziq_tdata), .bdata(b_tdata), 
    .pdata(ac_tdata), .out_tvalid(ac_tvalid), 
    .out_tlast(ac_tlast), .out_tready(ac_tready)
  );

wire [PMAG_WIDTH-1:0] pow_itdata, pow_qtdata;
wire pow_tvalid, pow_tlast, pow_tready;
assign pow_tdata = {pow_itdata, pow_qtdata};
cmoving_sum #(
  .DATA_WIDTH(DATA_WIDTH), .MAX_LEN(MAX_LEN), 
  .LEN(LEN), .OUT_WIDTH(PMAG_WIDTH))
    AVG_POW(
      .clk(clk), .reset(reset), .clear(clear),
      .in_tvalid(p_tvalid), .in_tlast(p_tlast), .in_tready(p_tready),
      .in_itdata(p_itdata), .in_qtdata(p_qtdata),
      .out_tvalid(pow_tvalid), .out_tlast(pow_tlast), .out_tready(pow_tready),
      .out_itdata(pow_itdata), .out_qtdata(pow_qtdata)
    );

wire [PMAG_WIDTH-1:0] acorr_itdata, acorr_qtdata;
wire acorr_tvalid, acorr_tlast, acorr_tready;
assign acorr_tdata = {acorr_itdata, acorr_qtdata};
cmoving_sum #(
  .DATA_WIDTH(DATA_WIDTH), .MAX_LEN(MAX_LEN), 
  .LEN(LEN), .OUT_WIDTH(PMAG_WIDTH))
    ACORR(
      .clk(clk), .reset(reset), .clear(clear),
      .in_tvalid(ac_tvalid), .in_tlast(ac_tlast), .in_tready(ac_tready),
      .in_itdata(ac_itdata), .in_qtdata(ac_qtdata),
      .out_tvalid(acorr_tvalid), .out_tlast(acorr_tlast), .out_tready(acorr_tready),
      .out_itdata(acorr_itdata), .out_qtdata(acorr_qtdata)
    );

wire pmag_tlast, pmag_tvalid, pmag_tready;
wire acmag_tlast, acmag_tvalid, acmag_tready;
wire [PMAG_WIDTH-1:0] acmag_tdata, pmag_tdata;
assign pow_mag_tdata   = pmag_tdata;
assign acorr_mag_tdata = acmag_tdata;

complex_to_mag_approx #(
  .SAMP_WIDTH(PMAG_WIDTH))
    PMAG(
      .clk(clk), .reset(reset), .clear(clear),
      .i_tdata({pow_itdata, pow_qtdata}), .i_tvalid(pow_tvalid),
      .i_tlast(pow_tlast), .i_tready(pow_tready),
      .o_tdata(pmag_tdata), .o_tvalid(pmag_tvalid),
      .o_tlast(pmag_tlast), .o_tready(pmag_tready)
    );

complex_to_mag_approx #(
  .SAMP_WIDTH(PMAG_WIDTH))
    ACMAG(
      .clk(clk), .reset(reset), .clear(clear),
      .i_tdata({acorr_itdata, acorr_qtdata}), .i_tvalid(acorr_tvalid),
      .i_tlast(acorr_tlast), .i_tready(acorr_tready),
      .o_tdata(acmag_tdata), .o_tvalid(acmag_tvalid),
      .o_tlast(acmag_tlast), .o_tready(acmag_tready)
    );

reg peak_stb_in;
wire peak_tvalid, peak_tlast;
wire peak_tready, peak_stb_out;
assign peak_tvalid = pmag_tvalid & acmag_tvalid;
assign peak_tlast  = pmag_tlast  & acmag_tlast; 
assign pmag_tready  = peak_tready;
assign acmag_tready = peak_tready; 
wire [PMAG_WIDTH-1:0] pow_12, pow_14, pow_18, pow_38, pow_58, pow_34, comp_pow;
assign pow_12   = {1'b0,   pmag_tdata[PMAG_WIDTH-1:1]};
assign pow_14   = {2'b00,  pmag_tdata[PMAG_WIDTH-1:2]};
assign pow_18   = {3'b000, pmag_tdata[PMAG_WIDTH-1:3]};

add2_and_clip #(
  .WIDTH(PMAG_WIDTH))
  P38(
    .in1(pow_14), .in2(pow_18), .sum(pow_38)
  );

add2_and_clip #(
  .WIDTH(PMAG_WIDTH))
  P58(
    .in1(pow_18), .in2(pow_12), .sum(pow_58)
  );

add2_and_clip #(
  .WIDTH(PMAG_WIDTH))
  P34(
    .in1(pow_14), .in2(pow_12), .sum(pow_34)
  );
assign comp_pow = THRES_SEL[1] ?  (THRES_SEL[0] ? pow_34 : pow_58) : 
                                  (THRES_SEL[0] ? pow_12 : pow_38);

wire [PMAG_WIDTH-1:0] thres;
assign thres = (noise_thres[PMAG_WIDTH-1:0] == 0) ? NOISE_POW : noise_thres[PMAG_WIDTH-1:0];

always @(posedge clk) begin
  if (reset | clear) begin
    peak_stb_in <= 1'b0;
  end
  else begin
    if(acmag_tvalid & pmag_tvalid) begin
      peak_stb_in <=  ((acmag_tdata > comp_pow)   & 
                      (pmag_tdata   > thres)) & 
                      (acmag_tdata  > thres);
    end
  end
end

peak_detect_nrx #(
  .DATA_WIDTH(PMAG_WIDTH), .NRX_TRIG(NRX_TRIG), .NRX_WIDTH(NRX_WIDTH))
    PKD(
      .clk(clk), .reset(reset), .clear(reset),
      .in_tvalid(peak_tvalid), .in_tlast(peak_tlast), 
      .in_tready(peak_tready), .in_tdata(acmag_tdata), 
      .peak_stb_in(peak_stb_in), .peak_stb_out(peak_stb_out),
      .out_tvalid(out_tvalid), .out_tlast(out_tlast), 
      .out_tready(out_tready), .nrx_after_peak(nrx_after_peak),
      .pow_in(pmag_tdata), .pow_out(pow)
    );
assign peak_stb    = peak_stb_out; // & peak_stb_in;
assign peak_thres  = peak_stb_in;
assign in_tready   = ( out_tready | ~out_tvalid ) & ~reset;

endmodule