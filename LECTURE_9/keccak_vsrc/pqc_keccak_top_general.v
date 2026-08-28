`timescale 1ns / 1ps

module pqc_keccak_top_general(
  input  wire         iClk,
  input  wire         iRst,
  input  wire         iWriteEn,     // SW writes 64-bit data
  input  wire  [63:0] iWriteData,
  input  wire  [11:0] iDataLen, 
  input  wire         iEndPacket,   // SW signals end of one message
  input  wire         iFinalPacket, // SW signals this is last packet (oLastBlk=1)
  output reg          oInReady,     // FSM ready to accept writes

  input  wire         iReadEn,
  input  wire         iReadDone,
  output reg  [63:0]  oReadData,
  output reg          oDigestValid, // digest/XOF block available
  output reg          oOutReady,
  input  wire  [2:0]  iMode
    );
    
localparam [2:0] MODE_SHA3_224 = 3'b000, 
                 MODE_SHA3_256 = 3'b001, 
                 MODE_SHA3_512 = 3'b010, 
                 MODE_SHAKE128 = 3'b011, 
                 MODE_SHAKE256 = 3'b100; 


reg  [ 7:0] rate_bytes; 
reg  [ 7:0] pad_byte;
reg  [11:0] bytes_left;
wire [63:0] raw_word;

always @(*) begin 
    case (iMode) 
        MODE_SHA3_224: begin rate_bytes <= 8'd144; pad_byte   <= 8'h06; end 
        MODE_SHA3_256: begin rate_bytes <= 8'd136; pad_byte   <= 8'h06; end 
        MODE_SHA3_512: begin rate_bytes <= 8'd72;  pad_byte   <= 8'h06; end 
        MODE_SHAKE128: begin rate_bytes <= 8'd168; pad_byte   <= 8'h1F; end 
        MODE_SHAKE256: begin rate_bytes <= 8'd136; pad_byte   <= 8'h1F; end 
        default: begin       rate_bytes <= 8'd136; pad_byte   <= 8'h06; end 
    endcase 
end

localparam [3:0]
    S_IDLE            = 4'd0,
    S_RECV            = 4'd1, 
    S_WAIT_DATA       = 4'd2, 
    S_PAD             = 4'd3, 
    S_WAIT_DONE       = 4'd4, 
    S_STORE_OUT       = 4'd5, 
    S_WAIT_RD_READY   = 4'd6, 
    S_OUTPUT_RD       = 4'd7,
    S_WAIT_END_PACKET = 4'd8,
    S_START_KECCAK    = 4'd9,
    S_WAIT_1          = 4'd10, 
    S_SEND            = 4'd11;

reg [3:0]     state; 
reg [63:0]    ibuf_mem [0:24];
reg [11:0]    filled_bytes_in_block; 
reg [7:0]     out_read_word_idx;  
wire [1599:0] digest_from_core;

assign raw_word = digest_from_core[1599 - out_read_word_idx * 64 -: 64];
wire [63:0]   write_bytes; 
assign write_bytes = { iWriteData[7:0],   iWriteData[15:8],  iWriteData[23:16], iWriteData[31:24], 
                       iWriteData[39:32], iWriteData[47:40], iWriteData[55:48], iWriteData[63:56] };  

reg         write_enable; 
reg         read_enable; // Sequential datapath 
integer     b; 
wire [11:0] copy_bytes;
reg         up_date_byte_left;
wire [7:0]  word_idx;
wire [2:0]  ridx;
assign ridx         = filled_bytes_in_block[2:0]; 
assign word_idx     = filled_bytes_in_block[11:3]; 
assign copy_bytes   = (bytes_left >= 12'd8) ? 12'd8 : bytes_left; 

wire [1599:0] data_to_core;
reg  start_keccak_core;
wire keccak_core_finish;

assign data_to_core = {ibuf_mem[0],  ibuf_mem[1],  ibuf_mem[2],  ibuf_mem[3],  ibuf_mem[4],  
                       ibuf_mem[5],  ibuf_mem[6],  ibuf_mem[7],  ibuf_mem[8],  ibuf_mem[9],  
                       ibuf_mem[10], ibuf_mem[11], ibuf_mem[12], ibuf_mem[13], ibuf_mem[14], 
                       ibuf_mem[15], ibuf_mem[16], ibuf_mem[17], ibuf_mem[18], ibuf_mem[19], 
                       ibuf_mem[20], ibuf_mem[21], ibuf_mem[22], ibuf_mem[23], ibuf_mem[24]};


//============= catch the rising edge of write_enable ==========
reg       wr_en_delay;
wire      wr_en_rise;
always @(posedge iClk) begin
  if(iRst) wr_en_delay <= 1'b0;
  else     wr_en_delay <= iWriteEn;
end
assign wr_en_rise = iWriteEn & ~wr_en_delay;

//=========================================================

//============= catch the rising edge of read_enable ==========
reg       rd_en_delay;
wire      rd_en_rise;
always @(posedge iClk) begin
  if(iRst) rd_en_delay <= 1'b0;
  else     rd_en_delay <= iReadEn;
end
assign rd_en_rise = iReadEn & ~rd_en_delay;

//=========================================================

always @(posedge iClk) begin
    if (iRst) begin
        state                   <= S_IDLE;
        filled_bytes_in_block   <= 12'd0;
        out_read_word_idx       <= 0;
        up_date_byte_left       <= 1;
        start_keccak_core       <= 1'b0;
        write_enable            <= 1'b0;
        oInReady                <= 1'b0;
        oDigestValid            <= 1'b0;
        oOutReady               <= 1'b0;
        oReadData               <= 64'd0;
        read_enable  <= 1'b0;
        bytes_left   <= 12'd0;
        ibuf_mem[0]  <= 64'h0;
        ibuf_mem[1]  <= 64'h0;
        ibuf_mem[2]  <= 64'h0;
        ibuf_mem[3]  <= 64'h0;
        ibuf_mem[4]  <= 64'h0;
        ibuf_mem[5]  <= 64'h0;
        ibuf_mem[6]  <= 64'h0;
        ibuf_mem[7]  <= 64'h0;
        ibuf_mem[8]  <= 64'h0;
        ibuf_mem[9]  <= 64'h0;
        ibuf_mem[10] <= 64'h0;
        ibuf_mem[11] <= 64'h0;
        ibuf_mem[12] <= 64'h0;
        ibuf_mem[13] <= 64'h0;
        ibuf_mem[14] <= 64'h0;
        ibuf_mem[15] <= 64'h0;
        ibuf_mem[16] <= 64'h0;
        ibuf_mem[17] <= 64'h0;
        ibuf_mem[18] <= 64'h0;
        ibuf_mem[19] <= 64'h0;
        ibuf_mem[20] <= 64'h0;
        ibuf_mem[21] <= 64'h0;
        ibuf_mem[22] <= 64'h0;
        ibuf_mem[23] <= 64'h0;
        ibuf_mem[24] <= 64'h0;
    end else begin
        case (state)
//=======================================================================
        S_IDLE: begin
            oInReady <= 1'b1;
            oDigestValid <= 1'b0;
            oOutReady    <= 1'b0;
            oReadData    <= 64'd0;
            filled_bytes_in_block <= 12'd0;
            ibuf_mem[0]  <= 64'h0;
            ibuf_mem[1]  <= 64'h0;
            ibuf_mem[2]  <= 64'h0;
            ibuf_mem[3]  <= 64'h0;
            ibuf_mem[4]  <= 64'h0;
            ibuf_mem[5]  <= 64'h0;
            ibuf_mem[6]  <= 64'h0;
            ibuf_mem[7]  <= 64'h0;
            ibuf_mem[8]  <= 64'h0;
            ibuf_mem[9]  <= 64'h0;
            ibuf_mem[10] <= 64'h0;
            ibuf_mem[11] <= 64'h0;
            ibuf_mem[12] <= 64'h0;
            ibuf_mem[13] <= 64'h0;
            ibuf_mem[14] <= 64'h0;
            ibuf_mem[15] <= 64'h0;
            ibuf_mem[16] <= 64'h0;
            ibuf_mem[17] <= 64'h0;
            ibuf_mem[18] <= 64'h0;
            ibuf_mem[19] <= 64'h0;
            ibuf_mem[20] <= 64'h0;
            ibuf_mem[21] <= 64'h0;
            ibuf_mem[22] <= 64'h0;
            ibuf_mem[23] <= 64'h0;
            ibuf_mem[24] <= 64'h0;
            out_read_word_idx     <= 0;
            if(up_date_byte_left) begin
                bytes_left   <= iDataLen;
            end
            if (wr_en_rise && oInReady) begin
                write_enable <= 1'b1;
                oInReady     <= 1'b0;
                state        <= S_RECV;
            end
            else if(iFinalPacket) begin
                state <= S_SEND;
            end
        end
//=======================================================================
S_WAIT_DATA: begin
    up_date_byte_left <= 1'b0;
    oInReady <= 1'b1;
    if (wr_en_rise && oInReady) begin
        write_enable <= 1'b1;
        oInReady     <= 1'b0;
        state <= S_RECV;
        end
        else begin
            state <= S_WAIT_DATA;
        end
    end
//=======================================================================
S_RECV: begin
    if (write_enable) begin
        if (copy_bytes == 8) begin
            ibuf_mem[word_idx] <= write_bytes;
        end else begin
            for (b = 0; b < 8; b = b + 1)
                if (b < copy_bytes)
                    ibuf_mem[word_idx][(b*8)+:8] <= write_bytes[(b*8)+:8];
        end
        filled_bytes_in_block <= filled_bytes_in_block + copy_bytes;
        bytes_left            <= bytes_left - copy_bytes;
        write_enable          <= 1'b0;

        if (filled_bytes_in_block + copy_bytes >= rate_bytes || (bytes_left == copy_bytes) || iEndPacket) begin
            state <= S_WAIT_END_PACKET;
        end else begin
            state <= S_WAIT_DATA;
        end
      end
    end
//=======================================================================
S_WAIT_END_PACKET: begin
  if (iEndPacket || iFinalPacket) begin
    state <= S_PAD;
  end
end
//=======================================================================
S_PAD: begin
    if (iFinalPacket) begin
        ibuf_mem[word_idx] <= ibuf_mem[word_idx] ^ ({56'h0, pad_byte} << (ridx * 8));
        ibuf_mem[(rate_bytes >> 3) - 1][63] <= ibuf_mem[(rate_bytes >> 3) - 1][63] ^ 1'b1;
        filled_bytes_in_block <= rate_bytes;
    end
    state <= S_SEND;
  end
//========================================================================
S_SEND: begin
    start_keccak_core <= 1'b1;
    state  <= S_START_KECCAK;
end
//========================================================================
S_START_KECCAK: begin
    start_keccak_core <= 1'b0;
    state  <= S_WAIT_1;
end

//========================================================================
S_WAIT_1: begin
    state  <= S_WAIT_DONE;
end
//========================================================================
S_WAIT_DONE: begin
    if (keccak_core_done) begin
        if (iFinalPacket && keccak_core_finish)
            state <= S_STORE_OUT;
        else
            state <= S_IDLE;
        end
    end
//========================================================================
S_STORE_OUT: begin
    state <= S_WAIT_RD_READY;
    oDigestValid <= 1'b1;
end
//========================================================================
S_WAIT_RD_READY: begin
    if (rd_en_rise) begin
        oOutReady   <= 1'b0;
        state <= S_OUTPUT_RD;
        read_enable  <= 1'b1;
//        oDigestValid <= 1'b0;
    end
    else if(iReadDone) begin
        state <= S_IDLE;
        read_enable <= 1'b0;
    end
    else begin
        state <= S_WAIT_RD_READY;
        read_enable <= 1'b0;
    end
end
//========================================================================
S_OUTPUT_RD: begin
    if (read_enable) begin
        oOutReady <= 1'b1;
        oReadData <= {  raw_word[7:0],   raw_word[15:8],
                        raw_word[23:16], raw_word[31:24],
                        raw_word[39:32], raw_word[47:40],
                        raw_word[55:48], raw_word[63:56]};
        if (out_read_word_idx < 21)
            out_read_word_idx <= out_read_word_idx + 1;
            read_enable <= 1'b0;
        end
        if (iReadDone) begin
            state <= S_IDLE;
        end else begin
            state <= S_WAIT_RD_READY;
//            oDigestValid <= 1'b1;
        end 
    end 
//======================================================================== 
    endcase 
  end 
end
  
  
sha3 keccak_function(
    .iClk(iClk),
    .iRst(iRst),
    .iLast_blk(iFinalPacket),
    .iMsg(data_to_core),
    .iValid(start_keccak_core),
    .oState(digest_from_core),
    .oDone(keccak_core_done),
    .oFinish(keccak_core_finish)
);  
                   
endmodule