`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/23/2023 10:18:55 AM
// Design Name: 
// Module Name: asconp
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// Optimized ASCON permutation - single round
// Reduces intermediate signals and consolidates operations for better synthesis
module asconp (
    input  wire [3:0]  rcon,
    input  wire [63:0] x0_in, x1_in, x2_in, x3_in, x4_in,
    output wire [63:0] x0_out, x1_out, x2_out, x3_out, x4_out
);

// Round constant computation (same as original: t2=12-rcon, rc=(15-t2)|t2 = (15-(12-rcon))|(12-rcon) = (3+rcon)|(12-rcon))
wire [3:0] t2 = 4'hC - rcon;  // t2 = 12 - rcon
wire [7:0] rc = {4'hF - t2, t2};  // rc = ((15-t2) << 4) | t2

// Step 1: Addition of round constants (same as original x_first)
wire [63:0] x0_first = x0_in ^ x4_in;
wire [63:0] x2_first = {x2_in[63:8] ^ x1_in[63:8], x2_in[7:0] ^ x1_in[7:0] ^ rc};
wire [63:0] x4_first = x4_in ^ x3_in;

// Step 2: Nonlinear substitution layer (same as original x_second)
wire [63:0] x0_second = x0_first ^ ((~x1_in) & x2_first);
wire [63:0] x1_second = x1_in ^ ((~x2_first) & x3_in);
wire [63:0] x2_second = x2_first ^ ((~x3_in) & x4_first);
wire [63:0] x3_second = x3_in ^ ((~x4_first) & x0_first);
wire [63:0] x4_second = x4_first ^ ((~x0_first) & x1_in);

// Step 3: Linear layer preparation (same as original x_third)
wire [63:0] x0_third = x0_second ^ x4_second;
wire [63:0] x1_third = x1_second ^ x0_second;
wire [63:0] x2_third = ~x2_second;
wire [63:0] x3_third = x2_second ^ x3_second;
wire [63:0] x4_third = x4_second;

// Step 4: Lane rotations - final output (same as original)
assign x0_out = x0_third ^ {x0_third[18:0], x0_third[63:19]} ^ {x0_third[27:0], x0_third[63:28]}; 
assign x1_out = x1_third ^ {x1_third[60:0], x1_third[63:61]} ^ {x1_third[38:0], x1_third[63:39]}; 
assign x2_out = x2_third ^ {x2_third[0:0],  x2_third[63:1]}  ^ {x2_third[5:0],  x2_third[63:6]}; 
assign x3_out = x3_third ^ {x3_third[9:0],  x3_third[63:10]} ^ {x3_third[16:0], x3_third[63:17]}; 
assign x4_out = x4_third ^ {x4_third[6:0],  x4_third[63:7]}  ^ {x4_third[40:0], x4_third[63:41]}; 

endmodule
