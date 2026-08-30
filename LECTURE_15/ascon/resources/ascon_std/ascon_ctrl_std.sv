module ascon_ctrl_std (
  // Current control registers
  input  logic [3:0]   state_q,
  input  logic [3:0]   round_q,
  input  logic [2:0]   mode_q,
  input  logic [3:0]   ret_state_q,
  input  logic [10:0]  cnt_q,
  input  logic [10:0]  target_q,
  input  logic [3:0]   chunk_q,
  input  logic [3:0]   last_bytes_q,
  input  logic         last_block_q,
  input  logic         absorbing_ad_q,
  input  logic         phase2_q,
  input  logic         busy_q,
  input  logic         tag_valid_q,
  input  logic         auth_fail_q,

  // External inputs
  input  logic         start_i,
  input  logic [2:0]   mode_i,
  input  logic [10:0]  out_len_i,
  input  logic         data_in_valid_i,
  input  logic         last_block_i,
  input  logic [3:0]   last_bytes_i,
  input  logic         phase_sel_i,

  // From datapath
  input  logic         tag_fail_i,

  // Next control register values
  output logic [3:0]   state_d,
  output logic [3:0]   round_d,
  output logic [2:0]   mode_d,
  output logic [3:0]   ret_state_d,
  output logic [10:0]  cnt_d,
  output logic [10:0]  target_d,
  output logic [3:0]   chunk_d,
  output logic [3:0]   last_bytes_d,
  output logic         last_block_d,
  output logic         absorbing_ad_d,
  output logic         phase2_d,
  output logic         busy_d,
  output logic         done_d,
  output logic         tag_valid_d,
  output logic         auth_fail_d,

  // Datapath commands
  output logic         dp_x_ld_perm,
  output logic         dp_x_ld_init,
  output logic         dp_init_load,
  output logic         dp_x0_xor_data,
  output logic         dp_x0_xor_pad,
  output logic         dp_x1_xor_pad,
  output logic         dp_x4_dom_sep,
  output logic         dp_kadd_ph1,
  output logic         dp_kadd_ph2,
  output logic         dp_aead_ad,
  output logic         dp_aead_ct,
  output logic         dp_squeeze_hash,
  output logic         dp_tag_compute,
  output logic         dp_dout_squeeze
);

  `include "ascon_defs_std.svh"

  wire is_aead     = (mode_q == M_ENC) || (mode_q == M_DEC);
  wire [3:0] pb_rounds = is_aead ? 4'd8 : 4'd12;
  wire [3:0] pa_rounds = 4'd12;

  always_comb begin
    // ── Defaults: hold ──
    state_d        = state_q;
    round_d        = round_q;
    mode_d         = mode_q;
    ret_state_d    = ret_state_q;
    cnt_d          = cnt_q;
    target_d       = target_q;
    chunk_d        = chunk_q;
    last_bytes_d   = last_bytes_q;
    last_block_d   = last_block_q;
    absorbing_ad_d = absorbing_ad_q;
    phase2_d       = phase2_q;
    busy_d         = busy_q;
    done_d         = 1'b0;
    tag_valid_d    = tag_valid_q;
    auth_fail_d    = auth_fail_q;

    // ── DP commands: all off ──
    dp_x_ld_perm    = 1'b0;
    dp_x_ld_init    = 1'b0;
    dp_init_load    = 1'b0;
    dp_x0_xor_data  = 1'b0;
    dp_x0_xor_pad   = 1'b0;
    dp_x1_xor_pad   = 1'b0;
    dp_x4_dom_sep   = 1'b0;
    dp_kadd_ph1     = 1'b0;
    dp_kadd_ph2     = 1'b0;
    dp_aead_ad      = 1'b0;
    dp_aead_ct      = 1'b0;
    dp_squeeze_hash = 1'b0;
    dp_tag_compute  = 1'b0;
    dp_dout_squeeze = 1'b0;

    unique case (state_q)
      // ──────────────────────────────────────────────
      S_IDLE: begin
        busy_d = 1'b0;
        if (start_i) begin
          mode_d         = mode_i;
          cnt_d          = 11'd0;
          tag_valid_d    = 1'b0;
          auth_fail_d    = 1'b0;
          phase2_d       = 1'b0;
          chunk_d        = 4'd0;
          busy_d         = 1'b1;
          state_d        = S_INIT;
          // M_HASH always outputs 4 × 64-bit words (256 bits)
          target_d       = (mode_i == M_HASH) ? 11'd3 : (out_len_i - 11'd1);
          absorbing_ad_d = (mode_i == M_ENC) || (mode_i == M_DEC) || (mode_i == M_CXOF);
        end
      end

      // ──────────────────────────────────────────────
      // S_INIT — multi-cycle for AEAD (key/nonce via data_in)
      //   chunk_q == 0: load IV + zeros
      //                 AEAD: stay for 4 data_in words (key_hi, key_lo, nonce_hi, nonce_lo)
      //                 Hash/XOF/CXOF: immediate → permute
      //   chunk_q == 1..3: wait for data_in_valid, load word
      //   chunk_q == 4: last word loaded → permute(pa) → S_KADD
      // ──────────────────────────────────────────────
      S_INIT: begin
        if (chunk_q == 4'd0) begin
          dp_x_ld_init = 1'b1;
          phase2_d     = 1'b0;

          if (is_aead) begin
            // AEAD: need 4 data_in cycles (key_hi, key_lo, nonce_hi, nonce_lo)
            chunk_d = 4'd1;
            // Stay in S_INIT, wait for data_in_valid
          end else begin
            // Hash/XOF/CXOF: no key/nonce — proceed immediately to permutation
            round_d     = pa_rounds;
            ret_state_d = S_ABSORB;
            state_d     = S_PERMUTE;
          end
        end else if (data_in_valid_i) begin
          // Sub-steps 1..4: load AEAD key/nonce from data_in
          dp_init_load = 1'b1;
          if (chunk_q == 4'd4) begin
            chunk_d     = 4'd0;
            round_d     = pa_rounds;
            ret_state_d = S_KADD;
            state_d     = S_PERMUTE;
          end else begin
            chunk_d = chunk_q + 4'd1;
          end
        end
        // else: waiting for data_in_valid — hold
      end

      // ──────────────────────────────────────────────
      S_PERMUTE: begin
        dp_x_ld_perm = 1'b1;
        if (round_q == 4'd1) begin
          state_d = ret_state_q;
          busy_d  = (ret_state_q != S_ABSORB) && (ret_state_q != S_IDLE);
        end else begin
          round_d = round_q - 4'd1;
        end
      end

      // ──────────────────────────────────────────────
      S_KADD: begin
        if (!phase2_q) begin
          dp_kadd_ph1 = 1'b1;
          state_d     = S_ABSORB;
          busy_d      = 1'b0;
        end else begin
          dp_kadd_ph2 = 1'b1;
          round_d     = pa_rounds;
          ret_state_d = S_TAG;
          state_d     = S_PERMUTE;
        end
      end

      // ──────────────────────────────────────────────
      S_ABSORB: begin
        // P4: AEAD empty-AD skip (phase_sel_i=1 with no data signals end of AD)
        if (is_aead && absorbing_ad_q && phase_sel_i && !data_in_valid_i) begin
          state_d = S_DOM_SEP;
          busy_d  = 1'b1;

        // P5: External data word
        end else if (data_in_valid_i) begin
          last_bytes_d = last_bytes_i;
          last_block_d = last_block_i;

          if (is_aead) begin
            if (absorbing_ad_q)
              dp_aead_ad = 1'b1;
            else
              dp_aead_ct = 1'b1;

            if (!phase_sel_i && !last_block_i) begin
              // First half of 128-bit block: stay for second half
            end else if (last_block_i) begin
              // last_bytes_i counts valid bytes in the whole 128-bit block,
              // spanning 0..15, so it cannot express a block that exactly fills
              // the rate. A final block on the second half (phase_sel_i) with
              // last_bytes_i == 0 is therefore full: absorb it, permute, then
              // pad a fresh empty block. A genuinely empty final block arrives
              // on the first half, so the two cases stay distinct.
              if (phase_sel_i && last_bytes_i == 4'd0) begin
                last_bytes_d = 4'd0;
                round_d      = pb_rounds;
                ret_state_d  = S_PAD;
                state_d      = S_PERMUTE;
                busy_d       = 1'b1;
              end else begin
                state_d = S_PAD;
                busy_d  = 1'b1;
              end
            end else begin
              round_d     = pb_rounds;
              ret_state_d = S_ABSORB;
              state_d     = S_PERMUTE;
              busy_d      = 1'b1;
            end
          end else begin
            dp_x0_xor_data = 1'b1;

            if (!last_block_i) begin
              round_d     = pb_rounds;
              ret_state_d = S_ABSORB;
              state_d     = S_PERMUTE;
              busy_d      = 1'b1;
            end else if (last_bytes_i >= 4'd8) begin
              round_d     = pb_rounds;
              ret_state_d = S_PAD;
              state_d     = S_PERMUTE;
              busy_d      = 1'b1;
            end else begin
              state_d = S_PAD;
              busy_d  = 1'b1;
            end
          end
        end
      end

      // ──────────────────────────────────────────────
      S_PAD: begin
        if (is_aead && last_bytes_q >= 4'd8)
          dp_x1_xor_pad = 1'b1;
        else
          dp_x0_xor_pad = 1'b1;

        if (is_aead) begin
          if (absorbing_ad_q) begin
            round_d     = pb_rounds;
            ret_state_d = S_DOM_SEP;
            state_d     = S_PERMUTE;
          end else begin
            phase2_d = 1'b1;
            state_d  = S_KADD;
          end
        end else if (mode_q == M_CXOF && absorbing_ad_q) begin
          absorbing_ad_d = 1'b0;
          round_d        = pa_rounds;
          ret_state_d    = S_ABSORB;
          state_d        = S_PERMUTE;
        end else begin
          round_d     = pa_rounds;
          ret_state_d = S_SQUEEZE;
          state_d     = S_PERMUTE;
          cnt_d       = 11'd0;
        end
      end

      // ──────────────────────────────────────────────
      S_DOM_SEP: begin
        dp_x4_dom_sep  = 1'b1;
        absorbing_ad_d = 1'b0;
        state_d        = S_ABSORB;
        busy_d         = 1'b0;
      end

      // ──────────────────────────────────────────────
      S_SQUEEZE: begin
        dp_dout_squeeze = 1'b1;
        dp_squeeze_hash = 1'b1;
        cnt_d           = cnt_q + 11'd1;

        if (cnt_q == target_q) begin
          done_d  = 1'b1;
          busy_d  = 1'b0;
          state_d = S_IDLE;
        end else begin
          round_d     = pa_rounds;
          ret_state_d = S_SQUEEZE;
          state_d     = S_PERMUTE;
          busy_d      = 1'b1;
        end
      end

      // ──────────────────────────────────────────────
      S_TAG: begin
        dp_tag_compute = 1'b1;
        tag_valid_d    = 1'b1;
        state_d        = S_TAG_CHK;
      end

      S_TAG_CHK: begin
        if (mode_q == M_DEC)
          auth_fail_d = tag_fail_i;
        done_d  = 1'b1;
        busy_d  = 1'b0;
        state_d = S_IDLE;
      end

      default: ;
    endcase
  end

endmodule
