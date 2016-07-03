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

//This is a top level used to bring together the various parts
//needed for the video generation. This code is mostly 
//Spartan-3A specific, but might work as is also in some other
//Xilinx devices
module demo_demo (
  input  CLK,
  input  SDA,
  input  SCL,
  input  HPD_B,
  input  CEC,
  output V_EN,
  output LEDPIX,
  output LEDBIT,
  output LEDALIVE,
  output LEDERROR,
  output [3:0] TMDS,
  output [3:0] TMDSB
);

  BUFG bufgentr (.I(CLK), .O(CLK_BUF));

  //DCM that generates Pixel clock

  DCM_SP #(
    .CLK_FEEDBACK ("NONE"),
    .CLKFX_DIVIDE (26),
    .CLKFX_MULTIPLY (11))
  DCM_SP_PIXELCLK (
    .CLKIN(CLK_BUF),
    .CLKFB(),
    .RST(1'b0),
    .PSEN(1'b0),
    .PSINCDEC(1'b0),
    .PSCLK(1'b0),
    .DSSEN(1'b0),
    .CLK0(),
    .CLK90(),
    .CLK180(),
    .CLK270(),
    .CLKDV(),
    .CLK2X(),
    .CLK2X180(),
    .CLKFX(CLK_PIX),
    .CLKFX180(),
    .STATUS(),
    .LOCKED(lockedPix),
    .PSDONE());
  
  BUFG pclkbufg (.I(CLK_PIX), .O(pixel_clk));
//  BUFG pclkbufg (.I(CLK_BUF), .O(pixel_clk));

//  wire lockedPix;
//  assign lockedPix = 1'b1;


  //DCM that generates 5x or 10x pixel clock
  DCM_SP #(
    .CLK_FEEDBACK ("NONE"),
    .CLKFX_DIVIDE	(1),	
    .CLKFX_MULTIPLY	(5))
  DCM_SP_BITCLK (
    .CLKIN(pixel_clk),
    .CLKFB(),
    .RST(1'b0),
    .PSEN(1'b0),
    .PSINCDEC(1'b0),
    .PSCLK(1'b0),
    .DSSEN(1'b0),
    .CLKFX(clkx5p),
    .CLKFX180(clkx5n),
    .LOCKED(lockedBit));

  BUFG bclkbufgp (.I(clkx5p), .O(bit_clk));
  BUFG bclkbufgn (.I(clkx5n), .O(bit_clk_inv));

  wire [11:0] abs_pixel;
  wire [11:0] abs_line;

  wire [7:0] colour0;
  wire [7:0] colour1;
  wire [7:0] colour2;

  wire [9:0]  token0;
  wire [9:0]  token1;
  wire [9:0]  token2;


  hdmi_interface 
   #(.VIDEO_MODE("720p"),
     .COLOUR_SCALING("LIMITED_RGB"))
  hdmi_front (
    .clk(pixel_clk),
    .channel0_pixel(colour0),
    .channel1_pixel(colour1),
    .channel2_pixel(colour2),
    .audio_sample_left(16'h0000),
    .audio_sample_right(16'h0000),
    .dvi(1'b1),
    .de(de),
    .pixel(abs_pixel),
    .line(abs_line),
    .line_end(line_end),
    .frame_end(frame_end),
    .audio_sample_strobe(),
    .channel0_token(token0),
    .channel1_token(token1),
    .channel2_token(token2));


  video_controller vc
   (.clk(pixel_clk),
    .pixel(abs_pixel),
    .line(abs_line),
    .line_end(line_end),
    .frame_end(frame_end),
    .Cb(colour0),
    .Y(colour1),
    .Cr(colour2));


  wire [2:0] tmds_data_even;
  wire [2:0] tmds_data_odd;
  wire [3:0] TMDSINT;

//Use the true ddr serializer
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


/*
//Use the dual serializer with delaying ddr buffers
  tmds_dual_serializer serialise (
    .clk(pixel_clk),
    .clkx5(bit_clk),
    .rst(~lockedBit),
    .chan0_token (token0),
    .chan1_token (token1),
    .chan2_token (token2),
    .tmds_even (tmds_data_even),
    .tmds_odd (tmds_data_odd));

  ODDR2 #(.DDR_ALIGNMENT("C0")) ddr_reg0 (
    .C0(bit_clk),
    .C1(~bit_clk),
    .D0(tmds_data_even[0]),
    .D1(tmds_data_odd[0]),
    .Q(TMDSINT[0]));

  ODDR2 #(.DDR_ALIGNMENT("C0")) ddr_reg1 (
    .C0(bit_clk),
    .C1(~bit_clk),
    .D0(tmds_data_even[1]),
    .D1(tmds_data_odd[1]),
    .Q(TMDSINT[1]));

  ODDR2 #(.DDR_ALIGNMENT("C0")) ddr_reg2 (
    .C0(bit_clk),
    .C1(~bit_clk),
    .D0(tmds_data_even[2]),
    .D1(tmds_data_odd[2]),
    .Q(TMDSINT[2]));
*/

/*
//Use the simple serializer
  tmds_serializer serialise (
    .clk(pixel_clk),
    .clkx10(bit_clk),
    .rst(~lockedBit),
    .chan0_token (token0),
    .chan1_token (token1),
    .chan2_token (token2),
    .tmds_stream (TMDSINT[2:0]));
*/

//Mirror the pixel clock directly from the DCM into the
//corresponding TMDS line. This is kind of a lazy approach
//but in practise seems to be completely adequate as there
//are no phasing requirements between the pixel clock to
//the bitstreams in the TMDS specifications.
  ODDR2 #(.DDR_ALIGNMENT("NONE")) ddr_reg3 (
    .C0(pixel_clk),
    .C1(~pixel_clk),
    .D0(1'b1),
    .D1(1'b0),
    .Q(TMDSINT[3]));

  OBUFDS TMDS0 (.I(TMDSINT[0]), .O(TMDS[0]), .OB(TMDSB[0])) ;
  OBUFDS TMDS1 (.I(TMDSINT[1]), .O(TMDS[1]), .OB(TMDSB[1])) ;
  OBUFDS TMDS2 (.I(TMDSINT[2]), .O(TMDS[2]), .OB(TMDSB[2])) ;
  OBUFDS TMDS3 (.I(TMDSINT[3]), .O(TMDS[3]), .OB(TMDSB[3])) ;

  assign LEDALIVE = HPD_B;
  assign LEDPIX = ~lockedPix;
  assign LEDBIT = ~lockedBit;
  assign LEDERROR = 1'b1;
  assign V_EN = 1'b1;
endmodule
