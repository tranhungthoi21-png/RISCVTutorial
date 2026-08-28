`timescale 1ns / 1ps
module keccak_f (
    input               iClk,
    input               iRst,
    input               iActive,
    input      [1599:0] iState,
    input      [63:0]   iRC, 
    output reg [1599:0] oState
);

wire [63:0] A00, A01, A02, A03, A04;
wire [63:0] A10, A11, A12, A13, A14;
wire [63:0] A20, A21, A22, A23, A24;
wire [63:0] A30, A31, A32, A33, A34;
wire [63:0] A40, A41, A42, A43, A44;

assign A00 = iState[1599:1536];
assign A10 = iState[1535:1472];
assign A20 = iState[1471:1408];
assign A30 = iState[1407:1344];
assign A40 = iState[1343:1280];
assign A01 = iState[1279:1216];
assign A11 = iState[1215:1152];
assign A21 = iState[1151:1088];
assign A31 = iState[1087:1024];
assign A41 = iState[1023:960];
assign A02 = iState[959:896];
assign A12 = iState[895:832];
assign A22 = iState[831:768];
assign A32 = iState[767:704];
assign A42 = iState[703:640];
assign A03 = iState[639:576];
assign A13 = iState[575:512];
assign A23 = iState[511:448];
assign A33 = iState[447:384];
assign A43 = iState[383:320];
assign A04 = iState[319:256];
assign A14 = iState[255:192];
assign A24 = iState[191:128];
assign A34 = iState[127:64];
assign A44 = iState[63:0];

wire [63:0] A00_theta, A01_theta, A02_theta, A03_theta, A04_theta;
wire [63:0] A10_theta, A11_theta, A12_theta, A13_theta, A14_theta;
wire [63:0] A20_theta, A21_theta, A22_theta, A23_theta, A24_theta;
wire [63:0] A30_theta, A31_theta, A32_theta, A33_theta, A34_theta;
wire [63:0] A40_theta, A41_theta, A42_theta, A43_theta, A44_theta;
//// Theta
wire [63:0] C0, C1, C2, C3, C4;
assign C0 = A00 ^ A01 ^ A02 ^ A03 ^ A04; //f
assign C1 = A10 ^ A11 ^ A12 ^ A13 ^ A14; //28
assign C2 = A20 ^ A21 ^ A22 ^ A23 ^ A24; //41
assign C3 = A30 ^ A31 ^ A32 ^ A33 ^ A34; //5a
assign C4 = A40 ^ A41 ^ A42 ^ A43 ^ A44; //73

wire [63:0] D0, D1, D2, D3, D4;

assign D0 = C4 ^ {C1[62:0], C1[63]};
assign D1 = C0 ^ {C2[62:0], C2[63]};
assign D2 = C1 ^ {C3[62:0], C3[63]};
assign D3 = C2 ^ {C4[62:0], C4[63]};
assign D4 = C3 ^ {C0[62:0], C0[63]};

assign A00_theta = A00 ^ D0; //50
assign A01_theta = A01 ^ D0;
assign A02_theta = A02 ^ D0;
assign A03_theta = A03 ^ D0;
assign A04_theta = A04 ^ D0;

assign A10_theta = A10 ^ D1; //91
assign A11_theta = A11 ^ D1;
assign A12_theta = A12 ^ D1;
assign A13_theta = A13 ^ D1;
assign A14_theta = A14 ^ D1;

assign A20_theta = A20 ^ D2; //DC
assign A21_theta = A21 ^ D2;
assign A22_theta = A22 ^ D2;
assign A23_theta = A23 ^ D2;
assign A24_theta = A24 ^ D2;

assign A30_theta = A30 ^ D3; //127
assign A31_theta = A31 ^ D3;
assign A32_theta = A32 ^ D3;
assign A33_theta = A33 ^ D3;
assign A34_theta = A34 ^ D3;

assign A40_theta = A40 ^ D4; //78
assign A41_theta = A41 ^ D4;
assign A42_theta = A42 ^ D4;
assign A43_theta = A43 ^ D4;
assign A44_theta = A44 ^ D4;

//// Ham rho-pi
wire [63:0] A00_rhopi, A01_rhopi, A02_rhopi, A03_rhopi, A04_rhopi;
wire [63:0] A10_rhopi, A11_rhopi, A12_rhopi, A13_rhopi, A14_rhopi;
wire [63:0] A20_rhopi, A21_rhopi, A22_rhopi, A23_rhopi, A24_rhopi;
wire [63:0] A30_rhopi, A31_rhopi, A32_rhopi, A33_rhopi, A34_rhopi;
wire [63:0] A40_rhopi, A41_rhopi, A42_rhopi, A43_rhopi, A44_rhopi;

assign A00_rhopi = A00_theta;
assign A01_rhopi = {A30_theta[35:0], A30_theta[63:36]};
assign A02_rhopi = {A10_theta[62:0], A10_theta[63]};
assign A03_rhopi = {A40_theta[36:0], A40_theta[63:37]};
assign A04_rhopi = {A20_theta[ 1:0], A20_theta[63:2 ]};

assign A10_rhopi = {A11_theta[19:0], A11_theta[63:20]};
assign A11_rhopi = {A41_theta[43:0], A41_theta[63:44]};
assign A12_rhopi = {A21_theta[57:0], A21_theta[63:58]};
assign A13_rhopi = {A01_theta[27:0], A01_theta[63:28]};
assign A14_rhopi = {A31_theta[ 8:0], A31_theta[63:9 ]};

assign A20_rhopi = {A22_theta[20:0], A22_theta[63:21]};
assign A21_rhopi = {A02_theta[60:0], A02_theta[63:61]};
assign A22_rhopi = {A32_theta[38:0], A32_theta[63:39]};
assign A23_rhopi = {A12_theta[53:0], A12_theta[63:54]};
assign A24_rhopi = {A42_theta[24:0], A42_theta[63:25]};

assign A30_rhopi = {A33_theta[42:0], A33_theta[63:43]};
assign A31_rhopi = {A13_theta[18:0], A13_theta[63:19]};
assign A32_rhopi = {A43_theta[55:0], A43_theta[63:56]};
assign A33_rhopi = {A23_theta[48:0], A23_theta[63:49]};
assign A34_rhopi = {A03_theta[22:0], A03_theta[63:23]};

assign A40_rhopi = {A44_theta[49:0], A44_theta[63:50]};
assign A41_rhopi = {A24_theta[ 2:0], A24_theta[63:3 ]};
assign A42_rhopi = {A04_theta[45:0], A04_theta[63:46]};
assign A43_rhopi = {A34_theta[ 7:0], A34_theta[63:8 ]};
assign A44_rhopi = {A14_theta[61:0], A14_theta[63:62]};

//// Chi + Iota
wire [63:0] A00_chi, A01_chi, A02_chi, A03_chi, A04_chi;
wire [63:0] A10_chi, A11_chi, A12_chi, A13_chi, A14_chi;
wire [63:0] A20_chi, A21_chi, A22_chi, A23_chi, A24_chi;
wire [63:0] A30_chi, A31_chi, A32_chi, A33_chi, A34_chi;
wire [63:0] A40_chi, A41_chi, A42_chi, A43_chi, A44_chi;

assign A00_chi = A00_rhopi ^ ((~A10_rhopi) & A20_rhopi) ^ iRC;
assign A01_chi = A01_rhopi ^ ((~A11_rhopi) & A21_rhopi);
assign A02_chi = A02_rhopi ^ ((~A12_rhopi) & A22_rhopi);
assign A03_chi = A03_rhopi ^ ((~A13_rhopi) & A23_rhopi);
assign A04_chi = A04_rhopi ^ ((~A14_rhopi) & A24_rhopi);

assign A10_chi = A10_rhopi ^ ((~A20_rhopi) & A30_rhopi);
assign A11_chi = A11_rhopi ^ ((~A21_rhopi) & A31_rhopi);
assign A12_chi = A12_rhopi ^ ((~A22_rhopi) & A32_rhopi);
assign A13_chi = A13_rhopi ^ ((~A23_rhopi) & A33_rhopi);
assign A14_chi = A14_rhopi ^ ((~A24_rhopi) & A34_rhopi);

assign A20_chi = A20_rhopi ^ ((~A30_rhopi) & A40_rhopi);
assign A21_chi = A21_rhopi ^ ((~A31_rhopi) & A41_rhopi);
assign A22_chi = A22_rhopi ^ ((~A32_rhopi) & A42_rhopi);
assign A23_chi = A23_rhopi ^ ((~A33_rhopi) & A43_rhopi);
assign A24_chi = A24_rhopi ^ ((~A34_rhopi) & A44_rhopi);

assign A30_chi = A30_rhopi ^ ((~A40_rhopi) & A00_rhopi);
assign A31_chi = A31_rhopi ^ ((~A41_rhopi) & A01_rhopi);
assign A32_chi = A32_rhopi ^ ((~A42_rhopi) & A02_rhopi);
assign A33_chi = A33_rhopi ^ ((~A43_rhopi) & A03_rhopi);
assign A34_chi = A34_rhopi ^ ((~A44_rhopi) & A04_rhopi);

assign A40_chi = A40_rhopi ^ ((~A00_rhopi) & A10_rhopi);
assign A41_chi = A41_rhopi ^ ((~A01_rhopi) & A11_rhopi);
assign A42_chi = A42_rhopi ^ ((~A02_rhopi) & A12_rhopi);
assign A43_chi = A43_rhopi ^ ((~A03_rhopi) & A13_rhopi);
assign A44_chi = A44_rhopi ^ ((~A04_rhopi) & A14_rhopi);

// output
wire [1599:0] state_out;
assign state_out = {A00_chi, A10_chi, A20_chi, A30_chi, A40_chi, 
                    A01_chi, A11_chi, A21_chi, A31_chi, A41_chi, 
                    A02_chi, A12_chi, A22_chi, A32_chi, A42_chi, 
                    A03_chi, A13_chi, A23_chi, A33_chi, A43_chi, 
                    A04_chi, A14_chi, A24_chi, A34_chi, A44_chi};
                    
always @ (posedge iClk) begin
  if (iRst) 
    oState <= 1600'b0;
  else
    if(iActive) 
        oState <= state_out;
end

endmodule

