class_name XJRng
extends RefCounted
## PCG32 XSH-RR. Every operation uses nonnegative limbs, never a float seed.
const Dtos = preload("res://contracts/contract_dtos.gd")
const MASK32: int = 0xffffffff
const MULT16: Array[int] = [0x7f2d, 0x4c95, 0xf42d, 0x5851]
var row: Dtos.RngStateDto

func _init(saved: Dtos.RngStateDto = null) -> void:
	row = saved if saved != null else Dtos.RngStateDto.new()

func initialize(seed_value: int) -> void:
	row.stream_id = "world"
	row.algorithm = "pcg32_v1"
	row.state_hi = 0
	row.state_lo = 0
	row.increment_hi = 0
	row.increment_lo = 109
	next_uint32()
	var total: int = row.state_lo + (seed_value & MASK32)
	row.state_lo = total & MASK32
	row.state_hi = (row.state_hi + ((seed_value >> 32) & MASK32) + (total >> 32)) & MASK32
	next_uint32()

func valid() -> bool:
	return row.stream_id == "world" and row.algorithm == "pcg32_v1" and row.increment_hi == 0 and row.increment_lo == 109 and row.state_hi >= 0 and row.state_hi <= MASK32 and row.state_lo >= 0 and row.state_lo <= MASK32

func next_uint32() -> int:
	var old_hi: int = row.state_hi
	var old_lo: int = row.state_lo
	var limbs: Array[int] = [old_lo & 0xffff, old_lo >> 16, old_hi & 0xffff, old_hi >> 16]
	var inc: Array[int] = [row.increment_lo & 0xffff, row.increment_lo >> 16, row.increment_hi & 0xffff, row.increment_hi >> 16]
	var result: Array[int] = []
	var carry: int = 0
	for column in range(4):
		var total: int = carry + inc[column]
		for index in range(column + 1):
			total += limbs[index] * MULT16[column - index]
		result.append(total & 0xffff)
		carry = total >> 16
	row.state_lo = result[0] | (result[1] << 16)
	row.state_hi = result[2] | (result[3] << 16)
	var shifted: Array[int] = _shr(old_hi, old_lo, 18)
	shifted = _shr(shifted[0] ^ old_hi, shifted[1] ^ old_lo, 27)
	var x: int = shifted[1]
	var rotation: int = old_hi >> 27
	return ((x >> rotation) | (x << ((-rotation) & 31))) & MASK32

func bounded(bound: int) -> int:
	if bound < 1 or bound > MASK32:
		return -1
	var threshold: int = 4294967296 % bound
	while true:
		var value: int = next_uint32()
		if value >= threshold:
			return value % bound
	return -1

static func _shr(hi: int, lo: int, bits: int) -> Array[int]:
	if bits == 0:
		return [hi, lo]
	if bits < 32:
		return [hi >> bits, ((lo >> bits) | ((hi & ((1 << bits) - 1)) << (32 - bits))) & MASK32]
	return [0, hi >> (bits - 32)]
