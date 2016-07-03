/*
Copyright (c) 2014 Antti Siponen

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

//A silly simple serializer to use if your device is incredibly fast
//or if you are aiming for a relatively humble resolution
module tmds_serializer (
  input          clk,         // pixel clock input
  input          clkx10,      // bit clock input
  input          rst,
  input [9:0]    chan0_token,
  input [9:0]    chan1_token,
  input [9:0]    chan2_token,
  output [2:0]   tmds_stream); 

  reg local_rst;

  always @(posedge clk)
    local_rst <= rst;

  ring_buffer #(.SIZE(10)) loadtimer (.clk(clkx10), .clear(1'b0), .load(local_rst), .p_in(10'b0000100000), .s_out(load_flag));
  ring_buffer #(.SIZE(10)) ser0 (.clk(clkx10), .clear(local_rst), .load(load_flag), .p_in(chan0_token), .s_out(tmds_stream[0]));
  ring_buffer #(.SIZE(10)) ser1 (.clk(clkx10), .clear(local_rst), .load(load_flag), .p_in(chan1_token), .s_out(tmds_stream[1]));
  ring_buffer #(.SIZE(10)) ser2 (.clk(clkx10), .clear(local_rst), .load(load_flag), .p_in(chan2_token), .s_out(tmds_stream[2]));
endmodule

//A dual serializer to generate two clkx5 syncronous datastreams
//per colour, one carrying the even bits and the other carrying 
//the odd bits. To be used with a ddr buffer that can delay it's one 
//input to generate a true ddr result stream (for example Spartan 
//ODDR2 cascade mode).  
module tmds_dual_serializer (
  input          clk,         // pixel clock input
  input          clkx5,       // bit clock input
  input          rst,
  input [9:0]    chan0_token,
  input [9:0]    chan1_token,
  input [9:0]    chan2_token,
  output [2:0]   tmds_even,   //even and odd bitstreams synced to clkx5
  output [2:0]   tmds_odd); 

  reg local_rst;
  wire [4:0] chan0_even;
  wire [4:0] chan0_odd;
  wire [4:0] chan1_even;
  wire [4:0] chan1_odd;
  wire [4:0] chan2_even;
  wire [4:0] chan2_odd;

  always @(posedge clk)
    local_rst <= rst;

//Separate the input bits to evens and odds
  assign chan0_even = {chan0_token[8], chan0_token[6], chan0_token[4], chan0_token[2], chan0_token[0]};
  assign chan0_odd = {chan0_token[9], chan0_token[7], chan0_token[5], chan0_token[3], chan0_token[1]};

  assign chan1_even = {chan1_token[8], chan1_token[6], chan1_token[4], chan1_token[2], chan1_token[0]};
  assign chan1_odd = {chan1_token[9], chan1_token[7], chan1_token[5], chan1_token[3], chan1_token[1]};

  assign chan2_even = {chan2_token[8], chan2_token[6], chan2_token[4], chan2_token[2], chan2_token[0]};
  assign chan2_odd = {chan2_token[9], chan2_token[7], chan2_token[5], chan2_token[3], chan2_token[1]};

//The serializer buffers and a timer line with one hot bit to signal when to load in new data.
//Adjusting the value of p_in of the loadtimer changes the loading delay. This delay is used to avoid
//timing problems at the clock region border
  ring_buffer loadtimer (.clk(clkx5), .clear(1'b0), .load(local_rst), .p_in(5'b00100), .s_out(load_flag));

  ring_buffer ser0even (.clk(clkx5), .clear(local_rst), .load(load_flag), .p_in(chan0_even), .s_out(tmds_even[0]));
  ring_buffer ser0odd (.clk(clkx5), .clear(local_rst), .load(load_flag), .p_in(chan0_odd), .s_out(tmds_odd[0]));

  ring_buffer ser1even (.clk(clkx5), .clear(local_rst), .load(load_flag), .p_in(chan1_even), .s_out(tmds_even[1]));
  ring_buffer ser1odd (.clk(clkx5), .clear(local_rst), .load(load_flag), .p_in(chan1_odd), .s_out(tmds_odd[1]));

  ring_buffer ser2even (.clk(clkx5), .clear(local_rst), .load(load_flag), .p_in(chan2_even), .s_out(tmds_even[2]));
  ring_buffer ser2odd (.clk(clkx5), .clear(local_rst), .load(load_flag), .p_in(chan2_odd), .s_out(tmds_odd[2]));
endmodule




//A ddr serializer that creates two datastreams per colour, 
//one carrying the even bits syncronized to clkx5 positive edges
//and the other carrying the odd bits syncronized to the clkx5
//negative edges. To be used with a regular ddr buffer.
module tmds_ddr_serializer (
  input          clkx5,      // bit clock input
  input          clkx5n,      // bit clock input inverted
  input [9:0]    chan0_token,
  input [9:0]    chan1_token,
  input [9:0]    chan2_token,
  output [2:0]   tmds_ddr_p,
  output [2:0]   tmds_ddr_n);

//Separate the input bits to evens and odds
  wire [4:0] chan0_even;
  wire [4:0] chan0_odd;
  wire [4:0] chan1_even;
  wire [4:0] chan1_odd;
  wire [4:0] chan2_even;
  wire [4:0] chan2_odd;

  assign chan0_even = {chan0_token[8], chan0_token[6], chan0_token[4], chan0_token[2], chan0_token[0]};
  assign chan0_odd = {chan0_token[9], chan0_token[7], chan0_token[5], chan0_token[3], chan0_token[1]};

  assign chan1_even = {chan1_token[8], chan1_token[6], chan1_token[4], chan1_token[2], chan1_token[0]};
  assign chan1_odd = {chan1_token[9], chan1_token[7], chan1_token[5], chan1_token[3], chan1_token[1]};

  assign chan2_even = {chan2_token[8], chan2_token[6], chan2_token[4], chan2_token[2], chan2_token[0]};
  assign chan2_odd = {chan2_token[9], chan2_token[7], chan2_token[5], chan2_token[3], chan2_token[1]};


//Two ring buffers with one hot bit counting to 5 and signaling the serializer lines when to
//load in new data. The p_in values here can be adjusted to change the load timings.
//The default values make both loads happen on the third clkx5 edge, positive and negative
//respectively.
  wire load_flag_p;
  wire load_flag_n;
  reg [4:0] load_counter = 5'b01000;
  reg load_counter_cross = 1'b0;

  always @(posedge clkx5)
    load_counter <= {load_counter[0], load_counter[4:1]};
  always @(posedge clkx5n)
    load_counter_cross <= load_counter[0];

  assign load_flag_p = load_counter[0];
  assign load_flag_n = load_counter_cross;

//The serializer lines
  ring_buffer ser0p (.clk(clkx5), .clear(1'b0), .load(load_flag_p), .p_in(chan0_even), .s_out(tmds_ddr_p[0]));
  ring_buffer ser0n (.clk(clkx5n), .clear(1'b0), .load(load_flag_n), .p_in(chan0_odd), .s_out(tmds_ddr_n[0]));

  ring_buffer ser1p (.clk(clkx5), .clear(1'b0), .load(load_flag_p), .p_in(chan1_even), .s_out(tmds_ddr_p[1]));
  ring_buffer ser1n (.clk(clkx5n), .clear(1'b0), .load(load_flag_n), .p_in(chan1_odd), .s_out(tmds_ddr_n[1]));

  ring_buffer ser2p (.clk(clkx5), .clear(1'b0), .load(load_flag_p), .p_in(chan2_even), .s_out(tmds_ddr_p[2]));
  ring_buffer ser2n (.clk(clkx5n), .clear(1'b0), .load(load_flag_n), .p_in(chan2_odd), .s_out(tmds_ddr_n[2]));
endmodule
