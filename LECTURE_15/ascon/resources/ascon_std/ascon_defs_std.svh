// ASCON standard-modes shared definitions (5 modes: ENC, DEC, HASH, XOF, CXOF)
// HMAC-ASCON and XDRBG-ASCON are intentionally excluded.
// Include inside module body only.

// Mode encoding
localparam logic [2:0] M_ENC  = 3'd0;
localparam logic [2:0] M_DEC  = 3'd1;
localparam logic [2:0] M_HASH = 3'd2;
localparam logic [2:0] M_XOF  = 3'd3;
localparam logic [2:0] M_CXOF = 3'd4;

// IVs per NIST SP 800-232
localparam logic [63:0] IV_AEAD = 64'h00001000808c0001;
localparam logic [63:0] IV_HASH = 64'h0000080100cc0002;
localparam logic [63:0] IV_XOF  = 64'h0000080000cc0003;
localparam logic [63:0] IV_CXOF = 64'h0000080000cc0004;

// FSM states (10 states; S_TRNG/S_FETCH removed vs. full 7-mode engine)
localparam logic [3:0] S_IDLE    = 4'd0;
localparam logic [3:0] S_INIT    = 4'd1;
localparam logic [3:0] S_PERMUTE = 4'd2;
localparam logic [3:0] S_KADD    = 4'd3;
localparam logic [3:0] S_ABSORB  = 4'd4;
localparam logic [3:0] S_PAD     = 4'd5;
localparam logic [3:0] S_DOM_SEP = 4'd6;
localparam logic [3:0] S_SQUEEZE = 4'd7;
localparam logic [3:0] S_TAG     = 4'd8;
localparam logic [3:0] S_TAG_CHK = 4'd9;
