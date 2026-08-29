`default_nettype none
module singleport_bram #(
    parameter DEPTH = 512
)(
    input wire CLK,
                	input wire ME,  //input                 : Master Enable (1: selected; 0: not selected)
                	input wire[$clog2(DEPTH)-1:0] ADR,     //input [8:0]   : Address
                	input wire WE,    //input                 : Write Enable (1: Write;  0: Read)
                	input wire[7:0] D, //input [31:0]  : Write Data
                	input wire OE, //input                 : Output Enable (1: enable; 0: disable)
                	output reg[7:0] Q   //output [31:0] : Read Data
);
    reg[7:0] mem[DEPTH];
    always @(posedge CLK)
        if (ME) begin
            if (WE) mem[ADR] <= D;
            else Q <= mem[ADR];
        end
endmodule


module RDPB18_512X8_G1(
		//A side
		input wire CPA,	//input			: Clock
		input wire CSBA,	//input			: Chip Select (0: selected;	1: not selected)
		input wire[8:0] AA,	//input [8:0]	: Address
		input wire WEBA,	//input			: Write Enable (0: Write)
		input wire REBA,	//input			: Read Enable (0: Read)
		input wire OEBA,	//input			: Output Enable (0: enable; 1: disable)
		input wire[7:0] IA,	//input [7:0]	: Write Data
		output reg[7:0] OA,	//output [7:0]	: Read Data
		//B side
		input wire CPB,	//input			: Clock
		input wire CSBB, //input			: Chip Select (0: selected;	1: not selected)
		input wire[8:0] AB, //input [8:0]	: Address
		input wire WEBB, //input			: Write Enable (0: Write)
		input wire REBB, //input			: Read Enable (0: Read)
		input wire OEBB, //input			: Output Enable (0: enable; 1: disable)
		input wire[7:0] IB, //input [7:0]	: Write Data
		output reg[7:0] OB			//output [7:0]	: Read Data
	);

	reg[7:0] mem[512];
	always_ff @(posedge CPA)
		if (!CSBA) begin
			if (!WEBA) mem[AA] <= IA;
			if (!REBA) OA <= mem[AA];
		end

	always_ff @(posedge CPB)
		if (!CSBB) begin
			if (!WEBB) mem[AB] <= IB;
			if (!REBB) OB <= mem[AB];
		end

endmodule

module RSPB18_16KX32M16_G1(
                	input wire CLK,
                	input wire ME,  //input                 : Master Enable (1: selected; 0: not selected)
                	input wire[13:0] ADR,     //input [8:0]   : Address
                	input wire WE,    //input                 : Write Enable (1: Write;  0: Read)
                	input wire[3:0] WEM,  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	input wire[31:0] D, //input [31:0]  : Write Data
                	input wire OE, //input                 : Output Enable (1: enable; 0: disable)
                	output reg[31:0] Q   //output [31:0] : Read Data
        	);

    for (genvar i = 0; i < 4; ++i) begin
        singleport_bram #(.DEPTH(16384)) bram_inst(
            .CLK, .ME, .ADR, .WE(WE & WEM[i]), .D(D[8*i+:8]), .Q(Q[8*i+:8]), .OE
        );
    end
endmodule
module RSPB18_8KX32M16_G1(
                	input wire CLK,
                	input wire ME,  //input                 : Master Enable (1: selected; 0: not selected)
                	input wire[12:0] ADR,     //input [8:0]   : Address
                	input wire WE,    //input                 : Write Enable (1: Write;  0: Read)
                	input wire[3:0] WEM,  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	input wire[31:0] D, //input [31:0]  : Write Data
                	input wire OE, //input                 : Output Enable (1: enable; 0: disable)
                	output reg[31:0] Q   //output [31:0] : Read Data
        	);

    for (genvar i = 0; i < 4; ++i) begin
        singleport_bram #(.DEPTH(8192)) bram_inst(
            .CLK, .ME, .ADR, .WE(WE & WEM[i]), .D(D[8*i+:8]), .Q(Q[8*i+:8]), .OE
        );
    end
endmodule

module RSPB18_4KX32M8_G1(
                	input wire CLK,
                	input wire ME,  //input                 : Master Enable (1: selected; 0: not selected)
                	input wire[11:0] ADR,     //input [8:0]   : Address
                	input wire WE,    //input                 : Write Enable (1: Write;  0: Read)
                	input wire[3:0] WEM,  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	input wire[31:0] D, //input [31:0]  : Write Data
                	input wire OE, //input                 : Output Enable (1: enable; 0: disable)
                	output reg[31:0] Q   //output [31:0] : Read Data
        	);

    for (genvar i = 0; i < 4; ++i) begin
        singleport_bram #(.DEPTH(4096)) bram_inst(
            .CLK, .ME, .ADR, .WE(WE & WEM[i]), .D(D[8*i+:8]), .Q(Q[8*i+:8]), .OE
        );
    end
endmodule

module RSPB18_2KX32M4_G1(
                	input wire CLK,
                	input wire ME,  //input                 : Master Enable (1: selected; 0: not selected)
                	input wire[10:0] ADR,     //input [8:0]   : Address
                	input wire WE,    //input                 : Write Enable (1: Write;  0: Read)
                	input wire[3:0] WEM,  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	input wire[31:0] D, //input [31:0]  : Write Data
                	input wire OE, //input                 : Output Enable (1: enable; 0: disable)
                	output reg[31:0] Q   //output [31:0] : Read Data
        	);

    for (genvar i = 0; i < 4; ++i) begin
        singleport_bram #(.DEPTH(2048)) bram_inst(
            .CLK, .ME, .ADR, .WE(WE & WEM[i]), .D(D[8*i+:8]), .Q(Q[8*i+:8]), .OE
        );
    end
endmodule

module RSPB18_1KX32M8_G1(
                	input wire CLK,
                	input wire ME,  //input                 : Master Enable (1: selected; 0: not selected)
                	input wire[9:0] ADR,     //input [8:0]   : Address
                	input wire WE,    //input                 : Write Enable (1: Write;  0: Read)
                	input wire[3:0] WEM,  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	input wire[31:0] D, //input [31:0]  : Write Data
                	input wire OE, //input                 : Output Enable (1: enable; 0: disable)
                	output reg[31:0] Q   //output [31:0] : Read Data
        	);

    
    for (genvar i = 0; i < 4; ++i) begin
        singleport_bram #(.DEPTH(1024)) bram_inst(
            .CLK, .ME, .ADR, .WE(WE & WEM[i]), .D(D[8*i+:8]), .Q(Q[8*i+:8]), .OE
        );
    end
endmodule


module RSPB18_512X32M4_G1(
                	input wire CLK,
                	input wire ME,  //input                 : Master Enable (1: selected; 0: not selected)
                	input wire[8:0] ADR,     //input [8:0]   : Address
                	input wire WE,    //input                 : Write Enable (1: Write;  0: Read)
                	input wire[3:0] WEM,  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	input wire[31:0] D, //input [31:0]  : Write Data
                	input wire OE, //input                 : Output Enable (1: enable; 0: disable)
                	output reg[31:0] Q   //output [31:0] : Read Data
        	);

   
    for (genvar i = 0; i < 4; ++i) begin
        singleport_bram #(.DEPTH(512)) bram_inst(
            .CLK, .ME, .ADR, .WE(WE & WEM[i]), .D(D[8*i+:8]), .Q(Q[8*i+:8]), .OE
        );
    end
endmodule

module RSPB18_256X32M4_G1(
                	input wire CLK,
                	input wire ME,  //input                 : Master Enable (1: selected; 0: not selected)
                	input wire[7:0] ADR,     //input [8:0]   : Address
                	input wire WE,    //input                 : Write Enable (1: Write;  0: Read)
                	input wire[3:0] WEM,  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	input wire[31:0] D, //input [31:0]  : Write Data
                	input wire OE, //input                 : Output Enable (1: enable; 0: disable)
                	output reg[31:0] Q   //output [31:0] : Read Data
        	);

  
    for (genvar i = 0; i < 4; ++i) begin
        singleport_bram #(.DEPTH(256)) bram_inst(
            .CLK, .ME, .ADR, .WE(WE & WEM[i]), .D(D[8*i+:8]), .Q(Q[8*i+:8]), .OE
        );
    end
endmodule

module RSPB18_128X32M4_G1(
                	input wire CLK,
                	input wire ME,  //input                 : Master Enable (1: selected; 0: not selected)
                	input wire[6:0] ADR,     //input [8:0]   : Address
                	input wire WE,    //input                 : Write Enable (1: Write;  0: Read)
                	input wire[3:0] WEM,  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	input wire[31:0] D, //input [31:0]  : Write Data
                	input wire OE, //input                 : Output Enable (1: enable; 0: disable)
                	output reg[31:0] Q   //output [31:0] : Read Data
        	);

  
    for (genvar i = 0; i < 4; ++i) begin
        singleport_bram #(.DEPTH(128)) bram_inst(
            .CLK, .ME, .ADR, .WE(WE & WEM[i]), .D(D[8*i+:8]), .Q(Q[8*i+:8]), .OE
        );
    end
endmodule


module RSPB18_128X16M8_G1(
                	input wire CLK,
                	input wire ME,  //input                 : Master Enable (1: selected; 0: not selected)
                	input wire[6:0] ADR,     //input [8:0]   : Address
                	input wire WE,    //input                 : Write Enable (1: Write;  0: Read)
                	input wire[1:0] WEM,  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	input wire[15:0] D, //input [31:0]  : Write Data
                	input wire OE, //input                 : Output Enable (1: enable; 0: disable)
                	output reg[15:0] Q   //output [31:0] : Read Data
        	);

    
    for (genvar i = 0; i < 2; ++i) begin
        singleport_bram #(.DEPTH(128)) bram_inst(
            .CLK, .ME, .ADR, .WE(WE & WEM[i]), .D(D[8*i+:8]), .Q(Q[8*i+:8]), .OE
        );
    end
endmodule

module RSPB18_256X16M8_G1(
                	input wire CLK,
                	input wire ME,  //input                 : Master Enable (1: selected; 0: not selected)
                	input wire[7:0] ADR,     //input [8:0]   : Address
                	input wire WE,    //input                 : Write Enable (1: Write;  0: Read)
                	input wire[1:0] WEM,  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	input wire[15:0] D, //input [31:0]  : Write Data
                	input wire OE, //input                 : Output Enable (1: enable; 0: disable)
                	output reg[15:0] Q   //output [31:0] : Read Data
        	);

    
    for (genvar i = 0; i < 2; ++i) begin
        singleport_bram #(.DEPTH(256)) bram_inst(
            .CLK, .ME, .ADR, .WE(WE & WEM[i]), .D(D[8*i+:8]), .Q(Q[8*i+:8]), .OE
        );
    end
endmodule


module RSPB18_512X16M8_G1(
                	input wire CLK,
                	input wire ME,  //input                 : Master Enable (1: selected; 0: not selected)
                	input wire[8:0] ADR,     //input [8:0]   : Address
                	input wire WE,    //input                 : Write Enable (1: Write;  0: Read)
                	input wire[1:0] WEM,  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	input wire[15:0] D, //input [31:0]  : Write Data
                	input wire OE, //input                 : Output Enable (1: enable; 0: disable)
                	output reg[15:0] Q   //output [31:0] : Read Data
        	);

    
    for (genvar i = 0; i < 2; ++i) begin
        singleport_bram #(.DEPTH(512)) bram_inst(
            .CLK, .ME, .ADR, .WE(WE & WEM[i]), .D(D[8*i+:8]), .Q(Q[8*i+:8]), .OE
        );
    end
endmodule

module RSPB18_1KX16M8_G1(
                	input wire CLK,
                	input wire ME,  //input                 : Master Enable (1: selected; 0: not selected)
                	input wire[9:0] ADR,     //input [8:0]   : Address
                	input wire WE,    //input                 : Write Enable (1: Write;  0: Read)
                	input wire[1:0] WEM,  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	input wire[15:0] D, //input [31:0]  : Write Data
                	input wire OE, //input                 : Output Enable (1: enable; 0: disable)
                	output reg[15:0] Q   //output [31:0] : Read Data
        	);

    
    for (genvar i = 0; i < 2; ++i) begin
        singleport_bram #(.DEPTH(1024)) bram_inst(
            .CLK, .ME, .ADR, .WE(WE & WEM[i]), .D(D[8*i+:8]), .Q(Q[8*i+:8]), .OE
        );
    end
endmodule

module RSPB18_2KX16M8_G1(
                	input wire CLK,
                	input wire ME,  //input                 : Master Enable (1: selected; 0: not selected)
                	input wire[10:0] ADR,     //input [8:0]   : Address
                	input wire WE,    //input                 : Write Enable (1: Write;  0: Read)
                	input wire[1:0] WEM,  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	input wire[15:0] D, //input [31:0]  : Write Data
                	input wire OE, //input                 : Output Enable (1: enable; 0: disable)
                	output reg[15:0] Q   //output [31:0] : Read Data
        	);

    
    for (genvar i = 0; i < 2; ++i) begin
        singleport_bram #(.DEPTH(2048)) bram_inst(
            .CLK, .ME, .ADR, .WE(WE & WEM[i]), .D(D[8*i+:8]), .Q(Q[8*i+:8]), .OE
        );
    end
endmodule

module RSPB18_4KX16M8_G1(
                	input wire CLK,
                	input wire ME,  //input                 : Master Enable (1: selected; 0: not selected)
                	input wire[11:0] ADR,     //input [8:0]   : Address
                	input wire WE,    //input                 : Write Enable (1: Write;  0: Read)
                	input wire[1:0] WEM,  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	input wire[15:0] D, //input [31:0]  : Write Data
                	input wire OE, //input                 : Output Enable (1: enable; 0: disable)
                	output reg[15:0] Q   //output [31:0] : Read Data
        	);

    
    for (genvar i = 0; i < 2; ++i) begin
        singleport_bram #(.DEPTH(4096)) bram_inst(
            .CLK, .ME, .ADR, .WE(WE & WEM[i]), .D(D[8*i+:8]), .Q(Q[8*i+:8]), .OE
        );
    end
endmodule

module RSPB18_8KX16M16_G1(
                	input wire CLK,
                	input wire ME,  //input                 : Master Enable (1: selected; 0: not selected)
                	input wire[12:0] ADR,     //input [8:0]   : Address
                	input wire WE,    //input                 : Write Enable (1: Write;  0: Read)
                	input wire[1:0] WEM,  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	input wire[15:0] D, //input [31:0]  : Write Data
                	input wire OE, //input                 : Output Enable (1: enable; 0: disable)
                	output reg[15:0] Q   //output [31:0] : Read Data
        	);

    
    for (genvar i = 0; i < 2; ++i) begin
        singleport_bram #(.DEPTH(8192)) bram_inst(
            .CLK, .ME, .ADR, .WE(WE & WEM[i]), .D(D[8*i+:8]), .Q(Q[8*i+:8]), .OE
        );
    end
endmodule

module RSPB18_16KX16M16_G1(
                	input wire CLK,
                	input wire ME,  //input                 : Master Enable (1: selected; 0: not selected)
                	input wire[13:0] ADR,     //input [8:0]   : Address
                	input wire WE,    //input                 : Write Enable (1: Write;  0: Read)
                	input wire[1:0] WEM,  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	input wire[15:0] D, //input [31:0]  : Write Data
                	input wire OE, //input                 : Output Enable (1: enable; 0: disable)
                	output reg[15:0] Q   //output [31:0] : Read Data
        	);

    
    for (genvar i = 0; i < 2; ++i) begin
        singleport_bram #(.DEPTH(16384)) bram_inst(
            .CLK, .ME, .ADR, .WE(WE & WEM[i]), .D(D[8*i+:8]), .Q(Q[8*i+:8]), .OE
        );
    end
endmodule



module ROHM18INVP010(input wire A, output wire Y);
    assign Y = ~A;
endmodule

module ROHM18INVP040(input wire A, output wire Y);
    assign Y = ~A;
endmodule


