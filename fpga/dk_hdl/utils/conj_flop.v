//
// Copyright 2014 Ettus Research LLC
// Copyright 2018 Ettus Research, a National Instruments Company
//
// SPDX-License-Identifier: LGPL-3.0-or-later
//
// NOTE -- does not flop the output.  could cause timing issues, so follow with axi_fifo_flop if you need it

module conj_flop
  #(parameter WIDTH=16, parameter FIFOSIZE=1)
   (input clk, input reset, input clear,
    input [2*WIDTH-1:0] i_tdata, input i_tlast, input i_tvalid, output i_tready,
    output [2*WIDTH-1:0] o_tdata, output o_tlast, output o_tvalid, input o_tready);

   wire [2*WIDTH-1:0] conj_out;
   assign conj_out = { i_tdata[2*WIDTH-1:WIDTH] , -i_tdata[WIDTH-1:0] };

   axi_fifo #(.WIDTH(2*WIDTH+1), .SIZE(FIFOSIZE)) 
      flop(
        .clk(clk), .reset(reset), .clear(clear),
        .i_tdata({i_tlast, conj_out}), .i_tvalid(i_tvalid), .i_tready(i_tready),
        .o_tdata({o_tlast, o_tdata}), .o_tvalid(o_tvalid), .o_tready(o_tready),
        .occupied(), .space());
   
endmodule // conj
