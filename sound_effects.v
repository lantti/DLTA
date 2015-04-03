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
  output reg [15:0] left_sample,
  output reg [15:0] right_sample);

  reg [31:0] sample_count = 32'hFFFE53FF; //music counter for use with making music

  reg [20:0] noise = 7'h55; //music noise generator lfsr
  reg [20:0] control_noise = 21'hAAAAA;

  wire [3:0] control;

  wire [15:0] tone0;
  wire [15:0] tone1;
  wire [15:0] tone2;
  wire [15:0] tone3;

  assign control = {control_noise[20], control_noise[19], control_noise[18], control_noise[17]};


  assign tone0 = control[0] & mc[15:0];
  assign tone1 = control[1] & (((noise[20]&mc[12]&mc[14])<<15)^((mc[9:0]<<(7+{mc[14],mc[15],mc[13]}-mc[16]))+(mc[9:0]&{10{mc[13]}})));
  assign tone2 = control[2] & (((noise[20]&mc[12]&mc[14]&(mc[16]^mc[13]))<<15)^((mc[5:0]<<(16-{0,mc[12:10]}))|{16{(mc[18]|mc[17]|(mc[12]^mc[10]))}}));
  assign tone3 = control[0] & (mc[31:16]);

  always @(posedge clk)
  if (sample_strobe)
  begin
    mc <= mc - 1;
    noise[20:1] <= noise[19:0];
    noise[0] <= noise[20] ^ noise[19];

    left_sample <= tone0 ^ tone1;
    right_sample <= tone2 ^ tone3;
  end
endmodule

