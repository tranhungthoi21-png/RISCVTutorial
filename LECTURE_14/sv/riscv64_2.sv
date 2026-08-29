`default_nettype none
	 typedef struct packed {
        reg is_illegal;
        reg is_read_mem;
        reg is_write_mem;
        reg is_branch;
        reg is_jalr;
        reg is_fence;
        reg is_ifencei;
        reg is_atomic;
        reg is_jal;
        
        reg reg_op_imm;
        reg is_muldiv;
        reg reg_op_reg;
        reg is_csr_access;
        reg is_auipc;
        reg is_lui;
        
		reg is_wfi;
        reg is_mret;
        reg is_ebreak;
        reg is_ecall;
		reg reg_wren;
		reg csr_wren;
		  
		reg[31:0] imm_val;
		reg[2:0] funct3;
		reg alu_op_alt;
        reg alu32_mode;
    } DECODED_VAL;


(* use_dsp = "no" *) (* multstyle = "logic" *) module mul_div_unit64(
    input wire clk,
    input wire rstn,

    input wire in_valid,
    input wire[2:0] funct3,
    output wire in_ready,
    input wire[63:0] rs1,
    input wire[63:0] rs2,
    input wire alu32_mode,
    output reg out_valid,
    output reg[63:0] out_value
) /* synthesis syn_dspstyle = "logic" */ ;

    typedef enum {
        IDLE,
        LONG_DIV,
        MUL_PIPE,
        MUL_OUTREG,
        DONE
    } MUL_DIV_STATE;
    MUL_DIV_STATE state;
    
    wire[63:0] numer = alu32_mode ? {{32{funct3[0] == 1'b0 && rs1[31]}}, rs1[31:0]} : rs1;
    wire[63:0] denom = alu32_mode ? {{32{funct3[0] == 1'b0 && rs2[31]}}, rs2[31:0]} : rs2;
    
    reg[2:0] funct3_q;
    reg alu32_mode_q;
    reg sgn_rs1;
    reg sgn_diff;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn) begin
            funct3_q <= '0;
            alu32_mode_q <= 1'b0;
            sgn_rs1 <= 1'b0;
            sgn_diff <= 1'b0;
        end else begin
            funct3_q <= funct3;
            alu32_mode_q <= alu32_mode;
            sgn_rs1 <= numer[63];
            sgn_diff <= numer[63] != denom[63] && denom != 0;
        end
    
    wire mul_sext_rs1 = funct3[1] == 1'b0 || funct3[0] == 1'b0; // (funct3[1:0] == 2'b01 || funct3[1:0] == 2'b10 || funct3[1:0] == 2'b00);
    wire mul_sext_rs2 = funct3[1] == 1'b0; // funct3[1:0] == 2'b01 || funct3[1:0] == 2'b00;
    reg[63:0] rs1_abs;
    reg[63:0] rs2_abs;
    reg[63:0] mul_low;
    reg[63:0] mul_temp;
    reg[5:0] mul_counter;
    reg mul_neg;

    parameter MUL_UNROLL_FACTOR = 1;
    wire[127:0] mul_res = {mul_temp, mul_low};
    reg[127:0] mul_res_adj;// = mul_neg ? -mul_res : mul_res;
    wire[63:0] rs1_abs_w = mul_sext_rs1 && rs1[63] ? -rs1 : rs1;
    wire[63:0] rs2_abs_w = mul_sext_rs2 && rs2[63] ? -rs2 : rs2;
    wire[63+MUL_UNROLL_FACTOR:0] mul_temp_w = mul_temp + rs1_abs * rs2_abs[MUL_UNROLL_FACTOR-1:0];
    always_ff @(posedge clk or negedge rstn)
        if (!rstn) begin
            rs1_abs <= '0;
            rs2_abs <= '0;
            mul_low <= '0;
            mul_temp <= '0;
            mul_counter <= '0;
            mul_neg <= 1'b0;
            mul_res_adj <= '0;
        end else begin
            rs2_abs <= {{MUL_UNROLL_FACTOR{1'b0}}, rs2_abs[63:MUL_UNROLL_FACTOR]};
            mul_low <= {mul_temp_w[MUL_UNROLL_FACTOR-1:0], mul_low[63:MUL_UNROLL_FACTOR]};
            mul_temp <= mul_temp_w[63+MUL_UNROLL_FACTOR:MUL_UNROLL_FACTOR];
            mul_res_adj <= mul_neg ? -mul_res : mul_res;
            mul_counter <= mul_counter + MUL_UNROLL_FACTOR;
            if (in_valid & in_ready) begin
                rs1_abs <= rs1_abs_w;
                rs2_abs <= rs2_abs_w;
                mul_temp <= '0;
                mul_counter <= 0;
                mul_neg <= (mul_sext_rs1 && rs1[63]) ^ (mul_sext_rs2 && rs2[63]);
            end
        end

    reg[5:0] div_counter;
    reg[63:0] div_upper;
    reg[63:0] div_result;
    reg[126:0] shift_up;
	

	 wire[64:0] sub_shiftup = div_upper - shift_up[63:0];
	 wire[63:0] div_upper_w = (funct3[0] == 1'b0 && numer[63]) ? -numer : numer;
	 wire[63:0] div_lower_w = (funct3[0] == 1'b0 && denom[63]) ? -denom : denom;
	 
   always_ff @(posedge clk or negedge rstn)
        if (!rstn) begin
            div_counter <= '0;
            div_upper <= '0;
			shift_up <= '0;
            div_result <= '0;
        end else begin
            shift_up <= {1'b0, shift_up[126:1]};
            if (!shift_up[126:64] && !sub_shiftup[64]) begin
                div_upper <= sub_shiftup[63:0];
                div_result <= {div_result[62:0], 1'b1};
            end else begin
                div_upper <= div_upper;
                div_result <= {div_result[62:0], 1'b0};
            end
            div_counter <= div_counter + 1'b1;
            
            if (in_valid & in_ready) begin
                div_counter <= alu32_mode ? 32 : 0;
                div_upper <= div_upper_w;
                shift_up <= alu32_mode ? {div_lower_w, 31'd0} : {div_lower_w, 63'd0};
            end
        end
    MUL_DIV_STATE state_nxt;
    always_comb begin
        state_nxt = state;
        case (state)
            IDLE: if (in_valid) state_nxt = funct3[2] ? LONG_DIV : MUL_PIPE;
            LONG_DIV: if (&div_counter) state_nxt = DONE;
            MUL_PIPE: if (mul_counter >= 64-MUL_UNROLL_FACTOR) state_nxt = MUL_OUTREG;
            MUL_OUTREG: state_nxt = DONE;
            DONE: state_nxt = IDLE;
        endcase
    end
   always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            state <= IDLE;
        else
            state <= state_nxt;
    always_comb begin
        case (funct3_q)
            3'b000: out_value = mul_res_adj[0+:64];
            3'b001: out_value = mul_res_adj[64+:64];
            3'b010: out_value = mul_res_adj[64+:64];
            3'b011: out_value = mul_res_adj[64+:64];
            3'b100: out_value = sgn_diff ? -div_result : div_result;
            3'b101: out_value = div_result;
            3'b110: out_value = sgn_rs1 ? -div_upper : div_upper;
            3'b111: out_value = div_upper;
        endcase
        if (alu32_mode_q) out_value[63:32] = {32{out_value[31]}};
    end
    assign in_ready = state == IDLE;
    assign out_valid = state == DONE;
endmodule


module ALU_RISCV64(
    input wire[2:0] alu_op,
    input wire alu_op_alt,
    input wire alu32_mode,
    input wire[63:0] operand_1,
    input wire[63:0] operand_2,
    output wire[63:0] result
);
    wire sra = alu_op_alt;
    wire is_shift_right = alu_op[2];

    wire[5:0] shamt = alu32_mode ? {1'b0, operand_2[4:0]} : operand_2[5:0];
    wire[63:0] shifter = alu32_mode ? {operand_1[63], {31{operand_1[31]&sra}}, operand_1[31:0]} : operand_1;
    wire[189:0] shifter_padded = {{63{shifter[63]&sra}}, shifter, 63'd0};
    wire[6:0] get_index = is_shift_right ? (63+shamt) : (63-shamt);
    wire[63:0] shift_result = shifter_padded >> get_index;//[get_index+:64];
    wire[63:0] shift_32_bit_sext = alu32_mode ? {{32{shift_result[31]}}, shift_result[31:0]} : shift_result;
    
    wire[64:0] alu_addsub = alu_op_alt ? operand_1 - operand_2 : operand_1 + operand_2;
    wire cmp_ltu = alu_addsub[64];
    wire cmp_lt = operand_1[63] == operand_2[63] || alu_op[0] ? cmp_ltu : operand_1[63];
    reg[63:0] alu_result;
    always_comb
        case (alu_op)
            3'b000: alu_result = alu32_mode ? {{32{alu_addsub[31]}}, alu_addsub[31:0]} : alu_addsub[63:0];
            3'b001: alu_result = shift_32_bit_sext; // shift left
            3'b101: alu_result = shift_32_bit_sext; // shift right
            3'b010: alu_result = cmp_lt; // signed lt
            3'b011: alu_result = cmp_lt; // unsigned lt
            3'b100: alu_result = operand_1 ^ operand_2;
            3'b110: alu_result = operand_1 | operand_2;
            3'b111: alu_result = operand_1 & operand_2;
        endcase
    assign result = alu_result;
endmodule



module REGISTER_FILE64(
    input wire clk,
    input wire wr_en,
    input wire rd_en,
    input wire[4:0] wr_addr,
    input wire[63:0] wr_data,
    
    input wire[4:0] rd_addr1,
    output reg[63:0] rd_data1,
    input wire[4:0] rd_addr2,
    output reg[63:0] rd_data2
) /* synthesis syn_ramstyle = "distributed_ram" */;
    (* ram_style = "distributed" *) reg[63:0] x[32];
    
    always_ff @(posedge clk)
        if (wr_en)
		  x[wr_addr] <= wr_data;
    always_ff @(posedge clk)
        if (rd_en) begin
           rd_data1 <= rd_addr1 ? x[rd_addr1] : '0;
	       rd_data2 <= rd_addr2 ? x[rd_addr2] : '0;
        end

endmodule

module RV64_ID_DECODER(
    input wire[31:0] inst,
    output DECODED_VAL ex_decoded_nxt
);
    wire[4:0] inst_rd = inst[11:7];
    wire[4:0] inst_rs1 = inst[19:15];
    wire[4:0] inst_rs2 = inst[24:20];
    wire[6:0] inst_funct7 = inst[31:25];
    wire[2:0] inst_funct3 = inst[14:12];
    wire[11:0] inst_funct12 = inst[31:20];
	 
    wire[11:0] csr_idx = inst[31:20];
    wire[4:0] atomic_opcode = inst[31:27];

    wire csr_wren = inst[13:12] == 2'b01 || inst[13] && inst[19:15];
    always_comb begin
        ex_decoded_nxt = '{is_illegal: 1'b1, imm_val: 'x, default: '0};
        
        case (inst[6:2])
            5'b00000: if (inst_funct3 != 3'b111) begin
                // load instructions
                ex_decoded_nxt = '{is_read_mem: 1'b1, reg_wren: 1'b1, imm_val: {{20{inst[31]}}, inst[31:20]}, default: '0};
            end
            5'b01000: if (inst_funct3 <= 3) begin
                // store instructions
                ex_decoded_nxt = '{is_write_mem: 1'b1, imm_val: {{20{inst[31]}}, inst[31:25], inst[11:7]}, default: '0};
            end
            5'b11000: if (!(inst_funct3 == 3'd2 || inst_funct3 == 3'd3)) begin
                // branch instructions
                ex_decoded_nxt = '{is_branch: 1'b1, imm_val: {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0}, default: '0};
            end
            5'b11001: if (inst_funct3 == 3'd0) begin
                // jalr instruction
                ex_decoded_nxt = '{is_jalr: 1'b1, reg_wren: 1'b1, imm_val: {{20{inst[31]}}, inst[31:20]}, default: '0};
            end
            5'b00011: if (inst_funct3 == 3'd0) begin
                // fence instruction
                ex_decoded_nxt = '{is_fence: 1'b1, imm_val: 'x, default: '0};
            end else if (inst_funct3 == 3'd1) begin
                // ifencei instruction
                ex_decoded_nxt = '{is_ifencei: 1'b1, imm_val: 'x, default: '0};
            end
            5'b01011: if ((inst_funct3 == 3'b010 || inst_funct3 == 3'b011) && (atomic_opcode == 2 && inst_rs2 == 0 || atomic_opcode == 3)) begin
				// atomic instructions, only support lr.w/d and sc.w/d for now
                ex_decoded_nxt = '{is_atomic: 1'b1, is_read_mem: atomic_opcode == 2, is_write_mem: atomic_opcode != 2, reg_wren: 1'b1, imm_val: '0, default: '0};
		    end
            // jal instructions
            5'b11011: ex_decoded_nxt = '{is_jal: 1'b1, reg_wren: 1'b1, imm_val: {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0}, default: '0};
            
            // reg op imm 64 bit
            5'b00100: if (inst[13:12] == 2'b01) begin
                // shift operation extra check
                if (inst_funct7[6:1] == 6'b000_000 || inst[14] && inst_funct7[6:1] == 6'b010_000)
                    ex_decoded_nxt = '{reg_op_imm: 1'b1, reg_wren: 1'b1, alu_op_alt: inst[30], imm_val: {{20{inst[31]}}, inst[31:20]}, default: '0};
            end else begin
                ex_decoded_nxt = '{reg_op_imm: 1'b1, reg_wren: 1'b1, imm_val: {{20{inst[31]}}, inst[31:20]}, default: '0};
                // slti sltiu then always subtract
                ex_decoded_nxt.alu_op_alt = inst[14:12] == 3'b010 || inst[14:12] == 3'b011;
            end
            
            // reg op imm 32-bit
            5'b00110: if (inst[13:12] == 2'b01) begin
                 // shift operation extra check
                if (inst_funct7 == 7'b000_0000 || inst[14] && inst_funct7 == 7'b010_0000)
                    ex_decoded_nxt = '{reg_op_imm: 1'b1, reg_wren: 1'b1, alu_op_alt: inst[30], imm_val: {{20{inst[31]}}, inst[31:20]}, alu32_mode: 1'b1, default: '0};
            end else if (inst[14:12] == 3'b000) begin
                // other than shifts, for 32-bit mode reg op imm only add exist
                ex_decoded_nxt = '{reg_op_imm: 1'b1, reg_wren: 1'b1, imm_val: {{20{inst[31]}}, inst[31:20]}, alu32_mode: 1'b1, default: '0};
            end
            
            // reg op reg 64-bit
			5'b01100: if (inst_funct7 == 7'b000_0001) begin
               ex_decoded_nxt = '{is_muldiv: 1'b1, reg_wren: 1'b1, imm_val: 'x, default: '0};		
            end else begin
                // only ADD/SUB and right shift have inst[30] set (alu_op_alt)
                if (inst_funct7 == 7'b000_0000 || inst_funct7 == 7'b010_0000 && (inst[14:12] == 3'b000 || inst[14:12] == 3'b101))
                    ex_decoded_nxt = '{reg_op_reg: 1'b1, reg_wren: 1'b1, imm_val: 'x, default: '0};
                // slt sltu then always subtract
                ex_decoded_nxt.alu_op_alt = inst[30] || inst[14:12] == 3'b010 || inst[14:12] == 3'b011;
            end
            
            // reg op reg 32-bit
            5'b01110: if (inst_funct7 == 7'b000_0001 && (inst[14:12] == 3'b000 || inst[14])) begin
                // only signed 32-bit mulw and division support
               ex_decoded_nxt = '{is_muldiv: 1'b1, reg_wren: 1'b1, alu32_mode: 1'b1, imm_val: 'x, default: '0};		
            end else if (inst[14:12] == 3'b000 || inst[14:12] == 3'b101 || inst[14:12] == 3'b001) begin
                // 32-bit mode only support ADDW/SUBW and shifts
                // only ADD/SUB and right shift have inst[30] set (alu_op_alt)
                if (inst_funct7 == 7'b000_0000 || inst_funct7 == 7'b010_0000 && (inst[14:12] == 3'b000 || inst[14:12] == 3'b101))
                    ex_decoded_nxt = '{reg_op_reg: 1'b1, reg_wren: 1'b1, alu32_mode: 1'b1, imm_val: 'x, default: '0};
                ex_decoded_nxt.alu_op_alt = inst[30];
            end
            5'b11100: if (inst_funct3 == 3'b000) begin
					if (inst_rd == 0) begin
//						if (inst_funct7 == 7'b000_1001)
//							ex_decoded_nxt = '{is_sfence_vma: 1'b1, imm_val: 'x, min_priv: 2'b01, default: '0};
						if (inst_rs1 == 0)
							case (inst_funct12)
								12'h105: ex_decoded_nxt = '{is_wfi: 1'b1, imm_val: 'x, default: '0};
								12'h302: ex_decoded_nxt = '{is_mret: 1'b1, imm_val: 'x, default: '0};
								//12'h102: ex_decoded_nxt = '{is_sret: 1'b1, imm_val: 'x, min_priv: 2'b01, default: '0};
								12'h001: ex_decoded_nxt = '{is_ebreak: 1'b1, imm_val: 'x, default: '0};
								12'h000: ex_decoded_nxt = '{is_ecall: 1'b1, imm_val: 'x, default: '0};
							endcase
							
					end
				end else if (inst_funct3 != 3'b100) begin
                    if (!(csr_idx[11:10] == 2'b11 && csr_wren)) // no error case
                        ex_decoded_nxt = '{is_csr_access: 1'b1, reg_wren: 1'b1, csr_wren: csr_wren, imm_val: 'x, default: '0};
                end
            5'b00101: ex_decoded_nxt = '{is_auipc: 1'b1, reg_wren: 1'b1, imm_val: {inst[31:12], 12'h000}, default: '0};
            5'b01101: ex_decoded_nxt = '{is_lui: 1'b1, reg_wren: 1'b1, imm_val: {inst[31:12], 12'h000}, default: '0};
        endcase
        
		  ex_decoded_nxt.funct3 = inst_funct3;
		  
		  //if (inst[1:0] != 2'b11)  ex_decoded_nxt = '{is_illegal: 1'b1, default: '0};
		      
    end
endmodule
module riscv64 #(
    parameter HART_ID = 32'h0
)(
    input wire clk,
    input wire rstn,
    slv_interface.master bus_if, 

    input wire in_MSIP,
    input wire in_MTIP,
    input wire in_MEIP,
	input wire in_SEIP,
	input wire[63:0] clint_mtime
);
    wire wb_commit;
    (* fsm_encoding = "one_hot" *) typedef enum {
        RISCV_IF,
        RISCV_ID,
        RISCV_EX,
        RISCV_MEM,
        RISCV_WB,
        RISCV_TRAP
    } RISCV_STATE;

    (* fsm_encoding = "one_hot" *) RISCV_STATE state;
	 
	 wire mmu_rvalid;
	 reg[63:0] mmu_rdata;
	 wire mmu_gnt;
	 
	 
    (* fsm_encoding = "one_hot" *) RISCV_STATE state_nxt;
    wire[31:0] id_instruction = mmu_rdata[31:0];
    reg[63:0] pc;
    wire wb_wren;
    wire[63:0] wb_wdata;
    wire[4:0] wb_dst;
    wire[63:0] ex_r1;
    wire[63:0] ex_r2;
    REGISTER_FILE64 register_file(
        .clk(clk), 
        .wr_en(wb_wren), .wr_addr(wb_dst), .wr_data(wb_wdata),
        .rd_en(state == RISCV_ID),
        .rd_addr1(id_instruction[19:15]), .rd_data1(ex_r1),
        .rd_addr2(id_instruction[24:20]), .rd_data2(ex_r2)
    );
	 
    DECODED_VAL ex_decoded_nxt;
    DECODED_VAL ex_decoded;
    
    RV64_ID_DECODER id_decoder0(.inst(id_instruction), .ex_decoded_nxt(ex_decoded_nxt));


    reg[31:0] ex_instruction;
   
    
    /*wire[64:0] ex_cmp_sub = ex_r1 - ex_r2;
    wire ex_cmp_eq  = ex_cmp_sub[63:0] == 64'd0;
    wire ex_cmp_lt  = ex_r1[63] != ex_r2[63] ? ex_r1[63] : ex_cmp_sub[64];
    wire ex_cmp_ltu = ex_cmp_sub[64];
    reg ex_can_branch;
    always_comb
        case (ex_decoded.funct3)
            3'b000: ex_can_branch = ex_cmp_eq;
            3'b001: ex_can_branch = ~ex_cmp_eq;
            3'b100: ex_can_branch = ex_cmp_lt;
            3'b101: ex_can_branch = ~ex_cmp_lt;
            3'b110: ex_can_branch = ex_cmp_ltu;
            3'b111: ex_can_branch = ~ex_cmp_ltu;
            default: ex_can_branch = 1'bX;
        endcase*/

    wire ex_cmp_eq = ex_r1 == ex_r2;
    wire ex_cmp_lt = ex_decoded.funct3[1] ? ex_r1 < ex_r2 : $signed(ex_r1) < $signed(ex_r2);
    wire ex_can_branch = (ex_decoded.funct3[2] ? ex_cmp_lt : ex_cmp_eq) ^ ex_decoded.funct3[0];

    reg[63:0] cycle_ctr;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            cycle_ctr <= '0;
        else
            cycle_ctr <= cycle_ctr + 1;
    
    reg[63:0] instret_ctr;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            instret_ctr <= '0;
        else if (wb_commit)
            instret_ctr <= instret_ctr + 1'b1;
    /* CSR HANDLING */

    typedef enum logic[11:0] {
        CSR_MVENDORID   = 12'hF11,
        CSR_MARCHID     = 12'hF12,
        CSR_MIMPID      = 12'hF13,
        CSR_MHARTID     = 12'hF14,
        CSR_MISA        = 12'h301,
        CSR_MCYCLE      = 12'hB00, CSR_CYCLE    = 12'hC00,
        CSR_TIME        = 12'hC01,
        CSR_MINSTRET    = 12'hB02, CSR_INSTRET  = 12'hC02,
        CSR_MTVAL       = 12'h343,
        CSR_MSTATUS     = 12'h300,
        CSR_MIE         = 12'h304,
        CSR_MTVEC       = 12'h305,
        CSR_MSCRATCH    = 12'h340,
        CSR_MEPC        = 12'h341,
        CSR_MCAUSE      = 12'h342,
        CSR_MIP         = 12'h344,
        CSR_MCONFIGPTR  = 12'hF15,
        CSR_MENVCFG     = 12'h30A
    } CSR_t;
    

    reg[63:0] csr_mtval;
	 
    wire[1:0] current_priv = 2'b11;

    reg csr_mstatus_mie;
    reg csr_mstatus_mpie;
	 
    
    reg[11:0] csr_mie;
    reg[31:0] csr_mtvec;
    reg[63:0] csr_mcause;
    reg[31:0] csr_mepc;
	 




    reg[63:0] csr_mscratch;
    localparam[63:0] CSR_MISA_CONST =   (64'h2 << 62) | // XLEN = 64-bit
                                        (64'h1 << 0) |  // A extension
                                        (64'h1 << 8) |  // I "extension"
                                        (64'h1 << 12);  // M extension

    reg[64:0] id_csr_rdval; // bit 64: invalid csr, = 0 when the csr is valid
    always_comb begin
        id_csr_rdval = '1;
        case (id_instruction[31:20])
            CSR_MVENDORID:              id_csr_rdval = '0;
            CSR_MARCHID:                id_csr_rdval = '0;
            CSR_MIMPID:                 id_csr_rdval = '0;
            CSR_MHARTID:                id_csr_rdval = HART_ID;
            CSR_MISA:                   id_csr_rdval = CSR_MISA_CONST;
            
            CSR_MCYCLE,CSR_CYCLE:       id_csr_rdval = cycle_ctr;
            CSR_TIME:                   id_csr_rdval = clint_mtime;
            CSR_MINSTRET,CSR_INSTRET:   id_csr_rdval = instret_ctr;
            CSR_MSTATUS:                id_csr_rdval = {2'b11, 1'b0, 1'b0, 1'b0, csr_mstatus_mpie, 1'b0, 1'b0, 1'b0, csr_mstatus_mie, 3'b000};
            CSR_MIP:                    id_csr_rdval = {in_MEIP, 3'b000, in_MTIP, 3'b000, in_MSIP, 3'b000};
            CSR_MIE:                    id_csr_rdval = csr_mie;						  
            CSR_MTVEC:                  id_csr_rdval = {csr_mtvec[31:2], 2'b00}; 					  
            CSR_MEPC:                   id_csr_rdval = {csr_mepc[31:2], 2'b00};
            CSR_MTVAL:                  id_csr_rdval = csr_mtval; 
            CSR_MCAUSE:                 id_csr_rdval = csr_mcause;
            CSR_MSCRATCH:               id_csr_rdval = csr_mscratch; 				  
			
			
            CSR_MCONFIGPTR:             id_csr_rdval = '0;
            CSR_MENVCFG:                id_csr_rdval = '0;
            default:                    id_csr_rdval = '1;
        endcase
		  /*if (id_csr_idx >= 12'hB03 && id_csr_idx <= 12'hB1F ||
				id_csr_idx >= 12'hB83 && id_csr_idx <= 12'hB9F ||
				id_csr_idx >= 12'hC03 && id_csr_idx <= 12'hC1F ||
				id_csr_idx >= 12'hC83 && id_csr_idx <= 12'hC9F) id_csr_rdval = '0;*/
    end
	 
    reg[64:0] ex_csr_rdval;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            ex_csr_rdval <= '0;
        else if (state == RISCV_ID)
            ex_csr_rdval <= id_csr_rdval;
    
    
    reg[63:0] wb_csr_wrdata;
    reg[63:0] wb_csr_rdval;
    reg wb_csr_wren;
    reg wb_reg_write;
    reg[11:0] wb_csr_idx;
    wire[11:0] ex_csr_idx = ex_instruction[31:20];
    wire[63:0] ex_csr_operand = ex_decoded.funct3[2] ? ex_instruction[19:15] : ex_r1;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn) begin
            wb_csr_wren <= 1'b0;
            wb_csr_idx <= '0;
            wb_csr_wrdata <= '0;
            wb_csr_rdval <= '0;
        end else if (state == RISCV_EX) begin
            wb_csr_wren <= ex_decoded.csr_wren;
            wb_csr_idx <= ex_csr_idx;
            wb_csr_rdval <= ex_csr_rdval[63:0];
            case (ex_decoded.funct3[1:0])
                2'b00: wb_csr_wrdata <= 'x;
                2'b01: wb_csr_wrdata <= ex_csr_operand;
                2'b10: wb_csr_wrdata <= ex_csr_rdval[63:0] | ex_csr_operand; 
                2'b11: wb_csr_wrdata <= ex_csr_rdval[63:0] & ~ex_csr_operand;
            endcase
        end

    
    
    wire[63:0] ex_decoded_imm_val = {{32{ex_decoded.imm_val[31]}}, ex_decoded.imm_val};
    wire[63:0] ex_r1_p_imm = ex_r1 + ex_decoded_imm_val;
    wire[63:0] ex_pc_p_imm = pc + ex_decoded_imm_val;
    wire[63:0] ex_mem_addr_w = ex_r1_p_imm;
    
    wire[63:0] wb_pc_nxt = ex_decoded.is_jal || ex_decoded.is_branch && ex_can_branch ? {ex_pc_p_imm[63:1], 1'b0} :
                           ex_decoded.is_jalr										  ? {ex_r1_p_imm[63:1], 1'b0} :
                                                                                        pc + 4;
    
         
    wire[63:0] ex_alu_result;
    ALU_RISCV64 alu0(
        .result(ex_alu_result), 
        .operand_1(ex_r1), 
        .operand_2(ex_decoded.reg_op_imm ? ex_decoded_imm_val : ex_r2),
        .alu_op(ex_decoded.funct3), 
        .alu_op_alt(ex_decoded.alu_op_alt), 
        .alu32_mode(ex_decoded.alu32_mode)
    );
    
    wire muldiv_done;
    wire[63:0] wb_muldiv_result;
    
    mul_div_unit64 muldiv0(
            .clk,
            .rstn,
            .in_valid(state == RISCV_EX && ex_decoded.is_muldiv),
            .funct3(ex_decoded.funct3),
            .in_ready(),
            .rs1(ex_r1),
            .rs2(ex_r2),
            .alu32_mode(ex_decoded.alu32_mode),
            .out_valid(muldiv_done),
            .out_value(wb_muldiv_result)
    );
    
                     
    reg[63:0] wb_pc;
    reg[63:0] wb_alu_result;
    reg[4:0] wb_rd;
    reg[63:0] mem_mem_addr;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn) begin
            ex_instruction <= '0;
            ex_decoded <= '{default: '0};
            wb_pc <= '0;
            wb_alu_result  <= '0;
            mem_mem_addr <= '0;
            wb_reg_write <= '0;
            wb_rd <= '0;
        end else case (state)
            RISCV_ID: begin
                ex_instruction <= id_instruction;
                ex_decoded <= ex_decoded_nxt;
            end
            RISCV_EX: begin
                wb_alu_result <= ex_alu_result;
                wb_pc <= wb_pc_nxt;
                mem_mem_addr <= ex_mem_addr_w;
                wb_reg_write <= ex_decoded.reg_wren;
                wb_rd <= ex_instruction[11:7];
            end
        endcase

    
	
			
    reg[3:0] exception_cause_nxt;
    reg[3:0] exception_cause;
    reg[63:0] exception_mtval_nxt;
    reg[63:0] exception_mtval;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn) begin
            exception_cause <= '0;
            exception_mtval <= '0;
        end else begin
            exception_cause <= exception_cause_nxt;
            exception_mtval <= exception_mtval_nxt;
        end
    
	wire[11:0] mmode_irq_pending = {in_MEIP, 3'b000,
                                    in_MTIP, 3'b000,
                                    in_MSIP, 3'b000} & csr_mie;
    
    wire mmode_fire_irq = csr_mstatus_mie && mmode_irq_pending;


    wire[63:0] ifetch_pc = mmode_fire_irq ? {csr_mtvec[31:2], 2'b00} : pc;
    reg[11:0] csr_mie_nxt;
    reg[31:0] csr_mtvec_nxt;
    reg[31:0] csr_mepc_nxt;

    reg[63:0] pc_nxt;
    
    reg csr_mstatus_mie_nxt;
    reg csr_mstatus_mpie_nxt;
    

    reg[63:0] csr_mcause_nxt;


    reg[63:0] csr_mscratch_nxt;
    reg[63:0] csr_mtval_nxt;
    
    always_comb begin
        csr_mie_nxt = csr_mie;
        csr_mtvec_nxt = csr_mtvec;
        csr_mscratch_nxt = csr_mscratch;
        csr_mstatus_mie_nxt = csr_mstatus_mie;
        csr_mstatus_mpie_nxt = csr_mstatus_mpie;
        csr_mepc_nxt = csr_mepc;
        csr_mcause_nxt = csr_mcause;
        csr_mtval_nxt = csr_mtval;
        pc_nxt = pc;

        if (state == RISCV_IF && mmu_gnt) begin
                if (mmode_fire_irq) begin
					
                    csr_mepc_nxt = {pc[31:2], 2'b00};
                    csr_mcause_nxt = mmode_irq_pending[11] ? 64'h8000_0000_0000_000B :
                                     mmode_irq_pending[3]  ? 64'h8000_0000_0000_0003 :
                                     mmode_irq_pending[7]  ? 64'h8000_0000_0000_0007 : 'x;
                    // $display("M mode interrupt %08x", csr_mcause);
					 csr_mtval_nxt = '0;
                     pc_nxt = {csr_mtvec[31:2], 2'b00};
                    
                    csr_mstatus_mpie_nxt = csr_mstatus_mie;
                    csr_mstatus_mie_nxt = 1'b0;
				end 
        end
        if (state == RISCV_WB) begin
                if (wb_commit)
                    pc_nxt = wb_pc;
				if (wb_csr_wren) begin
                    case (wb_csr_idx)
                        CSR_MIE: csr_mie_nxt = wb_csr_wrdata[11:0] & 12'h888;
                        CSR_MTVEC: csr_mtvec_nxt = {wb_csr_wrdata[31:2], 2'b00};
                        CSR_MSCRATCH: csr_mscratch_nxt = wb_csr_wrdata;
                        CSR_MSTATUS: {csr_mstatus_mpie_nxt, csr_mstatus_mie_nxt} = {wb_csr_wrdata[7], wb_csr_wrdata[3]};
                        CSR_MEPC: 	csr_mepc_nxt = {wb_csr_wrdata[31:2], 2'b00};
                        CSR_MCAUSE:  csr_mcause_nxt = wb_csr_wrdata & 64'h8000_0000_0000_001F;
                        CSR_MTVAL: 	csr_mtval_nxt = wb_csr_wrdata;
                    endcase
                end
                if (ex_decoded.is_mret) begin
					pc_nxt = {csr_mepc[31:2], 2'b00};
                    
                   csr_mstatus_mie_nxt = csr_mstatus_mpie;
                   csr_mstatus_mpie_nxt = 1'b1;
				end
					 
		  end
          if (state == RISCV_TRAP) begin
					csr_mepc_nxt = {pc[31:2], 2'b00};
					csr_mcause_nxt = exception_cause;
					csr_mtval_nxt = exception_mtval;
                    
					pc_nxt = {csr_mtvec[31:2], 2'b00};
					
                    csr_mstatus_mpie_nxt = csr_mstatus_mie;
                    csr_mstatus_mie_nxt = 1'b0;
            end
        end
    
    always_ff @(posedge clk or negedge rstn)
        if (!rstn) begin
            csr_mie <= '0;
            csr_mtvec <= '0;
            csr_mscratch <= '0;
            
            csr_mstatus_mie <= 1'b0;
            csr_mstatus_mpie <= 1'b0;
            csr_mepc <= '0;
            csr_mcause <= 0;
            csr_mtval <= '0;
            pc <= 64'h10000;
        end else begin
            csr_mie <= csr_mie_nxt;
            csr_mtvec <= csr_mtvec_nxt;
            csr_mscratch <= csr_mscratch_nxt;
            csr_mstatus_mie <= csr_mstatus_mie_nxt;
            csr_mstatus_mpie <= csr_mstatus_mpie_nxt;
            csr_mepc <= csr_mepc_nxt;
            csr_mcause <= csr_mcause_nxt;
            csr_mtval <= csr_mtval_nxt;
            pc <= pc_nxt;
        end
    
            
            
        

    
    reg[63:0] omem_wdata;
    always_comb case (ex_decoded.funct3[1:0])
        2'b11: omem_wdata = {1{ex_r2[63:0]}};
        2'b10: omem_wdata = {2{ex_r2[31:0]}};
        2'b01: omem_wdata = {4{ex_r2[15:0]}};
        2'b00: omem_wdata = {8{ex_r2[7:0]}};
	 endcase
    
    reg[63:0] wb_rd_mem_data;
    always_comb case (ex_decoded.funct3[1:0])
        2'b11: wb_rd_mem_data = mmu_rdata[63:0];
        2'b10: wb_rd_mem_data = {{32{mmu_rdata[31] & ~ex_decoded.funct3[2]}}, mmu_rdata[31:0]};
        2'b01: wb_rd_mem_data = {{48{mmu_rdata[15] & ~ex_decoded.funct3[2]}}, mmu_rdata[15:0]};
        2'b00: wb_rd_mem_data = {{56{mmu_rdata[7] & ~ex_decoded.funct3[2]}}, mmu_rdata[7:0]};
    endcase

    
    
    assign wb_commit = state == RISCV_WB && (
        ex_decoded.is_muldiv ? muldiv_done : 
        ex_decoded.is_read_mem || ex_decoded.is_write_mem || ex_decoded.is_atomic ? mmu_rvalid :
        1'b1
    );
    always_comb begin
        state_nxt = state;
        exception_cause_nxt = 'x;
        exception_mtval_nxt = 'x;
        case (state)
            RISCV_IF: if (mmu_gnt) state_nxt = RISCV_ID;
            RISCV_ID: if (mmu_rvalid) state_nxt = RISCV_EX;
            RISCV_EX: begin
					state_nxt = ex_decoded.is_atomic || ex_decoded.is_write_mem || ex_decoded.is_read_mem ? RISCV_MEM : RISCV_WB;
					if (wb_pc_nxt[1]) begin
					   exception_cause_nxt = 4'd0;
					   exception_mtval_nxt = wb_pc_nxt;
					   state_nxt = RISCV_TRAP;
					end
					if (ex_decoded.is_csr_access && ex_csr_rdval[64] || ex_decoded.is_illegal) begin
					   exception_cause_nxt = 4'd2;
					   exception_mtval_nxt = ex_instruction;
					   state_nxt = RISCV_TRAP;
					end
					if (ex_decoded.is_ebreak) begin
					   exception_cause_nxt = 4'd3;
					   exception_mtval_nxt = pc;
					   state_nxt = RISCV_TRAP;
					end
					if (ex_decoded.is_read_mem) begin
					   exception_cause_nxt = 4'd4;
					   exception_mtval_nxt = ex_mem_addr_w;
					   if (ex_decoded.funct3[1:0] == 2'b01 && ex_mem_addr_w[0] ||
					       ex_decoded.funct3[1:0] == 2'b10 && ex_mem_addr_w[1:0] ||
					       ex_decoded.funct3[1:0] == 2'b11 && ex_mem_addr_w[2:0])
					       state_nxt = RISCV_TRAP;
					end
					if (ex_decoded.is_write_mem) begin
					   exception_cause_nxt = 4'd6;
					   exception_mtval_nxt = ex_mem_addr_w;
					   if (ex_decoded.funct3[1:0] == 2'b01 && ex_mem_addr_w[0] ||
					       ex_decoded.funct3[1:0] == 2'b10 && ex_mem_addr_w[1:0] ||
					       ex_decoded.funct3[1:0] == 2'b11 && ex_mem_addr_w[2:0])
					       state_nxt = RISCV_TRAP;
					end
					if (ex_decoded.is_ecall) begin
					   exception_cause_nxt = {2'b10, current_priv};
					   exception_mtval_nxt = '0;
					   state_nxt = RISCV_TRAP;
					end
				end
            RISCV_MEM: if (mmu_gnt) state_nxt = RISCV_WB;
            RISCV_WB:
                    if (ex_decoded.is_muldiv)
                        state_nxt = muldiv_done ? RISCV_IF : RISCV_WB;
                      else if (ex_decoded.is_read_mem || ex_decoded.is_write_mem || ex_decoded.is_atomic)
                        state_nxt = mmu_rvalid ? RISCV_IF : RISCV_WB;
                      else
                        state_nxt = RISCV_IF;
			RISCV_TRAP: state_nxt = RISCV_IF;
            default: state_nxt = RISCV_IF;
        endcase
    end
    assign wb_wren = wb_commit && wb_reg_write;
    assign wb_wdata = ex_decoded.is_read_mem || ex_decoded.is_atomic ?  wb_rd_mem_data : 
                      ex_decoded.is_muldiv 							 ? 	wb_muldiv_result :
                      ex_decoded.is_lui                              ?  ex_decoded_imm_val :
                      ex_decoded.is_auipc                            ?  ex_pc_p_imm :
                      ex_decoded.is_jalr || ex_decoded.is_jal        ?  pc + 4 :
                      ex_decoded.is_csr_access                       ?  wb_csr_rdval : 
                                                                        wb_alu_result;
    assign wb_dst = wb_rd;

    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            state <= RISCV_IF;
        else
            state <= state_nxt;
	 typedef struct packed {
		reg[2:0] size;
		reg[63:0] wdata;
		reg access_instfetch;
		reg access_atomic;
		reg access_memwrite;
		reg access_memread;
		reg[4:0] atomic_opcode;
	 } MEM_REQ_ENTRY;
	 MEM_REQ_ENTRY mmu_data;
     
	 
	 (* fsm_encoding = "one_hot" *) typedef enum {
		MMU_IDLE,
		MMU_PHY_REQ,
        MMU_PHY_RES,
		MMU_DONE
	 } MMU_STATE;
	 (* fsm_encoding = "one_hot" *) MMU_STATE mmu_state /*synthesis syn_encoding="onehot"*/;
	 (* fsm_encoding = "one_hot" *) MMU_STATE mmu_state_nxt /*synthesis syn_encoding="onehot"*/;
    
    wire mmu_req  = state == RISCV_IF || state == RISCV_MEM;

	 
	 always_comb begin
		mmu_state_nxt = mmu_state;
		case (mmu_state)
			MMU_IDLE: if (mmu_req) mmu_state_nxt = MMU_PHY_REQ;
			MMU_PHY_REQ: if (bus_if.aready) mmu_state_nxt = MMU_PHY_RES;
            MMU_PHY_RES: if (bus_if.rvalid) mmu_state_nxt = MMU_DONE;
			MMU_DONE: mmu_state_nxt = MMU_IDLE;
            default: mmu_state_nxt = MMU_IDLE;
		endcase
	 end
	 
	 always_ff @(posedge clk or negedge rstn)
		if (!rstn)
			mmu_state <= MMU_IDLE;
		else
			mmu_state <= mmu_state_nxt;
			
	 reg[31:0] mmu_walk_addr;
	 always_ff @(posedge clk or negedge rstn)
		if (!rstn) begin
			mmu_data <= '{default: '0};
			mmu_walk_addr <= '0;
            mmu_rdata <= '0;
		end else begin
		      case (mmu_state)
                MMU_IDLE: begin
                    mmu_walk_addr <= state == RISCV_IF ? ifetch_pc : mem_mem_addr;

                    mmu_data <= '{
                                      size: (state == RISCV_IF ? 2 : ex_decoded.funct3[1:0]),
                                      wdata: omem_wdata,
                                      access_instfetch: state == RISCV_IF,
                                      access_memread : state == RISCV_MEM && ex_decoded.is_read_mem,
                                      access_memwrite: state == RISCV_MEM && ex_decoded.is_write_mem,
                                      access_atomic: state == RISCV_MEM && ex_decoded.is_atomic,
                                      atomic_opcode: ex_instruction[31:27]
                                   };
                end
                
                MMU_PHY_RES: begin
                    mmu_rdata <= bus_if.rdata;
                end
		      endcase
        end
			
	 
	 assign bus_if.avalid         = mmu_state == MMU_PHY_REQ;
	 assign bus_if.awren          = mmu_data.access_memwrite;
	 assign bus_if.asize          = mmu_data.size;
	 assign bus_if.awdata         = mmu_data.wdata; 
	 assign bus_if.addr           = mmu_walk_addr;
	 assign bus_if.atomic_opcode  = mmu_data.atomic_opcode;
	 assign bus_if.is_atomic      = mmu_data.access_atomic;
	 
	 
	 assign mmu_gnt = mmu_state == MMU_IDLE;
	 assign mmu_rvalid = mmu_state == MMU_DONE;
    
endmodule
