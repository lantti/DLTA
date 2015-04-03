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
  input [23:0] addr,
  input [23:0] len,
  input miso,
  output cs_b,
  output mosi,
  output icap_clk,
  output reg running,
  output reg [7:0] icap_d);

  reg [31:0] read_cmd = 32'h0B000000;
  reg [23:0] len_count;
  reg [7:0] icap_clk_gen = 8'b11110000;
  reg [7:0] d;
  reg cs = 0;
//  reg running = 0;

  assign mosi = read_cmd[31];
  assign cs_b = ~cs;
  assign icap_clk = icap_clk_gen[7];
  assign sync = ~icap_clk_gen[0] & icap_clk_gen[1];
  assign byte_boundary = ~icap_clk_gen[7] & icap_clk_gen[0];
  assign stop = ~|len_count;

  always @(posedge clk)
  begin
    running <= ((running && !stop) || trigger);
    read_cmd <= (trigger) ? {8'h0B,addr} : read_cmd;
    len_count <= (trigger) ? len : (byte_boundary) ? len_count - 1 : len_count;
    d <= {miso, d[7:1]};
    icap_clk_gen <= {icap_clk_gen[0], icap_clk_gen[7:1]};
    cs <= (!stop && (cs || (running && sync))); 
    if (cs)
      read_cmd <= {read_cmd[30:0],1'b0};  
    if (byte_boundary)
      icap_d <= d;
  end
endmodule

