`default_nettype none


interface slv_interface();
    // address channel input
    logic avalid;
    logic awren;
    logic[2:0] asize;
    logic[63:0] awdata;
    logic[31:0] addr;
    logic[4:0] atomic_opcode;
    logic is_atomic;
    logic aready;
    
    // read channel output
    logic rvalid;
    logic[63:0] rdata;
    modport slv(input avalid, input awren, input asize, input awdata, input addr, output aready, output rvalid, output rdata, input atomic_opcode, input is_atomic);
    modport master(output avalid, output awren, output asize, output awdata, output addr, input aready, input rvalid, input rdata, output atomic_opcode, output is_atomic);
endinterface



module single_master_multi_slave #(
    parameter N_SLAVES = 1,
    parameter logic[31:0] ADDRESS_RANGES[N_SLAVES][2] = '{default: '0}
) (
    input wire clk,
    input wire rstn,
    slv_interface.slv master,
    slv_interface.master slv[N_SLAVES]
);
    for (genvar i = 0; i < N_SLAVES; ++i) begin
        for (genvar j = i+1; j < N_SLAVES; ++j) begin
            if (ADDRESS_RANGES[i][0] < ADDRESS_RANGES[j][1] &&
                ADDRESS_RANGES[j][0] < ADDRESS_RANGES[i][1]) begin
                $error("Error, crossbar, overlap %d %d", i, j);
            end
        end
    end
    typedef enum {
        IDLE,
        SC_RESULT,
        DONE
    } CROSSBAR_STATE;
    CROSSBAR_STATE state;
    CROSSBAR_STATE state_nxt;
    localparam SLV_IDX_WIDTH = $clog2(N_SLAVES);
    
    wire[N_SLAVES-1:0] slave_sel;
    wire[N_SLAVES-1:0] slave_ready;
    wire[N_SLAVES-1:0] slave_rvalid;
    wire[63:0] slave_rdata[N_SLAVES];

    reg[SLV_IDX_WIDTH-1:0] slave_sel_idx;
    always_comb begin
        slave_sel_idx = 0;
        for (int i = 1; i < N_SLAVES; ++i)
            if (slave_sel[i])
                slave_sel_idx = i;
	end
	
    reg[SLV_IDX_WIDTH-1:0] slv_idx_q;
    reg reserved_flag;
    reg[25:0] reserved_address;
    reg sc_failed;
    
    wire sc_success_nxt = reserved_flag && reserved_address == master.addr[31:6];
    wire m_is_sc = master.is_atomic && master.atomic_opcode == 3;
    wire m_is_lr = master.is_atomic && master.atomic_opcode == 2;
    
    always_ff @(posedge clk or negedge rstn)
        if (!rstn) begin
            slv_idx_q <= '0;
            reserved_flag <= 1'b0;
            reserved_address <= '0;
            sc_failed <= 1'b0;
        end else if (master.aready & master.avalid) begin
            slv_idx_q <= slave_sel_idx;
            
            if (m_is_lr) begin
                reserved_flag <= 1'b1;
                reserved_address <= master.addr[31:6];
            end
            
            if (m_is_sc || reserved_address == master.addr[31:6] && master.awren)
                reserved_flag <= 1'b0;
            
            sc_failed <= !sc_success_nxt;
        end
        
    wire to_slave_valid = state == IDLE && master.avalid && !(m_is_sc && !sc_success_nxt);
    genvar i;
    generate
        for (i = 0; i < N_SLAVES; ++i) begin : slave_sel_genvar
            assign slave_sel[i] = master.addr >= ADDRESS_RANGES[i][0] && master.addr < ADDRESS_RANGES[i][1];        
            assign slave_ready[i] = slv[i].aready;
            assign slave_rvalid[i] = slv[i].rvalid;
            assign slave_rdata[i] = slv[i].rdata;
    
    
            assign slv[i].addr = master.addr - ADDRESS_RANGES[i][0];
            assign slv[i].awren = master.awren;
            assign slv[i].asize = master.asize;
            assign slv[i].awdata = master.awdata;
            assign slv[i].avalid = to_slave_valid && slave_sel[i];
            assign slv[i].atomic_opcode = 'x;
            assign slv[i].is_atomic = 1'b0;
        end
    endgenerate
	 
    always_comb begin
        state_nxt = state;
        case (state)
            IDLE: if (master.aready & master.avalid) state_nxt = m_is_sc ? SC_RESULT : DONE;
            SC_RESULT: state_nxt = IDLE;
            DONE: if (slave_rvalid[slv_idx_q]) state_nxt = IDLE;
        endcase
    end


    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            state <= IDLE;
        else
            state <= state_nxt;


    assign master.rvalid = slave_rvalid[slv_idx_q] && state == DONE || state == SC_RESULT;
    assign master.rdata = state == SC_RESULT ? sc_failed : slave_rdata[slv_idx_q];
    assign master.aready = state == IDLE && (slave_sel[slave_sel_idx] && slave_ready[slave_sel_idx]);
endmodule


