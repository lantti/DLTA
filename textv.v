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

module textv (
  input  CLK,
  output LED1,
  output LED2,
  output LED3,
  output LED4,
  output V_EN,
  input [1:0] A,
  input [1:0] B,
  output CS_B,
  output W_B,
  output HOLD_B,
  output MOSI,
  output CCLK,
  input MISO,
  output [3:0] TMDS,
  output [3:0] TMDSB
);

  IBUFG iclkbufg (.I(CLK), .O(input_clk));

  //DCM that generates pixel clocks and bit clocks
  DCM_SP #(
    .CLK_FEEDBACK ("1X"),
    .CLKFX_DIVIDE	(1),	
    .CLKFX_MULTIPLY	(5))
  DCM_SP_BITCLK (
    .CLKIN(input_clk),
    .CLKFB(clkx1p),
    .RST(1'b0),
    .CLK0(clkx1p),
    .CLK180(clkx1n),
    .CLKFX(clkx5p),
    .CLKFX180(clkx5n),
    .LOCKED());


  BUFG bclkbufgp (.I(clkx5p), .O(bit_clk));
  BUFG bclkbufgn (.I(clkx5n), .O(bit_clk_inv));

  BUFG pclkpbufg (.I(clkx1p), .O(pixel_clk));
  BUFG pclknbufg (.I(clkx1n), .O(pixel_clk_inv));


  wire [11:0] abs_pixel;
  wire [11:0] abs_line;

  wire [7:0] Y_G;
  wire [7:0] Cb_B;
  wire [7:0] Cr_R;

  wire [9:0]  token0;
  wire [9:0]  token1;
  wire [9:0]  token2;



  hdmi_interface 
   #(.VIDEO_MODE("720p_reduced"),
     .COLOUR_SCALING("NONE"))
  hdmi_front (
    .clk(pixel_clk),
    .channel0_pixel(Cb_B),
    .channel1_pixel(Y_G),
    .channel2_pixel(Cr_R),
    .audio_sample_left(16'h0000),
    .audio_sample_right(16'h0000),
    .dvi(1'b1),
    .de(),
    .pixel(abs_pixel),
    .line(abs_line),
    .line_end(),
    .frame_end(fr_end),
    .audio_sample_strobe(),
    .channel0_token(token0),
    .channel1_token(token1),
    .channel2_token(token2));

  reg [13:0] frame;
  wire [5:0] px_off;
  wire [7:0] tx_off;

  assign px_off = ~frame[5:0];
  assign tx_off = frame[13:6];

  always @(posedge pixel_clk)
    frame <= frame + fr_end;

  wire [1:0] textq;
  wire [12:0] waddr;
  wire [7:0] wdat;

  text_mode 
   #(.COLUMNS(32),
     .ROWS(8),
     .SCALE(2))
  tm
 (.clk(pixel_clk),
  .pixel(abs_pixel),
  .line(abs_line),
  .pixel_offset(12'h0D0),//px_off),
  .line_offset(12'h090),
  .text_offset(8'h00),//tx_off),
  .we(dstrobe),
  .waddr(waddr),
  .din(wdat),
  .q(textq));

  wire [23:0] raddr;
  wire [12:0] rlen;
  wire load_src;
  reg [15:0] load_src_delay;

  assign raddr = (load_src) ? {4'h0,A[0],B[0],2'h2,16'h1700} : {4'h0,A[0],B[0],2'h1,16'h0000};
  assign rlen = (load_src) ? 13'h0100 : 13'h1700;
  assign load_src = |load_src_delay[15:8];

  always @(posedge pixel_clk)
    if (fr_end)
    begin
      load_src_delay[15:1] <= load_src_delay[14:0];
      load_src_delay[0] <= A[1];
    end

  wire CS_B_mem;
  wire MOSI_mem;
  wire CCLK_mem;

  wire flash_pwn;

flash_read fr (
  .clk(pixel_clk),
  .trigger(fr_end & ~flash_pwn),
  .addrin(raddr),
  .length(rlen),
  .miso(MISO),
  .dstrobe(dstrobe),
  .addrout(waddr),
  .dout(wdat),
  .cclk(CCLK_mem),
  .cs_b(CS_B_mem),
  .mosi(MOSI_mem)
);


  wire [7:0] backY;

  multiply mul
   (.clk(pixel_clk),
    .i1((abs_pixel- 20)>>1),
    .i2((abs_line + 50)>>2),
    .i3(abs_pixel- 20),
    .i4(abs_line + 50),
    .product(backY));

  mixer mmm
 (.textq(textq),
  .backY(backY),
  .backCb(8'hB0),
  .backCr(8'h50),
  .Y(Y_G),
  .Cb(Cb_B),
  .Cr(Cr_R));


  reg [31:0] hello;
  wire [3:0] sector;

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
  .TDO1(MISO),
  .TDO2(hello[31])
  );

  wire CS_B_jtag;
  wire MOSI_jtag;
  wire CCLK_jtag;


  assign CS_B_jtag = ~(user1_select & jtag_shift);
  assign MOSI_jtag = jtag_in;
  assign CCLK_jtag = jtag_clk;

  assign flash_pwn = user1_select | user2_select;
  assign sector = {A[0],B[0],2'h3};

  always @(posedge jtag_clk)
    if (jtag_shift)
      hello <= {hello[30:0],hello[31]};
    else
      hello <= {24'hC0FFEE,sector,4'h3};



  wire [2:0] tmds_data_even;
  wire [2:0] tmds_data_odd;
  wire [3:0] TMDSINT;

  tmds_ddr_serializer serialise (
    .clkx5(bit_clk),
    .clkx5n(bit_clk_inv),
    .chan0_token (~token0),
    .chan1_token (~token1),
    .chan2_token (~token2),
    .tmds_ddr_p (tmds_data_even),
    .tmds_ddr_n (tmds_data_odd));

  ODDR2 #(.DDR_ALIGNMENT("NONE")) ddr_reg0 (
    .C0(bit_clk),
    .C1(bit_clk_inv),
    .D0(tmds_data_even[0]),
    .D1(tmds_data_odd[0]),
    .Q(TMDSINT[0]));

  ODDR2 #(.DDR_ALIGNMENT("NONE")) ddr_reg1 (
    .C0(bit_clk),
    .C1(bit_clk_inv),
    .D0(tmds_data_even[1]),
    .D1(tmds_data_odd[1]),
    .Q(TMDSINT[1]));

  ODDR2 #(.DDR_ALIGNMENT("NONE")) ddr_reg2 (
    .C0(bit_clk),
    .C1(bit_clk_inv),
    .D0(tmds_data_even[2]),
    .D1(tmds_data_odd[2]),
    .Q(TMDSINT[2]));



//Mirror the pixel clock directly from the DCM into the
//corresponding TMDS line. This is kind of a lazy approach
//but in practise seems to be completely adequate as there
//are no phasing requirements between the pixel clock to
//the bitstreams in the TMDS specifications.
  ODDR2 #(.DDR_ALIGNMENT("NONE")) ddr_reg3 (
    .C0(pixel_clk),
    .C1(pixel_clk_inv),
    .D0(1'b1),
    .D1(1'b0),
    .Q(TMDSINT[3]));

  OBUFDS TMDS0 (.I(TMDSINT[0]), .O(TMDS[0]), .OB(TMDSB[0])) ;
  OBUFDS TMDS1 (.I(TMDSINT[1]), .O(TMDS[1]), .OB(TMDSB[1])) ;
  OBUFDS TMDS2 (.I(TMDSINT[2]), .O(TMDS[2]), .OB(TMDSB[2])) ;
  OBUFDS TMDS3 (.I(TMDSINT[3]), .O(TMDS[3]), .OB(TMDSB[3])) ;


  assign CS_B = (flash_pwn) ? CS_B_jtag : CS_B_mem;
  assign MOSI = (flash_pwn) ? MOSI_jtag : MOSI_mem;
  assign CCLK = (flash_pwn) ? CCLK_jtag : CCLK_mem;

  assign W_B = 1'b1;
  assign HOLD_B = 1'b1;
  assign V_EN = 1'b1;
  assign LED1 = 1'b1;
  assign LED2 = 1'b1;
  assign LED3 = 1'b1;
  assign LED4 = 1'b1;
endmodule

module flash_read (
  input clk,
  input trigger,
  input [23:0] addrin,
  input [12:0] length,
  input miso,
  output reg dstrobe,
  output reg [12:0] addrout,
  output reg [7:0] dout,
  output cclk,
  output cs_b,
  output mosi
);

  reg [28:0] op_cnt = 29'hFFFFFFFF;
  reg [31:0] flash_cmd;
  reg [6:0] cmd_cnt = 7'hFF;
  reg [2:0] byte_cnt = 3'b111;
  reg trig_int;

  assign cclk  = ~clk;
  assign mosi = flash_cmd[31];
  assign cs_b = op_cnt[28] | trig_int;


  always @(posedge clk)
  begin
    trig_int <= trigger;
    if (trig_int)
    begin
      flash_cmd <= {8'h0B,addrin};
      op_cnt <= (length<<3) + 7'd40;
      addrout <= addrin[12:0];
      byte_cnt <= 3'b000;
      cmd_cnt <= 7'd40;
      dstrobe <= 1'b0;
      dout <= 8'h00;
    end
    else
    begin
      flash_cmd <= {flash_cmd[30:0],1'b0};
      op_cnt <= (op_cnt[28]) ? op_cnt : op_cnt - 1;
      addrout <= addrout + dstrobe;
      byte_cnt <= byte_cnt + 1;
      cmd_cnt <= (cmd_cnt[6]) ? cmd_cnt : cmd_cnt - 1;
      dstrobe <= (cmd_cnt[6] && !op_cnt[28]) ? &byte_cnt : 1'b0;
      dout <= {dout[6:0],miso};
    end
  end
endmodule
