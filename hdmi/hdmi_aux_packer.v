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

//This module takes in various aux packet sources and multiplexes them
//according to a fixed priority if several sources need to send at once.
//Also the aux packet ECC is calculated here
module hdmi_aux_packer
#(parameter BYPASS_ECC = "FALSE")

 (input clk,
  input ae,          //Aux enable
  input hsync,       //The sync signals need to be included in each data island
  input vsync,
  input packet_end,  //The signal to indicate we are at the end of one complete packet
  input [4:0] slot,  //The low-order bits of the current aux time slot, needed to determine when to send ECC
  output aux_request,  //An output to signal the sequencer that there is a need to send at least one aux packet
  output [3:0] channel0_aux,
  output [3:0] channel1_aux,
  output [3:0] channel2_aux,

  input ready_a,
  input header_a,
  input [1:0] sub0_a,
  input [1:0] sub1_a,
  input [1:0] sub2_a,
  input [1:0] sub3_a,
  output reg enable_a,

  input ready_b,
  input header_b,
  input [1:0] sub0_b,
  input [1:0] sub1_b,
  input [1:0] sub2_b,
  input [1:0] sub3_b,
  output reg enable_b,

  input ready_c,
  input header_c,
  input [1:0] sub0_c,
  input [1:0] sub1_c,
  input [1:0] sub2_c,
  input [1:0] sub3_c,
  output reg enable_c,

  input ready_d,
  input header_d,
  input [1:0] sub0_d,
  input [1:0] sub1_d,
  input [1:0] sub2_d,
  input [1:0] sub3_d,
  output reg enable_d);



  //The signals of the packet source that currently has priority
  reg header = 0;
  reg [1:0] sub0 = 0;
  reg [1:0] sub1 = 0;
  reg [1:0] sub2 = 0;
  reg [1:0] sub3 = 0;

  //Aux packet bits ready to be sent
  wire BCH4; //Header
  wire [1:0] BCH0;
  wire [1:0] BCH1;
  wire [1:0] BCH2;
  wire [1:0] BCH3;

  //Control signals to guide the module timings
  reg send_header_parity = 0;
  reg send_data_parity = 0;
  reg invalid_aux_data = 0;
  reg packet_complete = 0;
  reg delayed_hsync = 0;
  reg delayed_vsync = 0;

  //ECC
  wire header_parity;
  wire [1:0] sub0_parity;
  wire [1:0] sub1_parity;
  wire [1:0] sub2_parity;
  wire [1:0] sub3_parity;

  //When any of the sources needs to send a packet we signal that a packet needs to be sent
  assign aux_request = ready_a | ready_b | ready_c | ready_d;

  //Routing the parts of the packet to correct aux lines for the encoder
  assign channel0_aux[0] = delayed_hsync;
  assign channel0_aux[1] = delayed_vsync;
  assign channel0_aux[2] = BCH4 | invalid_aux_data;
  assign channel0_aux[3] = 1'b1;

  assign channel1_aux[0] = BCH0[0];
  assign channel1_aux[1] = BCH1[0];
  assign channel1_aux[2] = BCH2[0];
  assign channel1_aux[3] = BCH3[0];

  assign channel2_aux[0] = BCH0[1];
  assign channel2_aux[1] = BCH1[1];
  assign channel2_aux[2] = BCH2[1];
  assign channel2_aux[3] = BCH3[1];


  //Multiplexer for the aux packet sources
  always @(*)
    case ({enable_a, enable_b, enable_c, enable_d})
      4'b1000:
      begin
        header = header_a;
        sub0 = sub0_a;
        sub1 = sub1_a;
        sub2 = sub2_a;
        sub3 = sub3_a;
      end
      4'b0100:
      begin
        header = header_b;
        sub0 = sub0_b;
        sub1 = sub1_b;
        sub2 = sub2_b;
        sub3 = sub3_b;
      end
      4'b0010:
      begin
        header = header_c;
        sub0 = sub0_c;
        sub1 = sub1_c;
        sub2 = sub2_c;
        sub3 = sub3_c;
      end
      4'b0001:
      begin
        header = header_d;
        sub0 = sub0_d;
        sub1 = sub1_d;
        sub2 = sub2_d;
        sub3 = sub3_d;
      end
      default:
      begin
        header = 1'b0;
        sub0 = 2'b00;
        sub1 = 2'b00;
        sub2 = 2'b00;
        sub3 = 2'b00;
      end
    endcase

  always @(posedge clk)
  begin
    invalid_aux_data <= ~ae;
    send_header_parity <= (BYPASS_ECC != "TRUE") & slot[4] & slot[3];
    send_data_parity <= (BYPASS_ECC != "TRUE") & slot[4] & slot[3] & slot[2];
    packet_complete <= packet_end;
    delayed_hsync <= hsync;
    delayed_vsync <= vsync;

  //Priority of the aux sources is decided here
    if (invalid_aux_data | packet_complete)
    begin
      if (ready_a)
      begin
        enable_a <= 1'b1;
        enable_b <= 1'b0;
        enable_c <= 1'b0;
        enable_d <= 1'b0;
      end
      else if (ready_b)
      begin
        enable_a <= 1'b0;
        enable_b <= 1'b1;
        enable_c <= 1'b0;
        enable_d <= 1'b0;
      end
      else if (ready_c)
      begin
        enable_a <= 1'b0;
        enable_b <= 1'b0;
        enable_c <= 1'b1;
        enable_d <= 1'b0;
      end
      else if (ready_d)
      begin
        enable_a <= 1'b0;
        enable_b <= 1'b0;
        enable_c <= 1'b0;
        enable_d <= 1'b1;
      end
      else
      begin
        enable_a <= 1'b0;
        enable_b <= 1'b0;
        enable_c <= 1'b0;
        enable_d <= 1'b0;
      end
    end
  end

  //LFSRs to calculate the ECC
  hdmi_ecc hdpr (
    .clk(clk),
    .rst(invalid_aux_data),
    .d(header),
    .t(~send_header_parity),
    .s(header_parity));

  assign BCH4 = (send_header_parity) ? header_parity : header;

  hdmi_ecc_bi dapr0 (
    .clk(clk),
    .rst(invalid_aux_data),
    .d1(sub0[0]),
    .d2(sub0[1]),
    .t(~send_data_parity),
    .s1(sub0_parity[0]),
    .s2(sub0_parity[1]));

  assign BCH0 = (send_data_parity) ? sub0_parity : sub0;

  hdmi_ecc_bi dapr1 (
    .clk(clk),
    .rst(invalid_aux_data),
    .d1(sub1[0]),
    .d2(sub1[1]),
    .t(~send_data_parity),
    .s1(sub1_parity[0]),
    .s2(sub1_parity[1]));

  assign BCH1 = (send_data_parity) ? sub1_parity : sub1;

  hdmi_ecc_bi dapr2 (
    .clk(clk),
    .rst(invalid_aux_data),
    .d1(sub2[0]),
    .d2(sub2[1]),
    .t(~send_data_parity),
    .s1(sub2_parity[0]),
    .s2(sub2_parity[1]));

  assign BCH2 = (send_data_parity) ? sub2_parity : sub2;

  hdmi_ecc_bi dapr3 (
    .clk(clk),
    .rst(invalid_aux_data),
    .d1(sub3[0]),
    .d2(sub3[1]),
    .t(~send_data_parity),
    .s1(sub3_parity[0]),
    .s2(sub3_parity[1]));

  assign BCH3 = (send_data_parity) ? sub3_parity : sub3;
endmodule



//ECC calculator that works one bit at a time
//Used for the header ECC
module hdmi_ecc
 (input  clk,
  input  rst,
  input  d,
  input  t,
  output s);

  reg [7:0] r = 0;
  wire a;

  assign s = r[7];
  assign a = t & (r[7] ^ d);

  always @(posedge clk)
  if (rst)
    r <= 8'h00;
  else
  begin
    r[7] <= r[6] ^ a;
    r[6] <= r[5] ^ a;
    r[5:1] <= r[4:0];
    r[0] <= a;
  end
endmodule


//ECC calculator that works two bits at a time
//Used for the packet body ECCs
module hdmi_ecc_bi
 (input  clk,
  input  rst,
  input  d1,
  input  d2,
  input  t,
  output s1,
  output s2);

  wire a_int;
  wire a;
  wire [7:0] r_int;

  reg [7:0] r = 0;

  assign a_int = t & (r[7] ^ d1);
  assign r_int[7] = r[6] ^ a_int;
  assign r_int[6] = r[5] ^ a_int;
  assign r_int[5:1] = r[4:0];
  assign r_int[0] = a_int;
  assign a = t & (r_int[7] ^ d2);

  assign s1 = r[7];
  assign s2 = r_int[7];

  always @(posedge clk)
  if (rst)
  begin
    r <= 8'h00;
  end
  else
  begin
    r[7] <= r_int[6] ^ a;
    r[6] <= r_int[5] ^ a;
    r[5:1] <= r_int[4:0];
    r[0] <= a;
  end
endmodule
