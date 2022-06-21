type
  Regs* = enum
    rA, rF, rB, rC, rD, rE, rH, rL
  Regs16* = enum
    rAF, rBC, rDE, rHL
  Flags* = enum
    fC = 1 shl 4,
    fH = 1 shl 5,
    fN = 1 shl 6,
    fZ = 1 shl 7,
  Cpu* = ref object
    regs: array[Regs, uint8]

proc newCpu*(): Cpu =
  Cpu()

func `[]`*(self: Cpu; r: Regs): uint8 {.inline.} = self.regs[r]

func `[]=`*(self: Cpu; r: Regs; v: uint8) {.inline.} = self.regs[r] = v

func `[]`*(self: Cpu; f: Flags): bool {.inline.} =
  (self.regs[rF] and uint8(ord(f))) != 0

func `[]=`*(self: Cpu; f: Flags; v: bool) {.inline.} =
  if v:
    self.regs[rF] = self.regs[rF] or uint8(ord(f))
  else:
    self.regs[rF] = self.regs[rF] and (not uint8(ord(f)))

func `[]`*(self: var Cpu; r: Regs16): uint16 {.inline.} =
  cast[ptr UncheckedArray[uint16]](addr self.regs[rA])[r.ord]

func `[]=`*(self: var Cpu; r: Regs16; v: uint16) {.inline.} =
  cast[ptr UncheckedArray[uint16]](addr self.regs[rA])[r.ord] = v
