"""Independent PCG32 XSH-RR reference tests for doc/21 section 3.1.

This is test-only Python code, not the Godot simulation or a production RNG.
Algorithm sources: https://www.pcg-random.org/using-pcg-c-basic.html
https://github.com/imneme/pcg-c-basic/blob/master/pcg_basic.c
https://github.com/imneme/pcg-c-basic/blob/master/pcg32-demo.c
"""
import sqlite3
import unittest

MASK32 = (1 << 32) - 1
MASK64 = (1 << 64) - 1
MULTIPLIER = 6364136223846793005
WORLD_INITSEQ = 54
GOLDEN42_54 = [0xA15C02B7, 0x7B47F409, 0xBA1D3330,
               0x83D2F293, 0xBFA4784B, 0xCBED606E]


def bounded(draw_uint32, bound):
    if type(bound) is not int or not 1 <= bound <= MASK32:
        raise ValueError("bound must be an integer in [1, 2^32-1]")
    threshold = (1 << 32) % bound
    while True:
        raw = draw_uint32()
        if raw >= threshold:
            return raw % bound


class ReferencePcg32:
    """Arbitrary-precision mathematical reference with explicit uint masks."""

    def __init__(self, initstate, initseq=WORLD_INITSEQ):
        self.state = 0
        self.increment = ((initseq << 1) | 1) & MASK64
        self.next_uint32()
        self.state = (self.state + (initstate & MASK64)) & MASK64
        self.next_uint32()

    def next_uint32(self):
        old = self.state
        self.state = (old * MULTIPLIER + self.increment) & MASK64
        x = (((old >> 18) ^ old) >> 27) & MASK32
        rotation = old >> 59
        return ((x >> rotation) | (x << ((-rotation) & 31))) & MASK32

    def snapshot(self):
        return (self.state >> 32, self.state & MASK32,
                self.increment >> 32, self.increment & MASK32)

    @classmethod
    def restore_world(cls, state_hi, state_lo, increment_hi, increment_lo):
        fields = (state_hi, state_lo, increment_hi, increment_lo)
        if any(type(value) is not int or not 0 <= value <= MASK32 for value in fields):
            raise ValueError("invalid uint32 limb")
        if (increment_hi, increment_lo) != (0, 109):
            raise ValueError("unexpected B world stream increment")
        result = cls.__new__(cls)  # Restore raw state without seeding draws.
        result.state = (state_hi << 32) | state_lo
        result.increment = (increment_hi << 32) | increment_lo
        return result


def logical_shift_pair(hi, lo, shift):
    if shift == 0:
        return hi, lo
    if 1 <= shift <= 31:
        return hi >> shift, ((lo >> shift) | ((hi & ((1 << shift) - 1)) << (32 - shift))) & MASK32
    if 32 <= shift <= 63:
        return 0, hi >> (shift - 32)
    raise ValueError("shift out of range")


def step_with_16bit_limbs(state_hi, state_lo, increment_hi, increment_lo):
    """Model the overflow-safe arithmetic planned for GDScript, independently."""
    state = [state_lo & 0xFFFF, state_lo >> 16,
             state_hi & 0xFFFF, state_hi >> 16]
    increment = [increment_lo & 0xFFFF, increment_lo >> 16,
                 increment_hi & 0xFFFF, increment_hi >> 16]
    multiplier = [0x7F2D, 0x4C95, 0xF42D, 0x5851]
    output, carry = [], 0
    for column in range(4):
        total = carry + increment[column]
        total += sum(state[index] * multiplier[column - index] for index in range(column + 1))
        assert 0 <= total < (1 << 35)
        output.append(total & 0xFFFF)
        carry = total >> 16
    new_lo = output[0] | (output[1] << 16)
    new_hi = output[2] | (output[3] << 16)
    shifted_hi, shifted_lo = logical_shift_pair(state_hi, state_lo, 18)
    mixed_hi, mixed_lo = shifted_hi ^ state_hi, shifted_lo ^ state_lo
    _, x = logical_shift_pair(mixed_hi, mixed_lo, 27)
    rotation = state_hi >> 27
    result = ((x >> rotation) | (x << ((32 - rotation) & 31))) & MASK32
    return new_hi, new_lo, result


class PcgContractTests(unittest.TestCase):
    def test_official42_54_golden_sequence(self):
        rng = ReferencePcg32(42, 54)
        self.assertEqual(rng.increment, 109)
        self.assertEqual([rng.next_uint32() for _ in range(6)], GOLDEN42_54)

    def test_sqlite_hi_lo_restore_continues_without_reseed(self):
        for seed in (42, -1, -(1 << 63), (1 << 63) - 1):
            with self.subTest(seed=seed):
                rng = ReferencePcg32(seed)
                for _ in range(77):
                    rng.next_uint32()
                saved = rng.snapshot()
                with sqlite3.connect(":memory:") as db:
                    db.execute("CREATE TABLE rng (state_hi INTEGER, state_lo INTEGER, increment_hi INTEGER, increment_lo INTEGER) STRICT")
                    db.execute("INSERT INTO rng VALUES (?,?,?,?)", saved)
                    restored = ReferencePcg32.restore_world(*db.execute("SELECT * FROM rng").fetchone())
                self.assertEqual(restored.snapshot(), saved)
                expected = [rng.next_uint32() for _ in range(128)]
                self.assertEqual([restored.next_uint32() for _ in range(128)], expected)
                self.assertEqual(restored.snapshot(), rng.snapshot())

    def test_signed_seed_uses_full64bit_pattern(self):
        signed = ReferencePcg32(-1)
        unsigned = ReferencePcg32(MASK64)
        self.assertEqual(signed.snapshot(), unsigned.snapshot())
        self.assertEqual([signed.next_uint32() for _ in range(32)],
                         [unsigned.next_uint32() for _ in range(32)])

    def test_bounded_rejection_consumes_every_raw(self):
        values = iter([0, 2147483646, 2147483647, MASK32])
        consumed = []
        def draw():
            value = next(values)
            consumed.append(value)
            return value
        bound = 2147483649  # threshold 2147483647, near-worst rejection path.
        self.assertEqual(bounded(draw, bound), 2147483647)
        self.assertEqual(len(consumed), 3)
        self.assertEqual(bounded(draw, bound), 2147483646)
        self.assertEqual(len(consumed), 4)

    def test_invalid_bounds_do_not_consume(self):
        def forbidden_draw():
            self.fail("invalid bound consumed RNG")
        for bound in (0, -1, 1 << 32, 3.0, True):
            with self.subTest(bound=bound), self.assertRaises(ValueError):
                bounded(forbidden_draw, bound)
        self.assertEqual(bounded(lambda: MASK32, 1), 0)
        self.assertEqual(bounded(lambda: 0, 4), 0)

    def test16bit_arithmetic_matches_reference_at_signed_edges(self):
        for initial in (0, 42, (1 << 63) - 1, 1 << 63, MASK64):
            for increment in (1, 109, MASK64):
                with self.subTest(state=initial, increment=increment):
                    state, hi, lo = initial, initial >> 32, initial & MASK32
                    for _ in range(128):
                        old = state
                        state = (old * MULTIPLIER + increment) & MASK64
                        x = (((old >> 18) ^ old) >> 27) & MASK32
                        rotation = old >> 59
                        expected = ((x >> rotation) | (x << ((-rotation) & 31))) & MASK32
                        hi, lo, actual = step_with_16bit_limbs(hi, lo, increment >> 32, increment & MASK32)
                        self.assertEqual((hi << 32) | lo, state)
                        self.assertEqual(actual, expected)

    def test_restore_rejects_invalid_or_wrong_stream(self):
        for fields in ((0, -1, 0, 109), (0, 1 << 32, 0, 109), (0, 0, 0, 110), (0, 0, 1, 109)):
            with self.subTest(fields=fields), self.assertRaises(ValueError):
                ReferencePcg32.restore_world(*fields)


if __name__ == "__main__":
    unittest.main()
