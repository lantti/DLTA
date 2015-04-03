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
module dlta_demo (
  input  CLK,
//  input  SDA,
//  input  SCL,
  input  HPD_B,
//  input  CEC,
  output V_EN,
  output LEDPIX,
  output LEDBIT,
  output LEDALIVE,
  output LEDERROR,
//  output [1:0] A,
//  output [1:0] B,
  output CS_B,
  output W_B,
  output HOLD_B,
  output MOSI,
  output CCLK,
  input MISO,
  output [3:0] TMDS,
  output [3:0] TMDSB
);

  BUFG iclkbufg (.I(CLK), .O(input_clk));

  //DCM that generates pixel clock
  DCM_SP 
//    #(
//    .CLK_FEEDBACK ("NONE"),
//    .CLKFX_DIVIDE	(4),	
//    .CLKFX_MULTIPLY	(4))
  DCM_SP_PIXELCLK (
    .CLKIN(input_clk),
    .CLKFB(pixel_clk),
    .RST(1'b0),
    .CLK0(clkx1),
//    .CLKFX(clkx1),
    .LOCKED(lockedPix));

  BUFG pclkbufg (.I(clkx1), .O(pixel_clk));


  //DCM that generates 5x or 10x pixel clock
  DCM_SP #(
    .CLK_FEEDBACK ("NONE"),
    .CLKFX_DIVIDE	(1),	
    .CLKFX_MULTIPLY	(5))
  DCM_SP_BITCLK (
    .CLKIN(input_clk),
    .RST(1'b0),
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

  wire [15:0] audio_left;
  wire [15:0] audio_right;

  wire [9:0]  token0;
  wire [9:0]  token1;
  wire [9:0]  token2;

//  assign colour0 = 8'h80;
//  assign colour1 = 8'h80;
//  assign colour2 = 8'h80;
//  assign audio_left = 16'h0000;
//  assign audio_right = 16'h0000;


  hdmi_interface 
   #(.COLOUR_SCALING("NONE"))
  hdmi_front (
    .clk(pixel_clk),
    .channel0_pixel(colour0),
    .channel1_pixel(colour1),
    .channel2_pixel(colour2),
    .audio_sample_left(audio_left),
    .audio_sample_right(audio_right),
    .de(de),
    .pixel(abs_pixel),
    .line(abs_line),
    .line_end(line_end),
    .frame_end(frame_end),
    .audio_sample_strobe(audio_strobe),
    .channel0_token(token0),
    .channel1_token(token1),
    .channel2_token(token2));


  wire [3:0] control;

  sound_gen biibtsiki
   (.clk(pixel_clk),
    .sample_strobe(audio_strobe),
    .control(control),
    .left_sample(audio_left),
    .right_sample(audio_right));

  wire halt;
  video_controller vc
   (.clk(pixel_clk),
    .halt(halt),
    .pixel(abs_pixel),
    .line(abs_line),
    .line_end(line_end),
    .frame_end(frame_end),
    .reconf(load_trigger),
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

  reg [1:0] load_addr;

  always @(posedge pixel_clk)
  begin
    load_addr <= load_addr + load_trigger;
  end


//  assign LEDALIVE = HPD_B;
//  assign LEDPIX = load_trigger;
//  assign LEDBIT = load_addr[0];
  assign V_EN = 1'b1;

  assign LEDALIVE = control[0];
  assign LEDPIX = control[1];
  assign LEDBIT = control[2];
  assign LEDERROR = control[3];


  assign CCLK = ~pixel_clk;
  assign W_B = 1'b1;
  assign HOLD_B = 1'b1;


  wire [7:0] icap_d;

  icap_flash icfl (
    .clk(pixel_clk),
    .trigger(load_trigger),
    .addr({6'h00,load_addr,16'hE000}),
    .len(24'h002d36),
    .miso(MISO),
    .cs_b(CS_B),
    .mosi(MOSI),
    .running(halt),
    .icap_clk(icap_clk),
    .icap_d(icap_d));

 // assign LEDERROR = ~halt;

  ICAP_SPARTAN3A icap (
    .CLK(icap_clk),
    .CE(CS_B),
    .I(icap_d),
    .WRITE(1'b0));
endmodule
