import
  memory,
  types

type
  Register8* = enum
    A, F, B, C, D, E, H, L
  Register16* = enum
    AF, BC, DE, HL
  Flags* = enum
    C = 1 shl 4,
    H = 1 shl 5,
    N = 1 shl 6,
    Z = 1 shl 7,
  Cpu* = ref object
    r: array[Register8, byte]
    pc: Address
    sp: Address

proc newCpu*(): Cpu =
  Cpu()

template register(name: untyped; index: Register8) {.dirty.} =
  func `name`*(self: Cpu): byte {.inline.} = self.r[index]
  func `name=`*(self: Cpu; v: byte) {.inline.} = self.r[index] = v

register(a, A)

register(b, B)

register(c, C)

register(d, D)

register(e, E)

register(h, H)

register(l, L)

template register(name: untyped; index: Register16) {.dirty.} =
  func `name`*(self: Cpu): uint16 {.inline.} = cast[ptr UncheckedArray[uint16]](
      addr self.r)[index.ord]
  func `name=`*(self: Cpu; v: uint16) {.inline.} = cast[ptr UncheckedArray[
      uint16]](addr self.r)[index.ord] = v

register(af, AF)

register(bc, BC)

register(de, DE)

register(hl, HL)

func f*(self: Cpu; index: Flags): bool {.inline.} =
  (self.r[F] and byte(index.ord)) != 0

func setF*(self: Cpu; index: Flags) {.inline.} =
  self.r[F] = self.r[F] or byte(index.ord)

func clearF*(self: Cpu; index: Flags) {.inline.} =
  self.r[F] = self.r[F] and (
    not byte(index.ord))

