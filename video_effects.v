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

module text_mode
#(parameter COLUMNS = 1,
  parameter ROWS = 1,
  parameter SCALE = 1)

 (input clk,
  input [11:0] pixel,
  input [11:0] line,
  input [11:0] pixel_offset,
  input [11:0] line_offset,
  input [7:0] text_offset,
  input we,
  input [12:0] waddr,
  input [7:0] din,
  output [1:0] q);

  wire [7:0] symbol;
  wire [11:0] tot_pixel;
  wire [11:0] tot_line;
  wire [7:0] cur_col;
  wire [7:0] cur_row;
  wire [7:0] text_addr;
  wire [14:0] font_addr;
  wire [14:0] run_addr;
  wire [1:0] font_bits;
  reg outside;

  assign tot_pixel = (pixel - pixel_offset)/SCALE;
  assign tot_line = (line - line_offset)/SCALE;
  assign cur_col = tot_pixel>>4;
  assign cur_row = tot_line>>4;
  assign text_addr = cur_row*COLUMNS + cur_col + text_offset;
  assign font_addr = ((symbol - 32)<<8) | (tot_line[3:0]<<4) | (tot_pixel[3:0]);
  assign run_addr = (we) ? waddr : {5'h17,text_addr};
  assign q = (outside) ? 2'b00 : font_bits;

  always @(posedge clk)
    outside <= (|(cur_row/ROWS) || |(cur_col/COLUMNS));


  textmodemem tm (
  .clk(clk),
  .addra(font_addr),
  .douta(font_bits),
  .we(we),
  .addrb(run_addr),
  .dinb(din),
  .doutb(symbol));
endmodule

module mixer
 (input [1:0] textq,
  input [7:0] backY,
  input [7:0] backCb,
  input [7:0] backCr,
  output [7:0] Y,
  output [7:0] Cb,
  output [7:0] Cr);

  assign Y = (textq == 0) ? backY : textq<<6;
  assign Cb = (textq == 0) ? backCb : 8'h80;
  assign Cr = (textq == 0) ? backCr : 8'h80;
endmodule

module multiply
 (input  clk,
  input [9:0] i1,
  input [9:0] i2,
  input [9:0] i3,
  input [9:0] i4,
  output [7:0] product);

  reg [17:0] t1;
  reg [17:0] t2;
  reg [17:0] t3;

  assign product = t3[17:10];

  always @(posedge clk)
  begin
    t1 <= i1*i2;
    t2 <= i3*i4;
    t3 <= t1[17:9]*t2[17:9];
  end
endmodule

module textmodemem
  (input clk,
   input [14:0] addra,
   output [1:0] douta,
   input we,
   input [12:0] addrb,
   input [7:0] dinb,
   output [7:0] doutb);

  reg prev_ena;
  reg prev_enb;

  wire [3:0] doutb0;
RAMB16BWE #(
.DATA_WIDTH_A(1), // Valid values are 1, 2, 4, 9, 18, or 36
.DATA_WIDTH_B(4), // Valid values are 1, 2, 4, 9, 18, or 36
.WRITE_MODE_A("WRITE_FIRST"),
.WRITE_MODE_B("WRITE_FIRST")
) mem0 (
.CLKA(clk),
.ENA(ena),
.WEA(0),
.ADDRA(addra[13:0]),
.DIA(0),
.DOA(douta0),
.SSRA(1'b0),
.CLKB(~clk),
.ENB(enb),
.WEB({4{we}}),
.ADDRB({addrb[11:0],2'h0}),
.DIB({dinb[7],dinb[5],dinb[3],dinb[1]}),
.DOB(doutb0),
.SSRB(1'b0)
);

wire [3:0] doutb1;
RAMB16BWE #(
.DATA_WIDTH_A(1), // Valid values are 1, 2, 4, 9, 18, or 36
.DATA_WIDTH_B(4), // Valid values are 1, 2, 4, 9, 18, or 36
.WRITE_MODE_A("WRITE_FIRST"),
.WRITE_MODE_B("WRITE_FIRST")
) mem1 (
.CLKA(clk),
.ENA(ena),
.WEA(4'h0),
.ADDRA(addra[13:0]),
.DIA(0),
.DOA(douta1),
.SSRA(1'b0),
.CLKB(~clk),
.ENB(enb),
.WEB({4{we}}),
.ADDRB({addrb[11:0],2'h0}),
.DIB({dinb[6],dinb[4],dinb[2],dinb[0]}),
.DOB(doutb1),
.SSRB(1'b0)
);

wire [1:0] douta2;
wire [7:0] doutb2;
RAMB16BWE #(
.DATA_WIDTH_A(2), // Valid values are 1, 2, 4, 9, 18, or 36
.DATA_WIDTH_B(9), // Valid values are 1, 2, 4, 9, 18, or 36
.WRITE_MODE_A("WRITE_FIRST"),
.WRITE_MODE_B("WRITE_FIRST")
) mem2 (
.CLKA(clk),
.ENA(~ena),
.WEA(4'h0),
.ADDRA({addra[12:0],1'h0}),
.DIA(0),
.DOA(douta2),
.SSRA(1'b0),
.CLKB(~clk),
.ENB(~enb),
.WEB({4{we}}),
.ADDRB({addrb[10:0],3'h0}),
.DIB(dinb),
.DOB(doutb2),
.DIPB(nc),
.DOPB(nc),
.SSRB(1'b0)
);

assign ena = ~addra[14];
assign douta = (prev_ena) ? {douta0,douta1} : douta2;

assign enb = ~addrb[12];
assign doutb = (prev_enb) ? {doutb0,doutb1} : doutb2;

always @(posedge clk)
  prev_ena <= ena;

always @(negedge clk)
  prev_enb <= enb;

endmodule
