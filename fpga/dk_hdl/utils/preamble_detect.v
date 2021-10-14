module  preamble_detect#(
  parameter DATA_WIDTH    = 16,
  parameter NDEC          = 4, 
  parameter DEC_MAX_RATE  = 255,
  parameter [$clog2(DEC_MAX_RATE+1)-1:0] DEC_RATE = 64,
  parameter MAX_LEN         = 4095,
  parameter [$clog2(MAX_LEN+1)-1:0] LEN = 4092,
  parameter [1:0] THRES_SEL = 2'b01,
  parameter NRX_TRIG        = 16, 
  parameter [DATA_WIDTH-1:0] NOISE_POW = 15 
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

  /*output peak detect strobe*/
  output  out_tlast,
  output  out_tvalid,
  input   out_tready,
  output  peak_stb, 

  /*debug*/
  output dec_stb,
  output [DATA_WIDTH-1:0] idec, qdec,
  output [DATA_WIDTH-1:0] zi, zq,
  output [DATA_WIDTH-1:0] ami, amq,
  output [DATA_WIDTH-1:0] pmi, pmq, 
  output [2*DATA_WIDTH-1:0]  pow_tdata,
  output [2*DATA_WIDTH-1:0]  acorr_tdata,
  output [DATA_WIDTH-1:0]  pow_mag_tdata,
  output [DATA_WIDTH-1:0]  acorr_mag_tdata
);

wire [DATA_WIDTH-1:0] iq_idec, iq_qdec;
wire [2*DATA_WIDTH-1:0] dec_tdata;
wire dec_tlast, dec_tvalid, dec_tready;

wire pout_tready;
wire dec_last_in, dec_stb_out, dec_stb_in, dec_last_out;
assign dec_stb_in = in_tvalid; 
assign dec_last_in = in_tlast;

assign idec = iq_idec;
assign qdec = iq_qdec;
assign dec_stb = dec_stb_out;


cic_decimate_iq #(
  .DATA_WIDTH(DATA_WIDTH), .N(NDEC), .MAX_RATE(DEC_MAX_RATE))
    DEC_IQ(
      .clk(clk), .reset(reset), 
      .rate_stb(reset), .rate(DEC_RATE),
      .strobe_in(dec_stb_in), .strobe_out(dec_stb_out),
      .last_in(dec_last_in), .last_out(dec_last_out),
      .in_itdata(in_itdata), .in_qtdata(in_qtdata),
      .out_itdata(iq_idec), .out_qtdata(iq_qdec)
    );

strobed_to_axi #(
    .WIDTH(2*DATA_WIDTH))
  strobed_to_axi (
    .clk(clk), .reset(reset), 
    .clear(clear), .in_stb(dec_stb_out), 
    .in_data({iq_idec, iq_qdec}), .in_last(dec_last_out),
    .o_tdata(dec_tdata), .o_tlast(dec_tlast),
    .o_tvalid(dec_tvalid), .o_tready(dec_tready)
  );


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
      .i_tdata(dec_tdata), .i_tlast(dec_tlast),
      .i_tvalid(dec_tvalid), .i_tready(dec_tready),
      .o_tdata(ziq_tdata), .o_tlast(ziq_tlast),
      .o_tvalid(ziq_tvalid), .o_tready(ziq_tready)
    );

wire [2*DATA_WIDTH-1:0] aziq_tdata;
wire aziq_tlast, aziq_tvalid, aziq_tready;

axi_fifo #(.WIDTH(2*DATA_WIDTH+1), .SIZE(1)) 
  flop_delay(
    .clk(clk), .reset(reset), .clear(clear),
    .i_tdata({ziq_tlast, ziq_tdata}), 
    .i_tvalid(ziq_tvalid), .i_tready(ziq_tready),
    .o_tdata({aziq_tlast, aziq_tdata}), .o_tvalid(aziq_tvalid), .o_tready(aziq_tready),
    .occupied(), .space());

wire [2*DATA_WIDTH-1:0] adec_tdata;
wire adec_tlast, adec_tvalid, adec_tready;


wire [2*DATA_WIDTH-1:0] bdec_tdata;
wire bdec_tlast, bdec_tvalid, bdec_tready;

assign adec_tready = bdec_tready;

axi_fifo #(.WIDTH(2*DATA_WIDTH+1), .SIZE(1)) 
  flop_dec(
    .clk(clk), .reset(reset), .clear(clear),
    .i_tdata({dec_tlast, dec_tdata}), 
    .i_tvalid(dec_tvalid), .i_tready(),
    .o_tdata({adec_tlast, adec_tdata}), .o_tvalid(adec_tvalid), .o_tready(adec_tready),
    .occupied(), .space());



conj_flop #(
  .WIDTH(DATA_WIDTH), .FIFOSIZE(1))
    CDEC(
      .clk(clk), .reset(reset), .clear(clear),
      .i_tdata(dec_tdata), .i_tvalid(dec_tvalid), 
      .i_tlast(dec_tlast), .i_tready(),
      .o_tdata(bdec_tdata), .o_tvalid(bdec_tvalid),
      .o_tlast(bdec_tlast), .o_tready(bdec_tready)
    );

wire [2*DATA_WIDTH-1:0] pdec_tdata;
wire [DATA_WIDTH-1:0] pdec_itdata, pdec_qtdata;
wire pdec_tlast, pdec_tvalid, pdec_tready;
assign pdec_qtdata = pdec_tdata[DATA_WIDTH-1:0];
assign pdec_itdata = pdec_tdata[2*DATA_WIDTH-1:DATA_WIDTH];

assign pmi = pdec_itdata;
assign pmq = pdec_qtdata;

cmul16 #(
  .DATA_WIDTH(DATA_WIDTH))
  PMUL(
    .clk(clk), .reset(reset),
    .in_tvalid(bdec_tvalid), .in_tlast(bdec_tlast), .in_tready(bdec_tready),
    .adata(adec_tdata), .bdata(bdec_tdata), 
    .pdata(pdec_tdata), .out_tvalid(pdec_tvalid), 
    .out_tlast(pdec_tlast), .out_tready(pdec_tready)
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
    .adata(aziq_tdata), .bdata(bdec_tdata), 
    .pdata(ac_tdata), .out_tvalid(ac_tvalid), 
    .out_tlast(ac_tlast), .out_tready(ac_tready)
  );

wire [DATA_WIDTH-1:0] pow_itdata, pow_qtdata;
wire pow_tvalid, pow_tlast, pow_tready;
assign pow_tdata = {pow_itdata, pow_qtdata};
cmoving_avg #(
  .DATA_WIDTH(DATA_WIDTH), .MAX_LEN(MAX_LEN), .LEN(LEN))
    AVG_POW(
      .clk(clk), .reset(reset), .clear(clear),
      .in_tvalid(pdec_tvalid), .in_tlast(pdec_tlast), .in_tready(pdec_tready),
      .in_itdata(pdec_itdata), .in_qtdata(pdec_qtdata),
      .out_tvalid(pow_tvalid), .out_tlast(pow_tlast), .out_tready(pow_tready),
      .out_itdata(pow_itdata), .out_qtdata(pow_qtdata)
    );

wire [DATA_WIDTH-1:0] acorr_itdata, acorr_qtdata;
wire acorr_tvalid, acorr_tlast, acorr_tready;
assign acorr_tdata = {acorr_itdata, acorr_qtdata};
cmoving_avg #(
  .DATA_WIDTH(DATA_WIDTH), .MAX_LEN(MAX_LEN), .LEN(LEN))
    ACORR(
      .clk(clk), .reset(reset), .clear(clear),
      .in_tvalid(ac_tvalid), .in_tlast(ac_tlast), .in_tready(ac_tready),
      .in_itdata(ac_itdata), .in_qtdata(ac_qtdata),
      .out_tvalid(acorr_tvalid), .out_tlast(acorr_tlast), .out_tready(acorr_tready),
      .out_itdata(acorr_itdata), .out_qtdata(acorr_qtdata)
    );

wire pmag_tlast, pmag_tvalid, pmag_tready;
wire acmag_tlast, acmag_tvalid, acmag_tready;
wire [DATA_WIDTH-1:0] acmag_tdata, pmag_tdata;
assign pow_mag_tdata   = pmag_tdata;
assign acorr_mag_tdata = acmag_tdata;
complex_to_mag_approx #(
  .SAMP_WIDTH(DATA_WIDTH))
    PMAG(
      .clk(clk), .reset(reset), .clear(clear),
      .i_tdata({pow_itdata, pow_qtdata}), .i_tvalid(pow_tvalid),
      .i_tlast(pow_tlast), .i_tready(pow_tready),
      .o_tdata(pmag_tdata), .o_tvalid(pmag_tvalid),
      .o_tlast(pmag_tlast), .o_tready(pmag_tready)
    );

complex_to_mag_approx #(
  .SAMP_WIDTH(DATA_WIDTH))
    ACMAG(
      .clk(clk), .reset(reset), .clear(clear),
      .i_tdata({acorr_itdata, acorr_qtdata}), .i_tvalid(acorr_tvalid),
      .i_tlast(acorr_tlast), .i_tready(acorr_tready),
      .o_tdata(acmag_tdata), .o_tvalid(acmag_tvalid),
      .o_tlast(acmag_tlast), .o_tready(acmag_tready)
    );

reg peak_stb_in, peak_tvalid, peak_tlast;
wire peak_tready, peak_stb_out;
assign pmag_tready  = peak_tready;
assign acmag_tready = peak_tready; 
wire [DATA_WIDTH-1:0] pow_12, pow_14, pow_18, pow_38, pow_58, comp_pow;
assign pow_12   = pow_mag_tdata >> 1;
assign pow_14   = pow_mag_tdata >> 2;
assign pow_18   = pow_mag_tdata >> 3;

add2_and_clip #(
  .WIDTH(DATA_WIDTH))
  P38(
    .in1(pow_14), .in2(pow_18), .sum(pow_38)
  );

add2_and_clip #(
  .WIDTH(DATA_WIDTH))
  P34(
    .in1(pow_18), .in2(pow_12), .sum(pow_58)
  );
assign comp_pow = THRES_SEL[1] ?  (THRES_SEL[0] ? pow_58 : pow_12) : 
                                  (THRES_SEL[0] ? pow_38 : pow_14);
always @(posedge clk) begin
  if (reset | clear) begin
    peak_stb_in <= 1'b0;
  end
  else begin
    peak_tvalid <= pmag_tvalid & acmag_tvalid;
    peak_tlast  <= pmag_tlast  & acmag_tlast; 
    if(acmag_tvalid & pmag_tvalid) begin
      peak_stb_in <= (acmag_tdata > comp_pow) & (pmag_tdata > NOISE_POW);
    end
  end
end

peak_detect #(
  .DATA_WIDTH(DATA_WIDTH), .NRX_TRIG(NRX_TRIG))
    DUT(
      .clk(clk), .reset(reset), .clear(reset),
      .in_tvalid(peak_tvalid), .in_tlast(peak_tlast), 
      .in_tready(peak_tready), .in_tdata(acmag_tdata), 
      .peak_stb_in(peak_stb_in), .peak_stb_out(peak_stb_out),
      .out_tvalid(out_tvalid), .out_tlast(out_tlast), 
      .out_tready(out_tready)
    );
assign peak_stb    = peak_stb_out; // & peak_stb_in;
assign in_tready   = ( out_tready | ~out_tvalid ) & ~reset;

endmodule