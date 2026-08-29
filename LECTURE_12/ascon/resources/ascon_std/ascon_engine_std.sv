module ascon_engine_std (
  input  logic        clk_i,
  input  logic        rst_ni,

  // Control interface
  input  logic        start_i,
  input  logic [2:0]  mode_i,
  input  logic [63:0] data_in_i,
  input  logic        data_in_valid_i,
  input  logic        last_block_i,
  input  logic [3:0]  last_bytes_i,
  input  logic        phase_sel_i,
  input  logic [127:0] exp_tag_i,
  input  logic [10:0] out_len_i,

  // Outputs
  output logic [63:0]  data_out_o,
  output logic         data_out_valid_o,
  output logic         data_in_ready_o,
  output logic         busy_o,
  output logic         done_o,
  output logic [255:0] hash_o,
  output logic         tag_valid_o,
  output logic         auth_fail_o
);

  `include "ascon_defs_std.svh"

  // ──────────────────────────────────────────────────────────────────────
  // Control registers
  // ──────────────────────────────────────────────────────────────────────
  logic [3:0]   state_q,      state_d;
  logic [3:0]   round_q,      round_d;
  logic [2:0]   mode_q,       mode_d;
  logic [3:0]   ret_state_q,  ret_state_d;
  logic [10:0]  cnt_q,        cnt_d;
  logic [10:0]  target_q,     target_d;
  logic [3:0]   chunk_q,      chunk_d;
  logic [3:0]   last_bytes_q, last_bytes_d;
  logic         last_block_q, last_block_d;
  logic         absorbing_ad_q, absorbing_ad_d;
  logic         phase2_q,     phase2_d;
  logic         busy_q,       busy_d;
  logic         done_q,       done_d;
  logic         tag_valid_q,  tag_valid_d;
  logic         auth_fail_q,  auth_fail_d;

  // ──────────────────────────────────────────────────────────────────────
  // Datapath registers
  // ──────────────────────────────────────────────────────────────────────
  logic [63:0]  x0_q, x0_d;
  logic [63:0]  x1_q, x1_d;
  logic [63:0]  x2_q, x2_d;
  logic [63:0]  x3_q, x3_d;
  logic [63:0]  x4_q, x4_d;
  logic [255:0] hash_q,    hash_d;
  logic [127:0] entropy_q, entropy_d;  // 128-bit AEAD key only (no DRBG V)
  logic [63:0]  data_out_q,  data_out_d;
  logic         dout_valid_q, dout_valid_d;

  // ──────────────────────────────────────────────────────────────────────
  // Permutation (combinational, single round)
  // ──────────────────────────────────────────────────────────────────────
  wire [63:0] px0, px1, px2, px3, px4;

  asconp permutation (
    .rcon   (round_q),
    .x0_in  (x0_q), .x1_in(x1_q), .x2_in(x2_q), .x3_in(x3_q), .x4_in(x4_q),
    .x0_out (px0),   .x1_out(px1),  .x2_out(px2),  .x3_out(px3),  .x4_out(px4)
  );

  // ──────────────────────────────────────────────────────────────────────
  // DP command wires (ctrl → dp)
  // ──────────────────────────────────────────────────────────────────────
  logic dp_x_ld_perm, dp_x_ld_init, dp_init_load;
  logic dp_x0_xor_data, dp_x0_xor_pad;
  logic dp_x1_xor_pad, dp_x4_dom_sep;
  logic dp_kadd_ph1, dp_kadd_ph2;
  logic dp_aead_ad, dp_aead_ct;
  logic dp_squeeze_hash;
  logic dp_tag_compute, dp_dout_squeeze;
  logic tag_fail;

  // ──────────────────────────────────────────────────────────────────────
  // Control FSM
  // ──────────────────────────────────────────────────────────────────────
  ascon_ctrl_std ctrl_inst (
    .state_q,       .round_q,       .mode_q,        .ret_state_q,
    .cnt_q,         .target_q,      .chunk_q,
    .last_bytes_q,  .last_block_q,
    .absorbing_ad_q, .phase2_q,
    .busy_q,        .tag_valid_q,   .auth_fail_q,
    // External inputs
    .start_i,       .mode_i,        .out_len_i,
    .data_in_valid_i, .last_block_i, .last_bytes_i, .phase_sel_i,
    // From DP
    .tag_fail_i      (tag_fail),
    // Next ctrl regs
    .state_d,        .round_d,       .mode_d,        .ret_state_d,
    .cnt_d,          .target_d,      .chunk_d,
    .last_bytes_d,   .last_block_d,
    .absorbing_ad_d, .phase2_d,
    .busy_d,         .done_d,        .tag_valid_d,   .auth_fail_d,
    // DP commands
    .dp_x_ld_perm,   .dp_x_ld_init,  .dp_init_load,
    .dp_x0_xor_data, .dp_x0_xor_pad,
    .dp_x1_xor_pad,  .dp_x4_dom_sep,
    .dp_kadd_ph1,    .dp_kadd_ph2,
    .dp_aead_ad,     .dp_aead_ct,
    .dp_squeeze_hash,
    .dp_tag_compute, .dp_dout_squeeze
  );

  // ──────────────────────────────────────────────────────────────────────
  // Datapath
  // ──────────────────────────────────────────────────────────────────────
  ascon_dp_std dp_inst (
    .x0_q,           .x1_q,          .x2_q,          .x3_q,          .x4_q,
    .hash_q,         .entropy_q,     .data_out_q,
    // Permutation outputs
    .px0,            .px1,           .px2,           .px3,           .px4,
    // Context from ctrl registers
    .mode_q_i        (mode_q),
    .last_bytes_q_i  (last_bytes_q),
    .chunk_i         (chunk_q),
    // External inputs
    .data_in_i,      .last_block_i,  .last_bytes_i,
    .phase_sel_i,    .exp_tag_i,
    // DP commands
    .dp_x_ld_perm,   .dp_x_ld_init,  .dp_init_load,
    .dp_x0_xor_data, .dp_x0_xor_pad,
    .dp_x1_xor_pad,  .dp_x4_dom_sep,
    .dp_kadd_ph1,    .dp_kadd_ph2,
    .dp_aead_ad,     .dp_aead_ct,
    .dp_squeeze_hash,
    .dp_tag_compute, .dp_dout_squeeze,
    // Next DP regs
    .x0_d,           .x1_d,          .x2_d,          .x3_d,          .x4_d,
    .hash_d,         .entropy_d,     .data_out_d,    .dout_valid_d,
    // Tag comparison
    .tag_fail_o      (tag_fail)
  );

  // ──────────────────────────────────────────────────────────────────────
  // Sequential update
  // ──────────────────────────────────────────────────────────────────────
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      x0_q           <= 64'd0;
      x1_q           <= 64'd0;
      x2_q           <= 64'd0;
      x3_q           <= 64'd0;
      x4_q           <= 64'd0;
      state_q        <= S_IDLE;
      round_q        <= 4'd0;
      mode_q         <= 3'd0;
      ret_state_q    <= S_IDLE;
      cnt_q          <= 11'd0;
      target_q       <= 11'd0;
      chunk_q        <= 4'd0;
      last_bytes_q   <= 4'd0;
      last_block_q   <= 1'b0;
      absorbing_ad_q <= 1'b0;
      phase2_q       <= 1'b0;
      hash_q         <= 256'd0;
      entropy_q      <= 128'd0;
      data_out_q     <= 64'd0;
      dout_valid_q   <= 1'b0;
      busy_q         <= 1'b0;
      done_q         <= 1'b0;
      tag_valid_q    <= 1'b0;
      auth_fail_q    <= 1'b0;
    end else begin
      x0_q           <= x0_d;
      x1_q           <= x1_d;
      x2_q           <= x2_d;
      x3_q           <= x3_d;
      x4_q           <= x4_d;
      state_q        <= state_d;
      round_q        <= round_d;
      mode_q         <= mode_d;
      ret_state_q    <= ret_state_d;
      cnt_q          <= cnt_d;
      target_q       <= target_d;
      chunk_q        <= chunk_d;
      last_bytes_q   <= last_bytes_d;
      last_block_q   <= last_block_d;
      absorbing_ad_q <= absorbing_ad_d;
      phase2_q       <= phase2_d;
      hash_q         <= hash_d;
      entropy_q      <= entropy_d;
      data_out_q     <= data_out_d;
      dout_valid_q   <= dout_valid_d;
      busy_q         <= busy_d;
      done_q         <= done_d;
      tag_valid_q    <= tag_valid_d;
      auth_fail_q    <= auth_fail_d;
    end
  end

  // ──────────────────────────────────────────────────────────────────────
  // Output assignments
  // ──────────────────────────────────────────────────────────────────────
  assign data_out_o       = data_out_q;
  assign data_out_valid_o = dout_valid_q;
  // Ready when the engine will consume data_in_valid_i on the next clock edge:
  //   S_INIT chunk≠0 : waiting for AEAD key/nonce words
  //   S_ABSORB        : waiting for AD/PT/message words
  assign data_in_ready_o  = (state_q == S_INIT && chunk_q != 4'd0) ||
                             (state_q == S_ABSORB);
  assign busy_o           = busy_q;
  assign done_o           = done_q;
  assign hash_o           = hash_q;
  assign tag_valid_o      = tag_valid_q;
  assign auth_fail_o      = auth_fail_q;

endmodule
