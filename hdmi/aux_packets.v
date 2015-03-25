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

//32kHz audio, expects 64MHz video clock and horizonztal refresh higher than 32kHz
module hdmi_audio
 (input clk,
  input ae,
  input [4:0] aux_slot,

  input [15:0] audio_sample_left,
  input [15:0] audio_sample_right,
  output reg sample_strobe,

  input regen_enable,
  output regen_ready,
  output regen_header,
  output [1:0] regen_sub0,
  output [1:0] regen_sub1,
  output [1:0] regen_sub2,
  output [1:0] regen_sub3,

  input sample_enable,
  output sample_ready,
  output sample_header,
  output [1:0] sample_sub0,
  output [1:0] sample_sub1,
  output [1:0] sample_sub2,
  output [1:0] sample_sub3);

  //Fixed Channel Status Block sent along with the audio data
  localparam [191:0] CSB = 192'h00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_C2_03_00_40_04;
  //Audio sample packet header 
  localparam [31:0] SHDR = 32'h00_10_01_02;

  reg [10:0] sample_counter = 0; //32kHz sample rate counter, counts from 64MHz and overflows at 32kHz
  reg [7:0]  other_counter = 0; //regen count and channel status count can be done together with the other counter

//  reg [15:0] sbl = 0; //sample buffer for the left channel
//  reg [15:0] sbr = 0; //sample buffer for the right channel
  reg [3:0] sblhiodd = 0;
  reg [3:0] sblhieven = 0;
  reg [3:0] sblloodd = 0;
  reg [3:0] sblloeven = 0;
  reg [3:0] sbrhiodd = 0;
  reg [3:0] sbrhieven = 0;
  reg [3:0] sbrloodd = 0;
  reg [3:0] sbrloeven = 0;

  wire [1:0] parity; //parity of the sample buffers, [1]=right channel parity, [0]=left channel parity

  reg regen_trigger = 0; //Signals when it is time to send another audio clock regeneration packet

  reg new_sample_header = 0; //Header bits for the audio sample packet entering the packet buffer next
  reg [1:0] new_sample_sub0 = 0; //Body bits for the audio sample packet entering the packet buffer next

  assign parity = {^{sbrhiodd,sbrhieven,sbrloodd,sbrloeven,CSB[other_counter]}, ^{sblhiodd,sblhieven,sblloodd,sblloeven,CSB[other_counter]}};

  //Audio sample packet headers stay the same except for the B.0 bit that is set to 1 for every 192th packet
  always @(*)
    if (aux_slot == 5'd20)
      new_sample_header = (other_counter == 0) ? 1'b1 : 1'b0;
    else
      new_sample_header = SHDR[aux_slot[4:0]];


  //The body of the audio sample packet is generated here by copying bits from
  //The sample buffers, parity and Channel Status Block where appropriate 

  always @(*)
/*
    if (aux_slot < 5'd4)
      new_sample_sub0 = 2'b00;
    else if (aux_slot < 5'd12)
      new_sample_sub0 = {sbl[(aux_slot-4)*2+1],sbl[(aux_slot-4)*2]};
    else if (aux_slot < 5'd16)
      new_sample_sub0 = 2'b00;
    else if (aux_slot < 5'd24)
      new_sample_sub0 = {sbr[(aux_slot-16)*2+1],sbr[(aux_slot-16)*2]};
    else
      new_sample_sub0 = (~aux_slot[0]) ? 2'b00 : {parity[aux_slot[1]], CSB[other_counter]};
*/
  case (aux_slot[4:2])
    3'h1 :    new_sample_sub0 = {sblloodd[aux_slot[1:0]], sblloeven[aux_slot[1:0]]};
    3'h2 :    new_sample_sub0 = {sblhiodd[aux_slot[1:0]], sblhieven[aux_slot[1:0]]};
    3'h4 :    new_sample_sub0 = {sbrloodd[aux_slot[1:0]], sbrloeven[aux_slot[1:0]]};
    3'h5 :    new_sample_sub0 = {sbrhiodd[aux_slot[1:0]], sbrhieven[aux_slot[1:0]]};
    3'h6 :    new_sample_sub0 = (~aux_slot[0]) ? 2'b00 : {parity[aux_slot[1]], CSB[other_counter]};
    default : new_sample_sub0 = 2'b00;
  endcase


  //Counter that counts the sample rate from the video clock
  //And signals samples to be sent
  always @(posedge clk)
    if (sample_counter >= 1999)
    begin
      sample_counter <= 0;
      sample_strobe <= 1'b1;
    end
    else
    begin
      sample_counter <= sample_counter + 1;
      sample_strobe <= 1'b0;
    end

  //The other counter that counts sent sample packets and
  //signals the correct timings for audio clock regeneration
  //packets and the audio sample packet preamble bit.
  //Also the audio data itself is generated and buffered here
  always @(posedge clk)
    if (sample_strobe)
    begin
      if (other_counter[4:0] == 31)
        regen_trigger <= 1'b1;
      else
        regen_trigger <= 1'b0;

      if (other_counter >= 191)
        other_counter <= 0;
      else
        other_counter <= other_counter + 1;

      sblhiodd = {audio_sample_left[15], audio_sample_left[13], audio_sample_left[11], audio_sample_left[9]};
      sblhieven = {audio_sample_left[14], audio_sample_left[12], audio_sample_left[10], audio_sample_left[8]};
      sblloodd = {audio_sample_left[7], audio_sample_left[5], audio_sample_left[3], audio_sample_left[1]};
      sblloeven = {audio_sample_left[6], audio_sample_left[4], audio_sample_left[2], audio_sample_left[0]};

      sbrhiodd = {audio_sample_right[15], audio_sample_right[13], audio_sample_right[11], audio_sample_right[9]};
      sbrhieven = {audio_sample_right[14], audio_sample_right[12], audio_sample_right[10], audio_sample_right[8]};
      sbrloodd = {audio_sample_right[7], audio_sample_right[5], audio_sample_right[3], audio_sample_right[1]};
      sbrloeven = {audio_sample_right[6], audio_sample_right[4], audio_sample_right[2], audio_sample_right[0]};
    end
    else
    begin
      regen_trigger <= 1'b0;
      other_counter <= other_counter;
      sblhiodd = sblhiodd;
      sblhieven = sblhieven;
      sblloodd = sblloodd;
      sblloeven = sblloeven;

      sbrhiodd = sbrhiodd;
      sbrhieven = sbrhieven;
      sbrloodd = sbrloodd;
      sbrloeven = sbrloeven;
    end

  //Audio clock regeneration packet buffer
  fixed_aux_packet 
  #(.HEADER(32'h00_00_00_01),
    .SP0(64'h00_00_10_00_00_FA_00_00),
    .SP1(64'h00_00_10_00_00_FA_00_00),
    .SP2(64'h00_00_10_00_00_FA_00_00),
    .SP3(64'h00_00_10_00_00_FA_00_00))
  audio_clk_regen
   (.clk(clk),
    .trigger(regen_trigger),
    .enable(regen_enable),
    .ae(ae),
    .slot(aux_slot[4:0]),
    .ready(regen_ready),
    .header(regen_header),
    .sub0(regen_sub0[1:0]),
    .sub1(regen_sub1[1:0]),
    .sub2(regen_sub2[1:0]),
    .sub3(regen_sub3[1:0]));

  //Audio sample packet buffer
  aux_packet 
  #(.HEADER(SHDR),
    .SP0(64'h00_00_00_00_00_00_00_00),
    .SP1(64'h00_00_00_00_00_00_00_00),
    .SP2(64'h00_00_00_00_00_00_00_00),
    .SP3(64'h00_00_00_00_00_00_00_00))
  audio_sample_frame
   (.clk(clk),
    .trigger(sample_strobe),
    .enable(sample_enable),
    .ae(ae),
    .slot(aux_slot[4:0]),
    .ready(sample_ready),
    .header(sample_header),
    .sub0(sample_sub0[1:0]),
    .sub1(sample_sub1[1:0]),
    .sub2(sample_sub2[1:0]),
    .sub3(sample_sub3[1:0]),
    .write_enable(1'b1),
    .header_in(new_sample_header),
    .sub0_in(new_sample_sub0[1:0]),
    .sub1_in(2'b00),
    .sub2_in(2'b00),
    .sub3_in(2'b00));
endmodule



//A module to contain a fixed aux packet.
module fixed_aux_packet
#(parameter [31:0] HEADER = 32'h0,
  parameter [63:0] SP0 = 64'h0,
  parameter [63:0] SP1 = 64'h0,
  parameter [63:0] SP2 = 64'h0,
  parameter [63:0] SP3 = 64'h0)

 (input clk,
  input [4:0] slot, //Current aux time slot
  input trigger, //Trigger to start the packet sending process
  input enable, //A signal that sending of this packet is starting
  input ae,     //Aux enable to tell that we are now sending an aux packet payload
  output reg ready = 0, //An output to signal that this packet needs to be sent
  output reg header,
  output reg [1:0] sub0,
  output reg [1:0] sub1,
  output reg [1:0] sub2,
  output reg [1:0] sub3);




  always @(posedge clk) 
  begin
    header <= HEADER[slot];
    sub0[1:0] <= {SP0[({1'b0,slot}<<1)+1], SP0[{1'b0,slot}<<1]};
    sub1[1:0] <= {SP1[({1'b0,slot}<<1)+1], SP1[{1'b0,slot}<<1]};
    sub2[1:0] <= {SP2[({1'b0,slot}<<1)+1], SP2[{1'b0,slot}<<1]};
    sub3[1:0] <= {SP3[({1'b0,slot}<<1)+1], SP3[{1'b0,slot}<<1]};

    if (trigger)
      ready <= 1'b1;
    else if (ae & enable)
      ready <= 1'b0;
  end

endmodule


//A module to contain modifiable aux packets
module aux_packet
#(parameter [31:0] HEADER = 32'h0,
  parameter [63:0] SP0 = 64'h0,
  parameter [63:0] SP1 = 64'h0,
  parameter [63:0] SP2 = 64'h0,
  parameter [63:0] SP3 = 64'h0)

 (input clk,
  input [4:0] slot,   //Current aux time slot
  input write_enable, //Enable write to the packet buffer
  input header_in,    //Data lines that carry the data to be written in
  input [1:0] sub0_in,
  input [1:0] sub1_in,
  input [1:0] sub2_in,
  input [1:0] sub3_in,
  input trigger,      //Trigger to start the packet sending process
  input enable,       //Indication that sending of this packet has started
  input ae,           //Aux enable to tell that we are sending an aux packet payload
  output reg ready = 0, //An output to signal that this packet needs to be sent
  output reg header = 0,
  output reg [1:0] sub0 = 0,
  output reg [1:0] sub1 = 0,
  output reg [1:0] sub2 = 0,
  output reg [1:0] sub3 = 0);


  //Initial values of the packet buffer are taken from the module parameters
  reg [31:0] header_mem = HEADER[31:0];

  reg [31:0] sub0even_mem = {SP0[62], SP0[60], SP0[58], SP0[56], SP0[54], SP0[52], SP0[50], SP0[48],
                             SP0[46], SP0[44], SP0[42], SP0[40], SP0[38], SP0[36], SP0[34], SP0[32],
                             SP0[30], SP0[28], SP0[26], SP0[24], SP0[22], SP0[20], SP0[18], SP0[16],
                             SP0[14], SP0[12], SP0[10], SP0[8],  SP0[6],  SP0[4],  SP0[2],  SP0[0]};
  reg [31:0] sub0odd_mem = {SP0[63], SP0[61], SP0[59], SP0[57], SP0[55], SP0[53], SP0[51], SP0[49],
                            SP0[47], SP0[45], SP0[43], SP0[41], SP0[39], SP0[37], SP0[35], SP0[33],
                            SP0[31], SP0[29], SP0[27], SP0[25], SP0[23], SP0[21], SP0[19], SP0[17],
                            SP0[15], SP0[13], SP0[11], SP0[9],  SP0[7],  SP0[5],  SP0[3],  SP0[1]};

  reg [31:0] sub1even_mem = {SP1[62], SP1[60], SP1[58], SP1[56], SP1[54], SP1[52], SP1[50], SP1[48],
                             SP1[46], SP1[44], SP1[42], SP1[40], SP1[38], SP1[36], SP1[34], SP1[32],
                             SP1[30], SP1[28], SP1[26], SP1[24], SP1[22], SP1[20], SP1[18], SP1[16],
                             SP1[14], SP1[12], SP1[10], SP1[8],  SP1[6],  SP1[4],  SP1[2],  SP1[0]};
  reg [31:0] sub1odd_mem = {SP1[63], SP1[61], SP1[59], SP1[57], SP1[55], SP1[53], SP1[51], SP1[49],
                            SP1[47], SP1[45], SP1[43], SP1[41], SP1[39], SP1[37], SP1[35], SP1[33],
                            SP1[31], SP1[29], SP1[27], SP1[25], SP1[23], SP1[21], SP1[19], SP1[17],
                            SP1[15], SP1[13], SP1[11], SP1[9],  SP1[7],  SP1[5],  SP1[3],  SP1[1]};

  reg [31:0] sub2even_mem = {SP2[62], SP2[60], SP2[58], SP2[56], SP2[54], SP2[52], SP2[50], SP2[48],
                             SP2[46], SP2[44], SP2[42], SP2[40], SP2[38], SP2[36], SP2[34], SP2[32],
                             SP2[30], SP2[28], SP2[26], SP2[24], SP2[22], SP2[20], SP2[18], SP2[16],
                             SP2[14], SP2[12], SP2[10], SP2[8],  SP2[6],  SP2[4],  SP2[2],  SP2[0]};
  reg [31:0] sub2odd_mem = {SP2[63], SP2[61], SP2[59], SP2[57], SP2[55], SP2[53], SP2[51], SP2[49],
                            SP2[47], SP2[45], SP2[43], SP2[41], SP2[39], SP2[37], SP2[35], SP2[33],
                            SP2[31], SP2[29], SP2[27], SP2[25], SP2[23], SP2[21], SP2[19], SP2[17],
                            SP2[15], SP2[13], SP2[11], SP2[9],  SP2[7],  SP2[5],  SP2[3],  SP2[1]};

  reg [31:0] sub3even_mem = {SP3[62], SP3[60], SP3[58], SP3[56], SP3[54], SP3[52], SP3[50], SP3[48],
                             SP3[46], SP3[44], SP3[42], SP3[40], SP3[38], SP3[36], SP3[34], SP3[32],
                             SP3[30], SP3[28], SP3[26], SP3[24], SP3[22], SP3[20], SP3[18], SP3[16],
                             SP3[14], SP3[12], SP3[10], SP3[8],  SP3[6],  SP3[4],  SP3[2],  SP3[0]};
  reg [31:0] sub3odd_mem = {SP3[63], SP3[61], SP3[59], SP3[57], SP3[55], SP3[53], SP3[51], SP3[49],
                            SP3[47], SP3[45], SP3[43], SP3[41], SP3[39], SP3[37], SP3[35], SP3[33],
                            SP3[31], SP3[29], SP3[27], SP3[25], SP3[23], SP3[21], SP3[19], SP3[17],
                            SP3[15], SP3[13], SP3[11], SP3[9],  SP3[7],  SP3[5],  SP3[3],  SP3[1]};



  always @(posedge clk)
  begin
    header <= header_mem[slot];
    sub0[1:0] <= {sub0odd_mem[slot], sub0even_mem[slot]};
    sub1[1:0] <= {sub1odd_mem[slot], sub1even_mem[slot]};
    sub2[1:0] <= {sub2odd_mem[slot], sub2even_mem[slot]};
    sub3[1:0] <= {sub3odd_mem[slot], sub3even_mem[slot]};

    if (write_enable)
    begin
      header_mem[slot] <= header_in;
      sub0even_mem[slot] <= sub0_in[0];
      sub0odd_mem[slot] <= sub0_in[1];
      sub1even_mem[slot] <= sub1_in[0];
      sub1odd_mem[slot] <= sub1_in[1];
      sub2even_mem[slot] <= sub2_in[0];
      sub2odd_mem[slot] <= sub2_in[1];
      sub3even_mem[slot] <= sub3_in[0];
      sub3odd_mem[slot] <= sub3_in[1];
    end

  //Keep the ready signal up from the moment when we receive the trigger to
  //until we are sending the payload of this packet
    if (trigger)
      ready <= 1'b1;
    else if (ae & enable)
      ready <= 1'b0;
  end
endmodule
