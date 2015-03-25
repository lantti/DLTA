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

module icap_flash (
  input clk,
  input trigger,
  input miso,
  output cs_b,
  output mosi,
  output icap_clk,
  output reg [7:0] icap_d,
  output s0,
  output s1);

  reg [31:0] read_cmd = 32'h0B00E000;
  reg [7:0] icap_clk_gen = 8'b11110000;
  reg [7:0] d;
  reg cs = 0;
  reg int_trig = 0;

  reg check0;
  reg check1;

  assign mosi = read_cmd[31];
  assign cs_b = ~cs;


  assign icap_clk = icap_clk_gen[7];
  assign sync = ~icap_clk_gen[0] & icap_clk_gen[1];
  assign byte_boundary = ~icap_clk_gen[7] & icap_clk_gen[0];


  assign s0 = d[7];
  assign s1 = byte_boundary;

  always @(posedge clk)
  begin
    int_trig <= int_trig | trigger;
    d <= {miso, d[7:1]};
    icap_clk_gen <= {icap_clk_gen[0], icap_clk_gen[7:1]};
    cs <= cs | (int_trig & sync); 
    if (cs)
      read_cmd <= {read_cmd[30:0],1'b0};  
    if (byte_boundary)
      icap_d <= d;
  end

//      check0 <= (icap_d == 8'b01010101);
//      check1 <= check0 & (icap_d == 8'b10011001);

endmodule

