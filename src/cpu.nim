import memory, types, utils
import std/[bitops, logging, strformat]

const
  Clock* = 4194304u
  MCycles* = Clock shr 2
  TCycles* = Clock shr 0

  InterruptVector = Address(0x0040)

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
  InvFlag* {.size: sizeof(byte).} = distinct Flag
  InvFlags = set[InvFlag]
  FlagSet =
    Flags |
    InvFlags

proc `-=`(self: var Flags; fs: Flags) {.inline.} = self = self - fs

type
  Reg8Index = 0..PCH.ord
  Tick* = int
  Interrupt* = enum
    VBlank
    LcdStat
    Timer
    Serial
    Joypad
  InterruptFlags* = set[Interrupt]
  CpuFlag = enum
    cfIme
    cfSuspend
  CpuFlags = set[CpuFlag]
  Sm83* = ref object of Memory
    flags: CpuFlags
    regs: array[Reg8Index, byte]
    mctrl: MemoryCtrl
    freq: int
    ticks: Tick
    ie: InterruptFlags
    `if`: InterruptFlags

const
  NZ = InvFlag(Z.ord)
  NC = InvFlag(Flag.C.ord)

method load*(self: Sm83; a: Address; dest: pointer; length: uint16) {.locks: "unknown".} =
  cast[ptr byte](dest)[] = cast[byte](self.ie)

method store*(self: var Sm83; a: Address; src: pointer; length: uint16) {.locks: "unknown".} =
  cast[ptr byte](addr self.ie)[] = cast[ptr byte](src)[]
  debug &"IE: {self.ie}"

func loadIf*(self: Sm83; a: Address; d: var byte) =
  d = cast[byte](self.if)

proc storeIf*(self: Sm83; a: Address; s: byte) =
  self.if = cast[InterruptFlags](s)
  debug &"IF: {self.if}"

proc newSm83*(freq: int): Sm83 =
  result = Sm83(freq: freq)
  Memory.init(result, IE)

func freq*(self: Sm83): int = self.freq

func ticks*(self: Sm83): int = self.ticks

func memCtrl*(self: Sm83): MemoryCtrl {.inline.} = self.mctrl
func memCtrl*(self: var Sm83): var MemoryCtrl {.inline.} = self.mctrl
func `memCtrl=`*(self: Sm83, mctrl: MemoryCtrl) =
  if self.mctrl != nil:
    self.mctrl.unmap(IE)
  mctrl.map(self)
  self.mctrl = mctrl

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

proc fetch16(self: var Sm83): uint16 {.inline.} =
  result = load[uint16](self.mctrl, self.pc)
  self.pc += 2

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
  Reg8Inv = distinct Register8
  Reg16Inv = distinct Register16
  Imme8Inv = distinct Immediate8
  Indir[T] = distinct T
  IndirInv[T] = distinct Indir[T]
  AddrModesInv =
    Reg8Inv |
    Reg16Inv |
    Imme8Inv |
    IndirInv
  AddrModes =
    Immediate8 |
    Immediate16 |
    Register8 |
    Register16 |
    Indir
  AddrModes2 =
    Immediate8 |
    Immediate16 |
    Register8 |
    Register16 |
    Indir |
    Reg16Imme8 |
    AddrModesInv

const Immediate8Tag = Immediate8(0)
const Immediate16Tag = Immediate16(0)

func toT[T](i: Indir[T]): T {.inline.} =
  when T is enum:
    T(i.ord)
  else:
    T(i)

func toT[T](i: IndirInv[T]): T {.inline.} =
  when T is enum:
    T(i.ord)
  else:
    T(i)

func indir[T](v: T): Indir[T] {.inline.} =
  when T is enum:
    Indir[T](v.ord)
  else:
    Indir[T](v)

func inverted[T](_: T): bool =
  when T is AddrModesInv or T is InvFlag:
    true
  else:
    false

func value(r: Register8; cpu: Sm83): uint8 {.inline.} = cpu.r(r)
func value(r: Reg8Inv; cpu: Sm83): uint8 {.inline.} = 1 + not cpu.r(Register8(r.ord))
func setValue(r: Register8; cpu: var Sm83; v: uint8) {.inline.} = cpu.r(r) = v
func inv(r: Register8): Reg8Inv = Reg8Inv(r.ord)

proc value(i: Indir[(Address, Register8)]; cpu: var Sm83): uint8 {.inline.} =
  cpu.mctrl[i.toT[0] + cpu.r(i.toT[1])]
proc setValue(i: Indir[(Address, Register8)]; cpu: var Sm83; v: uint8) {.inline.} =
  cpu.mctrl[i.toT[0] + cpu.r(i.toT[1])] = v

func value(r: Register16; cpu: Sm83): uint16 {.inline.} = cpu.r(r)
func value(r: Reg16Inv; cpu: Sm83): uint16 {.inline.} = 1 + not cpu.r(Register16(r.ord))
func setValue(r: Register16; cpu: var Sm83; v: uint16) {.inline.} = cpu.r(r) = v

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
proc value(_: Imme8Inv; cpu: var Sm83): uint8 {.inline.} = 1 + not cpu.fetch()
func inv(i: Immediate8): Imme8Inv = Imme8Inv(i)

proc value(_: Immediate16; cpu: var Sm83): uint16 {.inline.} = cpu.fetch16()

proc value(i: Indir[Register16]; cpu: Sm83): uint8 {.inline.} =
  cpu.mctrl[cpu.r(Register16(i.ord))]
proc value(i: IndirInv[Register16]; cpu: Sm83): uint8 {.inline.} =
  1 + not cpu.mctrl[cpu.r(Register16(i.ord))]
proc setValue(i: Indir[Register16]; cpu: var Sm83; v: uint8) {.inline.} =
  cpu.mctrl[cpu.r(Register16(i.ord))] = v
func inv(i: Indir[Register16]): IndirInv[Register16] {.inline.} =
  IndirInv[Register16](i)

proc value(i: Indir[Reg16Inc]; cpu: var Sm83): uint8 {.inline.} =
  let r = Register16(i.toT.ord)
  result = cpu.mctrl[cpu.r(r)]
  cpu.r(r).inc
proc setValue(i: Indir[Reg16Inc]; cpu: var Sm83; v: uint8) {.inline.} =
  let r = Register16(i.toT.ord)
  cpu.mctrl[cpu.r(r)] = v
  cpu.r(r).inc
proc value(i: Indir[Reg16Dec]; cpu: var Sm83): uint8 {.inline.} =
  let r = Register16(i.toT.ord)
  result = cpu.mctrl[cpu.r(r)]
  cpu.r(r).dec
proc setValue(i: Indir[Reg16Dec]; cpu: var Sm83; v: uint8) {.inline.} =
  let r = Register16(i.toT.ord)
  cpu.mctrl[cpu.r(r)] = v
  cpu.r(r).dec

proc value(_: Indir[Immediate16]; cpu: var Sm83): uint8 {.inline.} =
  cpu.mctrl[cpu.fetch16()]
proc setValue(_: Indir[Immediate16]; cpu: var Sm83; v: uint8) {.inline.} =
  cpu.mctrl[cpu.fetch16()] = v
proc setValue(_: Indir[Immediate16]; cpu: var Sm83; v: uint16) {.inline.} =
  cpu.mctrl[cpu.fetch16()] = v

proc value(i: Indir[(Address, Immediate8)]; cpu: var Sm83): uint8 {.inline.} =
  cpu.mctrl[i.toT[0] + cpu.fetch()]
proc setValue(i: Indir[(Address, Immediate8)]; cpu: var Sm83; v: uint8) {.inline.} =
  cpu.mctrl[i.toT[0] + cpu.fetch()] = v

proc `$`(pair: (Address, Immediate8)): string = &"{pair[0].hex}+u8"
proc `$`(pair: (Address, Register8)): string = &"{pair[0].hex}+{pair[1]}"
proc `$`(_: Immediate8): string = "u8"
proc `$`(_: Imme8Inv): string = "u8"
proc `$`(_: Immediate16): string = "u16"
proc `$`(r: Reg16Inc): string = &"{Register16(r.ord)}+"
proc `$`(r: Reg16Dec): string = &"{Register16(r.ord)}-"
proc `$`[T](i: Indir[T]): string = &"({i.toT})"
proc `$`(r: Reg8Inv): string = &"{Register8(r.ord)}"
proc `$`[T](i: IndirInv[T]): string = &"({i.toT})"
proc `$`(f: InvFlag): string =
  let f = Flag(f.ord)
  if f == Z:
    "NZ"
  elif f == C:
    "NC"
  else:
    ""

type
  OpcodeEntry = proc(cpu: var Sm83; opcode: uint8): int {.nimcall.}

func suspended*(self: Sm83): bool {.inline.} = cfSuspend in self.flags

func suspend*(self: Sm83) {.inline.} = self.flags.incl cfSuspend

func awake*(self: Sm83) {.inline.} = self.flags.excl cfSuspend

func ime*(self: Sm83): bool {.inline.} = cfIme in self.flags

func `ime=`*(self: Sm83; v: bool) {.inline.} =
  if v:
    self.flags.incl cfIme
  else:
    self.flags.excl cfIme

proc opSuspend(cpu: var Sm83; opcode: uint8): int =
  if opcode == 0x10:
    debug "STOP"
  else:
    debug "HALT"
  cpu.suspend

proc opNop(cpu: var Sm83; opcode: uint8): int =
  debug "NOP"

proc opInc[T: static AddrModes; I: static SomeInteger](cpu: var Sm83; opcode: uint8): int =
  when I == 1:
    debug &"INC {T}"
  else:
    debug &"DEC {T}"
  let v = T.value(cpu)
  let r = v + I
  when T isnot Register16:
    when I == 1:
      cpu.f.excl N
    else:
      cpu.f.incl N
    if r == 0:
      cpu.f.incl Z
    else:
      cpu.f.excl Z
    if ((v and 0xff) + (I and 0xff)) shr 4 != 0:
      cpu.f.incl H
    else:
      cpu.f.excl H
    
  T.setValue(cpu, r)

proc opLd[D: static AddrModes; S: static AddrModes2](cpu: var Sm83; opcode: uint8): int =
  debug &"LD {D},{S}"
  let v = S.value(cpu)
  D.setValue(cpu, v)

  when S is Reg16Imme8:
    discard

proc opJr(cpu: var Sm83; opcode: uint8): int =
  let v = cast[int8](cpu.fetch)
  case opcode shr 4:
  of 0x1:
    debug &"JR {v}"
  of 0x2:
    if opcode.testBit(3):
      debug &"JR Z,{v}"
      if Z notin cpu.f: return
    else:
      debug &"JR NZ,{v}"
      if Z in cpu.f: return
    result = 4
  else:
    if opcode.testBit(3):
      debug &"JR C,{v}"
      if C notin cpu.f: return
    else:
      debug &"JR NC"
      if C in cpu.f: return
    result = 4
  cpu.pc += v

proc check(fs: static FlagSet; cpu: Sm83): bool {.inline.} =
  when fs is Flags:
    when Z in fs.Flags: Z in cpu.f
    elif N in fs.Flags: N in cpu.f
    elif H in fs.Flags: H in cpu.f
    elif C in fs.Flags: C in cpu.f
    else: true
  else:
    when NZ in fs: Z notin cpu.f
    elif NC in fs: C notin cpu.f
    else: true

proc opJp[S: static AddrModes; F: static FlagSet](cpu: var Sm83; opcode: uint8): int =
  debug &"JP {F},{S}"
  let v = S.value(cpu)
  if F.check(cpu):
    cpu.pc = v
    result = 4

proc opPop[D: static AddrModes](cpu: var Sm83; opcode: uint8): int =
  let v = cpu.pop
  debug &"POP {D}"
  D.setValue(cpu, v)

proc opPush[S: static AddrModes](cpu: var Sm83; opcode: uint8): int =
  let v = S.value(cpu)
  debug &"PUSH {S}"
  cpu.push v

proc opRet[F: static Flags; I: static bool](cpu: var Sm83; opcode: uint8): int =
  let c =
    when {}.Flags == F:
      debug "RET"
      true
    elif Z in F and I:
      debug "RET NZ"
      if Z notin cpu.f:
        true
      else:
        false
    elif Z in F and not I:
      debug "RET Z"
      if Z notin cpu.f:
        true
      else:
        false
    elif C in F and I:
      debug &"RET NC"
      if C notin cpu.f:
        true
      else:
        false
    elif C in F and not I:
      debug &"RET C"
      if C in cpu.f:
        true
      else:
        false
  if c:
    cpu.pc = cpu.pop
    result = 12

proc opCall[F: static Flags; I: static bool](cpu: var Sm83; opcode: uint8): int =
  let a = cpu.fetch16()
  let c =
    when {}.Flags == F:
      debug &"CALL {a.hex}"
      true
    elif Z in F and I:
      debug &"CALL NZ,{a.hex}"
      if Z notin cpu.f:
        true
      else:
        false
    elif Z in F and not I:
      debug &"CALL Z,{a.hex}"
      if Z in cpu.f:
        true
      else:
        false
    elif C in F and I:
      debug &"CALL NC,{a.hex}"
      if C notin cpu.f:
        true
      else:
        false
    elif C in F and not I:
      debug &"CALL C,{a.hex}"
      if C in cpu.f:
        true
      else:
        false
  if c:
    cpu.push cpu.pc
    cpu.pc = a
    result = 12

proc opUnimpl(cpu: var Sm83; opcode: uint8): int =
  fatal &"opcode {opcode.hex} not implemented yet"
  quit(1)

proc opIllegal(cpu: var Sm83; opcode: uint8): int =
  fatal &"illegal opcode {opcode.hex}"

proc opCbUnimpl(cpu: var Sm83; opcode: uint8): int =
  fatal &"opcode 0xcb{opcode:02x} is not implemented yet"
  quit(1)

proc opBit[B: static uint8; S: static AddrModes](cpu: var Sm83; opcode: uint8): int =
  debug &"BIT {B},{S}"
  let v = S.value(cpu)

  cpu.f.excl N
  cpu.f.incl H
  if v.testBit(B):
    cpu.f.excl Z
  else:
    cpu.f.incl Z

proc opRes[B: static uint8; S: static AddrModes](cpu: var Sm83; opcode: uint8): int =
  debug &"RES {B},{S}"
  var v = S.value(cpu)
  v.clearBit(B)
  S.setValue(cpu, v)

proc opSet[B: static uint8; S: static AddrModes](cpu: var Sm83; opcode: uint8): int =
  debug &"RES {B},{S}"
  var v = S.value(cpu)
  v.setBit(B)
  S.setValue(cpu, v)

proc opRl[T: static AddrModes; F: static Flags](cpu: var Sm83; opcode: uint8): int =
  var v = T.value(cpu)
  let c =
    if (opcode shr 4) == 0:
      debug &"RLC {T}"
      v shr 7
    else:
      debug &"RL {T}"
      (C in cpu.f).uint8
  cpu.f = {}
  if v shr 7 != 0:
    cpu.f.incl C
  v = (v shl 1) or c
  when Z in F.Flags:
    if v == 0:
      cpu.f.incl Z
  T.setValue(cpu, v)

proc opRr[T: static AddrModes; F: static Flags](cpu: var Sm83; opcode: uint8): int =
  var v = T.value(cpu)
  let c =
    if (opcode shr 4) == 0:
      debug &"RRC {T}"
      (v and 1) shl 7
    else:
      debug &"RR {T}"
      (C in cpu.f).uint8 shr 7
  cpu.f = {}
  if (v and 1) != 0:
    cpu.f.incl C
  v = (v shr 1) or c
  when Z in F.Flags:
    if v == 0:
      cpu.f.incl Z
  T.setValue(cpu, v)

proc opAdd[D: static AddrModes; S: static AddrModes2](cpu: var Sm83; opcode: uint8): int =
  let adc = (opcode and 0xf) > 7
  let s = S.value(cpu)
  let d = D.value(cpu)
  let c =
    if adc:
      when S.inverted:
        not cast[uint8](C in cpu.f)
      else:
        cast[uint8](C in cpu.f)
    else:
      0
  let r = d.uint16 + s + c
  when S.inverted:
    if adc:
      debug &"SBC A,{S}"
    else:
      debug &"SUB A,{S}"
  else:
    if adc:
      debug &"ADC A,{S}"
    else:
      debug &"ADD A,{S}"
  D.setValue(cpu, uint8(r and 0xff))
  if (r and 0xff) == 0:
    cpu.f.incl Z
  else:
    cpu.f.excl Z
  if r shr 8 != 0:
    cpu.f.incl C
  else:
    cpu.f.excl C
  if ((d and 0xf) + (s and 0xf) + (c and 0xf)) shr 4 != 0:
    cpu.f.incl H
  else:
    cpu.f.excl H
  when S.inverted:
    cpu.f.incl N
  else:
    cpu.f.excl N

proc opAdd16[D: static AddrModes; S: static AddrModes2](cpu: var Sm83; opcode: uint8): int =
  if S.inverted:
    debug &"SUB A,{S}"
  else:
    debug &"ADD A,{S}"
  let s = S.value(cpu)
  let d = D.value(cpu)
  let r = d.uint32 + s
  D.setValue(cpu, uint16(r and 0xffff))
  if r shr 16 != 0:
    cpu.f.incl C
  else:
    cpu.f.excl C
  if ((d and 0xfff) + (s and 0xfff)) shr 12 != 0:
    cpu.f.incl H
  else:
    cpu.f.excl H
  when S.inverted:
    cpu.f.incl N
  else:
    cpu.f.excl N

proc opAnd[S: static AddrModes2](cpu: var Sm83; opcode: uint8): int =
  debug &"AND A,{S}"
  let v1 = A.value(cpu)
  let v2 = D.value(cpu)
  let r = v1 and v2
  cpu.f = {Flag.H}
  if r == 0:
    cpu.f.incl Z

proc opXor[S: static AddrModes2](cpu: var Sm83; opcode: uint8): int =
  debug &"XOR A,{S}"
  let v1 = A.value(cpu)
  let v2 = D.value(cpu)
  let r = v1 xor v2
  cpu.f = {}
  if r == 0:
    cpu.f.incl Z

proc opOr[S: static AddrModes2](cpu: var Sm83; opcode: uint8): int =
  debug &"OR A,{S}"
  let v1 = A.value(cpu)
  let v2 = D.value(cpu)
  let r = v1 or v2
  cpu.f = {}
  if r == 0:
    cpu.f.incl Z

proc opCp[S: static AddrModes](cpu: var Sm83; opcode: uint8): int =
  debug &"CP A,{S}"
  let v = value(S, cpu)
  let vl = v and 0b1111
  let a = cpu.r(A)
  let al = a and 0b1111
  cpu.f =
    if a == v: {N, Z}
    elif a > v:
      if al >= vl: {N}
      else: {N, H}
    else:
      if al >= vl: {N, C}
      else: {N, H, C}

proc opIme(cpu: var Sm83; opcode: uint8): int =
  if opcode == 0xf3:
    debug "DI"
    cpu.flags.excl cfIme
  else:
    debug "EI"
    cpu.flags.incl cfIme

const cbOpcodes = [    
  (t: 8, entry: opRl[B, {Z}]),
  (t: 8, entry: opRl[Register8.C, {Z}]),
  (t: 8, entry: opRl[D, {Z}]),
  (t: 8, entry: opRl[E, {Z}]),
  (t: 8, entry: opRl[Register8.H, {Z}]),
  (t: 8, entry: opRl[L, {Z}]),
  (t: 16, entry: opRl[HL.indir, {Z}]),
  (t: 8, entry: opRl[A, {Z}]),
  (t: 8, entry: opRr[B, {Z}]),
  (t: 8, entry: opRr[Register8.C, {Z}]),
  (t: 8, entry: opRr[D, {Z}]),
  (t: 8, entry: opRr[E, {Z}]),
  (t: 8, entry: opRr[Register8.H, {Z}]),
  (t: 8, entry: opRr[L, {Z}]),
  (t: 16, entry: opRr[HL.indir, {Z}]),
  (t: 8, entry: opRr[A, {Z}]),
  (t: 8, entry: opRl[B, {Z}]),         # 0x10
  (t: 8, entry: opRl[Register8.C, {Z}]),
  (t: 8, entry: opRl[D, {Z}]),
  (t: 8, entry: opRl[E, {Z}]),
  (t: 8, entry: opRl[Register8.H, {Z}]),
  (t: 8, entry: opRl[L, {Z}]),
  (t: 16, entry: opRl[HL.indir, {Z}]),
  (t: 8, entry: opRl[A, {Z}]),
  (t: 8, entry: opRr[B, {Z}]),
  (t: 8, entry: opRr[Register8.C, {Z}]),
  (t: 8, entry: opRr[D, {Z}]),
  (t: 8, entry: opRr[E, {Z}]),
  (t: 8, entry: opRr[Register8.H, {Z}]),
  (t: 8, entry: opRr[L, {Z}]),
  (t: 16, entry: opRr[HL.indir, {Z}]),
  (t: 8, entry: opRr[A, {Z}]),
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
  (t: 4, entry: opBit[0, B]),         # 0x40
  (t: 4, entry: opBit[0, Register8.C]),
  (t: 4, entry: opBit[0, D]),
  (t: 4, entry: opBit[0, E]),
  (t: 4, entry: opBit[0, Register8.H]),
  (t: 4, entry: opBit[0, L]),
  (t: 8, entry: opBit[0, HL.indir]),
  (t: 4, entry: opBit[0, A]),
  (t: 4, entry: opBit[1, B]),
  (t: 4, entry: opBit[1, Register8.C]),
  (t: 4, entry: opBit[1, D]),
  (t: 4, entry: opBit[1, E]),
  (t: 4, entry: opBit[1, Register8.H]),
  (t: 4, entry: opBit[1, L]),
  (t: 8, entry: opBit[1, HL.indir]),
  (t: 4, entry: opBit[1, A]),
  (t: 4, entry: opBit[2, B]),         # 0x50
  (t: 4, entry: opBit[2, Register8.C]),
  (t: 4, entry: opBit[2, D]),
  (t: 4, entry: opBit[2, E]),
  (t: 4, entry: opBit[2, Register8.H]),
  (t: 4, entry: opBit[2, L]),
  (t: 8, entry: opBit[2, HL.indir]),
  (t: 4, entry: opBit[2, A]),
  (t: 4, entry: opBit[3, B]),
  (t: 4, entry: opBit[3, Register8.C]),
  (t: 4, entry: opBit[3, D]),
  (t: 4, entry: opBit[3, E]),
  (t: 4, entry: opBit[3, Register8.H]),
  (t: 4, entry: opBit[3, L]),
  (t: 8, entry: opBit[3, HL.indir]),
  (t: 4, entry: opBit[3, A]),
  (t: 4, entry: opBit[4, B]),         # 0x60
  (t: 4, entry: opBit[4, Register8.C]),
  (t: 4, entry: opBit[4, D]),
  (t: 4, entry: opBit[4, E]),
  (t: 4, entry: opBit[4, Register8.H]),
  (t: 4, entry: opBit[4, L]),
  (t: 8, entry: opBit[4, HL.indir]),
  (t: 4, entry: opBit[4, A]),
  (t: 4, entry: opBit[5, B]),
  (t: 4, entry: opBit[5, Register8.C]),
  (t: 4, entry: opBit[5, D]),
  (t: 4, entry: opBit[5, E]),
  (t: 4, entry: opBit[5, Register8.H]),
  (t: 4, entry: opBit[5, L]),
  (t: 8, entry: opBit[5, HL.indir]),
  (t: 4, entry: opBit[5, A]),
  (t: 4, entry: opBit[6, B]),         # 0x70
  (t: 4, entry: opBit[6, Register8.C]),
  (t: 4, entry: opBit[6, D]),
  (t: 4, entry: opBit[6, E]),
  (t: 4, entry: opBit[6, Register8.H]),
  (t: 4, entry: opBit[6, L]),
  (t: 8, entry: opBit[6, HL.indir]),
  (t: 4, entry: opBit[6, A]),
  (t: 4, entry: opBit[7, B]),
  (t: 4, entry: opBit[7, Register8.C]),
  (t: 4, entry: opBit[7, D]),
  (t: 4, entry: opBit[7, E]),
  (t: 4, entry: opBit[7, Register8.H]),
  (t: 4, entry: opBit[7, L]),
  (t: 8, entry: opBit[7, HL.indir]),
  (t: 4, entry: opBit[7, A]),
  (t: 4, entry: opRes[0, B]),         # 0x80
  (t: 4, entry: opRes[0, Register8.C]),
  (t: 4, entry: opRes[0, D]),
  (t: 4, entry: opRes[0, E]),
  (t: 4, entry: opRes[0, Register8.H]),
  (t: 4, entry: opRes[0, L]),
  (t: 8, entry: opRes[0, HL.indir]),
  (t: 4, entry: opRes[0, A]),
  (t: 4, entry: opRes[1, B]),
  (t: 4, entry: opRes[1, Register8.C]),
  (t: 4, entry: opRes[1, D]),
  (t: 4, entry: opRes[1, E]),
  (t: 4, entry: opRes[1, Register8.H]),
  (t: 4, entry: opRes[1, L]),
  (t: 8, entry: opRes[1, HL.indir]),
  (t: 4, entry: opRes[1, A]),
  (t: 4, entry: opRes[2, B]),         # 0x90
  (t: 4, entry: opRes[2, Register8.C]),
  (t: 4, entry: opRes[2, D]),
  (t: 4, entry: opRes[2, E]),
  (t: 4, entry: opRes[2, Register8.H]),
  (t: 4, entry: opRes[2, L]),
  (t: 8, entry: opRes[2, HL.indir]),
  (t: 4, entry: opRes[2, A]),
  (t: 4, entry: opRes[3, B]),
  (t: 4, entry: opRes[3, Register8.C]),
  (t: 4, entry: opRes[3, D]),
  (t: 4, entry: opRes[3, E]),
  (t: 4, entry: opRes[3, Register8.H]),
  (t: 4, entry: opRes[3, L]),
  (t: 8, entry: opRes[3, HL.indir]),
  (t: 4, entry: opRes[3, A]),
  (t: 4, entry: opRes[4, B]),         # 0xa0
  (t: 4, entry: opRes[4, Register8.C]),
  (t: 4, entry: opRes[4, D]),
  (t: 4, entry: opRes[4, E]),
  (t: 4, entry: opRes[4, Register8.H]),
  (t: 4, entry: opRes[4, L]),
  (t: 8, entry: opRes[4, HL.indir]),
  (t: 4, entry: opRes[4, A]),
  (t: 4, entry: opRes[5, B]),
  (t: 4, entry: opRes[5, Register8.C]),
  (t: 4, entry: opRes[5, D]),
  (t: 4, entry: opRes[5, E]),
  (t: 4, entry: opRes[5, Register8.H]),
  (t: 4, entry: opRes[5, L]),
  (t: 8, entry: opRes[5, HL.indir]),
  (t: 4, entry: opRes[5, A]),
  (t: 4, entry: opRes[6, B]),         # 0xb0
  (t: 4, entry: opRes[6, Register8.C]),
  (t: 4, entry: opRes[6, D]),
  (t: 4, entry: opRes[6, E]),
  (t: 4, entry: opRes[6, Register8.H]),
  (t: 4, entry: opRes[6, L]),
  (t: 8, entry: opRes[6, HL.indir]),
  (t: 4, entry: opRes[6, A]),
  (t: 4, entry: opRes[7, B]),
  (t: 4, entry: opRes[7, Register8.C]),
  (t: 4, entry: opRes[7, D]),
  (t: 4, entry: opRes[7, E]),
  (t: 4, entry: opRes[7, Register8.H]),
  (t: 4, entry: opRes[7, L]),
  (t: 8, entry: opRes[7, HL.indir]),
  (t: 4, entry: opRes[7, A]),
  (t: 4, entry: opSet[0, B]),         # 0xc0
  (t: 4, entry: opSet[0, Register8.C]),
  (t: 4, entry: opSet[0, D]),
  (t: 4, entry: opSet[0, E]),
  (t: 4, entry: opSet[0, Register8.H]),
  (t: 4, entry: opSet[0, L]),
  (t: 8, entry: opSet[0, HL.indir]),
  (t: 4, entry: opSet[0, A]),
  (t: 4, entry: opSet[1, B]),
  (t: 4, entry: opSet[1, Register8.C]),
  (t: 4, entry: opSet[1, D]),
  (t: 4, entry: opSet[1, E]),
  (t: 4, entry: opSet[1, Register8.H]),
  (t: 4, entry: opSet[1, L]),
  (t: 8, entry: opSet[1, HL.indir]),
  (t: 4, entry: opSet[1, A]),
  (t: 4, entry: opSet[2, B]),         # 0xd0
  (t: 4, entry: opSet[2, Register8.C]),
  (t: 4, entry: opSet[2, D]),
  (t: 4, entry: opSet[2, E]),
  (t: 4, entry: opSet[2, Register8.H]),
  (t: 4, entry: opSet[2, L]),
  (t: 8, entry: opSet[2, HL.indir]),
  (t: 4, entry: opSet[2, A]),
  (t: 4, entry: opSet[3, B]),
  (t: 4, entry: opSet[3, Register8.C]),
  (t: 4, entry: opSet[3, D]),
  (t: 4, entry: opSet[3, E]),
  (t: 4, entry: opSet[3, Register8.H]),
  (t: 4, entry: opSet[3, L]),
  (t: 8, entry: opSet[3, HL.indir]),
  (t: 4, entry: opSet[3, A]),
  (t: 4, entry: opSet[4, B]),         # 0xe0
  (t: 4, entry: opSet[4, Register8.C]),
  (t: 4, entry: opSet[4, D]),
  (t: 4, entry: opSet[4, E]),
  (t: 4, entry: opSet[4, Register8.H]),
  (t: 4, entry: opSet[4, L]),
  (t: 8, entry: opSet[4, HL.indir]),
  (t: 4, entry: opSet[4, A]),
  (t: 4, entry: opSet[5, B]),
  (t: 4, entry: opSet[5, Register8.C]),
  (t: 4, entry: opSet[5, D]),
  (t: 4, entry: opSet[5, E]),
  (t: 4, entry: opSet[5, Register8.H]),
  (t: 4, entry: opSet[5, L]),
  (t: 8, entry: opSet[5, HL.indir]),
  (t: 4, entry: opSet[5, A]),
  (t: 4, entry: opSet[6, B]),         # 0xf0
  (t: 4, entry: opSet[6, Register8.C]),
  (t: 4, entry: opSet[6, D]),
  (t: 4, entry: opSet[6, E]),
  (t: 4, entry: opSet[6, Register8.H]),
  (t: 4, entry: opSet[6, L]),
  (t: 8, entry: opSet[6, HL.indir]),
  (t: 4, entry: opSet[6, A]),
  (t: 4, entry: opSet[7, B]),
  (t: 4, entry: opSet[7, Register8.C]),
  (t: 4, entry: opSet[7, D]),
  (t: 4, entry: opSet[7, E]),
  (t: 4, entry: opSet[7, Register8.H]),
  (t: 4, entry: opSet[7, L]),
  (t: 8, entry: opSet[7, HL.indir]),
  (t: 4, entry: opSet[7, A]),
]

proc prefixCb(cpu: var Sm83; opcode: uint8): int =
  let opcode = cpu.fetch
  let desc = cbOpcodes[opcode]
  desc.entry(cpu, opcode) + desc.t

const opcodes = [
  (t: 4, entry: OpcodeEntry(opNop)),
  (t: 12, entry: opLd[BC, Immediate16Tag]),
  (t: 8, entry: opLd[BC.indir, A]),
  (t: 8, entry: opInc[BC, 1]),
  (t: 4, entry: opInc[B, 1]),
  (t: 4, entry: opInc[B, 0xff]),
  (t: 8, entry: opLd[B, Immediate8Tag]),
  (t: 4, entry: opRl[A, {}]),
  (t: 0, entry: opLd[Immediate16Tag.indir, SP]),
  (t: 8, entry: opAdd16[HL, BC]),
  (t: 8, entry: opLd[A, BC.indir]),
  (t: 8, entry: opInc[BC, 0xffff]),
  (t: 4, entry: opInc[Register8.C, 1]),
  (t: 4, entry: opInc[Register8.C, 0xff]),
  (t: 8, entry: opLd[Register8.C, Immediate8Tag]),
  (t: 4, entry: opRr[A, {}]),
  (t: 4, entry: opSuspend),         # 0x10
  (t: 12, entry: opLd[DE, Immediate16Tag]),
  (t: 8, entry: opLd[DE.indir, A]),
  (t: 8, entry: opInc[DE, 1]),
  (t: 4, entry: opInc[D, 1]),
  (t: 4, entry: opInc[D, 0xff]),
  (t: 8, entry: opLd[D, Immediate8Tag]),
  (t: 4, entry: opRl[A, {}]),
  (t: 12, entry: opJr),
  (t: 8, entry: opAdd16[HL, DE]),
  (t: 8, entry: opLd[A, DE.indir]),
  (t: 8, entry: opInc[DE, 0xffff]),
  (t: 4, entry: opInc[E, 1]),
  (t: 4, entry: opInc[E, 0xff]),
  (t: 8, entry: opLd[E, Immediate8Tag]),
  (t: 4, entry: opRr[A, {}]),
  (t: 8, entry: opJr),         # 0x20
  (t: 12, entry: opLd[HL, Immediate16Tag]),
  (t: 8, entry: opLd[Reg16Inc(HL).indir, A]),
  (t: 8, entry: opInc[HL, 1]),
  (t: 4, entry: opInc[Register8.H, 1]),
  (t: 4, entry: opInc[Register8.H, 0xff]),
  (t: 8, entry: opLd[Register8.H, Immediate8Tag]),
  (t: 0, entry: opUnimpl),
  (t: 8, entry: opJr),
  (t: 8, entry: opAdd16[HL, HL]),
  (t: 8, entry: opLd[A, Reg16Inc(HL).indir]),
  (t: 8, entry: opInc[HL, 0xffff]),
  (t: 4, entry: opInc[L, 1]),
  (t: 4, entry: opInc[L, 0xff]),
  (t: 8, entry: opLd[L, Immediate8Tag]),
  (t: 0, entry: opUnimpl),
  (t: 8, entry: opJr),         # 0x30
  (t: 12, entry: opLd[SP, Immediate16Tag]),
  (t: 8, entry: opLd[Reg16Dec(HL).indir, A]),
  (t: 8, entry: opInc[SP, 1]),
  (t: 12, entry: opInc[HL.indir, 1]),
  (t: 12, entry: opInc[HL.indir, 0xff]),
  (t: 8, entry: opLd[HL.indir, Immediate8Tag]),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opJr),
  (t: 8, entry: opAdd16[HL, SP]),
  (t: 8, entry: opLd[A, Reg16Dec(HL).indir]),
  (t: 8, entry: opInc[SP, 0xffff]),
  (t: 4, entry: opInc[A, 1]),
  (t: 4, entry: opInc[A, 0xff]),
  (t: 8, entry: opLd[A, Immediate8Tag]),
  (t: 0, entry: opUnimpl),
  (t: 4, entry: opLd[B, B]),         # 0x40
  (t: 4, entry: opLd[B, Register8.C]),
  (t: 4, entry: opLd[B, D]),
  (t: 4, entry: opLd[B, E]),
  (t: 4, entry: opLd[B, Register8.H]),
  (t: 4, entry: opLd[B, L]),
  (t: 8, entry: opLd[B, HL.indir]),
  (t: 4, entry: opLd[B, A]),
  (t: 4, entry: opLd[Register8.C, B]),
  (t: 4, entry: opLd[Register8.C, Register8.C]),
  (t: 4, entry: opLd[Register8.C, D]),
  (t: 4, entry: opLd[Register8.C, E]),
  (t: 4, entry: opLd[Register8.C, Register8.H]),
  (t: 4, entry: opLd[Register8.C, L]),
  (t: 8, entry: opLd[Register8.C, HL.indir]),
  (t: 4, entry: opLd[Register8.C, A]),
  (t: 4, entry: opLd[D, B]),         # 0x50
  (t: 4, entry: opLd[D, Register8.C]),
  (t: 4, entry: opLd[D, D]),
  (t: 4, entry: opLd[D, E]),
  (t: 4, entry: opLd[D, Register8.H]),
  (t: 4, entry: opLd[D, L]),
  (t: 8, entry: opLd[D, HL.indir]),
  (t: 4, entry: opLd[D, A]),
  (t: 4, entry: opLd[E, B]),
  (t: 4, entry: opLd[E, Register8.C]),
  (t: 4, entry: opLd[E, D]),
  (t: 4, entry: opLd[E, E]),
  (t: 4, entry: opLd[E, Register8.H]),
  (t: 4, entry: opLd[E, L]),
  (t: 8, entry: opLd[E, HL.indir]),
  (t: 4, entry: opLd[E, A]),
  (t: 4, entry: opLd[Register8.H, B]),         # 0x60
  (t: 4, entry: opLd[Register8.H, Register8.C]),
  (t: 4, entry: opLd[Register8.H, D]),
  (t: 4, entry: opLd[Register8.H, E]),
  (t: 4, entry: opLd[Register8.H, Register8.H]),
  (t: 4, entry: opLd[Register8.H, L]),
  (t: 8, entry: opLd[Register8.H, HL.indir]),
  (t: 4, entry: opLd[Register8.H, A]),
  (t: 4, entry: opLd[L, B]),
  (t: 4, entry: opLd[L, Register8.C]),
  (t: 4, entry: opLd[L, D]),
  (t: 4, entry: opLd[L, E]),
  (t: 4, entry: opLd[L, Register8.H]),
  (t: 4, entry: opLd[L, L]),
  (t: 8, entry: opLd[L, HL.indir]),
  (t: 4, entry: opLd[L, A]),
  (t: 8, entry: opLd[HL.indir, B]),         # 0x70
  (t: 8, entry: opLd[HL.indir, Register8.C]),
  (t: 8, entry: opLd[HL.indir, D]),
  (t: 8, entry: opLd[HL.indir, E]),
  (t: 8, entry: opLd[HL.indir, Register8.H]),
  (t: 8, entry: opLd[HL.indir, L]),
  (t: 4, entry: opSuspend),
  (t: 8, entry: opLd[HL.indir, A]),
  (t: 8, entry: opLd[A, B]),
  (t: 8, entry: opLd[A, Register8.C]),
  (t: 8, entry: opLd[A, D]),
  (t: 8, entry: opLd[A, E]),
  (t: 8, entry: opLd[A, Register8.H]),
  (t: 8, entry: opLd[A, L]),
  (t: 8, entry: opLd[A, HL.indir]),
  (t: 8, entry: opLd[A, A]),
  (t: 4, entry: opAdd[A, B]),         # 0x80
  (t: 4, entry: opAdd[A, Register8.C]),
  (t: 4, entry: opAdd[A, D]),
  (t: 4, entry: opAdd[A, E]),
  (t: 4, entry: opAdd[A, Register8.H]),
  (t: 4, entry: opAdd[A, L]),
  (t: 8, entry: opAdd[A, HL.indir]),
  (t: 4, entry: opAdd[A, A]),
  (t: 4, entry: opAdd[A, B]),
  (t: 4, entry: opAdd[A, Register8.C]),
  (t: 4, entry: opAdd[A, D]),
  (t: 4, entry: opAdd[A, E]),
  (t: 4, entry: opAdd[A, Register8.H]),
  (t: 4, entry: opAdd[A, L]),
  (t: 8, entry: opAdd[A, HL.indir]),
  (t: 4, entry: opAdd[A, A]),
  (t: 4, entry: opAdd[A, B.inv]),         # 0x90
  (t: 4, entry: opAdd[A, Register8.C.inv]),
  (t: 4, entry: opAdd[A, D.inv]),
  (t: 4, entry: opAdd[A, E.inv]),
  (t: 4, entry: opAdd[A, Register8.H.inv]),
  (t: 4, entry: opAdd[A, L.inv]),
  (t: 8, entry: opAdd[A, HL.indir.inv]),
  (t: 4, entry: opAdd[A, A.inv]),
  (t: 4, entry: opAdd[A, B.inv]),
  (t: 4, entry: opAdd[A, Register8.C.inv]),
  (t: 4, entry: opAdd[A, D.inv]),
  (t: 4, entry: opAdd[A, E.inv]),
  (t: 4, entry: opAdd[A, Register8.H.inv]),
  (t: 4, entry: opAdd[A, L.inv]),
  (t: 8, entry: opAdd[A, HL.indir.inv]),
  (t: 4, entry: opAdd[A, A.inv]),
  (t: 4, entry: opAnd[B]),        # 0xa0
  (t: 4, entry: opAnd[Register8.C]),
  (t: 4, entry: opAnd[D]),
  (t: 4, entry: opAnd[E]),
  (t: 4, entry: opAnd[Register8.H]),
  (t: 4, entry: opAnd[L]),
  (t: 8, entry: opAnd[HL.indir]),
  (t: 4, entry: opAnd[A]),
  (t: 4, entry: opXor[B]),
  (t: 4, entry: opXor[Register8.C]),
  (t: 4, entry: opXor[D]),
  (t: 4, entry: opXor[E]),
  (t: 4, entry: opXor[Register8.H]),
  (t: 4, entry: opXor[L]),
  (t: 8, entry: opXor[HL.indir]),
  (t: 4, entry: opXor[A]),
  (t: 4, entry: opOr[B]),        # 0xb0
  (t: 4, entry: opOr[Register8.C]),
  (t: 4, entry: opOr[D]),
  (t: 4, entry: opOr[E]),
  (t: 4, entry: opOr[Register8.H]),
  (t: 4, entry: opOr[L]),
  (t: 8, entry: opOr[HL.indir]),
  (t: 4, entry: opOr[A]),
  (t: 4, entry: opCp[B]),
  (t: 4, entry: opCp[Register8.C]),
  (t: 4, entry: opCp[D]),
  (t: 4, entry: opCp[E]),
  (t: 4, entry: opCp[Register8.H]),
  (t: 4, entry: opCp[L]),
  (t: 8, entry: opCp[HL.indir]),
  (t: 4, entry: opCp[A]),
  (t: 8, entry: opRet[{Z}, true]),         # 0xc0
  (t: 12, entry: opPop[BC]),
  (t: 12, entry: opJp[Immediate16Tag, {NZ}]),
  (t: 12, entry: opJp[Immediate16Tag, {}.Flags]),
  (t: 12, entry: opCall[{Z}, true]),
  (t: 16, entry: opPush[BC]),
  (t: 8, entry: opAdd[A, Immediate8Tag]),
  (t: 0, entry: opUnimpl),
  (t: 8, entry: opRet[{Z}, false]),
  (t: 8, entry: opRet[{}, false]),
  (t: 12, entry: opJp[Immediate16Tag, {Z}]),
  (t: 4, entry: prefixCb),
  (t: 12, entry: opCall[{Z}, false]),
  (t: 12, entry: opCall[{}, false]),
  (t: 8, entry: opAdd[A, Immediate8Tag]),
  (t: 0, entry: opUnimpl),
  (t: 8, entry: opRet[{Flag.C}, true]),         # 0xd0
  (t: 12, entry: opPop[DE]),
  (t: 12, entry: opJp[Immediate16Tag, {NC}]),
  (t: 0, entry: opIllegal),
  (t: 12, entry: opCall[{Flag.C}, true]),
  (t: 16, entry: opPush[DE]),
  (t: 8, entry: opAdd[A, Immediate8Tag.inv]),
  (t: 0, entry: opUnimpl),
  (t: 8, entry: opRet[{Flag.C}, false]),
  (t: 8, entry: opRet[{}, false]),
  (t: 12, entry: opJp[Immediate16Tag, {Flag.C}]),
  (t: 0, entry: opIllegal),
  (t: 12, entry: opCall[{Flag.C}, false]),
  (t: 0, entry: opIllegal),
  (t: 8, entry: opAdd[A, Immediate8Tag.inv]),
  (t: 0, entry: opUnimpl),
  (t: 12, entry: opLd[(Address(0xff00), Immediate8Tag).indir, A]),       # 0xe0
  (t: 12, entry: opPop[HL]),
  (t: 8, entry: opLd[(Address(0xff00), Register8.C).indir, A]),
  (t: 0, entry: opIllegal),
  (t: 0, entry: opIllegal),
  (t: 16, entry: opPush[HL]),
  (t: 8, entry: opAnd[Immediate8Tag]),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opUnimpl),
  (t: 0, entry: opJp[HL, {}.Flags]), # t: 0 is not typo
  (t: 16, entry: opLd[Immediate16Tag.indir, A]),
  (t: 0, entry: opIllegal),
  (t: 0, entry: opIllegal),
  (t: 0, entry: opIllegal),
  (t: 8, entry: opXor[Immediate8Tag]),
  (t: 0, entry: opUnimpl),
  (t: 12, entry: opLd[A, (Address(0xff00), Immediate8Tag).indir]),         # 0xf0
  (t: 12, entry: opPop[AF]),
  (t: 8, entry: opLd[A, (Address(0xff00), Register8.C).indir]),
  (t: 4, entry: opIme),
  (t: 0, entry: opIllegal),
  (t: 16, entry: opPush[AF]),
  (t: 8, entry: opOr[Immediate8Tag]),
  (t: 0, entry: opUnimpl),
  (t: 12, entry: opLd[HL, (SP, Immediate8Tag)]),
  (t: 8, entry: opLd[SP, HL]),
  (t: 16, entry: opLd[A, Immediate16Tag.indir]),
  (t: 4, entry: opIme),
  (t: 0, entry: opIllegal),
  (t: 0, entry: opIllegal),
  (t: 8, entry: opCp[Immediate8Tag]),
  (t: 0, entry: opUnimpl),
]

func setInterrupt*(self: Sm83; intr: Interrupt) =
  self.if.incl intr
                       
func clearInterrupt*(self: Sm83; intr: Interrupt) =
  self.if.excl intr

proc step*(self: var Sm83): Tick {.discardable.} =
  if self.suspended:
    if self.if == {}:
      return
    self.awake

  debug &"| PC:{self.pc.hex} SP:{self.sp.hex} A:{self.r(A).hex} F:{self.f} BC:{self.r(BC).hex} DE:{self.r(DE).hex} HL:{self.r(HL).hex} IE:{self.ie} IF:{self.if}"

  if self.ime:
    let iset = self.ie * self.if
    if iset != {}:
      self.ime = false
      self.push(self.pc)
      let intr = Interrupt(cast[byte](iset).firstSetBit() - 1)
      self.if.excl intr
      self.pc = InterruptVector + byte(intr.ord shl 3)

  let opcode = self.fetch
  let desc = opcodes[opcode]
  let t = desc.entry(self, opcode)
  debug &"- clocks({self.ticks})+={desc.t}+{t}"
  result = desc.t + t
  self.ticks += result
