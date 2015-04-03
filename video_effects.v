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
  input [11:0] pixel,
  input [11:0] line,
  input line_end,
  input frame_end,
  input halt,
  output reg reconf,
  output reg [7:0] Cb,
  output reg [7:0] Y,
  output reg [7:0] Cr);

  reg [11:0] frames;

  wire [11:0] rz_pixel;
  wire [11:0] rz_line;

  wire [7:0] sprite_Y;
  wire [7:0] sprite_Cb;
  wire [7:0] sprite_Cr;

  wire [35:0] mulres1;
  wire [35:0] mulres2;

  assign mulres1 = pixel*line;
  assign mulres2 = line*line;

  coord_count 
  #(.DEPTH(9))
  ccount
   (.clk(clk),
    .frame_end(frame_end),
    .line_end(line_end),
    .init_x(18'd0),
    .init_y(18'd0),
    .dx(mulres1[18:10]),
    .dy(mulres2[18:10]),
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


  reg spritedirx = 1;
  reg spritediry = 1;
  reg [11:0] spritepx = 300;
  reg [11:0] spriteln = 300;
  wire [11:0] next_spritepx;
  wire [11:0] next_spriteln;

  sprite sprt
   (.clk(clk),
    .halt(halt),
    .pixel(pixel),
    .line(line),
    .pixel_offset(spritepx),
    .line_offset(spriteln),
    .valid(sprite_valid),
    .Y(sprite_Y),
    .Cb(sprite_Cb),
    .Cr(sprite_Cr));


  wire [1:0] txtq;
  text_mode txtmde
   (.clk(clk),
    .halt(halt),
    .scale(2),
    .pixel(pixel),
    .line(line),
    .pixel_offset(160-(frames[3:0]<<3)),
    .line_offset(450),
    .text_offset(frames[11:4]),
    .q(txtq));



  assign next_spritepx = (spritedirx) ? spritepx + 1 : spritepx - 1;
  assign next_spriteln = (spritediry) ? spriteln + 1 : spriteln - 1;


  always @(*)
  begin
    Y =  (|txtq) ? txtq<<5 : (sprite_valid) ? sprite_Y : grids_c1;
    Cb = (|txtq) ? 8'h80 : (sprite_valid) ? sprite_Cb : grids_c0;
    Cr = (|txtq) ? 8'h80 : (sprite_valid) ? sprite_Cr : grids_c2;
  end



  always @(posedge clk)
  begin
    if (frame_end)
    begin
      frames <= frames + 1;
      reconf <= &frames[10:0];
      spritedirx <= (next_spritepx == 1300 || next_spritepx == 180) ? ~spritedirx : spritedirx;
      spritediry <= (next_spriteln == 670 || next_spriteln == 40) ? ~spritediry : spritediry;
      spritepx <= next_spritepx;
      spriteln <= next_spriteln;
    end
    else
    begin
      reconf <= 1'b0;
    end
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

  assign top_grid = (line) ^ ((pixel+frame));
  assign bottom_grid = ((line+frame)) ^ ((pixel+frame));


  always @(posedge clk)
  begin
    Cb <= 120;
    Y <= (top_grid[6]) ? top_grid : bottom_grid>>1;
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
  input halt,
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
  wire [3:0] p_ow;
  wire [3:0] l_ow;
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
    .ce(~halt),
    .addra(sprite_addr[12:2]),
    .addrb(colour),
    .doa(sprite_raw1),
    .dob(palette_raw1));

  dual_rom
   #(.INITFILE("sprite2.txt"))
  sprite2 (
    .clk(clk),
    .ce(~halt),
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
  input halt,
  input [2:0] scale,
  input [11:0] pixel,
  input [11:0] line,
  input [11:0] pixel_offset,
  input [11:0] line_offset,
  input [7:0] text_offset,
  output reg [1:0] q);

(* rom_style = "block" *)
  reg [3:0] text_mode_mem [4095:0];
  reg [3:0] font_raw;
  reg [3:0] symbol;
  reg [2:0] font_slice;

  wire [11:0] tot_pixel;
  wire [11:0] tot_line;
  wire [7:0] cur_col;
  wire [7:0] cur_row;
  wire [7:0] text_addr;
  wire [13:0] font_addr;
  wire font_bit;
  wire outside;

  wire [11:0] unscaled_pixel;
  wire [11:0] unscaled_line;

  assign scaledpx = pixel>>scale;
  assign scaledln = line>>scale;
  assign unscaled_pixel = pixel - pixel_offset;
  assign unscaled_line = line - line_offset;
  assign tot_pixel = unscaled_pixel>>scale;
  assign tot_line = unscaled_line>>scale;
  assign cur_col = tot_pixel>>5;
  assign cur_row = tot_line>>5;
  assign text_addr = (cur_row[0]) ? text_offset + cur_col + 128 : text_offset + cur_col;
  assign font_addr = (symbol<<10) | (tot_line[4:0]<<5) | (tot_pixel[4:0]);

  assign font_bit = font_raw[font_slice];
  assign outside = (|(cur_row>>1) || ~|symbol);

  initial
    $readmemb("textmode.txt",text_mode_mem);

  always @(negedge clk)
  begin
    if (!halt)
    begin
      symbol <= text_mode_mem[{4'b0000, text_addr[7:0]}];
      q <= (outside) ? 2'b00 : (font_bit && ~&q) ? q + 1 : (!font_bit && |q) ? q - 1 : q;
    end
  end

  always @(posedge clk)
  begin
    if (!halt)
    begin
      font_raw <= text_mode_mem[font_addr[13:2]];
      font_slice <= font_addr[1:0];
    end
  end
endmodule

module dual_rom
 #(parameter INITFILE = "mem.txt")

 (input clk,
  input ce,
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
      if (ce)
        doa <= mem[addra];
    end

  always @(posedge clk)
  begin
    if (ce)
      dob <= mem[addrb];
  end
endmodule
