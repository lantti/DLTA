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

  BUFG bufgentr (.I(CLK), .O(CLK_12M));

  //DCM that generates Pixel clock
  //Some typical pixel clock settings:
  //(assuming input clock 12MHz)
  //720p 74.4Mhz - MUL 31, DIV 5
  //720p_reduced 64MHz - MUL 16, DIV 3
  //1080p_24 63MHz - MUL 21, DIV 4
  //XGA 65MHz - MUL 27, DIV 5
  //SVGA 50MHz - MUL 25, DIV 6
  //STANDARD VGA 25MHz - MUL 25, DIV 12
/*
  DCM_SP #(
    .CLK_FEEDBACK ("NONE"),
    .CLKFX_DIVIDE (13),
    .CLKFX_MULTIPLY (5))
  DCM_SP_PIXELCLK (
    .CLKIN(CLK_12M),
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
*/
  wire lockedPix;
  assign lockedPix = 1'b1;
  BUFG pclkbufg (.I(CLK_12M), .O(pixel_clk));

  reg [3:0] reset_delay = 4'b1111;
  wire reset;
  assign reset = reset_delay[0];
  always @(posedge pixel_clk)
    if (~lockedPix)
      reset_delay <= 4'b1111;
    else
    begin
      reset_delay[3] <= 1'b0;
      reset_delay[2] <= reset_delay[3];
      reset_delay[1] <= reset_delay[2];
      reset_delay[0] <= reset_delay[1];
    end

  //DCM that generates 5x or 10x pixel clock
  DCM_SP #(
    .CLK_FEEDBACK ("NONE"),
    .CLKFX_DIVIDE	(1),	
    .CLKFX_MULTIPLY	(5))
  DCM_SP_BITCLK (
    .CLKIN(pixel_clk),
    .RST(reset),
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

  wire [15:0] audio_left;
  wire [15:0] audio_right;

  wire [9:0]  token0;
  wire [9:0]  token1;
  wire [9:0]  token2;


  hdmi_interface 
   #(.COLOUR_SCALING("NONE"))
  hdmi_front (
    .clk(pixel_clk),
    .reset(reset), 
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


/*
  wire command_strobe;
  wire [17:0] command;
  script scrpt
   (.clk(pixel_clk),
    .line_end(line_end),
    .command_strobe(command_strobe),
    .command(command));
*/

  sound_gen biibtsiki
   (.clk(pixel_clk),
    .sample_strobe(audio_strobe),
    .left_sample(audio_left),
    .right_sample(audio_right));


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
    .clk (pixel_clk),
    .clkx5p(bit_clk),
    .clkx5n(bit_clk_inv),
    .chan0_token (~token0),
    .chan1_token (~token1),
    .chan2_token (~token2),
    .rst (~lockedBit),
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

module script
 (input  clk,
  input line_end,
  output reg command_strobe,
  output [17:0] command);

  reg [15:0] lines;

(* rom_style = "block" *)
  reg [35:0] script_mem [511:0];
  reg [35:0] script_raw;
  reg [8:0] script_addr;

  assign command = script_raw[35:15];

  initial
    $readmemb("script.txt",script_mem);

  always @(posedge clk)
  begin
    script_raw <= script_mem[script_addr];
    if (line_end)
    begin
      if (|lines)
      begin
        lines <= lines - 1;
        command_strobe <= 1'b0;
        script_addr <= script_addr;
      end
      else
      begin
        lines <= script_raw[15:0];
        command_strobe <= 1'b1;
        script_addr <= script_addr + 1;
      end
    end
    else
    begin
        lines <= lines;
        command_strobe <= 1'b0;
        script_addr <= script_addr;
    end
  end

endmodule
