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

module dlta_bootloader (
  input  CLK,
  output LED1,
  output LED2,
  output LED3,
  output LED4,
  input A,
  input B,
  output CS_B,
  output W_B,
  output HOLD_B,
  output MOSI,
  output CCLK,
  input MISO
);

  IBUFG iclkbufg (.I(CLK), .O(clock));

  BSCAN_SPARTAN3A BSCAN_SPARTAN3A_inst (
  .CAPTURE(),
  .DRCK1(),
  .DRCK2(),
  .RESET(),
  .SEL1(user1_select),
  .SEL2(user2_select),
  .SHIFT(jtag_shift),
  .TCK(jtag_clk),
  .TDI(jtag_in),
  .TMS(),
  .UPDATE(),
  .TDO1(user1_out),
  .TDO2(user2_out)
  );

  reg [28:0] wait_count = 0;
  wire wait_step;
  reg [31:0] hello;

  reg [7:0] d;
  wire [7:0] d_swap;
  wire [3:0] sector;
  wire [4:0] addr;

  assign CS_B = ~(user1_select & jtag_shift);
  assign W_B = 1'b1;
  assign HOLD_B = 1'b1;
  assign MOSI = jtag_in;
  assign user1_out = MISO;
  assign CCLK = jtag_clk;

  assign LED1 = wait_step;
  assign LED2 = ~wait_count[27];
  assign LED3 = ~wait_count[25];
  assign LED4 = ~jtag_clk;

  assign user2_out = hello[31];

  assign wait_step = ~(user1_select | user2_select);

  always @(posedge clock)
    if (wait_step)
      wait_count <= wait_count + 1;
    else 
      wait_count <= 0;

  always @(posedge jtag_clk)
    if (jtag_shift)
      hello <= {hello[30:0],hello[31]};
    else
      hello <= {24'hC0FFEE,sector,4'h2};


  ICAP_SPARTAN3A icap (
    .CLK(~clock),
    .CE(icap_enable),
    .I(d_swap),
    .WRITE(1'b0));

  assign d_swap = (addr == 5'h0F) ? {sector[0],sector[1],sector[2],sector[3],4'h0} : {d[0],d[1],d[2],d[3],d[4],d[5],d[6],d[7]};
  assign icap_enable = ~(wait_count[28] & wait_count[5]);
  assign sector = {A,B,2'h3};
  assign addr = wait_count[4:0];

  always @(*)
    case (addr)
	   5'h00: d = 8'hFF;
	   5'h01: d = 8'hFF;
	   5'h02: d = 8'hFF;
	   5'h03: d = 8'hFF;
	   5'h04: d = 8'hFF;
	   5'h05: d = 8'hFF;
	   5'h06: d = 8'hAA;
	   5'h07: d = 8'h99;
	   5'h08: d = 8'h32;
	   5'h09: d = 8'h61;
	   5'h0A: d = 8'h00;
	   5'h0B: d = 8'h00;
	   5'h0C: d = 8'h32;
	   5'h0D: d = 8'h81;
	   5'h0E: d = 8'h00;
	   5'h0F: d = 8'h00;
	   5'h10: d = 8'h32;
	   5'h11: d = 8'hA1;
	   5'h12: d = 8'h00;
	   5'h13: d = 8'h0F;
	   5'h14: d = 8'h30;
	   5'h15: d = 8'hA1;
	   5'h16: d = 8'h00;
	   5'h17: d = 8'h0E;
	   5'h18: d = 8'h20;
	   5'h19: d = 8'h00;
	   5'h1A: d = 8'h20;
	   5'h1B: d = 8'h00;
	   5'h1C: d = 8'h20;
	   5'h1D: d = 8'h00;
	   5'h1E: d = 8'hFF;
	   5'h1F: d = 8'hFF;
    endcase
endmodule
