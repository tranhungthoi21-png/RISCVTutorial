# Fused ChaCha20-Poly1305 AEAD demo — Arty 100T

Bare-metal RV32 payload that drives the fused `AEAD_chacha_poly` accelerator
against RFC 8439 Sec 2.8.2 and prints PASS/FAIL plus cycle counts on UART0.

| | |
|---|---|
| SoC config | `SmallRocket32ChachaPolyAeadArty100TConfig` |
| Accelerator | `AEAD_chacha_poly` @ `0x6400A000` |
| Scratchpad | 128 kB @ `0x80000000` (firmware links for 64 kB — see `linker/memory.lds`) |
| UART0 | `0x64000000` (reuses whatever baud the bootrom set) |
| Core speed | 50 MHz |

The whole RFC 8439 construction runs in hardware. The core derives the Poly1305
one-time key from ChaCha20 block 0, encrypts from block 1, absorbs AAD and
ciphertext into the MAC, applies `pad16()` by masking each block, and appends
the `le64(len AAD) || le64(len CT)` block. Firmware supplies operands and pulses
the state machine — it never assembles the MAC input.

This is the counterpart to [`../chachapoly/`](../chachapoly/), which exposes the
two primitives as separate peripherals and composes AEAD in firmware.

## Layers

| Layer | Path |
|---|---|
| RTL | [`crypto-vsrc/AEAD_chacha_poly.v`](../../../generators/chipyard/src/main/resources/crypto-vsrc/AEAD_chacha_poly.v) |
| RTL (reused) | [`chacha.preprocessed.v`](../../../generators/chipyard/src/main/resources/crypto-vsrc/chacha.preprocessed.v), [`poly1305.preprocessed.v`](../../../generators/chipyard/src/main/resources/crypto-vsrc/poly1305.preprocessed.v) |
| Chisel wrapper | [`crypto/chacha_poly_aead/`](../../../generators/chipyard/src/main/scala/crypto/chacha_poly_aead/) |
| SoC config | `chipyard.SmallRocket32ChachaPolyAeadConfig`, `SmallRocket32ChachaPolyAeadArty100TConfig` |
| Driver | `src/aead.c`, `src/aead.h` |
| Test software | `src/main.c`, `src/chachapoly_kats.h` (regenerate with `gen_kats.py`) |
| RTL testbench | [`tests/chachapoly_aead_tb.cpp`](../../../tests/chachapoly_aead_tb.cpp), [`tests/Makefile.chachapoly_aead`](../../../tests/Makefile.chachapoly_aead) |
| Sweep vectors | [`tests/gen_chachapoly_aead_vectors.py`](../../../tests/gen_chachapoly_aead_vectors.py) → `tests/chachapoly_aead_vectors.h` |

`AEAD_chacha_poly.v` is imported from
`old_Workspace/TEE_dev/tee-hw-full/hardware/teehwfull/optvsrc/chacha_poly_aead/`.
Its `chacha_core`, `chacha_qr` and `poly1305_*` sub-modules are **byte-identical**
to the copies already inside `chacha.preprocessed.v` and `poly1305.preprocessed.v`,
so only the top-level file was copied in and the wrapper pulls the other two in
by their existing resource paths. Because those paths are the ones `CHACHATL`
and `POLYTL` also use, a design carrying this peripheral *and* the separate
ChaCha/Poly peripherals still sees each module defined exactly once — verified
in the elaborated output.

## 0. Simulate the core (optional, no board needed)

```bash
cd tests
make -f Makefile.chachapoly_aead run
```

Drives the RTL through the same sequence `aead.c` uses over MMIO, so a pass
covers the firmware's protocol and byte order as well as the core itself.

| Test | Coverage |
|---|---|
| RFC 8439 Sec 2.8.2 | encrypt and decrypt against the published vector |
| empty AAD | ciphertext unchanged, tag differs |
| length sweep | **140 vectors**, encrypt *and* decrypt each |
| zero-length message | confirms the documented limitation |

The sweep is 10 AAD lengths (0, 1, 15, 16, 17, 31, 32, 33, 47, 48) crossed with
14 message lengths (1, 15, 16, 17, 31, 32, 33, 63, 64, 65, 100, 127, 128, 129),
so it covers multi-block AAD, multi-block messages, and the partial-block
`pad16` path on either side of both the 16-byte AAD boundary and the 64-byte
data boundary. The nonce varies per vector, exercising a different keystream
each time.

Expected values come from the reference implementation in
`tests/gen_chachapoly_aead_vectors.py`, which validates itself against the
published RFC 8439 Sec 2.8.2 vector and refuses to emit anything if that check
fails. They are independent expectations, not DUT output recorded after the
fact — a self-consistent but wrong core would not pass. Regenerate with:

```bash
cd tests && python3 gen_chachapoly_aead_vectors.py
```

One AEAD operation over the 114-byte vector takes 435 clock cycles.

## 1. Build the bitstream

```bash
cd $CHIPYARD          # repo root
export RISCV=/home/khaiduy/opt/riscv
export PATH=$PWD/.conda-env/bin:$RISCV/bin:/home/khaiduy/Xilinx/Vivado/2024.2/bin:$PATH
export JAVA_HOME=$PWD/.conda-env

rm -f .classpath_cache/chipyard.jar        # only when switching sbt project
make -C fpga SUB_PROJECT=arty100t CONFIG=SmallRocket32ChachaPolyAeadArty100TConfig bitstream
```

The FPGA build and the `sims/verilator` build share `.classpath_cache/chipyard.jar`,
whose name does not record which sbt project produced it — hence the `rm`.
`source ./env.sh` is a no-op in a non-interactive shell, so export the three
variables rather than relying on it.

## 2. Build the payload

```bash
cd fpga/sw/chachapoly_aead
make                       # RISCV=/path/to/toolchain make  to override
```

Produces `build/main.elf`, `build/main.bin` (~4.2 kB), `build/main.dump`.

The Makefile adds `-fno-tree-loop-distribute-patterns`. That pass is on at `-O2`
and rewrites the byte-clearing loops in `aead.c` and `main.c` into calls to
`memset`, which does not exist in a `-nostdlib` link. `-fno-builtin` alone does
not disable it — the rewrite happens in the loop optimiser, not at a recognised
builtin call site.

## 3. Load and run

Identical to the X25519 demo — see [`../x25519/README.md`](../x25519/README.md)
for the SD-card and JTAG procedures. In short:

```bash
sudo ./upload.sh            # defaults to sdc1
```

Watch UART0 with e.g. `screen /dev/ttyUSB1 115200`.

## Register map

All fields are 32 bits, which is what makes the map valid on an RV32 pbus:
`RegMapper` rejects a field crossing a `beatBytes * 8` word boundary, and pbus
`beatBytes` is `XLen/8`. Offsets are carried over unchanged from the TEE
wrapper, so software written against that map still works.

| Offset | Access | Meaning |
|---|---|---|
| `0x100`–`0x11C` | RW | key bytes 0..31 |
| `0x120`–`0x12C` | RW | one 16-byte AAD block |
| `0x130`–`0x138` | RW | nonce bytes 0..11 |
| `0x13C`–`0x178` | RW | one 64-byte data block |
| `0x17C` | RW | active-low core reset; also clears the data block |
| `0x180` / `0x184` / `0x188` | W1 | pulse init / next / finish |
| `0x18C` | RW | valid bytes in this block, 1..64 |
| `0x190` | RO | ready, 1 = idle |
| `0x194` | RW | 1 = encrypt, 0 = decrypt; latched at init |
| `0x198`, `0x19C`, `0x200`–`0x234` | RO | output block bytes 0..63 |
| `0x238`–`0x244` | RO | tag bytes 0..15 |

Byte order is hex-string order: `word[i]` is the big-endian load of bytes
`4i..4i+3`. Both embedded cores byte-swap internally, so RFC 8439 byte strings
pass through unreversed.

Note the discontinuity in the output block: `out_0`/`out_1` sit at `0x198`/`0x19C`
and then `out_2` restarts at `0x200`. That gap is inherited, not a typo;
`aead.c` folds it into `out_offset()`.

## Calling sequence

```
pulse rst_core                          clears `in`, arms the core
write key, nonce, encrypt
pulse init, wait ready                  derives the Poly1305 one-time key
per AAD block:                          16 bytes, zero-padded
    write aad + block_len
    pulse next, wait ready
write in + block_len                    FIRST data block, 64 bytes
pulse finish, wait ready, read out      leaves AAD phase AND runs that block
per later block:
    write in + block_len
    pulse next, wait ready, read out
pulse finish, wait ready, read mac      absorbs lengths, emits the tag
```

`finish` is overloaded: in the AAD phase it means "AAD done, start the data
phase", in the data phase it means "data done, emit the tag".

## Four RTL constraints the driver works around

**`in` must read zero when `init` is pulsed.** `AEAD_chacha_poly.v` is missing a
`begin`/`end` around its `state_init` branch, so `chacha_input <= plain_text`
executes unconditionally and the key-generation pass XORs whatever `in` holds
into ChaCha20 block 0 — the block the Poly1305 one-time key comes from. The
wrapper clears `in` while `rst_core` is asserted (matching the original TEE
wrapper), and the driver always resets before `init`.

**`block_len` must already hold the first data block's length when the AAD-phase
`finish` is pulsed.** The state that pulse lands in latches the MAC sub-block
count and advances the length counter immediately. Hence `load_block()` before
the finish, not after.

**`cipher_text` is masked combinationally by the current `block_len`**
(`assign cipher_text = chacha_output & filter`), not by the value latched when
that block was produced. `block_len` must stay put until the output is read back.

**One operation per reset.** The core's final state (`CTRL_ADD_FINAL_READY_FINAL`)
loops to itself, so there is no path back to idle. `aead_encrypt()` and
`aead_decrypt()` each reset on entry, which also satisfies the first constraint.

Also inherited: the AAD register is a single 128-bit block absorbed with the
core's Poly1305 block length hardwired to 16, so firmware zero-pads each AAD
block — which is what `pad16()` calls for. And message length must be greater
than zero: with `block_len` at 0 the core still runs one MAC block while adding
nothing to the length counter. Measured, not assumed — it does not hang or
error, it returns a tag that is simply wrong (`7cf04d29…` where the correct
empty-message tag is `770f1cc2…`). That silent-wrong-answer failure mode is why
`aead.c` returns `AEAD_EINVAL` before touching the hardware.

### Two missing `begin`/`end` blocks — do not "fix" the first one

`AEAD_chacha_poly.v` has two places where indentation implies a multi-statement
`if` but no `begin`/`end` is present. Both were tested with the Verilator bench
described above; the results are not symmetric.

**Lines 347–349, `valid_block` — leave it alone.**

```verilog
if(off_valid_counter)
  valid_counters <= 1'h0;
  valid_block   <=  1'h0;      // NOT inside the if — runs every cycle
if((counter_poly == counter_poly_max) & valid_counters)
  valid_block   <=  1'h1;
```

It works because the second `if` re-asserts `valid_block` and the last
non-blocking assignment wins, so `valid_block` is effectively
`(counter_poly == counter_poly_max) & valid_counters`, recomputed every cycle.

Adding the `begin`/`end` **breaks the core**: `valid_block` then latches, the
per-block MAC loop terminates early, and every multi-block message produces a
wrong tag. The 114-byte RFC vector fails; a single-block 5-byte message still
passes, so a shallow test would miss it. Verified — see `make -f
Makefile.chachapoly_aead run` in `tests/`. The missing `begin`/`end` is
load-bearing. If it is ever cleaned up, the guarded form has to be rewritten to
recompute `valid_block` rather than latch it.

**Lines 305–311, `chacha_input` — safe to fix, not applied here.**

```verilog
if (state_init)
  chacha_init   <= 1'h1;
  chacha_input  <= 512'h0;     // NOT inside the if
if (!state_init)
  chacha_init   <= 1'h0;
  chacha_input  <= plain_text; // unconditional, so this always wins
```

This is what forces the "`in` must be zero at `init`" rule: the intended
`chacha_input <= 0` during key generation never happens. Adding the
`begin`/`end` passes every check in the bench, and would remove the rule
outright.

It was **not** applied, to keep the imported RTL identical to the TEE original.
The driver resets before `init` regardless, so the current stack does not need
it. Apply it if you would rather the hardware not depend on firmware
discipline.

## What the demo checks

| Test | What |
|---|---|
| `enc-ct` / `enc-tag` | RFC 8439 Sec 2.8.2 encryption |
| `dec-pt` | decrypt of the vector's ciphertext and tag |
| `rt-pt` | decrypt of what this board just encrypted |
| `noaad-*` | empty AAD — a distinct FSM path; ciphertext must be unchanged, tag must differ |
| `neg` | corrupted tag rejected, and the output buffer holds no plaintext |

## Troubleshooting

- **`FAIL rc=1` (timeout) everywhere** — nothing at `0x6400A000`. Wrong
  bitstream, or the config was built without `WithCHACHAPOLYAEAD`.
- **`FAIL rc=2`** — zero-length message.
- **`FAIL rc=3`** on a vector that should verify — tag mismatch. Check the AAD
  zero-padding and that `block_len` was the true byte count for every block.
- **Tag wrong but ciphertext right** — almost always the one-time key, i.e. `in`
  was not zero at `init`. Confirm the `rst_core` pulse happens first and that
  the wrapper's clear-on-reset is present.
- **First 64 bytes right, rest wrong** — `block_len` sequencing. It must be
  written before each pulse and left alone until the output is read.
