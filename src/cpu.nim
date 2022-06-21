import memory, types
import std/[bitops, logging, strformat]

type
  Register8* = enum
    A, F, B, C, D, E, H, L
  Register16* = enum
    AF, BC, DE, HL
  Flags* = enum
    C = 4,
    H = 5,
    N = 6,
    Z = 7,
  Cpu* = ref object
    r: array[Register8, byte]
    pc: Address
    sp: Address
    mctrl: MemoryCtrl

proc newCpu*(mc: MemoryCtrl): Cpu =
  Cpu(mctrl: mc)

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

func setF*(self: Cpu; f: Flags) {.inline.} =
  self.r[F].setBit(f.ord)

func clearF*(self: Cpu; f: Flags) {.inline.} =
  self.r[F].clearBit(f.ord)

func pc*(self: Cpu): Address {.inline.} = self.pc

func sp*(self: Cpu): Address {.inline.} = self.sp

func fetch(self: Cpu): byte {.inline.} =
  result = load[byte](self.mctrl, self.pc)
  self.pc.inc

proc step*(self: Cpu) =
  let opcode = self.fetch
  case opcode
  of 0x00:
    debug "NOP"
  of 0xc3:
    let a = self.fetch or (self.fetch.uint16 shl 8)
    debug &"JP 0x{a:x}"
    self.pc = a
  else:
    assert false
