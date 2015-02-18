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

//A ring buffer for the serializers. Made with the 
//Spartan-3A hardware in mind, so the clear input 
//is implemeted as a collection of AND gates. 
//This might not be optimal for some other devices,
//but for Spartan-3A it is somewhat faster than using
//the clear input on the flip-flop itself and the ANDs
//fit in the same LUTs together with the load multiplexes,
//so no extra resources are used. 
module ring_buffer #(parameter SIZE = 5)
 (input clear,
  input load,
  input clk,
  input [SIZE-1:0] p_in,
  output s_out);

  reg  [SIZE-1:0] ring;
  wire [SIZE-1:0] next;

  assign s_out = ring[0];

  assign next[SIZE-1] = ~clear & (load) ? p_in[SIZE-1] : ring[0];
  genvar i;
  generate
    for (i = SIZE-1; i > 0; i = i - 1)
    begin : shifter
      assign next[i-1] = ~clear & (load) ? p_in[i-1] : ring[i];
    end
  endgenerate

  always @(posedge clk)
  begin
      ring <= next;
  end
endmodule
