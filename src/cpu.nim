import memory, types
import std/[bitops, logging, strformat]

const
  Clock* = 4194304u
  MCycles* = Clock shr 2
  TCycles* = Clock shr 0

type
  Register8* = enum
    B, C,
    D, E,
    H, L,
    F, A,
    SPL, SPH,
    PCL, PCH,
  Register16* = enum
    BC,
    DE,
    HL,
    AF,
    SP,
    PC
  Flag* {.size: sizeof(byte).} = enum
    Pad0,
    Pad1,
    Pad2,
    Pad3,
    C,
    H,
    N,
    Z,
  Flags = set[Flag]
  Reg8Index = 0..PCH.ord
  Sm83* = ref object
    regs: array[Reg8Index, byte]
    mctrl: MemoryCtrl

proc `+=`(self: var Flags; f: Flag) {.inline.} = self.incl f
proc `+=`(self: var Flags; fs: Flags) {.inline.} = self = self + fs
proc `-=`(self: var Flags; f: Flag) {.inline.} = self.excl f
proc `-=`(self: var Flags; fs: Flags) {.inline.} = self = self - fs

proc newSm83*(mc: MemoryCtrl): Sm83 =
  Sm83(mctrl: mc)

converter toReg8Index(r: Register8): Reg8Index =
  const lut = [1, 0, 3, 2, 5, 4, 6, 7, 8, 9, 10, 11]
  lut[r.ord]

func r*(self: var Sm83; i: Register8): var byte {.inline.} = self.regs[i]
func r*(self: Sm83; i: Register8): byte {.inline.} = self.regs[i]
func `r=`*(self: var Sm83; i: Register8; v: byte) {.inline.} = self.r(i) = v
func `r=`*(self: var Sm83; i: Register8; v: int8) {.inline.} = self.r(i) = cast[byte](v)

func r*(self: var Sm83; i: Register16): var uint16 {.inline.} =
  cast[ptr uint16](addr self.regs[i.ord shl 1])[]
func r*(self: Sm83; i: Register16): uint16 {.inline.} =
  cast[ptr uint16](addr self.regs[i.ord shl 1])[]
func `r=`*(self: var Sm83; i: Register16; v: uint16) {.inline.} =
  self.r(i) = v
#func `r16=`*(self: Sm83; i: Register16; v: int16) {.inline.} =
#  self.regs[i.ord shl 1] = cast[byte](v)

func `+`(v1: uint16; v2: int8): uint16 {.inline.} = cast[uint16](int32(v1) + v2)
func `+=`(v1: var uint16; v2: int8) {.inline.} = v1 = cast[uint16](int32(v1) + v2)

func pc*(self: var Sm83): var Address {.inline.} = self.r(PC)
func `pc=`*(self: var Sm83; a: Address) {.inline.} = self.r(PC) = a
func pc*(self: Sm83): Address {.inline.} = self.r(PC)

func sp*(self: var Sm83): var Address {.inline.} = self.r(SP)
func sp*(self: Sm83): Address {.inline.} = self.r(SP)

func f*(self: var Sm83): var Flags {.inline.} = cast[ptr Flags](addr self.regs[F])[]
func f*(self: Sm83): Flags {.inline.} = cast[ptr Flags](addr self.regs[F])[]
func `f=`*(self: Sm83; flags: Flags) {.inline.} = cast[ptr Flags](addr self.regs[F])[] = flags
func setF*(self: var Sm83; f: Flag) {.inline.} = self.f.incl(f)
func clearF*(self: var Sm83; f: Flag) {.inline.} = self.f.excl(f)

proc fetch(self: var Sm83): byte {.inline.} =
  result = load[byte](self.mctrl, self.pc)
  self.pc.inc

proc push(self: var Sm83; v: uint16) {.inline.} =
  self.sp -= 2
  self.mctrl.store(self.sp, v)

proc peek(self: var Sm83): uint16 {.inline.} =
  load[uint16](self.mctrl, self.sp)

proc pop(self: var Sm83): uint16 {.inline.} =
  result = self.peek
  self.sp += 2

type
  Immediate8 = distinct uint8
  Immediate16 = distinct uint16
  Reg16Imme8 = (Register16, Immediate8)
  Reg16Inc = distinct Register16
  Reg16Dec = distinct Register16
  Indirect[T] = distinct T
  AddrModes =
    Immediate8 |
    Immediate16 |
    Register8 |
    Register16 |
    Indirect
  AddrModes2 =
    Immediate8 |
    Immediate16 |
    Register8 |
    Register16 |
    Indirect |
    Reg16Imme8

const Immediate8Tag = Immediate8(0)
const Immediate16Tag = Immediate16(0)

converter toT[T](i: Indirect[T]): T = T(i)
func indirect[T](v: T): Indirect[T] = Indirect[T](v)

proc value(r: Register8; cpu: Sm83): uint8 {.inline.} = cpu.r(r)
proc setValue(r: Register8; cpu: var Sm83; v: uint8) {.inline.} = cpu.r(r) = v

proc value(i: Indirect[(Address, Register8)]; cpu: var Sm83): uint8 {.inline.} =
  cpu.mctrl[i.toT[0] + cpu.r(i.toT[1])]
proc setValue(i: Indirect[(Address, Register8)]; cpu: var Sm83; v: uint8) {.inline.} =
  cpu.mctrl[i.toT[0] + cpu.r(i.toT[1])] = v

proc value(r: Register16; cpu: Sm83): uint16 {.inline.} = cpu.r(r)
proc setValue(r: Register16; cpu: var Sm83; v: uint16) {.inline.} = cpu.r(r) = v

proc value(pair: Reg16Imme8; cpu: var Sm83): uint16 {.inline.} =
  let v1 = cast[uint32](int32(cast[int8](cpu.fetch)))
  let v2 = uint32(cpu.r(pair[0]))
  let r = v1 + v2
  if pair[0] == SP:
    if r shr 16 != 0:
      cpu.f.incl C
    else:
      cpu.f.excl C
    if ((v1 and 0xf) + (v2 and 0xf)) shr 4 != 0:
      cpu.f.incl H
    else:
      cpu.f.excl H
    cpu.f -= {Z, N}
  return uint16(r and 0xffff)

proc value(_: Immediate8; cpu: var Sm83): uint8 {.inline.} = cpu.fetch()

proc value(_: Immediate16; cpu: var Sm83): uint16 {.inline.} =
  cpu.fetch() or (uint16(cpu.fetch()) shl 8)

proc value(i: Indirect[Register16]; cpu: Sm83): uint8 {.inline.} =
  cpu.mctrl[cpu.r(Register16(i.ord))]
proc setValue(i: Indirect[Register16]; cpu: var Sm83; v: uint8) {.inline.} =
  cpu.mctrl[cpu.r(Register16(i.ord))] = v

proc value(i: Indirect[Reg16Inc]; cpu: var Sm83): uint8 {.inline.} =
  let r = Register16(i.toT.ord)
  result = cpu.mctrl[cpu.r(r)]
  cpu.r(r).inc
proc setValue(i: Indirect[Reg16Inc]; cpu: var Sm83; v: uint8) {.inline.} =
  let r = Register16(i.toT.ord)
  cpu.mctrl[cpu.r(r)] = v
  cpu.r(r).inc
proc value(i: Indirect[Reg16Dec]; cpu: var Sm83): uint8 {.inline.} =
  let r = Register16(i.toT.ord)
  result = cpu.mctrl[cpu.r(r)]
  cpu.r(r).dec
proc setValue(i: Indirect[Reg16Dec]; cpu: var Sm83; v: uint8) {.inline.} =
  let r = Register16(i.toT.ord)
  cpu.mctrl[cpu.r(r)] = v
  cpu.r(r).dec

proc value(_: Indirect[Immediate16]; cpu: var Sm83): uint8 {.inline.} =
  cpu.mctrl[cpu.fetch() or (uint16(cpu.fetch()) shl 8)]
proc setValue(_: Indirect[Immediate16]; cpu: var Sm83; v: uint8) {.inline.} =
  cpu.mctrl[cpu.fetch() or (uint16(cpu.fetch()) shl 8)] = v
proc setValue(_: Indirect[Immediate16]; cpu: var Sm83; v: uint16) {.inline.} =
  cpu.mctrl[cpu.fetch() or (uint16(cpu.fetch()) shl 8)] = v

proc value(i: Indirect[(Address, Immediate8)]; cpu: var Sm83): uint8 {.inline.} =
  cpu.mctrl[i.toT[0] + cpu.fetch()]
proc setValue(i: Indirect[(Address, Immediate8)]; cpu: var Sm83; v: uint8) {.inline.} =
  cpu.mctrl[i.toT[0] + cpu.fetch()] = v

type
  OpcodeEntry = proc(cpu: var Sm83; opcode: uint8): int {.nimcall.}
  OpcodeDesc = tuple[t: int; entry: OpcodeEntry]

proc opNop(cpu: var Sm83; opcode: uint8): int = discard

  #of 0x05:
  #  var b = cast[int8](self.b)
  #  debug &"DEC B => B:{b}-=1, F[Z]={(b-1)==0}, F[N]={(b-1)<0}"
  #  b.dec
  #  self.b = cast[uint8](b)
  #  if b < 0:
  #    self.clearF(Z)
  #    self.setF(N)
  #  elif b == 0:
  #    self.setF(Z)
  #    self.clearF(N)
  #  else:
  #    self.clearF(Z)
  #    self.clearF(N)
  #of 0x06:
  #  let v = self.fetch
  #  debug &"LD B,0x{v:02x} => B=0x{v:02x}"
  #  self.b = v

func toReg[C, R: static uint](opcode: uint8): uint8 {.inline.} =
  ## for opcodes like 0x06 B,    0x0e C
  ##                  0x16 D,    0x1e E
  ##                  0x26 H,    0x2e L
  ##                  0x36 (HL), 0x3e A
  (opcode and 0b111) - C + ((opcode shr 3) and 1) +
    (((opcode shr 4) - (R.uint8 shr 4)) shl 1)

func toReg16[R: static uint](opcode: uint8): uint8 {.inline.} =
  ## for opcodes like 0x03 BC
  ##                  0x13 DE
  ##                  0x23 HL
  ##                  0x33 AF
  ## or
  ##                  0xc5 BC
  ##                  0xd5 DE
  ##                  0xe5 HL
  ##                  0xf5 SP
  (opcode shr 4) - uint8(R shr 4)

proc regOrDeref(cpu: Sm83; r: uint8): uint8 {.inline.} =
  if r == 0x6:
    load[uint8](cpu.mctrl, cpu.r(HL))
  else:
    cpu.r(Register8(r))

proc addU8[F: static Flags](cpu: var Sm83; v1: uint8; v2: uint8): byte =
  let h = (v1 and 0b1111) + (v2 and 0xb1111)
  #let r = uint16(v1 and 0xf0) + (v2 and 0xf0) + h
  let r = v1 + v2

  # https://github.com/nim-lang/Nim/issues/10220
  # nim can't infer type of empty `F`, convert it is a workaround
  when F.Flags != {}:
    when H in F:
      if cast[int8](v2) > 0:
        if h shr 4 != 0:
          cpu.setF(H)
        else:
          cpu.clearF(H)
      else:
        if h == 0:
          cpu.setF(H)
        else:
          cpu.clearF(H)
    when Z in F:
      if r == 0:
        cpu.setF(Z)
      else:
        cpu.clearF(Z)
    when C in F:
      if r shr 8 != 0:
        cpu.setF(C)
      else:
        cpu.clearF(C)

  cast[uint8](r)

proc opInc[C: static uint8; I: static uint8](cpu: var Sm83; opcode: uint8): int =
  let r = toReg[C, 0](opcode)
  let v = cpu.regOrDeref(r)
  const opname = when (I shl 7) == 0: "INC" else: "DEC"
  if r == 0x6:
    debug &"{opname} (HL) => (HL:0x{cpu.r(HL):04x})={v}{cast[int8](I):+d}"
    cpu.mctrl[cpu.r(HL)] = addU8[{Z, H}](cpu, v, I)
  else:
    debug &"{opname} {Register8(r)} => {Register8(r)}={v}{cast[int8](I):+d}"
    cpu.r(Register8(r)) = addU8[{Z, H}](cpu, v, I)
  cpu.clearF(N)

proc opInc16[R: static Register16; I: static uint16](cpu: var Sm83; opcode: uint8): int =
  const opname = when (not I) != 0: "INC" else: "DEC"
  debug &"{opname} {R} => {R}=0x{cpu.r(R):04x}{cast[int16](I):+d}"
  cpu.r(R) += I

proc `$`(_: Immediate8): string = "u8"
proc `$`(_: Immediate16): string = "u16"
proc `$`(r: Reg16Inc): string = &"{Register16(r.ord)}+"
proc `$`(r: Reg16Dec): string = &"{Register16(r.ord)}-"
proc `$`[T](i: Indirect[T]): string = &"({i.toT})"

proc opLd[D: static AddrModes; S: static AddrModes2](cpu: var Sm83; opcode: uint8): int =
  debug &"LD {D},{S}"
  let v = S.value(cpu)
  D.setValue(cpu, v)

  when S is Reg16Imme8:
    discard

proc opJr(cpu: var Sm83; opcode: uint8): int =
  let v = cast[int8](cpu.fetch)
  case opcode shr 4:
  of 0x1: discard
  of 0x2:
    if opcode.testBit(3):
      debug &"JR Z,{v} => Jump to 0x{cpu.pc:04x}{v:+d} if Z:{Z in cpu.f}"
      if Z notin cpu.f: return
    else:
      debug &"JR NZ,{v} => Jump to 0x{cpu.pc:04x}{v:+d} if NZ:{Z notin cpu.f}"
      if Z in cpu.f: return
    result = 4
  else:
    if opcode.testBit(3):
      debug &"JR C,{v} => Jump to 0x{cpu.pc:04x}{v:+d} if C:{C in cpu.f}"
      if C notin cpu.f: return
    else:
      debug &"JR NC,{v} => Jump to 0x{cpu.pc:04x}{v:+d} if NC:{C notin cpu.f}"
      if C in cpu.f: return
    result = 4
  cpu.pc += v

proc opXor(cpu: var Sm83; opcode: uint8): int =
  case opcode:
  of 0xee:
    let v = cpu.fetch
    debug &"XOR A,u8 => A=0x{cpu.r(A):02x} xor 0x{v:02x}"
    cpu.r(A) = cpu.r(A) xor v
    result = 4
  of 0xae:
    let v = load[uint8](cpu.mctrl, cpu.r(HL))
    debug &"XOR A,(HL:0x{cpu.r(HL):04x}) => A=0x{cpu.r(A):02x} xor 0x{v:02x}"
    cpu.r(A) = cpu.r(A) xor v
    result = 4
  of 0xaf:
    cpu.r(A) = 0
    debug &"XOR A,A"
  else:
    let i = (opcode and 0xf) - 8
    let r = if i == 7: A else: Register8(i + B.ord)
    debug &"XOR A,{r} => A={cpu.r(A):02x} xor {cpu.r(r):02x}"
  # unset N, C, H
  cpu.f = if cpu.r(A) == 0: {Z} else: {}

  #self.a = self.a xor self.a
proc opPop(cpu: var Sm83; opcode: uint8): int =
  let r = Register16(toReg16[0xc0](opcode))
  let v = cpu.pop
  debug &"POP {r} => {r}=0x{v:04x}, SP:0x{cpu.sp-2:04x}+=2"
  cpu.r(r) = v
  #of 0xc3:
  #  let a = self.fetch or (self.fetch.uint16 shl 8)
  #  debug &"JP 0x{a:x} => Jump 0x{a:04x}"
  #  self.pc = a
proc opPush(cpu: var Sm83; opcode: uint8): int =
  let r = Register16(toReg16[0xc0](opcode))
  let v = cpu.r(r)
  debug &"PUSH {r} => SP:0x{cpu.sp:04x}-=2, (SP)={r}:0x{v:04x}"
  cpu.push v

proc opRet[F: static Flags; I: static bool](cpu: var Sm83; opcode: uint8): int =
  var a: Address = cpu.peek
  let c =
    when {}.Flags == F:
      debug &"RET => PC=(SP:0x{cpu.sp-2:04x}):0x{a:04x}, SP=SP:0x{cpu.sp:04x}+2"
      true
    elif Z in F and I:
      if Z notin cpu.f:
        debug &"RET NZ => NZ:{Z notin cpu.f}, pop PC=(SP:0x{cpu.sp:04x}):0x{a:04x}, SP=SP:0x{cpu.sp:04x}+2"
        true
      else:
        debug &"RET NZ => NZ:{Z notin cpu.f}"
        false
    elif Z in F and not I:
      if Z notin cpu.f:
        debug &"RET Z => Z:{Z in cpu.f}, pop PC=(SP:0x{cpu.sp:04x}):0x{a:04x}, SP=SP:0x{cpu.sp:04x}+2"
        true
      else:
        debug &"RET Z => Z:{Z in cpu.f}"
        false
    elif C in F and I:
      if C notin cpu.f:
        debug &"RET NC => NC:{C notin cpu.f}, pop PC=(SP:0x{cpu.sp:04x}):0x{a:04x}, SP=SP:0x{cpu.sp:04x}+2"
        true
      else:
        debug &"RET NC => NC:{C notin cpu.f}"
        false
    elif C in F and not I:
      if C in cpu.f:
        debug &"RET C => C:{C in cpu.f}, pop PC=(SP:0x{cpu.sp:04x}):0x{a:04x}, SP=SP:0x{cpu.sp:04x}+2"
        true
      else:
        debug &"RET C => C:{C in cpu.f}"
        false
  if c:
    cpu.pc = cpu.pop
    result = 12

proc opCall[F: static Flags; I: static bool](cpu: var Sm83; opcode: uint8): int =
  let a = cpu.fetch or (uint16(cpu.fetch) shl 8)
  let c =
    when {}.Flags == F:
      debug &"CALL 0x{a:04x} => (SP:0x{cpu.sp:04x}-2)=PC:0x{cpu.pc:04x}, PC=0x{a:04x}"
      true
    elif Z in F and I:
      if Z notin cpu.f:
        debug &"CALL 0x{a:04x} => NZ:(Z notin cpu.f), (SP:0x{cpu.sp:04x}-2)=PC:0x{cpu.pc:04x}, PC=0x{a:04x}"
        true
      else:
        debug &"CALL 0x{a:04x} => NZ:(Z notin cpu.f)"
        false
    elif Z in F and not I:
      if Z notin cpu.f:
        debug &"CALL 0x{a:04x} => Z:(Z in cpu.f), (SP:0x{cpu.sp:04x}-2)=PC:0x{cpu.pc:04x}, PC=0x{a:04x}"
        true
      else:
        debug &"CALL 0x{a:04x} => Z:(Z in cpu.f)"
        false
    elif C in F and I:
      if C notin cpu.f:
        debug &"CALL 0x{a:04x} => NC:(C notin cpu.f), (SP:0x{cpu.sp:04x}-2)=PC:0x{cpu.pc:04x}, PC=0x{a:04x}"
        true
      else:
        debug &"CALL 0x{a:04x} => NC:(C notin cpu.f)"
        false
    elif C in F and not I:
      if C in cpu.f:
        debug &"CALL 0x{a:04x} => C:(C in cpu.f), (SP:0x{cpu.sp:04x}-2)=PC:0x{cpu.pc:04x}, PC=0x{a:04x}"
        true
      else:
        debug &"CALL 0x{a:04x} => C:(C in cpu.f)"
        false
  if c:
    cpu.push cpu.pc
    cpu.pc = a
    result = 12

proc opUnimpl(cpu: var Sm83; opcode: uint8): int =
  fatal &"opcode 0x{opcode:02x} not implemented yet"
  quit(1)

proc opIllegal(cpu: var Sm83; opcode: uint8): int =
  fatal &"illegal opcode 0x{opcode:02x}"

proc opCbUnimpl(cpu: var Sm83; opcode: uint8): int =
  fatal &"opcode 0xcb{opcode:02x} is not implemented yet"
  quit(1)

proc nthBit(opcode: uint8; base: uint8): uint8 {.inline.} =
  (((opcode shr 4) - (base shr 4)) shl 1) + ((opcode shr 3) and 1)

proc opBit(cpu: var Sm83; opcode: uint8): int =
  let b = opcode.nthBit(0x40)
  let r = opcode and 0x7
  let v =
    if r == 0x6:
      debug &"BIT {b},(HL) => ((HL:0x{cpu.r(HL):04x}) shr {b}) & 1"
      cpu.mctrl[cpu.r(HL)]
    else:
      let r = Register8(r)
      debug &"BIT {b},{r} => ({r}:0x{cpu.r(r):02x} shr {b}) & 1"
      cpu.r(Register8(r)) 

  cpu.f.excl N
  cpu.f.incl C
  if v.testBit(b):
    cpu.f.excl Z
  else:
    cpu.f.incl Z

proc opRl(cpu: var Sm83; opcode: uint8): int =
  ## C <- [7 <- 0] <- C
  let r = opcode and 0b111
  let c = C in cpu.f
  var v =
    if r == 0x6:
      let x = cpu.mctrl[cpu.r(HL)]
      debug &"RL (HL) => F[C]:{x.testBit(7)} << (HL:0x{cpu.r(HL):04x}):0x{x:02x} << F[C]:{c}"
      x
    else:
      let r = Register8(r)
      let x = cpu.r(r)
      debug &"RL {r} => F[C]:{x.testBit(7)} << {r}:0x{x:02x} << F[C]:{c}"
      x
  if v.testBit(7): cpu.f.incl C else: cpu.f.excl C
  v = (v shl 1) or c.uint8
  if v == 0: cpu.f.incl Z else: cpu.f.excl Z
  cpu.f.excl N
  cpu.f.excl H
  if r == 0x6: cpu.mctrl[cpu.r(HL)] = v else: cpu.r(Register8(r)) = v

proc opRr(cpu: var Sm83; opcode: uint8): int =
  ## C -> [7 -> 0] -> C
  let r = opcode and 0b111
  let c = C in cpu.f
  var v =
    if r == 0x6:
      let x = cpu.mctrl[cpu.r(HL)]
      debug &"RL (HL) => F[C]:{c} >> (HL:0x{cpu.r(HL):04x}):0x{x:02x} >> F[C]:{x.testBit(0)}"
      x
    else:
      let r = Register8(r)
      let x = cpu.r(r)
      debug &"RL {r} => F[C]:{c} >> {r}:0x{x:02x} >> F[C]:{x.testBit(0)}"
      x
  if v.testBit(0): cpu.f.incl C else: cpu.f.excl C
  v = (v shr 1) or (c.uint8 shl 7)
  if v == 0: cpu.f.incl Z else: cpu.f.excl Z
  cpu.f.excl N
  cpu.f.excl H
  if r == 0x6: cpu.mctrl[cpu.r(HL)] = v else: cpu.r(Register8(r)) = v

proc opCp[S: static AddrModes](cpu: var Sm83; opcode: uint8): int =
  let v = value(S, cpu)
  let vl = v and 0b1111
  let a = cpu.r(A)
  let al = a and 0b1111
  when S is Register8:
    debug &"CP A,{S} => Z:(A:0x{a:02x}=={S}:0x{v:02x}), C:0x{a:02x}<0x{v:02x}, H:0x{a and 0b1111:x}<0x{v and 0b1111:x}"
  elif S is Indirect[Register16]:
    debug &"CP A,(HL) => Z:(A:0x{a:02x}==(HL:{cpu.r(Register16(S))}):0x{v:02x}), C:0x{a:02x}<0x{v:02x}, H:0x{a and 0b1111:x}<0x{v and 0b1111:x}"
  elif S is Immediate8:
    debug &"CP A,u8 => Z:(A:0x{a:02x}==0x{v:02x}), C:0x{a:02x}<0x{v:02x}, H:0x{a and 0b1111:x}<0x{v and 0b1111:x}"
  cpu.f =
    if a == v: {N, Z}
    elif a > v:
      if al >= vl: {N}
      else: {N, H}
    else:
      if al >= vl: {N, C}
      else: {N, H, C}

proc opHalt(cpu: var Sm83; opcode: uint8): int = discard

const cbOpcodes = [    
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 8, entry: opRl),         # 0x10
  (t: 8, entry: opRl),
  (t: 8, entry: opRl),
  (t: 8, entry: opRl),
  (t: 8, entry: opRl),
  (t: 8, entry: opRl),
  (t: 16, entry: opRl),
  (t: 8, entry: opRl),
  (t: 8, entry: opRr),
  (t: 8, entry: opRr),
  (t: 8, entry: opRr),
  (t: 8, entry: opRr),
  (t: 8, entry: opRr),
  (t: 8, entry: opRr),
  (t: 16, entry: opRr),
  (t: 8, entry: opRr),
  (t: 0, entry: opCbUnimpl),         # 0x20
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),         # 0x30
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 4, entry: opBit),         # 0x40
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),         # 0x50
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),         # 0x60
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),         # 0x70
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 4, entry: opBit),
  (t: 0, entry: opCbUnimpl),         # 0x80
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),         # 0x90
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),         # 0xa0
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),         # 0xb0
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),         # 0xc0
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),         # 0xd0
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),         # 0xe0
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),         # 0xf0
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
  (t: 0, entry: opCbUnimpl),
]

proc prefixCb(cpu: var Sm83; opcode: uint8): int =
  let opcode = cpu.fetch
  debug &"| opcode: 0xcb{opcode:02x}"
  let desc = cbOpcodes[opcode]
  desc.entry(cpu, opcode) + desc.t
  #of 0xcb:
  #  let opcode = self.fetch
  #  case opcode
  #  of 0x7c:
  #    debug &"BIT 7,H => H:0x{self.h:02x}, testBit(7):{self.h.testBit(7)}"
  #    if self.h.testBit(7):
  #      self.setF(Z)
  #    else:
  #      self.clearF(Z)
const opcodes = [
  (t: 4, entry: OpcodeEntry(opNop)),
  (t: 12, entry: opLd[BC, Immediate16Tag]),
  (t: 8, entry: opLd[BC.indirect, A]),
  (t: 8, entry: opInc16[BC, 1]),
  (t: 4, entry: opInc[4, 1]),
  (t: 4, entry: opInc[5, 0xff]),
  (t: 8, entry: opLd[B, Immediate8Tag]),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opLd[Immediate16Tag.indirect, SP]),
  (t: 0, entry: opUnimpl),
  (t: 8, entry: opLd[A, BC.indirect]),
  (t: 8, entry: opInc16[BC, 0xffff]),
  (t: 4, entry: opInc[4, 1]),
  (t: 4, entry: opInc[5, 0xff]),
  (t: 8, entry: opLd[Register8.C, Immediate8Tag]),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),         # 0x10
  (t: 12, entry: opLd[DE, Immediate16Tag]),
  (t: 8, entry: opLd[DE.indirect, A]),
  (t: 8, entry: opInc16[DE, 1]),
  (t: 4, entry: opInc[4, 1]),
  (t: 4, entry: opInc[5, 0xff]),
  (t: 8, entry: opLd[D, Immediate8Tag]),
  (t: 0, entry: opRl),
  (t: 12, entry: opJr),
  (t: 0, entry: opUnimpl),
  (t: 8, entry: opLd[A, DE.indirect]),
  (t: 8, entry: opInc16[DE, 0xffff]),
  (t: 4, entry: opInc[4, 1]),
  (t: 4, entry: opInc[5, 0xff]),
  (t: 8, entry: opLd[E, Immediate8Tag]),
  (t: 0, entry: opRr),
  (t: 8, entry: opJr),         # 0x20
  (t: 12, entry: opLd[HL, Immediate16Tag]),
  (t: 8, entry: opLd[Reg16Inc(HL).indirect, A]),
  (t: 8, entry: opInc16[HL, 1]),
  (t: 4, entry: opInc[4, 1]),
  (t: 4, entry: opInc[5, 0xff]),
  (t: 8, entry: opLd[Register8.H, Immediate8Tag]),
  (t: 0, entry: opUnimpl),
  (t: 8, entry: opJr),
  (t: 0, entry: opUnimpl),
  (t: 8, entry: opLd[A, Reg16Inc(HL).indirect]),
  (t: 8, entry: opInc16[HL, 0xffff]),
  (t: 4, entry: opInc[4, 1]),
  (t: 4, entry: opInc[5, 0xff]),
  (t: 8, entry: opLd[L, Immediate8Tag]),
  (t: 0, entry: opUnimpl),
  (t: 8, entry: opJr),         # 0x30
  (t: 12, entry: opLd[SP, Immediate16Tag]),
  (t: 8, entry: opLd[Reg16Dec(HL).indirect, A]),
  (t: 8, entry: opInc16[SP, 1]),
  (t: 12, entry: opInc[4, 1]),
  (t: 12, entry: opInc[5, 0xff]),
  (t: 8, entry: opLd[HL.indirect, Immediate8Tag]),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opJr),
  (t: 0, entry: opUnimpl),
  (t: 8, entry: opLd[A, Reg16Dec(HL).indirect]),
  (t: 8, entry: opInc16[SP, 0xffff]),
  (t: 4, entry: opInc[4, 1]),
  (t: 4, entry: opInc[5, 0xff]),
  (t: 8, entry: opLd[A, Immediate8Tag]),
  (t: 0, entry: opUnimpl),
  (t: 4, entry: opLd[B, B]),         # 0x40
  (t: 4, entry: opLd[B, Register8.C]),
  (t: 4, entry: opLd[B, D]),
  (t: 4, entry: opLd[B, E]),
  (t: 4, entry: opLd[B, Register8.H]),
  (t: 4, entry: opLd[B, L]),
  (t: 8, entry: opLd[B, HL.indirect]),
  (t: 4, entry: opLd[B, A]),
  (t: 4, entry: opLd[Register8.C, B]),
  (t: 4, entry: opLd[Register8.C, Register8.C]),
  (t: 4, entry: opLd[Register8.C, D]),
  (t: 4, entry: opLd[Register8.C, E]),
  (t: 4, entry: opLd[Register8.C, Register8.H]),
  (t: 4, entry: opLd[Register8.C, L]),
  (t: 8, entry: opLd[Register8.C, HL.indirect]),
  (t: 4, entry: opLd[Register8.C, A]),
  (t: 4, entry: opLd[D, B]),         # 0x50
  (t: 4, entry: opLd[D, Register8.C]),
  (t: 4, entry: opLd[D, D]),
  (t: 4, entry: opLd[D, E]),
  (t: 4, entry: opLd[D, Register8.H]),
  (t: 4, entry: opLd[D, L]),
  (t: 8, entry: opLd[D, HL.indirect]),
  (t: 4, entry: opLd[D, A]),
  (t: 4, entry: opLd[E, B]),
  (t: 4, entry: opLd[E, Register8.C]),
  (t: 4, entry: opLd[E, D]),
  (t: 4, entry: opLd[E, E]),
  (t: 4, entry: opLd[E, Register8.H]),
  (t: 4, entry: opLd[E, L]),
  (t: 8, entry: opLd[E, HL.indirect]),
  (t: 4, entry: opLd[E, A]),
  (t: 4, entry: opLd[Register8.H, B]),         # 0x60
  (t: 4, entry: opLd[Register8.H, Register8.C]),
  (t: 4, entry: opLd[Register8.H, D]),
  (t: 4, entry: opLd[Register8.H, E]),
  (t: 4, entry: opLd[Register8.H, Register8.H]),
  (t: 4, entry: opLd[Register8.H, L]),
  (t: 8, entry: opLd[Register8.H, HL.indirect]),
  (t: 4, entry: opLd[Register8.H, A]),
  (t: 4, entry: opLd[L, B]),
  (t: 4, entry: opLd[L, Register8.C]),
  (t: 4, entry: opLd[L, D]),
  (t: 4, entry: opLd[L, E]),
  (t: 4, entry: opLd[L, Register8.H]),
  (t: 4, entry: opLd[L, L]),
  (t: 8, entry: opLd[L, HL.indirect]),
  (t: 4, entry: opLd[L, A]),
  (t: 8, entry: opLd[HL.indirect, B]),         # 0x70
  (t: 8, entry: opLd[HL.indirect, Register8.C]),
  (t: 8, entry: opLd[HL.indirect, D]),
  (t: 8, entry: opLd[HL.indirect, E]),
  (t: 8, entry: opLd[HL.indirect, Register8.H]),
  (t: 8, entry: opLd[HL.indirect, L]),
  (t: 4, entry: opHalt),
  (t: 8, entry: opLd[HL.indirect, A]),
  (t: 8, entry: opLd[HL.indirect, B]),
  (t: 8, entry: opLd[HL.indirect, Register8.C]),
  (t: 8, entry: opLd[HL.indirect, D]),
  (t: 8, entry: opLd[HL.indirect, E]),
  (t: 8, entry: opLd[HL.indirect, Register8.H]),
  (t: 8, entry: opLd[HL.indirect, L]),
  (t: 8, entry: opLd[A, HL.indirect]),
  (t: 8, entry: opLd[HL.indirect, A]),
  (t: 0, entry: opUnimpl),         # 0x80
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),         # 0x90
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),         # 0xa0
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 4, entry: opXor),
  (t: 4, entry: opXor),
  (t: 4, entry: opXor),
  (t: 4, entry: opXor),
  (t: 4, entry: opXor),
  (t: 4, entry: opXor),
  (t: 4, entry: opXor),
  (t: 4, entry: opXor),
  (t: 0, entry: opUnimpl),         # 0xb0
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 4, entry: opCp[B]),
  (t: 4, entry: opCp[Register8.C]),
  (t: 4, entry: opCp[D]),
  (t: 4, entry: opCp[E]),
  (t: 4, entry: opCp[Register8.H]),
  (t: 4, entry: opCp[L]),
  (t: 8, entry: opCp[HL.indirect]),
  (t: 4, entry: opCp[A]),
  (t: 8, entry: opRet[{Z}, true]),         # 0xc0
  (t: 12, entry: opPop),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 12, entry: opCall[{Z}, true]),
  (t: 16, entry: opPush),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 8, entry: opRet[{Z}, false]),
  (t: 8, entry: opRet[{}, false]),
  (t: 0, entry: opUnimpl),
  (t: 4, entry: prefixCb),
  (t: 12, entry: opCall[{Z}, false]),
  (t: 12, entry: opCall[{}, false]),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 8, entry: opRet[{Flag.C}, true]),         # 0xd0
  (t: 12, entry: opPop),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opIllegal),
  (t: 12, entry: opCall[{Flag.C}, true]),
  (t: 16, entry: opPush),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 8, entry: opRet[{Flag.C}, false]),
  (t: 8, entry: opRet[{}, false]),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opIllegal),
  (t: 12, entry: opCall[{Flag.C}, false]),
  (t: 0, entry: opIllegal),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 12, entry: opLd[(Address(0xff00), Immediate8Tag).indirect, A]),       # 0xe0
  (t: 12, entry: opPop),
  (t: 8, entry: opLd[(Address(0xff00), Register8.C).indirect, A]),
  (t: 0, entry: opIllegal),
  (t: 0, entry: opIllegal),
  (t: 16, entry: opPush),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 16, entry: opLd[Immediate16Tag.indirect, A]),
  (t: 0, entry: opIllegal),
  (t: 0, entry: opIllegal),
  (t: 0, entry: opIllegal),
  (t: 4, entry: opXor),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opLd[A, (Address(0xff00), Immediate8Tag).indirect]),         # 0xf0
  (t: 12, entry: opPop),
  (t: 0, entry: opLd[A, (Address(0xff00), Register8.C).indirect]),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opIllegal),
  (t: 16, entry: opPush),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opLd[HL, (SP, Immediate8Tag)]),
  (t: 0, entry: opLd[SP, HL]),
  (t: 16, entry: opLd[A, Immediate16Tag.indirect]),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opIllegal),
  (t: 0, entry: opIllegal),
  (t: 8, entry: opCp[Immediate8Tag]),
  (t: 0, entry: opUnimpl),
]                      
                       
proc step*(self: var Sm83) =
  debug &"| PC:0x{self.pc:04x}, SP:0x{self.sp:04x}"
  debug &"| B:0x{self.r(B):02x}, C:0x{self.r(C):02x}, D:0x{self.r(D):02x}, E:0x{self.r(E):02x}, "
  debug &"| H:0x{self.r(H):02x}, L:0x{self.r(L):02x}, A:0x{self.r(A):02x}, F:{self.f}"
  debug &"| AF:0x{self.r(AF):04x}, BC:{self.r(BC):04x}, DE:0x{self.r(DE):04x}, HL:0x{self.r(HL):04x}"

  let opcode = self.fetch
  if opcode != 0xcb:
    debug &"| opcode: 0x{opcode:02x}"
  let desc = opcodes[opcode]
  let t = desc.entry(self, opcode)
  debug &"~ clocks={desc.t}+{t}"
