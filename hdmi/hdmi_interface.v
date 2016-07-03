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

module hdmi_interface
#(parameter VIDEO_MODE = "STANDARD_VGA",
  parameter COLOUR_SCALING = "NONE")

 (input clk,
  input [7:0] channel0_pixel,
  input [7:0] channel1_pixel,
  input [7:0] channel2_pixel,
  input [15:0] audio_sample_left,
  input [15:0] audio_sample_right,
  input dvi,
  output de,
  output [11:0] pixel,
  output [11:0] line,
  output line_end,
  output frame_end,
  output audio_sample_strobe,
  output [9:0] channel0_token,
  output [9:0] channel1_token,
  output [9:0] channel2_token);

  reg [1:0] channel0_mode;
  reg [1:0] channel1_mode;
  reg [1:0] channel2_mode;
  reg [1:0] channel1_ctrl;
  reg [1:0] channel2_ctrl;
  reg channel2_guard;

  reg vsync_reg;
  reg hsync_reg;

  reg [7:0] channel0_pixel_scaled;
  reg [7:0] channel1_pixel_scaled;
  reg [7:0] channel2_pixel_scaled;

  reg [3:0] channel0_aux_delayed;
  reg [3:0] channel1_aux_delayed;
  reg [3:0] channel2_aux_delayed;

  reg vsync_delayed;
  reg hsync_delayed;

  reg [2:0] hdmi_mode_delayed;

  wire [2:0] hdmi_mode;
  wire [9:0] aux_slot;

  wire [3:0] channel0_aux;
  wire [3:0] channel1_aux;
  wire [3:0] channel2_aux;

  hdmi_sequencer #(.VIDEO_MODE(VIDEO_MODE)) 
  vtimer (
    .clk(clk),
    .aux_request(aux_request),
    .aux_enable(ae),
    .display_enable(de),
    .line_end(line_end),
    .frame_end(frame_end),
    .aux_packet_end(aux_packet_end),
    .hsync(hsync),
    .vsync(vsync),
    .pixel(pixel),
    .line(line),
    .aux_slot(aux_slot),
    .opmode(hdmi_mode));

  wire [1:0] avi_info_sub0;
  wire [1:0] avi_info_sub1;  
  wire [1:0] avi_info_sub2;
  wire [1:0] avi_info_sub3;
  fixed_aux_packet 
  #(.HEADER(32'h00_0D_02_82),
    .SP0(64'h00_00_00_04_80_08_40_A3),
    .SP1(64'h00_00_00_00_00_00_00_00),
    .SP2(64'h00_00_00_00_00_00_00_00),
    .SP3(64'h00_00_00_00_00_00_00_00))
  avi_infoframe
   (.clk(clk),
    .trigger(frame_end),
    .enable(avi_info_enable),
    .ae(ae),
    .slot(aux_slot[4:0]),
    .ready(avi_info_ready),
    .header(avi_info_header),
    .sub0(avi_info_sub0[1:0]),
    .sub1(avi_info_sub1[1:0]),
    .sub2(avi_info_sub2[1:0]),
    .sub3(avi_info_sub3[1:0]));


  wire [1:0] audio_info_sub0;
  wire [1:0] audio_info_sub1;
  wire [1:0] audio_info_sub2;
  wire [1:0] audio_info_sub3;
  fixed_aux_packet 
  #(.HEADER(32'h00_0A_01_84),
    .SP0(64'h00_00_00_00_00_00_01_70),
    .SP1(64'h00_00_00_00_00_00_00_00),
    .SP2(64'h00_00_00_00_00_00_00_00),
    .SP3(64'h00_00_00_00_00_00_00_00))
  audio_infoframe
   (.clk(clk),
    .trigger(frame_end),
    .enable(audio_info_enable),
    .ae(ae),
    .slot(aux_slot[4:0]),
    .ready(audio_info_ready),
    .header(audio_info_header),
    .sub0(audio_info_sub0[1:0]),
    .sub1(audio_info_sub1[1:0]),
    .sub2(audio_info_sub2[1:0]),
    .sub3(audio_info_sub3[1:0]));


  wire audio_clk_regen_enable;
  wire audio_clk_regen_ready;
  wire audio_clk_regen_header;
  wire [1:0] audio_clk_regen_sub0;
  wire [1:0] audio_clk_regen_sub1;
  wire [1:0] audio_clk_regen_sub2;
  wire [1:0] audio_clk_regen_sub3;

  wire audio_sample_enable;
  wire audio_sample_ready;
  wire audio_sample_header;
  wire [1:0] audio_sample_sub0;
  wire [1:0] audio_sample_sub1;
  wire [1:0] audio_sample_sub2;
  wire [1:0] audio_sample_sub3;

  hdmi_audio audio_pack
   (.clk(clk),
    .ae(ae),
    .aux_slot(aux_slot[4:0]),

    .audio_sample_left(audio_sample_left),
    .audio_sample_right(audio_sample_right),
    .sample_strobe(audio_sample_strobe),

    .regen_enable(audio_clk_regen_enable),
    .regen_ready(audio_clk_regen_ready),
    .regen_header(audio_clk_regen_header),
    .regen_sub0(audio_clk_regen_sub0[1:0]),
    .regen_sub1(audio_clk_regen_sub1[1:0]),
    .regen_sub2(audio_clk_regen_sub2[1:0]),
    .regen_sub3(audio_clk_regen_sub3[1:0]),

    .sample_enable(audio_sample_enable),
    .sample_ready(audio_sample_ready),
    .sample_header(audio_sample_header),
    .sample_sub0(audio_sample_sub0[1:0]),
    .sample_sub1(audio_sample_sub1[1:0]),
    .sample_sub2(audio_sample_sub2[1:0]),
    .sample_sub3(audio_sample_sub3[1:0]));


  hdmi_aux_packer auxmux (
    .clk(clk),
    .ae(ae),
    .hsync(hsync),
    .vsync(vsync),
    .packet_end(aux_packet_end),
    .slot(aux_slot[4:0]),
    .aux_request(aux_request),
    .channel0_aux(channel0_aux),
    .channel1_aux(channel1_aux),
    .channel2_aux(channel2_aux),

    .ready_a(audio_sample_ready),
    .header_a(audio_sample_header),
    .sub0_a(audio_sample_sub0[1:0]),
    .sub1_a(audio_sample_sub1[1:0]),
    .sub2_a(audio_sample_sub2[1:0]),
    .sub3_a(audio_sample_sub3[1:0]),
    .enable_a(audio_sample_enable),

    .ready_b(audio_clk_regen_ready),
    .header_b(audio_clk_regen_header),
    .sub0_b(audio_clk_regen_sub0[1:0]),
    .sub1_b(audio_clk_regen_sub1[1:0]),
    .sub2_b(audio_clk_regen_sub2[1:0]),
    .sub3_b(audio_clk_regen_sub3[1:0]),
    .enable_b(audio_clk_regen_enable),

    .ready_c(avi_info_ready),
    .header_c(avi_info_header),
    .sub0_c(avi_info_sub0[1:0]),
    .sub1_c(avi_info_sub1[1:0]),
    .sub2_c(avi_info_sub2[1:0]),
    .sub3_c(avi_info_sub3[1:0]),
    .enable_c(avi_info_enable),

    .ready_d(audio_info_ready),
    .header_d(audio_info_header),
    .sub0_d(audio_info_sub0[1:0]),
    .sub1_d(audio_info_sub1[1:0]),
    .sub2_d(audio_info_sub2[1:0]),
    .sub3_d(audio_info_sub3[1:0]),
    .enable_d(audio_info_enable));


  always @(posedge clk)
  begin
    vsync_reg <= vsync;
    hsync_reg <= hsync;

    channel0_aux_delayed <= channel0_aux;
    channel1_aux_delayed <= channel1_aux;
    channel2_aux_delayed <= channel2_aux;
    vsync_delayed <= vsync_reg;
    hsync_delayed <= hsync_reg;
    hdmi_mode_delayed <= hdmi_mode;

    case ({hdmi_mode_delayed,dvi})
      4'b1110: //111-Video preamble
      begin
        channel0_mode <= 2'b10; 
        channel1_mode <= 2'b10;
        channel2_mode <= 2'b10;
        channel1_ctrl <= 2'b01;
        channel2_ctrl <= 2'b00;
        channel2_guard <= 1'b0;
      end
      4'b1100: //110-Video guard
      begin
        channel0_mode <= 2'b00;
        channel1_mode <= 2'b00;
        channel2_mode <= 2'b00;
        channel1_ctrl <= 2'b00;
        channel2_ctrl <= 2'b00;
        channel2_guard <= 1'b1;
      end
      4'b1010: //101-Aux preamble
      begin
        channel0_mode <= 2'b10;
        channel1_mode <= 2'b10;
        channel2_mode <= 2'b10;
        channel1_ctrl <= 2'b01;
        channel2_ctrl <= 2'b01;
        channel2_guard <= 1'b0;
      end
      4'b1000: //100-Aux guard
      begin
        channel0_mode <= 2'b01;
        channel1_mode <= 2'b00;
        channel2_mode <= 2'b00;
        channel1_ctrl <= 2'b00;
        channel2_ctrl <= 2'b00;
        channel2_guard <= 1'b0;
      end
      4'b0110, 4'b0111: //011-Video data
      begin
        channel0_mode <= 2'b11;
        channel1_mode <= 2'b11;
        channel2_mode <= 2'b11;
        channel1_ctrl <= 2'b00;
        channel2_ctrl <= 2'b00;
        channel2_guard <= 1'b0;
      end
      4'b0010: //001-Aux data
      begin
        channel0_mode <= 2'b01;
        channel1_mode <= 2'b01;
        channel2_mode <= 2'b01;
        channel1_ctrl <= 2'b00;
        channel2_ctrl <= 2'b00;
        channel2_guard <= 1'b0;
      end
      default: //000-Control
      begin
        channel0_mode <= 2'b10;
        channel1_mode <= 2'b10;
        channel2_mode <= 2'b10;
        channel1_ctrl <= 2'b00;
        channel2_ctrl <= 2'b00;
        channel2_guard <= 1'b0;
      end
    endcase

    case (COLOUR_SCALING)
      "LIMITED_RGB" : 
      begin
        channel0_pixel_scaled <= 16 + (channel0_pixel>>1) + (channel0_pixel>>2) + (channel0_pixel>>3);
        channel1_pixel_scaled <= 16 + (channel1_pixel>>1) + (channel1_pixel>>2) + (channel1_pixel>>3);
        channel2_pixel_scaled <= 16 + (channel2_pixel>>1) + (channel2_pixel>>2) + (channel2_pixel>>3);
      end
      "YCbCr" :
      begin
        channel0_pixel_scaled <= 16 + (channel0_pixel>>1) + (channel0_pixel>>2) + (channel0_pixel>>3) + (channel0_pixel>>4);
        channel1_pixel_scaled <= 16 + (channel1_pixel>>1) + (channel1_pixel>>2) + (channel1_pixel>>3);
        channel2_pixel_scaled <= 16 + (channel2_pixel>>1) + (channel2_pixel>>2) + (channel2_pixel>>3) + (channel2_pixel>>4);
      end
      default :
      begin
        channel0_pixel_scaled <= channel0_pixel;
        channel1_pixel_scaled <= channel1_pixel;
        channel2_pixel_scaled <= channel2_pixel;
      end
    endcase
  end

  tmds_encoder 
   #(.TWO_STEPS("TRUE"))
  enc0
   (.clk(clk),
    .pixel(channel0_pixel_scaled),
    .aux(channel0_aux_delayed),
    .ctrl({vsync_delayed,hsync_delayed}),
    .guard(1'b1),
    .mode(channel0_mode),
    .tmds_token(channel0_token));

  tmds_encoder 
   #(.TWO_STEPS("TRUE"))
  enc1
   (.clk(clk),
    .pixel(channel1_pixel_scaled),
    .aux(channel1_aux_delayed),
    .ctrl(channel1_ctrl),
    .guard(1'b0),
    .mode(channel1_mode),
    .tmds_token(channel1_token));
	
  tmds_encoder 
   #(.TWO_STEPS("TRUE"))
  enc2
   (.clk(clk),
    .pixel(channel2_pixel_scaled),
    .aux(channel2_aux_delayed),
    .ctrl(channel2_ctrl),
    .guard(channel2_guard),
    .mode(channel2_mode),
    .tmds_token(channel2_token));
endmodule

