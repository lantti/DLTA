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


//Encoder to calculate TMDS tokens for colour and
//control data. The parameter TWO_STEPS may be set to
//"TRUE" to split the calculation over to two cycles.
module tmds_encoder 
#(parameter TWO_STEPS = "FALSE")   //In case this module does not run fast enough to do everything in one cycle, use this to make it in two.

 (input        clk,
  input  [7:0] pixel,   //Pixel data
  input  [3:0] aux,     //Auxilary data
  input  [1:0] ctrl,    //Control lines
  input        guard,   //Guard band polarity
  input  [1:0] mode,    //Operating mode: 11-Video period, 10-Control period, 01-Aux period, 00-Guard band
  output reg [9:0] tmds_token);

//Fixed control period tokens 
  localparam CTRLTOKEN_0 = 10'b1101010100;
  localparam CTRLTOKEN_1 = 10'b0010101011;
  localparam CTRLTOKEN_2 = 10'b0101010100;
  localparam CTRLTOKEN_3 = 10'b1010101011;

//Fixed TERC4 auxilary data tokens
  localparam AUXTOKEN_0 = 10'b1010011100;
  localparam AUXTOKEN_1 = 10'b1001100011;
  localparam AUXTOKEN_2 = 10'b1011100100;
  localparam AUXTOKEN_3 = 10'b1011100010;
  localparam AUXTOKEN_4 = 10'b0101110001;
  localparam AUXTOKEN_5 = 10'b0100011110;
  localparam AUXTOKEN_6 = 10'b0110001110;
  localparam AUXTOKEN_7 = 10'b0100111100;
  localparam AUXTOKEN_8 = 10'b1011001100;  //Used also as the guard band token
  localparam AUXTOKEN_9 = 10'b0100111001;
  localparam AUXTOKEN_A = 10'b0110011100;
  localparam AUXTOKEN_B = 10'b1011000110;
  localparam AUXTOKEN_C = 10'b1010001110;
  localparam AUXTOKEN_D = 10'b1001110001;
  localparam AUXTOKEN_E = 10'b0101100011;
  localparam AUXTOKEN_F = 10'b1011000011;



  reg  [4:0] cnt;        //excess 1s counter
  wire [3:0] n1d;        //1s count in the input data
  wire [8:0] q_m;        //transition minimized data
  wire [3:0] n1m;        //1s count in the transition minimized data
  wire min_with_xnor;    //choice of transition minimization op
  wire dc_bal_inv;       //choice of dc balance inversion 
  reg  [9:0] ctrltoken;  //token to output in a control period
  reg  [9:0] auxtoken;   //token to output in a data island
  reg  [9:0] guardtoken; //token to output in a guard band
  wire [9:0] dtoken;     //data token to output in case of display enable
  wire [4:0] next_cnt;   //excess 1s counter for the next round

//Intermediate values used in case the calculation is done in two steps
  reg [8:0] q_m_reg;
  reg [3:0] aux_reg;
  reg [1:0] ctrl_reg;
  reg [1:0] mode_reg;
  reg guard_reg;

//Transition minimization as defined in the DVI and HDMI specifications
  assign n1d = pixel[0] + pixel[1] + pixel[2] + pixel[3] + pixel[4] + pixel[5] + pixel[6] + pixel[7];
  assign min_with_xnor = (n1d > 4'd4) | ((n1d == 4'd4) && (pixel[0] == 1'b0));

  assign q_m[0] = pixel[0];
  assign q_m[1] = (min_with_xnor) ? (q_m[0] ^~ pixel[1]) : (q_m[0] ^ pixel[1]);
  assign q_m[2] = (min_with_xnor) ? (q_m[1] ^~ pixel[2]) : (q_m[1] ^ pixel[2]);
  assign q_m[3] = (min_with_xnor) ? (q_m[2] ^~ pixel[3]) : (q_m[2] ^ pixel[3]);
  assign q_m[4] = (min_with_xnor) ? (q_m[3] ^~ pixel[4]) : (q_m[3] ^ pixel[4]);
  assign q_m[5] = (min_with_xnor) ? (q_m[4] ^~ pixel[5]) : (q_m[4] ^ pixel[5]);
  assign q_m[6] = (min_with_xnor) ? (q_m[5] ^~ pixel[6]) : (q_m[5] ^ pixel[6]);
  assign q_m[7] = (min_with_xnor) ? (q_m[6] ^~ pixel[7]) : (q_m[6] ^ pixel[7]);
  assign q_m[8] = (min_with_xnor) ? 1'b0 : 1'b1;

//Save intermediate values in case the calculation is done in two steps
  generate
    if (TWO_STEPS == "TRUE")
    begin
      always @(posedge clk)
      begin
        q_m_reg <= q_m;
        aux_reg <= aux;
        ctrl_reg <= ctrl;
        mode_reg <= mode;
        guard_reg <= guard;
      end
    end
    else
    begin
      always @(*)
      begin
        q_m_reg = q_m;
        aux_reg = aux;
        ctrl_reg = ctrl;
        mode_reg = mode;
        guard_reg = guard;
      end
    end
  endgenerate

  assign n1m = q_m_reg[0] + q_m_reg[1] + q_m_reg[2] + q_m_reg[3] + q_m_reg[4] + q_m_reg[5] + q_m_reg[6] + q_m_reg[7];

//DC balancing as defined in the DVI and HDMI specifications
  assign dc_bal_inv = (cnt == 5'd0 || n1m == 4'd4) ? ~q_m_reg[8] : (~cnt[4] && (n1m > 4'd4)) || (cnt[4] && (n1m < 4'd4));

  assign dtoken = (dc_bal_inv) ? {1'b1, q_m_reg[8], ~q_m_reg[7:0]} : {1'b0, q_m_reg[8], q_m_reg[7:0]};
  assign next_cnt = (dc_bal_inv) ? cnt + {3'd0, q_m_reg[8], 1'b0} + 5'd8 - {n1m, 1'b0} : cnt - {3'd0, ~q_m_reg[8], 1'b0} - 5'd8 + {n1m, 1'b0};

//Choosing the control token
  always @(*)
    case (ctrl_reg)
      2'b00: ctrltoken = CTRLTOKEN_0;
      2'b01: ctrltoken = CTRLTOKEN_1;
      2'b10: ctrltoken = CTRLTOKEN_2;
      2'b11: ctrltoken = CTRLTOKEN_3;
    endcase

//Choosing the aux token
  always @(*)
    case (aux_reg)
      4'h0: auxtoken = AUXTOKEN_0;
      4'h1: auxtoken = AUXTOKEN_1;
      4'h2: auxtoken = AUXTOKEN_2;
      4'h3: auxtoken = AUXTOKEN_3;
      4'h4: auxtoken = AUXTOKEN_4;
      4'h5: auxtoken = AUXTOKEN_5;
      4'h6: auxtoken = AUXTOKEN_6;
      4'h7: auxtoken = AUXTOKEN_7;
      4'h8: auxtoken = AUXTOKEN_8;
      4'h9: auxtoken = AUXTOKEN_9;
      4'hA: auxtoken = AUXTOKEN_A;
      4'hB: auxtoken = AUXTOKEN_B;
      4'hC: auxtoken = AUXTOKEN_C;
      4'hD: auxtoken = AUXTOKEN_D;
      4'hE: auxtoken = AUXTOKEN_E;
      4'hF: auxtoken = AUXTOKEN_F;
    endcase

//Choosing the guard token
  always @(*)
    guardtoken = (guard_reg) ? AUXTOKEN_8 : ~AUXTOKEN_8;

//Clocking out the calculated values
  always @(posedge clk)
    case (mode_reg)
      2'b00:
      begin
        tmds_token <= guardtoken;
        cnt <= 5'd0;
      end

      2'b01:
      begin
        tmds_token <= auxtoken;
        cnt <= 5'd0;
      end

      2'b10:
      begin
        tmds_token <= ctrltoken;
        cnt <= 5'd0;
      end

      2'b11: 
      begin
        tmds_token <= dtoken;
        cnt <= next_cnt;
      end
    endcase
endmodule
