#!/usr/bin/env python3
"""
verify_rtl.py — ring-generator (RG-48 / RG-64) verifier and primitivity proof
==============================================================================

This script does THREE independent jobs, all against the actual RTL file
(not a hand-copied model of it):

  1. PARSE the Verilog `rS[i] <= ...;` assignments in the given ring-generator
     module and build the 48x48 (or 64x64) GF(2) transition matrix M for the
     *autonomous* recursion, i.e. with iTap forced to 0. The six iTap
     injection points are recorded separately (they are the external input
     vector B*u of the linear system, not part of M).

  2. PROVE primitivity of h(x), the characteristic polynomial the ring
     generator is supposed to realise (from Table I of [9]), using the
     matrix-order method:
         a) h(M) == 0                              (Cayley-Hamilton check:
                                                      confirms the parsed RTL
                                                      really implements h(x))
         b) M^(2^n - 1) == I                        (h(x) has all roots in
                                                      GF(2^n), i.e. its order
                                                      divides 2^n - 1)
         c) M^((2^n - 1)/p) != I  for every prime   (order is not a PROPER
            factor p of 2^n - 1                      divisor of 2^n - 1)
     h is primitive over GF(2)  <=>  (b) and (c) both hold.  This is NOT the
     same claim as "the RTL matches a golden trace" — it is a claim about the
     polynomial itself, independent of any particular simulation run.

  3. REGENERATE the golden simulation trace (same 8-bit LFSR driving iTap,
     same seed, same cycle count as the testbench) directly from the parsed
     RTL model, and diff it against sim/golden_rg48.txt, so the golden file
     itself is shown to be reproducible from the RTL rather than hand-typed.

Usage
-----
    # RG-48 (defaults match the homework's G48 = 48 35 22 10 0)
    python3 verify_rtl.py --rtl ring_generator48.v --golden golden_rg48.txt

    # RG-64 (G64 = 64 56 49 40 31 24 16 8 0), if/when you build it
    python3 verify_rtl.py --rtl ring_generator64.v --golden golden_rg64.txt \
        --width 64 --taps 64 56 49 40 31 24 16 8 0

Exit code is 0 iff every check (parse, h(M)=0, order, golden match) passes.
"""

import argparse
import re
import sys
from datetime import datetime

try:
    from sympy import factorint
except ImportError:
    sys.exit("This script needs sympy (`pip install sympy --break-system-packages`) "
             "to factor 2^n - 1 for the order proof.")


# --------------------------------------------------------------------------
# 1. Parse the RTL: build M (as n row-bitmasks) and the iTap injection map
# --------------------------------------------------------------------------

def parse_ring_generator(path, n):
    """Extract every `rS[i] <= <rhs>;` assignment from the RTL file and turn
    it into (a) a row of the GF(2) transition matrix M, ignoring iTap terms,
    and (b) a map iTap-bit -> destination state-bit for the entropy input.
    """
    with open(path) as f:
        text = f.read()

    rows = {}
    tap_bits = {}
    for m in re.finditer(r'rS\[\s*(\d+)\s*\]\s*<=\s*([^;]+);', text):
        idx = int(m.group(1))
        rhs = m.group(2)
        rows[idx] = [int(x) for x in re.findall(r'rS\[\s*(\d+)\s*\]', rhs)]
        tm = re.search(r'iTap\[\s*(\d+)\s*\]', rhs)
        if tm:
            tap_bits[int(tm.group(1))] = idx

    missing = [i for i in range(n) if i not in rows]
    if missing:
        raise ValueError(
            f"parser found no `rS[{missing[0]}] <= ...;` assignment in {path} "
            f"— is --width {n} correct, or did the signal get renamed?"
        )

    M = [0] * n
    for i in range(n):
        mask = 0
        for j in rows[i]:
            mask |= (1 << j)
        M[i] = mask
    return M, tap_bits


# --------------------------------------------------------------------------
# 2. GF(2) matrix arithmetic (rows stored as Python ints = bitmasks)
# --------------------------------------------------------------------------

def matmul(A, B, n):
    """(A*B)[i] = XOR of B[j] for every j with bit j set in A[i]."""
    out = [0] * n
    for i in range(n):
        row, acc = A[i], 0
        while row:
            j = (row & -row).bit_length() - 1
            acc ^= B[j]
            row &= row - 1
        out[i] = acc
    return out


def identity(n):
    return [1 << i for i in range(n)]


def matpow(M, e, n):
    R = identity(n)
    base = M
    while e:
        if e & 1:
            R = matmul(R, base, n)
        base = matmul(base, base, n)
        e >>= 1
    return R


def mat_xor(A, B):
    return [a ^ b for a, b in zip(A, B)]


def is_identity(M, n):
    return M == identity(n)


def popcount_parity(x):
    return bin(x).count("1") & 1


# --------------------------------------------------------------------------
# 3. h(M) == 0 check
# --------------------------------------------------------------------------

def check_h_of_M(M, n, taps):
    """taps is the list of exponents from Table I, e.g. [48,35,22,10,0]
    for h(x) = x^48+x^35+x^22+x^10+1."""
    acc = [0] * n
    for e in taps:
        term = identity(n) if e == 0 else matpow(M, e, n)
        acc = mat_xor(acc, term)
    return acc == [0] * n


# --------------------------------------------------------------------------
# 4. Primitivity via the matrix-order method
# --------------------------------------------------------------------------

def check_primitivity(M, n):
    N = 2 ** n - 1
    factors = factorint(N)
    full_order = is_identity(matpow(M, N, n), n)
    proper_divisor_hits = []
    for p in factors:
        if is_identity(matpow(M, N // p, n), n):
            proper_divisor_hits.append(p)
    primitive = full_order and not proper_divisor_hits
    return {
        "N": N,
        "factors": factors,
        "M_pow_N_is_I": full_order,
        "proper_divisor_hits": proper_divisor_hits,  # should be [] if primitive
        "primitive": primitive,
    }


# --------------------------------------------------------------------------
# 5. Regenerate + diff the golden trace
# --------------------------------------------------------------------------

def step(state, tap_word, M, tap_bits, n):
    new = 0
    for i in range(n):
        new |= popcount_parity(M[i] & state) << i
    for tap_idx, dest_bit in tap_bits.items():
        if (tap_word >> tap_idx) & 1:
            new ^= (1 << dest_bit)
    return new


def lfsr8_next(lfsr):
    """x^8 + x^6 + x^5 + x^4 + 1, matches the testbench's rLfsr update."""
    fb = ((lfsr >> 7) ^ (lfsr >> 5) ^ (lfsr >> 4) ^ (lfsr >> 3)) & 1
    return ((lfsr << 1) | fb) & 0xFF


def regenerate_and_diff(M, tap_bits, n, golden_path, cycles, seed):
    with open(golden_path) as f:
        gold_lines = [l.strip() for l in f if l.strip() and not l.startswith("//")]

    if len(gold_lines) != cycles:
        print(f"  note: golden file has {len(gold_lines)} lines, "
              f"--cycles={cycles}; comparing min length")
    cycles = min(cycles, len(gold_lines))

    state, lfsr, mismatches, first_bad = 0, seed, 0, None
    for t in range(cycles):
        expected = int(gold_lines[t], 16)
        if state != expected:
            mismatches += 1
            if first_bad is None:
                first_bad = (t, state, expected)
        state = step(state, lfsr & 0x3F, M, tap_bits, n)
        lfsr = lfsr8_next(lfsr)

    return mismatches, cycles, first_bad


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--rtl", required=True, help="path to ring_generatorNN.v")
    ap.add_argument("--width", type=int, default=48, help="ring width n (48 or 64)")
    ap.add_argument("--taps", type=int, nargs="+", default=[48, 35, 22, 10, 0],
                     help="exponents of h(x), e.g. 48 35 22 10 0 for G48, "
                          "or 64 56 49 40 31 24 16 8 0 for G64")
    ap.add_argument("--golden", help="path to golden_rgNN.txt to regenerate/diff")
    ap.add_argument("--cycles", type=int, default=512)
    ap.add_argument("--seed", type=lambda s: int(s, 0), default=0xA5,
                     help="8-bit LFSR seed driving iTap (default 0xA5)")
    ap.add_argument("--report", help="optional path to also write the report as text")
    args = ap.parse_args()

    n = args.width
    lines = []

    def out(s=""):
        print(s)
        lines.append(s)

    out("=" * 74)
    out(f"verify_rtl.py report — {datetime.now().isoformat(timespec='seconds')}")
    out(f"RTL file : {args.rtl}")
    out(f"width n  : {n}")
    out(f"h(x)     : " + " + ".join(f"x^{e}" if e else "1" for e in args.taps))
    out("=" * 74)

    all_ok = True

    # ---- 1. parse ----
    out("\n[1] Parsing RTL and building the GF(2) transition matrix M ...")
    try:
        M, tap_bits = parse_ring_generator(args.rtl, n)
        out(f"    OK — {n} state-bit equations recovered.")
        out(f"    iTap injection points (iTap bit -> state bit): {tap_bits}")
    except Exception as e:
        out(f"    FAILED: {e}")
        sys.exit(1)

    # ---- 2. h(M) == 0 ----
    out("\n[2] Checking h(M) = 0  (Cayley-Hamilton: confirms the RTL really")
    out("    implements the polynomial you claim it does) ...")
    h_ok = check_h_of_M(M, n, args.taps)
    out(f"    h(M) == 0 ?  {h_ok}")
    all_ok &= h_ok

    # ---- 3. primitivity via matrix order ----
    out("\n[3] Proving primitivity by the matrix-order method ...")
    res = check_primitivity(M, n)
    out(f"    2^{n}-1 = {res['N']}")
    out(f"    prime factorisation: {res['factors']}")
    out(f"    M^(2^{n}-1) == I ?            {res['M_pow_N_is_I']}")
    if res["proper_divisor_hits"]:
        out(f"    FAILS at proper divisor(s): {res['proper_divisor_hits']} "
            f"(order is smaller than 2^{n}-1 — h is NOT primitive)")
    else:
        out(f"    M^((2^{n}-1)/p) != I for every prime factor p ?  True")
    out(f"    => h(x) is {'PRIMITIVE' if res['primitive'] else 'NOT PRIMITIVE'} "
        f"over GF(2)")
    all_ok &= res["primitive"]

    # ---- 4. golden trace regeneration ----
    if args.golden:
        out(f"\n[4] Regenerating the {args.cycles}-cycle trace from the parsed RTL")
        out(f"    model and diffing against {args.golden} ...")
        mismatches, compared, first_bad = regenerate_and_diff(
            M, tap_bits, n, args.golden, args.cycles, args.seed)
        if mismatches == 0:
            out(f"    PASS — all {compared} states match "
                f"(LFSR seed 0x{args.seed:02X}).")
        else:
            out(f"    FAIL — {mismatches}/{compared} mismatches. "
                f"First at cycle {first_bad[0]}: "
                f"got {first_bad[1]:0{n // 4}x}, expected {first_bad[2]:0{n // 4}x}")
        all_ok &= (mismatches == 0)
    else:
        out("\n[4] Skipped (no --golden file given).")

    out("\n" + "=" * 74)
    out(f"OVERALL: {'PASS' if all_ok else 'FAIL'}")
    out("=" * 74)

    if args.report:
        with open(args.report, "w") as f:
            f.write("\n".join(lines) + "\n")
        print(f"\n(report also written to {args.report})")

    sys.exit(0 if all_ok else 1)


if __name__ == "__main__":
    main()
