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


module hdmi_sequencer
#(parameter VIDEO_MODE = "STANDARD_VGA",
  parameter CUSTOM_H_VISIBLE       = 0,
  parameter CUSTOM_H_FRONT_PORCH   = 0,
  parameter CUSTOM_H_SYNC          = 0,
  parameter CUSTOM_H_BACK_PORCH    = 0,
  parameter CUSTOM_H_SYNC_POLARITY = 0,
  parameter CUSTOM_V_VISIBLE       = 0,
  parameter CUSTOM_V_FRONT_PORCH   = 0,
  parameter CUSTOM_V_SYNC          = 0,
  parameter CUSTOM_V_BACK_PORCH    = 0,
  parameter CUSTOM_V_SYNC_POLARITY = 0)
 (input  clk,
  input  aux_request,
  output reg aux_enable = 1'b0,
  output reg display_enable = 1'b1,
  output reg line_end = 1'b1,
  output reg frame_end = 1'b1,
  output reg aux_packet_end = 1'b0,
  output reg hsync = 1'b0,
  output reg vsync = 1'b0,
  output reg [11:0] pixel = 12'd0,
  output reg [11:0] line = 12'd0,
  output reg [9:0] aux_slot = 10'd0,
  output reg [2:0] opmode = 3'b011); //Modes: 111-Video preamble, 110-Video guard, 101-Aux preamble, 100-Aux guard, 
                                    //       011-Video data,     001-Aux data,    000-Control,      010-Unused

  wire [11:0] H_VISIBLE;
  wire [11:0] H_FRONT_PORCH;
  wire [11:0] H_SYNC;
  wire [11:0] H_BACK_PORCH;
  wire [11:0] H_SYNC_POLARITY;
  wire [11:0] V_VISIBLE;
  wire [11:0] V_FRONT_PORCH;
  wire [11:0] V_SYNC;
  wire [11:0] V_BACK_PORCH;
  wire [11:0] V_SYNC_POLARITY;

  wire [11:0] HORIZONTAL_BLANKING;
  wire [11:0] VERTICAL_BLANKING;
  wire [11:0] LINE_LENGTH;
  wire [11:0] FRAME_LENGTH;

  localparam PREAMBLE = 8;
  localparam GUARDBAND = 2;
  localparam AUXPACKET = 32;
  localparam CTRL_MINIMUM = 12;
  localparam CTRL_EXTENDED = 32;

  generate
    case (VIDEO_MODE)
      "XGA" :
      begin
        assign H_VISIBLE       = 1024;
        assign H_FRONT_PORCH   = 24;
        assign H_SYNC          = 136;
        assign H_BACK_PORCH    = 160;
        assign H_SYNC_POLARITY = 0;
        assign V_VISIBLE       = 768;
        assign V_FRONT_PORCH   = 3;
        assign V_SYNC          = 6;
        assign V_BACK_PORCH    = 29;
        assign V_SYNC_POLARITY = 0;
      end
      "SVGA" :
      begin
        assign H_VISIBLE       = 800;
        assign H_FRONT_PORCH   = 56;
        assign H_SYNC          = 120;
        assign H_BACK_PORCH    = 64;
        assign H_SYNC_POLARITY = 1;
        assign V_VISIBLE       = 600;
        assign V_FRONT_PORCH   = 37;
        assign V_SYNC          = 6;
        assign V_BACK_PORCH    = 23;
        assign V_SYNC_POLARITY = 1;
      end
      "720p" :
      begin
        assign H_VISIBLE       = 1280;
        assign H_FRONT_PORCH   = 110;
        assign H_SYNC          = 40;
        assign H_BACK_PORCH    = 220;
        assign H_SYNC_POLARITY = 1;
        assign V_VISIBLE       = 720;
        assign V_FRONT_PORCH   = 5;
        assign V_SYNC          = 5;
        assign V_BACK_PORCH    = 20;
        assign V_SYNC_POLARITY = 1;
      end
      "720p_reduced" :
      begin
        assign H_VISIBLE       = 1280;
        assign H_FRONT_PORCH   = 48;
        assign H_SYNC          = 32;
        assign H_BACK_PORCH    = 80;
        assign H_SYNC_POLARITY = 1;
        assign V_VISIBLE       = 720;
        assign V_FRONT_PORCH   = 3;
        assign V_SYNC          = 5;
        assign V_BACK_PORCH    = 13;
        assign V_SYNC_POLARITY = 0;
      end
      "1080p" :
      begin
        assign H_VISIBLE       = 1920;
        assign H_FRONT_PORCH   = 56;
        assign H_SYNC          = 184;
        assign H_BACK_PORCH    = 240;
        assign H_SYNC_POLARITY = 0;
        assign V_VISIBLE       = 1080;
        assign V_FRONT_PORCH   = 3;
        assign V_SYNC          = 5;
        assign V_BACK_PORCH    = 10;
        assign V_SYNC_POLARITY = 1;
      end
      "1080p_reduced" :
      begin
        assign H_VISIBLE       = 1920;
        assign H_FRONT_PORCH   = 48;
        assign H_SYNC          = 32;
        assign H_BACK_PORCH    = 80;
        assign H_SYNC_POLARITY = 1;
        assign V_VISIBLE       = 1080;
        assign V_FRONT_PORCH   = 3;
        assign V_SYNC          = 5;
        assign V_BACK_PORCH    = 23;
        assign V_SYNC_POLARITY = 0;
      end
      "CUSTOM" :
      begin
        assign H_VISIBLE       = CUSTOM_H_VISIBLE;
        assign H_FRONT_PORCH   = CUSTOM_H_FRONT_PORCH;
        assign H_SYNC          = CUSTOM_H_SYNC;
        assign H_BACK_PORCH    = CUSTOM_H_BACK_PORCH;
        assign H_SYNC_POLARITY = CUSTOM_H_SYNC_POLARITY;
        assign V_VISIBLE       = CUSTOM_V_VISIBLE;
        assign V_FRONT_PORCH   = CUSTOM_V_FRONT_PORCH;
        assign V_SYNC          = CUSTOM_V_SYNC;
        assign V_BACK_PORCH    = CUSTOM_V_BACK_PORCH;
        assign V_SYNC_POLARITY = CUSTOM_V_SYNC_POLARITY;
      end
      default : //"STANDARD_VGA" :
      begin
        assign H_VISIBLE       = 640;
        assign H_FRONT_PORCH   = 16;
        assign H_SYNC          = 96;
        assign H_BACK_PORCH    = 48;
        assign H_SYNC_POLARITY = 0;
        assign V_VISIBLE       = 480;
        assign V_FRONT_PORCH   = 10;
        assign V_SYNC          = 2;
        assign V_BACK_PORCH    = 33;
        assign V_SYNC_POLARITY = 0;
      end
    endcase
  endgenerate

  assign HORIZONTAL_BLANKING = H_FRONT_PORCH + H_SYNC + H_BACK_PORCH;
  assign VERTICAL_BLANKING = V_FRONT_PORCH + V_SYNC + V_BACK_PORCH;
  assign LINE_LENGTH = H_FRONT_PORCH + H_SYNC + H_BACK_PORCH + H_VISIBLE;
  assign FRAME_LENGTH = V_FRONT_PORCH + V_SYNC + V_BACK_PORCH + V_VISIBLE;

  wire [11:0] next_pixel;
  wire [11:0] next_line;
  wire next_line_end;
  wire next_frame_end;
  wire next_aux_packet_end;
  wire h_blank;
  wire v_blank;
  wire next_hsync;
  wire next_vsync;
  wire video_preamble;
  wire video_guard;
  wire de;
  wire aux_granted;
  wire aux_in_progress;
  wire aux_setup_end;
  wire ae;
  wire [9:0] next_aux_slot;
  wire aux_end;
  wire aux_preamble;
  wire aux_guard;
  reg [3:0]  aux_setup_count = GUARDBAND + PREAMBLE + 1;
  reg [5:0]  ctrl_requirement_count = CTRL_EXTENDED - PREAMBLE;
  reg [2:0]  next_opmode = 3'b000;

  assign next_pixel = (line_end) ? 12'd0 : pixel + 1;
  assign next_line = (frame_end) ? 12'd0 : line + line_end;
  assign next_line_end = (next_pixel >= LINE_LENGTH-1);
  assign next_frame_end = (next_line >= FRAME_LENGTH-1) && next_line_end;

  assign h_blank = (next_pixel < HORIZONTAL_BLANKING);
  assign v_blank = (next_line < VERTICAL_BLANKING);
  assign next_hsync = H_SYNC_POLARITY ^~ ((next_pixel >= H_FRONT_PORCH) && (next_pixel < H_FRONT_PORCH + H_SYNC));
  assign next_vsync = V_SYNC_POLARITY ^~ ((next_line >= V_FRONT_PORCH) && (next_line < V_FRONT_PORCH + V_SYNC));
  assign de = ~h_blank & ~v_blank;
  assign video_guard = ~v_blank & h_blank & (next_pixel >= HORIZONTAL_BLANKING - GUARDBAND);
  assign video_preamble = ~v_blank & h_blank & ~video_guard & (next_pixel >= HORIZONTAL_BLANKING - (PREAMBLE + GUARDBAND));

  assign aux_granted = aux_request & ctrl_requirement_count[5] 
    & (v_blank || (next_pixel < HORIZONTAL_BLANKING - (3*GUARDBAND + PREAMBLE + AUXPACKET + CTRL_MINIMUM)));
  assign aux_in_progress = (aux_setup_count != GUARDBAND + PREAMBLE + 1);
  assign aux_setup_end = (aux_setup_count == GUARDBAND + PREAMBLE - 1);
  assign next_aux_slot = (aux_in_progress) ? (aux_enable && ae) ? aux_slot + 1 : aux_slot : 10'd0;
  assign ae = (aux_setup_count == GUARDBAND + PREAMBLE);
  assign next_aux_packet_end = (next_aux_slot%AUXPACKET == AUXPACKET - 1);
  assign aux_end = next_aux_packet_end & (~aux_request || (next_aux_slot/AUXPACKET >= 17) 
    || ~(v_blank || (next_pixel < HORIZONTAL_BLANKING - (2*GUARDBAND + AUXPACKET + CTRL_MINIMUM))));
  assign aux_preamble = (aux_setup_count < PREAMBLE);
  assign aux_guard = ~aux_preamble & (aux_setup_count < GUARDBAND + PREAMBLE);


  always @(*)
    if (video_preamble)
      next_opmode = 3'b111;
    else if (video_guard)
      next_opmode = 3'b110;
    else if (de)
      next_opmode = 3'b011;
    else if (aux_preamble)
      next_opmode = 3'b101;
    else if (aux_guard)
      next_opmode = 3'b100;
    else if (ae)
      next_opmode = 3'b001;
    else
      next_opmode = 3'b000;

  always @(posedge clk)
    if (next_frame_end || (aux_setup_end && aux_end))
      aux_setup_count <= GUARDBAND + PREAMBLE + 1;
    else if (aux_setup_count < GUARDBAND + PREAMBLE)
      aux_setup_count <= aux_setup_count + 1;
    else if (aux_end)
      aux_setup_count <= PREAMBLE;
    else if (~aux_in_progress && aux_granted)
      aux_setup_count <= 0;
    else
      aux_setup_count <= aux_setup_count;
      

  always @(posedge clk)
    if (next_frame_end)
      ctrl_requirement_count <= CTRL_EXTENDED - PREAMBLE;
    else if (next_opmode != 3'b000)
      ctrl_requirement_count <= CTRL_MINIMUM - PREAMBLE;
    else if (ctrl_requirement_count[5]) 
        ctrl_requirement_count <= ctrl_requirement_count;
    else ctrl_requirement_count <= ctrl_requirement_count - 1;


  always @(posedge clk)
    if (next_frame_end)
    begin 
      pixel <= 12'd0;
      line <= 12'd0;
      line_end <= 1'b1;
      frame_end <= 1'b1;
      aux_packet_end <= 1'b0;
      hsync <= ~H_SYNC_POLARITY;
      vsync <= ~V_SYNC_POLARITY;
      aux_enable <= 1'b0;
      aux_slot <= 10'd0;
      display_enable <= 1'b1;
      opmode <= 3'b011;
    end
    else
    begin
      pixel <= next_pixel;
      line <= next_line;
      line_end <= next_line_end;
      aux_packet_end <= next_aux_packet_end;
      frame_end <= 1'b0;
      hsync <= next_hsync;
      vsync <= next_vsync;
      aux_enable <= ae;
      aux_slot <= next_aux_slot;
      display_enable <= de;
      opmode <= next_opmode;      
    end
endmodule
