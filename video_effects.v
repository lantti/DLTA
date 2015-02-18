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

module video_controller
 (input  clk,
  input hold,
  input [11:0] pixel,
  input [11:0] line,
  input line_end,
  input frame_end,
  output reg [7:0] Cb,
  output reg [7:0] Y,
  output reg [7:0] Cr);

/*
(* rom_style = "distributed" *)
  reg [7:0] palette_y[31:0];
(* rom_style = "distributed" *)
  reg [7:0] palette_b[31:0];
(* rom_style = "distributed" *)
  reg [7:0] palette_r[31:0];
*/

  reg [11:0] frames;

  reg [20:0] prandom = 21'h55; //pseudorandom noise generator lfsr
  reg init_prandom;

  reg [11:0] fade0;
//  reg [11:0] fade1;
  reg [11:0] fade_goal0 = 21;
//  reg [11:0] fade_goal1 = 21;


  wire [11:0] rz_pixel;
  wire [11:0] rz_line;

  wire [9:0] zoom_count_x;
  wire [9:0] zoom_count_y;
  wire [8:0] zoom_sawtooth_x;
  wire [8:0] zoom_sawtooth_y;

  wire [7:0] sprite_Y;
  wire [7:0] sprite_Cb;
  wire [7:0] sprite_Cr;

  wire [3:0] part;

  coord_count 
  #(.DEPTH(9))
  ccount
   (.clk(clk),
    .frame_end(frame_end),
    .line_end(line_end),
    .init_x(18'd0),
    .init_y(18'd0),
    .dx(zoom_sawtooth_x),
    .dy(zoom_sawtooth_y),
    .x(rz_pixel),
    .y(rz_line));

  wire [7:0] grids_c0;
  wire [7:0] grids_c1;
  wire [7:0] grids_c2;
  two_grids eff
   (.clk(clk),
    .pixel(rz_pixel),
    .line(rz_line),
    .frame(frames),
    .Cb(grids_c0),
    .Y(grids_c1),
    .Cr(grids_c2));

/*  wire [7:0] mul_c0;
  wire [7:0] mul_c1;
  wire [7:0] mul_c2;
  multiply mul
   (.clk(clk),
    .pixel(pixel[10:0]+prandom[10:0]),
    .line(line),
    .Cb(mul_c0),
    .Y(mul_c1),
    .Cr(mul_c2));
*/

  reg [11:0] spritepx;
  reg [11:0] spriteln;
  reg [11:0] spritepx_off;
  reg [11:0] spriteln_off;
  sprite sprt
   (.clk(clk),
    .pixel(spritepx),
    .line(spriteln),
    .pixel_offset(spritepx_off),
    .line_offset(spriteln_off),
    .valid(sprite_valid),
    .Y(sprite_Y),
    .Cb(sprite_Cb),
    .Cr(sprite_Cr));



  wire [1:0] txtq;
  reg [11:0] txtpx_off;
  reg [11:0] txtln_off;
  wire [9:0] txt_off;
  wire [2:0] txt_rows;
  text_mode txtmde
   (.clk(clk),
    .cols(4),
    .rows(txt_rows),
    .pixel({pixel[11:3], pixel[2]^(&prandom[1:0])}),
    .line(line[11:2]),
    .pixel_offset(txtpx_off),
    .line_offset(txtln_off),
    .text_offset(txt_off),
    .q(txtq));


  wire [7:0] intermezzo;
  wire [4:0] f1;
  wire [4:0] f2;
  wire [4:0] f3;
  wire [4:0] f4;
  multiply mul
   (.clk(clk),
    .i1({f1, 4'hF}),
    .i2({f2, 4'hF}),
    .i3({f3, 4'hF}),
    .i4({f4, 4'hF}),
    .product(intermezzo));

  assign f1 = pixel>>1;
  assign f2 = line>>1;
  assign f3 = rz_pixel>>1;
  assign f4 = ~rz_pixel>>1;


  assign zoom_count_x = frames[9:0];
  assign zoom_count_y = zoom_count_x - 256;
  assign zoom_sawtooth_x = 9'hFF - ((zoom_count_x[9]) ? -zoom_count_x : zoom_count_x);
  assign zoom_sawtooth_y = 9'hFF - ((zoom_count_y[9]) ? -zoom_count_y : zoom_count_y);


  assign part = frames[11:8];

  assign txt_off = ((part[3]) ? {~part[1], ~part[0], 1'b0} : {2'b00, part[2]})<<7;
  assign txt_rows = {part[3],~part[3],~part[3]};

  always @(*)
  begin
    case (part)
      4'h0 : 
        begin
          Y =  (sprite_valid) ? sprite_Y : (prandom[0]) ? 8'hFF : (intermezzo - 1'b1)>>2;
          Cb = (sprite_valid) ? 8'h80 : (prandom[0]) ? 8'h80 : grids_c0;
          Cr = (sprite_valid) ? 8'h80 : (prandom[0]) ? 8'h80 : grids_c2;
          spritepx = pixel>>3;
          spriteln = line>>3;
          spritepx_off = 31;
          spriteln_off = fade0;
          txtpx_off = 20;
          txtln_off = 20;
          fade_goal0 = 21;
        end
      4'h1 : 
        begin
          Y =  (sprite_valid) ? sprite_Y : (prandom[0]) ? 8'hFF : grids_c1;
          Cb = (sprite_valid) ? 8'h80 : (prandom[0]) ? 8'h80 : grids_c0;
          Cr = (sprite_valid) ? 8'h80 : (prandom[0]) ? 8'h80 : grids_c2;
          spritepx = pixel>>3;
          spriteln = line>>3;
          spritepx_off = 31;
          spriteln_off = fade0;
          txtpx_off = 20;
          txtln_off = 20;
          fade_goal0 = 255;
        end
      4'h2 : 
        begin
          Y = (prandom[0]) ? (|txtq) ? txtq<<6 : fade0 : (sprite_valid) ? sprite_Y : grids_c1;
          Cb = (prandom[0]) ? (|txtq) ? 8'h10 : 8'h80 : (sprite_valid) ? sprite_Cb : grids_c0;
          Cr = (prandom[0]) ? (|txtq) ? 8'hB0 : 8'h80 : (sprite_valid) ? sprite_Cr : grids_c2;
          spritepx = rz_pixel>>1;
          spriteln = rz_line>>1;
          spritepx_off = 31;
          spriteln_off = 21;
          txtpx_off = 20;
          txtln_off = fade0;
          fade_goal0 = 40;
        end
      4'h3 : 
        begin
          Y = (prandom[0]) ? (|txtq) ? txtq<<6 : fade0[3:0] : (sprite_valid) ? sprite_Y : grids_c1;
          Cb = (prandom[0]) ? (|txtq) ? 8'h10 : fade0<<3 : (sprite_valid) ? sprite_Cb : grids_c0;
          Cr = (prandom[0]) ? (|txtq) ? 8'hB0 : {fade0[7:6], 5'h1F} : (sprite_valid) ? sprite_Cr : grids_c2;
          spritepx = rz_pixel>>1;
          spriteln = rz_line>>1;
          spritepx_off = 31;
          spriteln_off = 21;
          txtpx_off = 20;
          txtln_off = fade0;
          fade_goal0 = 245;
        end
      4'h4 : 
        begin
          Y =  grids_c1;
          Cb = grids_c0;
          Cr = grids_c2;
          spritepx = pixel>>3;
          spriteln = line>>3;
          spritepx_off = 31;
          spriteln_off = 21;
          txtpx_off = 20;
          txtln_off = 20;
          fade_goal0 = 200;
        end
      4'h5 : 
        begin
          Y =  (|txtq) ? txtq<<5 : (sprite_valid) ? sprite_Y : grids_c1;
          Cb = (|txtq) ? {1'b0, 1'b0, prandom[0], 1'b1, 1'b1, prandom[20:19], 1'b1} : (sprite_valid) ? sprite_Cb : grids_c0;
          Cr = (|txtq) ? {1'b1, 1'b0, prandom[20:19], prandom[0], 1'b0, 1'b0, 1'b0} : (sprite_valid) ? sprite_Cr : grids_c2;
          spritepx = rz_pixel>>1;
          spriteln = rz_line>>1;
          spritepx_off = 31;
          spriteln_off = 21;
          txtpx_off = 20;
          txtln_off = fade0;
          fade_goal0 = 20;
        end
      4'h6 : 
        begin
          Y =  (|txtq) ? txtq<<5 : (sprite_valid) ? sprite_Y : grids_c1;
          Cb = (|txtq) ? {1'b0, 1'b0, prandom[0], 1'b1, 1'b1, prandom[20:19], 1'b1} : (sprite_valid) ? sprite_Cb : grids_c0;
          Cr = (|txtq) ? {1'b1, 1'b0, prandom[20:19], prandom[0], 1'b0, 1'b0, 1'b0} : (sprite_valid) ? sprite_Cr : grids_c2;
          spritepx = rz_pixel>>1;
          spriteln = rz_line>>1;
          spritepx_off = 31;
          spriteln_off = 21;
          txtpx_off = fade0;
          txtln_off = 20;
          fade_goal0 = 330;
        end
      4'h7 : 
        begin
          Y =  (sprite_valid) ? sprite_Y : grids_c1;
          Cb = (sprite_valid) ? sprite_Cb : grids_c0;
          Cr = (sprite_valid) ? sprite_Cr : grids_c2;
          spritepx = pixel>>3;
          spriteln = line>>3;
          spritepx_off = fade0[8:0];
          spriteln_off = 21;
          txtpx_off = 20;
          txtln_off = 20;
          fade_goal0 = 0;
        end
      4'h8 : 
        begin
          Y =  (sprite_valid) ? sprite_Y : grids_c1;
          Cb = (sprite_valid) ? sprite_Cb : grids_c0;
          Cr = (sprite_valid) ? sprite_Cr : grids_c2;
          spritepx = pixel>>3;
          spriteln = line>>3;
          spritepx_off = fade0[8:0];
          spriteln_off = 21;
          txtpx_off = 20;
          txtln_off = 20;
          fade_goal0 = 21;
        end
      4'h9 : 
        begin
          Y =  (sprite_valid) ? sprite_Y : grids_c1;
          Cb = (sprite_valid) ? sprite_Cb : grids_c0;
          Cr = (sprite_valid) ? sprite_Cr : grids_c2;
          spritepx = pixel>>3;
          spriteln = line>>3;
          spritepx_off = fade0[8:0];
          spriteln_off = fade0[8:0];
          txtpx_off = 20;
          txtln_off = 20;
          fade_goal0 = 255;
        end

      4'hA, 4'hB : 
        begin
          Y[6:0] = intermezzo - 1'b1;
          Y[7] = 1'b0;
          Cb = grids_c0;
          Cr = grids_c2;
          spritepx = pixel>>3;
          spriteln = line>>3;
          spritepx_off = 31;
          spriteln_off = 21;
          txtpx_off = 20;
          txtln_off = 20;
          fade_goal0 = 31;
        end


      4'hC, 4'hD, 4'hE, 4'hF : 
        begin
          Y =  (|txtq) ? txtq<<5 : intermezzo;
          Cb = (|txtq) ? {1'b0, 1'b0, prandom[0], 1'b1, 1'b1, prandom[20:19], 1'b1} : grids_c0;
          Cr = (|txtq) ? {1'b1, 1'b0, prandom[20:19], prandom[0], 1'b0, 1'b0, 1'b0} : grids_c2;
          spritepx = pixel>>3;
          spriteln = line>>3;
          spritepx_off = 31;
          spriteln_off = 21;
          txtpx_off = 20;
          txtln_off = 20;
          fade_goal0 = 0;
        end
      default :
        begin
          Y =  grids_c1;
          Cb = grids_c0;
          Cr = grids_c2;
          spritepx = pixel>>3;
          spriteln = line>>3;
          spritepx_off = 31;
          spriteln_off = 21;
          txtpx_off = 20;
          txtln_off = 20;
          fade_goal0 = 21;
        end
    endcase 
  end

  always @(posedge clk)
  begin
    if (frame_end)
    begin
      frames <= frames + (!hold);

      if (fade0 > fade_goal0)
        fade0 <= fade0 - 1;
      else if (fade0 < fade_goal0)
        fade0 <= fade0 + 1;
      else
        fade0 <= fade0;
    end
    else
    begin
      frames <= frames;
      fade0 <= fade0;
    end
    prandom[20:1] <= prandom[19:0];
    prandom[0] <= (init_prandom) ? pixel[0] : prandom[20] ^ prandom[19];
    init_prandom <= ~(init_prandom & line_end) & (init_prandom | frame_end);
  end
endmodule


module two_grids
 (input  clk,
  input [8:0] pixel,
  input [8:0] line,
  input [8:0] frame,
  output reg [7:0] Cb,
  output reg [7:0] Y,
  output reg [7:0] Cr);

  wire [7:0] top_grid;
  wire [7:0] bottom_grid;

  assign top_grid = (line>>1) ^ ((pixel+(frame<<2))>>1);
  assign bottom_grid = ((line+frame)>>1) ^ ((pixel+(frame<<1))>>1);


  always @(posedge clk)
  begin
    Cb <= 120;
    Y <= (top_grid[6]) ? top_grid>>1 : bottom_grid>>2;
    Cr <= 125;
  end
endmodule


module multiply
 (input  clk,
  input [8:0] i1,
  input [8:0] i2,
  input [8:0] i3,
  input [8:0] i4,
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


module coord_count
#(parameter DEPTH = 8)
 (input clk,
  input frame_end,
  input line_end,
  input [2*DEPTH-1:0] init_x,
  input [2*DEPTH-1:0] init_y,
  input [2*DEPTH-1:0] dx,
  input [2*DEPTH-1:0] dy,
  output [DEPTH-1:0] x,
  output [DEPTH-1:0] y);

  reg [2*DEPTH-1:0] count_x;
  reg [2*DEPTH-1:0] count_y;
  reg [2*DEPTH-1:0] next_line_x;
  reg [2*DEPTH-1:0] next_line_y;
  
  assign x = count_x[2*DEPTH-1:DEPTH];
  assign y = count_y[2*DEPTH-1:DEPTH];

  always @(posedge clk)
    if(frame_end)
    begin
      count_x <= init_x;
      count_y <= init_y;
      next_line_x <= init_x - dy;
      next_line_y <= init_y + dx;
    end
    else if (line_end)
    begin
      count_x <= next_line_x;
      count_y <= next_line_y;
      next_line_x <= next_line_x - dy;
      next_line_y <= next_line_y + dx;
    end
    else
    begin
      count_x <= count_x + dx;
      count_y <= count_y + dy;
      next_line_x <= next_line_x;
      next_line_y <= next_line_y;
    end
endmodule


module sprite
 (input clk,
  input [11:0] pixel,
  input [11:0] line,
  input [11:0] pixel_offset,
  input [11:0] line_offset,
  output reg valid,
  output [7:0] Y,
  output [7:0] Cb,
  output [7:0] Cr);

  wire [8:0] sprite_raw1;
  wire [8:0] sprite_raw2;
  wire [8:0] palette_raw1;
  wire [8:0] palette_raw2;
  wire [6:0] tot_pixel;
  wire [5:0] tot_line;
  wire [2:0] p_ow;
  wire [2:0] l_ow;
  wire [12:0] sprite_addr;
  wire outside;
  reg [4:0] colour;

  assign {p_ow, tot_pixel} = pixel - pixel_offset;
  assign {l_ow, tot_line} = line - line_offset;
  assign sprite_addr = (tot_line<<7) | (tot_pixel);
  assign outside = (|p_ow) | (|l_ow) | (~|tot_line);

  assign Y = palette_raw1[7:0];
  assign Cb = {palette_raw2[8:4], 3'h0};
  assign Cr = {palette_raw1[8], palette_raw2[3:0], 3'h0};

  dual_rom
   #(.INITFILE("sprite1.txt"))
  sprite1 (
    .clk(clk),
    .addra(sprite_addr[12:2]),
    .addrb(colour),
    .doa(sprite_raw1),
    .dob(palette_raw1));

  dual_rom
   #(.INITFILE("sprite2.txt"))
  sprite2 (
    .clk(clk),
    .addra(sprite_addr[12:2]),
    .addrb(colour),
    .doa(sprite_raw2),
    .dob(palette_raw2));
    
  always @*
  begin
    case ({sprite_addr[1:0]})
      2'b00: colour <= {sprite_raw1[8], sprite_raw1[3:0]};
      2'b01: colour <= {sprite_raw1[8], sprite_raw1[7:4]};
      2'b10: colour <= {sprite_raw2[8], sprite_raw2[3:0]};
      2'b11: colour <= {sprite_raw2[8], sprite_raw2[7:4]};
    endcase
  end

  always @(posedge clk)
  begin
    valid <= ~outside & |colour;
  end

endmodule

module text_mode
 (input clk,
  input [2:0] cols,
  input [2:0] rows,
  input [11:0] pixel,
  input [11:0] line,
  input [11:0] pixel_offset,
  input [11:0] line_offset,
  input [9:0] text_offset,
  output [1:0] q);

(* rom_style = "block" *)
  reg [8:0] text_mode_mem [2047:0];
  reg [8:0] font_raw;
  reg [8:0] text_raw;
  reg [4:0] text;
  reg outside;
  reg [2:0] font_slice;

  wire [11:0] tot_pixel;
  wire [11:0] tot_line;
  wire [7:0] cur_col;
  wire [7:0] cur_row;
  wire [9:0] text_addr;
  wire [13:0] font_addr;
  wire [7:0] even_font;
  wire [7:0] odd_font;
  wire p_neg;
  wire l_neg;

  assign {p_neg, tot_pixel} = pixel - pixel_offset;
  assign {l_neg, tot_line} = line - line_offset;
  assign cur_col = tot_pixel>>5;
  assign cur_row = tot_line>>4;
  assign text_addr = text_offset + ((cur_row<<cols) | cur_col);
  assign font_addr = (text<<9) | (tot_line[3:0]<<5) | (tot_pixel[4:0]);

//  assign even_font = {font_raw[6], font_raw[4], font_raw[2], font_raw[0]};
//  assign odd_font = {font_raw[7], font_raw[5], font_raw[3], font_raw[1]};

//Silly saturating up-down adder
  assign odd_font[0] = font_raw[8];
  assign even_font[0] = font_raw[7];
  assign odd_font[1] = (odd_font[0]^font_raw[6]) ? even_font[0] : font_raw[6];
  assign even_font[1] = (odd_font[0]^font_raw[6]) ? ~even_font[0] : font_raw[6];
  assign odd_font[2] = (odd_font[1]^font_raw[5]) ? even_font[1] : font_raw[5];
  assign even_font[2] = (odd_font[1]^font_raw[5]) ? ~even_font[1] : font_raw[5];
  assign odd_font[3] = (odd_font[2]^font_raw[4]) ? even_font[2] : font_raw[4];
  assign even_font[3] = (odd_font[2]^font_raw[4]) ? ~even_font[2] : font_raw[4];
  assign odd_font[4] = (odd_font[3]^font_raw[3]) ? even_font[3] : font_raw[3];
  assign even_font[4] = (odd_font[3]^font_raw[3]) ? ~even_font[3] : font_raw[3];
  assign odd_font[5] = (odd_font[4]^font_raw[2]) ? even_font[4] : font_raw[2];
  assign even_font[5] = (odd_font[4]^font_raw[2]) ? ~even_font[4] : font_raw[2];
  assign odd_font[6] = (odd_font[5]^font_raw[1]) ? even_font[5] : font_raw[1];
  assign even_font[6] = (odd_font[5]^font_raw[1]) ? ~even_font[5] : font_raw[1];
  assign odd_font[7] = (odd_font[6]^font_raw[0]) ? even_font[6] : font_raw[0];
  assign even_font[7] = (odd_font[6]^font_raw[0]) ? ~even_font[6] : font_raw[0];

  always @(*)
  begin
    text[2:0] = (text_addr[0]) ? text_raw[5:3] : text_raw[2:0];
    case ({text_addr[0],text_raw[8:6]})
      4'b0000 : text[4:3] = 2'b00;
      4'b0001 : text[4:3] = 2'b01;
      4'b0010 : text[4:3] = 2'b00;
      4'b0011 : text[4:3] = 2'b01;
      4'b0100 : text[4:3] = 2'b10;
      4'b0101 : text[4:3] = 2'b10;
      4'b0110 : text[4:3] = 2'b00;
      4'b0111 : text[4:3] = 2'b01;
      4'b1000 : text[4:3] = 2'b00;
      4'b1001 : text[4:3] = 2'b00;
      4'b1010 : text[4:3] = 2'b01;
      4'b1011 : text[4:3] = 2'b01;
      4'b1100 : text[4:3] = 2'b00;
      4'b1101 : text[4:3] = 2'b01;
      4'b1110 : text[4:3] = 2'b10;
      4'b1111 : text[4:3] = 2'b10;
    endcase
  end

  assign q[0] = (outside) ? 1'b0 : even_font[font_slice];
  assign q[1] = (outside) ? 1'b0 : odd_font[font_slice];

  initial
    $readmemb("textmode.txt",text_mode_mem);

  always @(negedge clk)
    text_raw <= text_mode_mem[{2'b11, text_addr[9:1]}];

  always @(posedge clk)
  begin
    font_raw <= text_mode_mem[font_addr[13:3]];
    font_slice <= font_addr[2:0];
    outside <= (p_neg || l_neg || |(cur_col>>cols) || |(cur_row>>rows));
  end
endmodule

module dual_rom
 #(parameter INITFILE = "mem.txt")

 (input clk,
  input [10:0] addra,
  input [10:0] addrb,
  output reg [8:0] doa,
  output reg [8:0] dob);

  (* rom_style = "block" *)
  reg [8:0] mem [2047:0];

  initial
  begin
    $readmemb(INITFILE, mem);
  end

  always @(negedge clk)
    begin
      doa <= mem[addra];
    end

  always @(posedge clk)
  begin
      dob <= mem[addrb];
  end
endmodule
