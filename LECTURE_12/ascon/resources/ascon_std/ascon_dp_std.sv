module ascon_dp_std (
  // Current DP registers
  input  logic [63:0]   x0_q, x1_q, x2_q, x3_q, x4_q,
  input  logic [255:0]  hash_q,
  input  logic [127:0]  entropy_q,
  input  logic [63:0]   data_out_q,

  // Permutation outputs
  input  logic [63:0]   px0, px1, px2, px3, px4,

  // Context from ctrl registers (read-only)
  input  logic [2:0]    mode_q_i,
  input  logic [3:0]    last_bytes_q_i,
  input  logic [3:0]    chunk_i,

  // External inputs
  input  logic [63:0]   data_in_i,
  input  logic          last_block_i,
  input  logic [3:0]    last_bytes_i,
  input  logic          phase_sel_i,
  input  logic [127:0]  exp_tag_i,

  // DP commands from ctrl
  input  logic          dp_x_ld_perm,
  input  logic          dp_x_ld_init,
  input  logic          dp_init_load,
  input  logic          dp_x0_xor_data,
  input  logic          dp_x0_xor_pad,
  input  logic          dp_x1_xor_pad,
  input  logic          dp_x4_dom_sep,
  input  logic          dp_kadd_ph1,
  input  logic          dp_kadd_ph2,
  input  logic          dp_aead_ad,
  input  logic          dp_aead_ct,
  input  logic          dp_squeeze_hash,
  input  logic          dp_tag_compute,
  input  logic          dp_dout_squeeze,

  // Next DP register values
  output logic [63:0]   x0_d, x1_d, x2_d, x3_d, x4_d,
  output logic [255:0]  hash_d,
  output logic [127:0]  entropy_d,
  output logic [63:0]   data_out_d,
  output logic          dout_valid_d,

  // Tag comparison result
  output logic          tag_fail_o
);

  `include "ascon_defs_std.svh"

  // ────────────────────────────────────────────────────────────────
  // Key alias
  // entropy_q holds the 128-bit symmetric key for AEAD.
  // Loaded word-by-word during S_INIT (dp_init_load, chunks 1-2).
  // ────────────────────────────────────────────────────────────────
  wire [127:0] stored_key = entropy_q;

  // ────────────────────────────────────────────────────────────────
  // Derived wires
  // ────────────────────────────────────────────────────────────────
  wire is_aead = (mode_q_i == M_ENC) || (mode_q_i == M_DEC);

  // IV mux — selects the ASCON initialisation vector per NIST SP 800-232.
  wire [63:0] iv_mux = is_aead              ? IV_AEAD :
                        (mode_q_i == M_XOF)  ? IV_XOF  :
                        (mode_q_i == M_CXOF) ? IV_CXOF :
                                               IV_HASH;

  // Padding constant — byte-position one-hot used in S_PAD.
  // last_bytes_q_i counts valid data bytes in the last block; the '1' bit is
  // placed one position after the last valid byte (NIST SP 800-232 LE order).
  // Implemented as a case LUT to avoid the wide-shift critical path.
  logic [63:0] pad_const;
  always_comb begin
    case (last_bytes_q_i[2:0])
      3'd0: pad_const = 64'h0000000000000001; // no valid bytes: pad at byte 0
      3'd1: pad_const = 64'h0000000000000100; // 1 valid byte:  pad at byte 1
      3'd2: pad_const = 64'h0000000000010000;
      3'd3: pad_const = 64'h0000000001000000;
      3'd4: pad_const = 64'h0000000100000000;
      3'd5: pad_const = 64'h0000010000000000;
      3'd6: pad_const = 64'h0001000000000000;
      3'd7: pad_const = 64'h0100000000000000; // 7 valid bytes: pad at byte 7
    endcase
  end

  // ────────────────────────────────────────────────────────────────
  // AEAD absorb datapath
  // phase_sel_i selects which ASCON rate word absorbs this block half:
  //   phase_sel_i == 0  →  first 64-bit half  → x0
  //   phase_sel_i == 1  →  second 64-bit half → x1
  // ────────────────────────────────────────────────────────────────
  wire [63:0] absorb_ks  = phase_sel_i ? x1_q : x0_q;
  wire [63:0] absorb_xor = absorb_ks ^ data_in_i;
  // last_bytes_i counts valid bytes across the whole 128-bit AEAD block (0..15),
  // but this replacement operates on one 64-bit half, so the half's own count is
  // derived here. A final block on the second half with last_bytes_i == 0 is the
  // full-rate encoding (16 valid bytes), so both halves are fully valid.
  wire        aead_full_rate = last_block_i && phase_sel_i && (last_bytes_i == 4'd0);
  logic [3:0] half_bytes;
  always_comb begin
    if (aead_full_rate)
      half_bytes = 4'd8;
    else if (!phase_sel_i)
      half_bytes = (last_bytes_i > 4'd8) ? 4'd8 : last_bytes_i;
    else
      half_bytes = (last_bytes_i > 4'd8) ? (last_bytes_i - 4'd8) : 4'd0;
  end

  logic [63:0] absorb_new;
  always_comb begin
    if (mode_q_i == M_ENC) begin
      absorb_new = absorb_xor;
    end else if (!last_block_i || half_bytes == 4'd8) begin
      absorb_new = data_in_i;
    end else begin
      absorb_new = absorb_ks;
      if (half_bytes >= 4'd1) absorb_new[7:0]   = data_in_i[7:0];
      if (half_bytes >= 4'd2) absorb_new[15:8]  = data_in_i[15:8];
      if (half_bytes >= 4'd3) absorb_new[23:16] = data_in_i[23:16];
      if (half_bytes >= 4'd4) absorb_new[31:24] = data_in_i[31:24];
      if (half_bytes >= 4'd5) absorb_new[39:32] = data_in_i[39:32];
      if (half_bytes >= 4'd6) absorb_new[47:40] = data_in_i[47:40];
      if (half_bytes >= 4'd7) absorb_new[55:48] = data_in_i[55:48];
    end
  end

  // ────────────────────────────────────────────────────────────────
  // AEAD tag computation
  // ────────────────────────────────────────────────────────────────
  wire [127:0] computed_tag = {(x3_q ^ stored_key[127:64]), (x4_q ^ stored_key[63:0])};
  assign tag_fail_o = (hash_q[255:128] != exp_tag_i);

  // ────────────────────────────────────────────────────────────────
  // x0 XOR input mux
  // ────────────────────────────────────────────────────────────────
  logic [63:0] x0_xor_rhs;
  logic        x0_xor_en;
  always_comb begin
    x0_xor_rhs = 64'd0;
    x0_xor_en  = 1'b0;
    if      (dp_aead_ad && !phase_sel_i) begin x0_xor_rhs = data_in_i; x0_xor_en = 1'b1; end
    else if (dp_x0_xor_data)            begin x0_xor_rhs = data_in_i; x0_xor_en = 1'b1; end
    else if (dp_x0_xor_pad)             begin x0_xor_rhs = pad_const; x0_xor_en = 1'b1; end
  end

  // ────────────────────────────────────────────────────────────────
  // Datapath next-state logic
  // ────────────────────────────────────────────────────────────────
  always_comb begin
    // ── Defaults: hold all registers ──
    x0_d         = x0_q;
    x1_d         = x1_q;
    x2_d         = x2_q;
    x3_d         = x3_q;
    x4_d         = x4_q;
    hash_d       = hash_q;
    entropy_d    = entropy_q;
    data_out_d   = data_out_q;
    dout_valid_d = 1'b0;

    // ── x0 ──────────────────────────────────────────────────────
    if      (dp_x_ld_perm)               x0_d = px0;
    else if (dp_x_ld_init)               x0_d = iv_mux;
    else if (dp_aead_ct && !phase_sel_i) x0_d = absorb_new;
    else if (x0_xor_en)                  x0_d = x0_q ^ x0_xor_rhs;

    // ── x1 ──────────────────────────────────────────────────────
    if      (dp_x_ld_perm)                                    x1_d = px1;
    else if (dp_x_ld_init)                                    x1_d = 64'd0;
    else if (dp_init_load && is_aead && chunk_i == 4'd1)      x1_d = data_in_i;
    else if (dp_aead_ct) begin if (phase_sel_i) x1_d = absorb_new; end
    else if (dp_aead_ad) begin if (phase_sel_i) x1_d = x1_q ^ data_in_i; end
    else if (dp_x1_xor_pad)                                   x1_d = x1_q ^ pad_const;

    // ── x2 ──────────────────────────────────────────────────────
    if      (dp_x_ld_perm)                                    x2_d = px2;
    else if (dp_x_ld_init)                                    x2_d = 64'd0;
    else if (dp_init_load && is_aead && chunk_i == 4'd2)      x2_d = data_in_i;
    else if (dp_kadd_ph2)                                     x2_d = x2_q ^ stored_key[127:64];

    // ── x3 ──────────────────────────────────────────────────────
    if      (dp_x_ld_perm)                                    x3_d = px3;
    else if (dp_x_ld_init)                                    x3_d = 64'd0;
    else if (dp_init_load && is_aead && chunk_i == 4'd3)      x3_d = data_in_i;
    else if (dp_kadd_ph1)                                     x3_d = x3_q ^ stored_key[127:64];
    else if (dp_kadd_ph2)                                     x3_d = x3_q ^ stored_key[63:0];

    // ── x4 ──────────────────────────────────────────────────────
    if      (dp_x_ld_perm)                                    x4_d = px4;
    else if (dp_x_ld_init)                                    x4_d = 64'd0;
    else if (dp_init_load && is_aead && chunk_i == 4'd4)      x4_d = data_in_i;
    else if (dp_kadd_ph1)                                     x4_d = x4_q ^ stored_key[63:0];
    else if (dp_x4_dom_sep)                                   x4_d = x4_q ^ 64'h8000_0000_0000_0000;

    // ── hash_q ──────────────────────────────────────────────────
    //   dp_tag_compute  : store computed AEAD tag in [255:128] for S_TAG_CHK
    //   dp_squeeze_hash : Hash/XOF/CXOF — shift x0 in from right
    if (dp_tag_compute) begin
      hash_d[255:128] = computed_tag;
    end else if (dp_squeeze_hash) begin
      hash_d = {hash_q[191:0], x0_q};
    end

    // ── entropy_q (128-bit key) ──────────────────────────────────
    //   dp_init_load chunks 1/2: write AEAD key words (no masking needed)
    if (dp_init_load) begin
      unique case (chunk_i)
        4'd1: entropy_d[127:64] = data_in_i;
        4'd2: entropy_d[63:0]   = data_in_i;
        default: ;
      endcase
    end

    // ── data_out_q ──────────────────────────────────────────────
    //   dp_dout_squeeze : output x0 (squeezed hash/XOF word)
    //   dp_aead_ct      : output absorb_xor (CT for ENC, PT for DEC)
    if (dp_dout_squeeze) begin
      data_out_d   = x0_q;
      dout_valid_d = 1'b1;
    end else if (dp_aead_ct) begin
      data_out_d   = absorb_xor;
      dout_valid_d = 1'b1;
    end
  end

endmodule
