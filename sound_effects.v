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

module sound_gen
 (input clk,
  input sample_strobe,
  output [3:0] control,
  output reg [15:0] left_sample,
  output reg [15:0] right_sample);

  reg [31:0] sc = 32'hFFFE53FF; //music counter for use with making music

  reg [20:0] noise = 7'h55; //music noise generator lfsr
  reg [20:0] control_noise = 21'hAAAAA;

//  wire [3:0] control;

  wire [15:0] tone0;
  wire [15:0] tone1;
  wire [15:0] tone2;
  wire [15:0] tone3;

  wire [13:0] melody;
  reg [7:0] melody_mul;

  wire [15:0] noise0;
  wire [15:0] noise1;

  assign control = {control_noise[20], control_noise[19], control_noise[18], control_noise[17]};

  assign tone0 = ({7{control[0]}} & sc[6:0])<<5;
  assign tone1 = ({6{control[1]}} & sc[5:0])<<6;
  assign tone2 = ({5{control[2]}} & sc[4:0])<<7;
  assign tone3 = ({4{control[3]}} & sc[3:0])<<8;

  assign melody = sc[9:0] * melody_mul;

  assign noise0 = {14{sc[14]&sc[12]&sc[10]}} & noise[13:0];
  assign noise1 = {14{~sc[14]&sc[13]& ~sc[10]}} & noise[13:0];

  always @(*)
  case (sc[16:14])
    3'b000: melody_mul = 8'h0F+sc[11:10];
    3'b001: melody_mul = 8'h2F+sc[11:10];
    3'b010: melody_mul = 8'h5F+sc[11:10];
    3'b011: melody_mul = 8'h42+sc[11:10];
    3'b100: melody_mul = 8'h37+sc[11:10];
    3'b101: melody_mul = 8'h10+sc[11:10];
    3'b110: melody_mul = 8'h32+sc[11:10];
    3'b111: melody_mul = 8'h1F+sc[11:10];
  endcase

  always @(posedge clk)
  if (sample_strobe)
  begin
    sc <= sc + 1;

    if (&sc[1:0])
    begin
      noise[20:1] <= noise[19:0];
      noise[0] <= noise[20] ^ noise[19];
    end

    if (&sc[10:0])
    begin
      control_noise[20:1] <= control_noise[19:0];
      control_noise[0] <= control_noise[20] ^ control_noise[19];
    end 

    left_sample <= tone0 + tone1 + noise0 + melody;
    right_sample <= tone2 + tone3 + noise1 + melody;

//    left_sample <= sc[5:0];
//    right_sample <= sc[4:0];

  end
endmodule

