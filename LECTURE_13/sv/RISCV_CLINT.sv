//`default_nettype none
//module RISCV_CLINT64(
//    input wire clk,
//    input wire rstn,

    
//    slv_interface.slv bus_if,
//    output wire[63:0] out_mtime,
//    output wire out_MTIP0,
//    output wire out_MSIP0
//);

//    reg msip0_q;
//    reg[63:0] mtimecmp0;
//    reg[63:0] mtime;
//    reg rvalid;
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            rvalid <= 1'b0;
//        else
//            rvalid <= bus_if.avalid;
//    assign bus_if.rvalid = rvalid;
//    reg[63:0] rdata;
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            rdata <= '0;
//        else if (bus_if.avalid) begin
//            case ({bus_if.addr[15:2], 2'd0})
//                16'h0000: rdata <= msip0_q;
//                16'h4000: rdata <= mtimecmp0;
//                16'hC000: rdata <= mtime;
//                default: rdata <= '0;
//            endcase
//        end
//    assign bus_if.rdata = rdata;
//    assign bus_if.aready = 1'b1;
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn) begin
//            mtimecmp0 <= '0;
//            msip0_q <= 1'b0;
//            mtime <= '0;
//        end else begin
//            mtime <= mtime + 1;
//            if (bus_if.avalid && bus_if.awren)
//                case ({bus_if.addr[15:2], 2'd0})
//                    16'h0000: msip0_q <= bus_if.awdata[0];
//                    16'h4000: mtimecmp0 <= bus_if.awdata[63:0];
//                    //16'hC000: mtime <= bus_if.awdata[63:0];
//                endcase
//        end
//    reg assert_MTIP0;
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn) begin
//            assert_MTIP0 <= 1'b0;
//        end else begin
//            assert_MTIP0 <= mtime >= mtimecmp0;
//        end

//    assign out_mtime = mtime;
//    assign out_MTIP0 = assert_MTIP0;
//    assign out_MSIP0 = msip0_q;

//endmodule


//module RISCV_PLIC31 #(
//    parameter NUM_DEVICES = 1,
//    parameter THRESHOLD_BITS = 3
//) (
//    input wire clk,
//    input wire rstn,
//    slv_interface.slv bus_if,
	 
//	input wire[NUM_DEVICES-1:0] sources_irq,
	 
//    output reg out_MEIP0,
//	output reg out_SEIP0
//);

//    localparam INTERRUPT_NUM_BITS = 5;
//    localparam TARGET_NUM_BITS = 12;
//	typedef enum logic[2:0] {
//		COMPLETED = 1 << 0,
//		PENDING = 1 << 1,
//		CLAIMED = 1 << 2
//	} IRQ_STATE;

//	IRQ_STATE sources_state[1:NUM_DEVICES];
//    reg[THRESHOLD_BITS-1:0] sources_priority[1:NUM_DEVICES];

//	wire[NUM_DEVICES:0] source0to31_pending;
//    assign source0to31_pending[0] = 1'b0;
//    for (genvar i = 1; i <= NUM_DEVICES; ++i) begin
//        assign source0to31_pending[i] = sources_state[i] == PENDING;
//    end
	
//	reg[NUM_DEVICES:0] source0to31_enable_context0;
//	reg[NUM_DEVICES:0] source0to31_enable_context1;


	
	
//    reg[INTERRUPT_NUM_BITS-1:0] context0_claim_result;
//    reg[THRESHOLD_BITS-1:0] context0_highest_priority;
//    always_comb begin
//        context0_claim_result = 0;
//        context0_highest_priority = 0;
//        for (int i = 1; i <= NUM_DEVICES; ++i) begin
//            if (source0to31_pending[i] && source0to31_enable_context0[i] && sources_priority[i] > context0_highest_priority) begin
//                context0_claim_result = i;
//                context0_highest_priority = sources_priority[i];
//            end
//        end
//    end

//    reg[INTERRUPT_NUM_BITS-1:0] context1_claim_result;
//    reg[THRESHOLD_BITS-1:0] context1_highest_priority;
//    always_comb begin
//        context1_claim_result = 0;
//        context1_highest_priority = 0;
//        for (int i = 1; i <= NUM_DEVICES; ++i) begin
//            if (source0to31_pending[i] && source0to31_enable_context1[i] && sources_priority[i] > context1_highest_priority) begin
//                context1_claim_result = i;
//                context1_highest_priority = sources_priority[i];
//            end
//        end
//    end
    
//	for (genvar i = 1; i <= NUM_DEVICES; ++i) begin
//        reg[11:0] claimed_target;
//        always_ff @(posedge clk or negedge rstn)
//            if (!rstn) begin
//                sources_state[i] <= COMPLETED;
//                claimed_target <= '0;
//            end
//            else case (sources_state[i])
//                COMPLETED: if (sources_irq[i-1]) sources_state[i] <= PENDING;
//                PENDING: if (bus_if.avalid && !bus_if.awren && 
//                            {bus_if.addr[11:2], 2'b00} == 12'h004) begin
//                    if (bus_if.addr[23:12] == 12'h200 && context0_claim_result == i ||
//                        bus_if.addr[23:12] == 12'h201 && context1_claim_result == i) begin
//                        sources_state[i] <= CLAIMED;
//                        claimed_target <= bus_if.addr[23:12];
//                    end
//                end
//                CLAIMED: if (bus_if.avalid && bus_if.awren && bus_if.awdata[INTERRUPT_NUM_BITS-1:0] == i &&
//                            {bus_if.addr[11:2], 2'b00} == 12'h004) begin
//                    if (bus_if.addr[23:12] == claimed_target)
//                        sources_state[i] <= COMPLETED;
//                end
//            endcase
//    end
	
	
//	reg[THRESHOLD_BITS-1:0] context0_threshold;
//	reg[THRESHOLD_BITS-1:0] context1_threshold;

//    reg[31:0] rdata;
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            rdata <= '0;
//        else if (bus_if.avalid) begin
//            case ({bus_if.addr[23:2], 2'd0})
                
//                24'h001000: rdata <= source0to31_pending;
                
//                24'h002000: rdata <= source0to31_enable_context0;
//                24'h002080: rdata <= source0to31_enable_context1;
					 
//				24'h200000: rdata <= context0_threshold;
//				24'h200004: rdata <= context0_claim_result;

//				24'h201000: rdata <= context1_threshold;
//				24'h201004: rdata <= context1_claim_result;
//                default: rdata <= '0;
//            endcase
            
//            if (bus_if.addr[23:2] >= 1 && bus_if.addr[23:2] <= NUM_DEVICES)
//                rdata <= sources_priority[bus_if.addr[23:2]];
//        end
//    reg rvalid;
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            rvalid <= 1'b0;
//        else
//            rvalid <= bus_if.avalid;
//    assign bus_if.rvalid = rvalid;
//    assign bus_if.aready = 1'b1;
//    assign bus_if.rdata = rdata;
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn) begin
//            sources_priority <= '{default: '0};
//            source0to31_enable_context0 <= '0;
//            source0to31_enable_context1 <= '0;
//            context0_threshold <= '0;
//            context1_threshold <= '0;
//        end else if (bus_if.avalid & bus_if.awren) begin
//            if (bus_if.addr[23:2] >= 1 && bus_if.addr[23:2] <= NUM_DEVICES)
//                sources_priority[bus_if.addr[23:2]] <= bus_if.awdata[THRESHOLD_BITS-1:0];
//            case ({bus_if.addr[23:2], 2'd0})
                
//                24'h002000: source0to31_enable_context0 <= {bus_if.awdata[NUM_DEVICES:1], 1'b0};
//				24'h002080: source0to31_enable_context1 <= {bus_if.awdata[NUM_DEVICES:1], 1'b0};
					 
//				24'h200000: context0_threshold <= bus_if.awdata[THRESHOLD_BITS-1:0];
//				24'h201000: context1_threshold <= bus_if.awdata[THRESHOLD_BITS-1:0];
//            endcase
//        end


	
	
//	always_ff @(posedge clk or negedge rstn)
//		if (!rstn) begin
//			out_MEIP0 <= 1'b0;
//			out_SEIP0 <= 1'b0;
//		end else begin
//			out_MEIP0 <= context0_highest_priority > context0_threshold;
//			out_SEIP0 <= context1_highest_priority > context1_threshold;
//		end
//endmodule


//module count_trailing_zero256(
//    input wire[255:0] in,
//    output reg[7:0] out
//);
//    reg[255:0] temp;
    
//    always_comb begin
//        //out = $countones((in & -in) - 1);
//        out = 0;
//        temp = in;
//        if (!temp[127:0]) begin
//            out |= 128;
//            temp >>= 128;
//        end
//        if (!temp[63:0]) begin
//            out |= 64;
//            temp >>= 64;
//        end
//        if (!temp[31:0]) begin
//            out |= 32;
//            temp >>= 32;
//        end
//        if (!temp[15:0]) begin
//            out |= 16;
//            temp >>= 16;
//        end
//        if (!temp[7:0]) begin
//            out |= 8;
//            temp >>= 8;
//        end
//        if (!temp[3:0]) begin
//            out |= 4;
//            temp >>= 4;
//        end
//        if (!temp[1:0]) begin
//            out |= 2;
//            temp >>= 2;
//        end
        
//        if (!temp[0]) begin
//            out |= 1;
//        end
//    end


//endmodule


//module RISCV_PLIC31_OPT #(
//    parameter NUM_DEVICES = 1,
//    parameter THRESHOLD_BITS = 3
//) (
//    input wire clk,
//    input wire rstn,
//    slv_interface.slv bus_if,
	 
//	input wire[NUM_DEVICES-1:0] sources_irq,
	 
//    output reg out_MEIP0,
//	output reg out_SEIP0
//);

//    localparam INTERRUPT_NUM_BITS = 5;
//    localparam TARGET_NUM_BITS = 12;
//	typedef enum logic[2:0] {
//		COMPLETED = 1 << 0,
//		PENDING = 1 << 1,
//		CLAIMED = 1 << 2
//	} IRQ_STATE;

//	IRQ_STATE sources_state[1:NUM_DEVICES];
//    reg[THRESHOLD_BITS-1:0] sources_priority[1:NUM_DEVICES];

//	wire[NUM_DEVICES:0] source0to31_pending;
//    assign source0to31_pending[0] = 1'b0;
//    for (genvar i = 1; i <= NUM_DEVICES; ++i) begin
//        assign source0to31_pending[i] = sources_state[i] == PENDING;
//    end
	
//	reg[NUM_DEVICES:0] source0to31_enable_context0;
//	reg[NUM_DEVICES:0] source0to31_enable_context1;

//    reg[7:1] sources_priority_i_one_hot[1:NUM_DEVICES];
    
    
//	for (genvar p = 7; p > 0; --p) begin
//        for (genvar i = 1; i <= NUM_DEVICES; ++i) begin
//            always_ff @(posedge clk or negedge rstn)
//                if (!rstn)
//                    sources_priority_i_one_hot[i][p] <= 1'b0;
//                else
//                    sources_priority_i_one_hot[i][p] <= source0to31_enable_context1[i] && sources_priority[i] == p;
//        end
//    end
	
//    wire[255:0] context0_irq_array;
//    wire[255:0] context1_irq_array;
//    for (genvar p = 7; p > 0; --p) begin
//        assign context0_irq_array[(7-p)*32+0] = 1'b0;
//        assign context1_irq_array[(7-p)*32+0] = 1'b0;
//        for (genvar i = 1; i <= NUM_DEVICES; ++i) begin
//            assign context0_irq_array[(7-p)*32+i] = source0to31_pending[i] && sources_priority_i_one_hot[i][p];
//            assign context1_irq_array[(7-p)*32+i] = source0to31_pending[i] && sources_priority_i_one_hot[i][p];
//        end
//    end
//    for (genvar i = 0; i <= NUM_DEVICES; ++i) begin
//            assign context0_irq_array[7*32+i] = 1'b1;
//            assign context1_irq_array[7*32+i] = 1'b1;
//        end
    
//    wire[7:0] ctz_context0;
//    wire[7:0] ctz_context1;
//    count_trailing_zero256 ctz0(.in(context0_irq_array), .out(ctz_context0));
//    count_trailing_zero256 ctz1(.in(context1_irq_array), .out(ctz_context1));
    
//    wire[INTERRUPT_NUM_BITS-1:0] context0_claim_result     = ctz_context0[4:0];
//    wire[THRESHOLD_BITS-1:0]     context0_highest_priority = ~ctz_context0[7:5];
//    wire[INTERRUPT_NUM_BITS-1:0] context1_claim_result     = ctz_context1[4:0];
//    wire[THRESHOLD_BITS-1:0]     context1_highest_priority = ~ctz_context1[7:5];
    
    
//	for (genvar i = 1; i <= NUM_DEVICES; ++i) begin
//        reg[11:0] claimed_target;
//        always_ff @(posedge clk or negedge rstn)
//            if (!rstn) begin
//                sources_state[i] <= COMPLETED;
//                claimed_target <= '0;
//            end else case (sources_state[i])
//                COMPLETED: if (sources_irq[i-1]) sources_state[i] <= PENDING;
//                PENDING: if (bus_if.avalid && !bus_if.awren && 
//                            {bus_if.addr[11:2], 2'b00} == 12'h004) begin
//                        claimed_target <= bus_if.addr[23:12];
//                    if (bus_if.addr[23:12] == 12'h200 && context0_claim_result == i ||
//                        bus_if.addr[23:12] == 12'h201 && context1_claim_result == i) begin
//                        sources_state[i] <= CLAIMED;
//                    end
//                end
//                CLAIMED: if (bus_if.avalid && bus_if.awren && bus_if.awdata[INTERRUPT_NUM_BITS-1:0] == i &&
//                            {bus_if.addr[11:2], 2'b00} == 12'h004) begin
//                    if (bus_if.addr[23:12] == claimed_target)
//                        sources_state[i] <= COMPLETED;
//                end
//            endcase
//    end
	
	
//	reg[THRESHOLD_BITS-1:0] context0_threshold;
//	reg[THRESHOLD_BITS-1:0] context1_threshold;

//    reg[31:0] rdata;
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            rdata <= '0;
//        else if (bus_if.avalid) begin
//            case ({bus_if.addr[23:2], 2'd0})
                
//                24'h001000: rdata <= source0to31_pending;
                
//                24'h002000: rdata <= source0to31_enable_context0;
//                24'h002080: rdata <= source0to31_enable_context1;
					 
//				24'h200000: rdata <= context0_threshold;
//				24'h200004: rdata <= context0_claim_result;

//				24'h201000: rdata <= context1_threshold;
//				24'h201004: rdata <= context1_claim_result;
//                default: rdata <= '0;
//            endcase
            
//            if (bus_if.addr[23:2] >= 1 && bus_if.addr[23:2] <= NUM_DEVICES)
//                rdata <= sources_priority[bus_if.addr[23:2]];
//        end
//    reg rvalid;
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            rvalid <= 1'b0;
//        else
//            rvalid <= bus_if.avalid;
//    assign bus_if.rvalid = rvalid;
//    assign bus_if.aready = 1'b1;
//    assign bus_if.rdata = rdata;
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn) begin
//            sources_priority <= '{default: '0};
//            source0to31_enable_context0 <= '0;
//            source0to31_enable_context1 <= '0;
//            context0_threshold <= '0;
//            context1_threshold <= '0;
//        end else if (bus_if.avalid & bus_if.awren) begin
//            if (bus_if.addr[23:2] >= 1 && bus_if.addr[23:2] <= NUM_DEVICES)
//                sources_priority[bus_if.addr[23:2]] <= bus_if.awdata[THRESHOLD_BITS-1:0];
//            case ({bus_if.addr[23:2], 2'd0})
                
//                24'h002000: source0to31_enable_context0 <= {bus_if.awdata[NUM_DEVICES:1], 1'b0};
//				24'h002080: source0to31_enable_context1 <= {bus_if.awdata[NUM_DEVICES:1], 1'b0};
					 
//				24'h200000: context0_threshold <= bus_if.awdata[THRESHOLD_BITS-1:0];
//				24'h201000: context1_threshold <= bus_if.awdata[THRESHOLD_BITS-1:0];
//            endcase
//        end


	
	
//	always_ff @(posedge clk or negedge rstn)
//		if (!rstn) begin
//			out_MEIP0 <= 1'b0;
//			out_SEIP0 <= 1'b0;
//		end else begin
//			out_MEIP0 <= context0_highest_priority > context0_threshold;
//			out_SEIP0 <= context1_highest_priority > context1_threshold;
//		end
//endmodule





//module count_trailing_zero128(
//    input wire[127:0] in,
//    output wire[6:0] out
//);

//    wire add64 = !in[63:0];
//    wire[63:0] in64 = add64 ? in[127:64] : in[63:0];
//    wire add32 = !in64[31:0];
//    wire[31:0] in32 = add32 ? in64[63:32] : in64[31:0];
//    wire add16 = !in32[15:0];
//    wire[15:0] in16 = add16 ? in32[31:16] : in32[15:0];
//    wire add8 = !in16[7:0];
//    wire[7:0] in8 = add8 ? in16[15:8] : in16[7:0];
//    wire add4 = !in8[3:0];
//    wire[3:0] in4 = add4 ? in8[7:4] : in8[3:0];
//    wire add2 = !in4[1:0];
//    wire[1:0] in2 = add2 ? in4[3:2] : in4[1:0];
//    wire add1 = !in2[0];

//    assign out = {add64, add32, add16, add8, add4, add2, add1};

//endmodule


//module RISCV_PLIC15_OPT #(
//    parameter NUM_DEVICES = 15,
//    parameter THRESHOLD_BITS = 3
//) (
//    input wire clk,
//    input wire rstn,
//    slv_interface.slv bus_if,
	 
//	input wire[NUM_DEVICES-1:0] sources_irq,
	 
//    output reg out_MEIP0,
//	output reg out_SEIP0
//);

//    localparam INTERRUPT_NUM_BITS = 4;
//	typedef enum logic[2:0] {
//		COMPLETED = 1 << 0,
//		PENDING = 1 << 1,
//		CLAIMED = 1 << 2
//	} IRQ_STATE;

//	IRQ_STATE sources_state[1:NUM_DEVICES];
//    reg[THRESHOLD_BITS-1:0] sources_priority[1:NUM_DEVICES];

//	wire[NUM_DEVICES:0] source0to31_pending;
//	reg[NUM_DEVICES:1] source0to31_pending_nxt;
//    assign source0to31_pending[0] = 1'b0;
//    for (genvar i = 1; i <= NUM_DEVICES; ++i) begin
//        assign source0to31_pending[i] = sources_state[i] == PENDING;
//    end
	
//	reg[NUM_DEVICES:0] source0to31_enable_context0;
//	reg[NUM_DEVICES:0] source0to31_enable_context1;

//    reg[7:1] sources_priority_i_one_hot[1:NUM_DEVICES];
    
    
//	for (genvar p = 7; p > 0; --p) begin
//        for (genvar i = 1; i <= NUM_DEVICES; ++i) begin
//            always_ff @(posedge clk or negedge rstn)
//                if (!rstn)
//                    sources_priority_i_one_hot[i][p] <= 1'b0;
//                else
//                    sources_priority_i_one_hot[i][p] <= source0to31_pending_nxt[i] && source0to31_enable_context1[i] && sources_priority[i] == p;
//        end
//    end
	
//    wire[127:0] context0_irq_array;
//    wire[127:0] context1_irq_array;
//    for (genvar p = 7; p > 0; --p) begin
//        assign context0_irq_array[(7-p)*16+0] = 1'b0;
//        assign context1_irq_array[(7-p)*16+0] = 1'b0;
//        for (genvar i = 1; i <= NUM_DEVICES; ++i) begin
//            assign context0_irq_array[(7-p)*16+i] = sources_priority_i_one_hot[i][p];
//            assign context1_irq_array[(7-p)*16+i] = sources_priority_i_one_hot[i][p];
//        end
//    end
//    for (genvar i = 0; i <= NUM_DEVICES; ++i) begin
//            assign context0_irq_array[7*16+i] = 1'b1;
//            assign context1_irq_array[7*16+i] = 1'b1;
//        end
    
//    wire[6:0] ctz_context0;
//    wire[6:0] ctz_context1;
//    count_trailing_zero128 ctz0(.in(context0_irq_array), .out(ctz_context0));
//    count_trailing_zero128 ctz1(.in(context1_irq_array), .out(ctz_context1));
    
//    wire[INTERRUPT_NUM_BITS-1:0] context0_claim_result     = ctz_context0[3:0];
//    wire[THRESHOLD_BITS-1:0]     context0_highest_priority = ~ctz_context0[6:4];
//    wire[INTERRUPT_NUM_BITS-1:0] context1_claim_result     = ctz_context1[3:0];
//    wire[THRESHOLD_BITS-1:0]     context1_highest_priority = ~ctz_context1[6:4];
    
    
//	for (genvar i = 1; i <= NUM_DEVICES; ++i) begin
//        reg[11:0] claimed_target;
//        IRQ_STATE source_state_nxt;
//        always_comb begin
//            source_state_nxt = sources_state[i];
//            case (sources_state[i])
//                COMPLETED: if (sources_irq[i-1]) begin
//                    source_state_nxt = PENDING;
//                end
//                PENDING: begin
//                    if (bus_if.avalid && !bus_if.awren && 
//                                {bus_if.addr[11:2], 2'b00} == 12'h004) begin
//                        if (bus_if.addr[23:12] == 12'h200 && context0_claim_result == i ||
//                            bus_if.addr[23:12] == 12'h201 && context1_claim_result == i) begin
//                            source_state_nxt = CLAIMED;
//                        end
//                    end
//                end
//                CLAIMED: if (bus_if.avalid && bus_if.awren && bus_if.awdata[INTERRUPT_NUM_BITS-1:0] == i &&
//                            {bus_if.addr[11:2], 2'b00} == 12'h004) begin
//                    if (bus_if.addr[23:12] == claimed_target)
//                        source_state_nxt = COMPLETED;
//                end
//            endcase
//        end
//        assign source0to31_pending_nxt[i] = source_state_nxt == PENDING;
        
//        always_ff @(posedge clk or negedge rstn)
//            if (!rstn) begin
//                sources_state[i] <= COMPLETED;
//                claimed_target <= '0;
//            end else begin
//                sources_state[i] <= source_state_nxt;
//                case (sources_state[i])
//                    PENDING: if (bus_if.avalid && !bus_if.awren && 
//                                {bus_if.addr[11:2], 2'b00} == 12'h004) begin
//                            claimed_target <= bus_if.addr[23:12];
//                    end
//                endcase
//           end
//    end
	
	
//	reg[THRESHOLD_BITS-1:0] context0_threshold;
//	reg[THRESHOLD_BITS-1:0] context1_threshold;

//    reg[31:0] rdata;
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            rdata <= '0;
//        else if (bus_if.avalid) begin
//            case ({bus_if.addr[23:2], 2'd0})
                
//                24'h001000: rdata <= source0to31_pending;
                
//                24'h002000: rdata <= source0to31_enable_context0;
//                24'h002080: rdata <= source0to31_enable_context1;
					 
//				24'h200000: rdata <= context0_threshold;
//				24'h200004: rdata <= context0_claim_result;

//				24'h201000: rdata <= context1_threshold;
//				24'h201004: rdata <= context1_claim_result;
//                default: rdata <= '0;
//            endcase
            
//            if (bus_if.addr[23:2] >= 1 && bus_if.addr[23:2] <= NUM_DEVICES)
//                rdata <= sources_priority[bus_if.addr[23:2]];
//        end
//    reg rvalid;
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            rvalid <= 1'b0;
//        else
//            rvalid <= bus_if.avalid;
//    assign bus_if.rvalid = rvalid;
//    assign bus_if.aready = 1'b1;
//    assign bus_if.rdata = rdata;
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn) begin
//            sources_priority <= '{default: '0};
//            source0to31_enable_context0 <= '0;
//            source0to31_enable_context1 <= '0;
//            context0_threshold <= '0;
//            context1_threshold <= '0;
//        end else if (bus_if.avalid & bus_if.awren) begin
//            if (bus_if.addr[23:2] >= 1 && bus_if.addr[23:2] <= NUM_DEVICES)
//                sources_priority[bus_if.addr[23:2]] <= bus_if.awdata[THRESHOLD_BITS-1:0];
//            case ({bus_if.addr[23:2], 2'd0})
                
//                24'h002000: source0to31_enable_context0 <= {bus_if.awdata[NUM_DEVICES:1], 1'b0};
//				24'h002080: source0to31_enable_context1 <= {bus_if.awdata[NUM_DEVICES:1], 1'b0};
					 
//				24'h200000: context0_threshold <= bus_if.awdata[THRESHOLD_BITS-1:0];
//				24'h201000: context1_threshold <= bus_if.awdata[THRESHOLD_BITS-1:0];
//            endcase
//        end


	
	
//	always_ff @(posedge clk or negedge rstn)
//		if (!rstn) begin
//			out_MEIP0 <= 1'b0;
//			out_SEIP0 <= 1'b0;
//		end else begin
//			out_MEIP0 <= context0_highest_priority > context0_threshold;
//			out_SEIP0 <= context1_highest_priority > context1_threshold;
//		end
//endmodule

//// Add interrupt/////////

`default_nettype none
module RISCV_CLINT64(
    input wire clk,
    input wire rstn,

    
    slv_interface.slv bus_if,
    output wire[63:0] out_mtime,
    output wire out_MTIP0,
    output wire out_MSIP0
);

    reg msip0_q;
    reg[63:0] mtimecmp0;
    reg[63:0] mtime;
    reg rvalid;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            rvalid <= 1'b0;
        else
            rvalid <= bus_if.avalid;
    assign bus_if.rvalid = rvalid;
    reg[63:0] rdata;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            rdata <= '0;
        else if (bus_if.avalid) begin
            case ({bus_if.addr[15:2], 2'd0})
                16'h0000: rdata <= msip0_q;
                16'h4000: rdata <= mtimecmp0;
                16'hC000: rdata <= mtime;
                default: rdata <= '0;
            endcase
        end
    assign bus_if.rdata = rdata;
    assign bus_if.aready = 1'b1;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn) begin
            mtimecmp0 <= '0;
            msip0_q <= 1'b0;
            mtime <= '0;
        end else begin
            mtime <= mtime + 1;
            if (bus_if.avalid && bus_if.awren)
                case ({bus_if.addr[15:2], 2'd0})
                    16'h0000: msip0_q <= bus_if.awdata[0];
                    16'h4000: mtimecmp0 <= bus_if.awdata[63:0];
                    //16'hC000: mtime <= bus_if.awdata[63:0];
                endcase
        end
    reg assert_MTIP0;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn) begin
            assert_MTIP0 <= 1'b0;
        end else begin
            assert_MTIP0 <= mtime >= mtimecmp0;
        end

    assign out_mtime = mtime;
    assign out_MTIP0 = assert_MTIP0;
    assign out_MSIP0 = msip0_q;

endmodule


module count_trailing_zero128(
    input wire[127:0] in,
    output wire[6:0] out
);

	wire[127:0] LSB_only = in & -in;
    assign out[6] = |(LSB_only & 128'hFFFFFFFFFFFFFFFF0000000000000000);
    assign out[5] = |(LSB_only & 128'hFFFFFFFF00000000FFFFFFFF00000000);
    assign out[4] = |(LSB_only & 128'hFFFF0000FFFF0000FFFF0000FFFF0000);
    assign out[3] = |(LSB_only & 128'hFF00FF00FF00FF00FF00FF00FF00FF00);
    assign out[2] = |(LSB_only & 128'hF0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0);
    assign out[1] = |(LSB_only & 128'hCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC);
    assign out[0] = |(LSB_only & 128'hAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA);
endmodule


module RISCV_PLIC15_OPT #(
    parameter NUM_DEVICES = 15,
    parameter THRESHOLD_BITS = 3
) (
    input wire clk,
    input wire rstn,
    slv_interface.slv bus_if,
	 
	input wire[NUM_DEVICES-1:0] sources_irq,
	 
    output reg out_MEIP0,
	output reg out_SEIP0
);

    localparam INTERRUPT_NUM_BITS = 4;
	typedef enum logic[2:0] {
		COMPLETED = 1 << 0,
		PENDING = 1 << 1,
		CLAIMED = 1 << 2
	} IRQ_STATE;

	IRQ_STATE sources_state[1:NUM_DEVICES];
    reg[THRESHOLD_BITS-1:0] sources_priority[1:NUM_DEVICES];

	wire[NUM_DEVICES:0] source0to31_pending;
	reg[NUM_DEVICES:1] source0to31_pending_nxt;
    assign source0to31_pending[0] = 1'b0;
    for (genvar i = 1; i <= NUM_DEVICES; ++i) begin
        assign source0to31_pending[i] = sources_state[i] == PENDING;
    end
	
	reg[NUM_DEVICES:0] source0to31_enable_context0;
	reg[NUM_DEVICES:0] source0to31_enable_context1;

    reg[7:1] sources_priority_i_one_hot[1:NUM_DEVICES];
    
    
	for (genvar p = 7; p > 0; --p) begin
        for (genvar i = 1; i <= NUM_DEVICES; ++i) begin
            always_ff @(posedge clk or negedge rstn)
                if (!rstn)
                    sources_priority_i_one_hot[i][p] <= 1'b0;
                else
                    sources_priority_i_one_hot[i][p] <= source0to31_pending_nxt[i] && source0to31_enable_context0[i] && sources_priority[i] == p;
        end
    end
	
    wire[127:0] context0_irq_array;
    for (genvar p = 7; p > 0; --p) begin
        assign context0_irq_array[(7-p)*16+0] = 1'b0;
        for (genvar i = 1; i <= NUM_DEVICES; ++i) begin
            assign context0_irq_array[(7-p)*16+i] = sources_priority_i_one_hot[i][p];
        end
    end
    for (genvar i = 0; i <= NUM_DEVICES; ++i) begin
            assign context0_irq_array[7*16+i] = 1'b1;
        end
    
    wire[6:0] ctz_context0;
    count_trailing_zero128 ctz0(.in(context0_irq_array), .out(ctz_context0));
    
    wire[INTERRUPT_NUM_BITS-1:0] context0_claim_result     = ctz_context0[3:0];
    wire[THRESHOLD_BITS-1:0]     context0_highest_priority = ~ctz_context0[6:4];
    wire[INTERRUPT_NUM_BITS-1:0] context1_claim_result     = '0;
    wire[THRESHOLD_BITS-1:0]     context1_highest_priority = '0;
    
    
	for (genvar i = 1; i <= NUM_DEVICES; ++i) begin
        reg[11:0] claimed_target;
        IRQ_STATE source_state_nxt;
        always_comb begin
            source_state_nxt = sources_state[i];
            case (sources_state[i])
                COMPLETED: if (sources_irq[i-1]) begin
                    source_state_nxt = PENDING;
                end
                PENDING: begin
                    if (bus_if.avalid && !bus_if.awren && 
                                {bus_if.addr[11:2], 2'b00} == 12'h004) begin
                        if (bus_if.addr[23:12] == 12'h200 && context0_claim_result == i ||
                            bus_if.addr[23:12] == 12'h201 && context1_claim_result == i) begin
                            source_state_nxt = CLAIMED;
                        end
                    end
                end
                CLAIMED: if (bus_if.avalid && bus_if.awren && bus_if.awdata[INTERRUPT_NUM_BITS-1:0] == i &&
                            {bus_if.addr[11:2], 2'b00} == 12'h004) begin
                    if (bus_if.addr[23:12] == claimed_target)
                        source_state_nxt = COMPLETED;
                end
            endcase
        end
        assign source0to31_pending_nxt[i] = source_state_nxt == PENDING;
        
        always_ff @(posedge clk or negedge rstn)
            if (!rstn) begin
                sources_state[i] <= COMPLETED;
                claimed_target <= '0;
            end else begin
                sources_state[i] <= source_state_nxt;
                case (sources_state[i])
                    PENDING: if (bus_if.avalid && !bus_if.awren && 
                                {bus_if.addr[11:2], 2'b00} == 12'h004) begin
                            claimed_target <= bus_if.addr[23:12];
                    end
                endcase
           end
    end
	
	
	reg[THRESHOLD_BITS-1:0] context0_threshold;
	reg[THRESHOLD_BITS-1:0] context1_threshold;

    reg[31:0] rdata;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            rdata <= '0;
        else if (bus_if.avalid) begin
            case ({bus_if.addr[23:2], 2'd0})
                
                24'h001000: rdata <= source0to31_pending;
                
                24'h002000: rdata <= source0to31_enable_context0;
                24'h002080: rdata <= source0to31_enable_context1;
					 
				24'h200000: rdata <= context0_threshold;
				24'h200004: rdata <= context0_claim_result;

				24'h201000: rdata <= context1_threshold;
				24'h201004: rdata <= context1_claim_result;
                default: rdata <= '0;
            endcase
            
            if (bus_if.addr[23:2] >= 1 && bus_if.addr[23:2] <= NUM_DEVICES)
                rdata <= sources_priority[bus_if.addr[23:2]];
        end
    reg rvalid;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            rvalid <= 1'b0;
        else
            rvalid <= bus_if.avalid;
    assign bus_if.rvalid = rvalid;
    assign bus_if.aready = 1'b1;
    assign bus_if.rdata = rdata;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn) begin
            sources_priority <= '{default: '0};
            source0to31_enable_context0 <= '0;
            source0to31_enable_context1 <= '0;
            context0_threshold <= '0;
            context1_threshold <= '0;
        end else if (bus_if.avalid & bus_if.awren) begin
            if (bus_if.addr[23:2] >= 1 && bus_if.addr[23:2] <= NUM_DEVICES)
                sources_priority[bus_if.addr[23:2]] <= bus_if.awdata[THRESHOLD_BITS-1:0];
            case ({bus_if.addr[23:2], 2'd0})
                
                24'h002000: source0to31_enable_context0 <= {bus_if.awdata[NUM_DEVICES:1], 1'b0};
				24'h002080: source0to31_enable_context1 <= {bus_if.awdata[NUM_DEVICES:1], 1'b0};
					 
				24'h200000: context0_threshold <= bus_if.awdata[THRESHOLD_BITS-1:0];
				24'h201000: context1_threshold <= bus_if.awdata[THRESHOLD_BITS-1:0];
            endcase
        end


	
	
	always_ff @(posedge clk or negedge rstn)
		if (!rstn) begin
			out_MEIP0 <= 1'b0;
			out_SEIP0 <= 1'b0;
		end else begin
			out_MEIP0 <= context0_highest_priority > context0_threshold;
			out_SEIP0 <= context1_highest_priority > context1_threshold;
		end
endmodule