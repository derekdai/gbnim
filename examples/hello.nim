import cpu, memory, types, cartridge, utils
import libbacktrace
import std/[logging, strformat, strutils]

addHandler(newConsoleLogger(fmtStr = "[$time] $levelid "))
setLogFilter(lvlDebug)

type
  SpriteAttrTable* = ref object of Memory

proc newSpriteAttrTable*(): SpriteAttrTable =
  result = SpriteAttrTable()
  Memory.init(result, OAM)

method load*(self: SpriteAttrTable; a: Address; dest: pointer; length: uint16) {.locks: "unknown".} =
  debug "OAM.load"

method store*(self: var SpriteAttrTable; a: Address; src: pointer; length: uint16) {.locks: "unknown".} =
  debug "OAM.store"

type
  Ram* = ref object of Memory
    buf: seq[byte]

proc newRam*(region: MemoryRegion): Ram =
  result = Ram()
  Memory.init(result, region)
  result.buf = newSeq[byte](region.b - region.a + 1)

method load*(self: Ram; a: Address; dest: pointer; length: uint16) {.locks: "unknown".} =
  copyMem(dest, addr self.buf[a - self.region.a], length)

method store*(self: var Ram; a: Address; src: pointer; length: uint16) {.locks: "unknown".} =
  copyMem(addr self.buf[a - self.region.a], src, length)

proc newVideoRam*(): Ram = newRam(VRAM)

proc newHighRam*(): Ram = newRam(HRAM)

type
  SoundOnFlag {.size: 1.} = enum
    Sound1
    Sound2
    Sound3
    Sound4
    Pad0
    Pad1
    Pad2
    SoundAll
  SoundOnFlags = set[SoundOnFlag]
  SoundOutTerminal {.size: 1.} = enum
    Sound1ToSo1
    Sound2ToSo1
    Sound3ToSo1
    Sound4ToSo1
    Sound1ToSo2
    Sound2ToSo2
    Sound3ToSo2
    Sound4ToSo2
  SoundOutTerminals = set[SoundOutTerminal]
  EnvelopeDir = enum
    Decrease
    Increase
  VolumeEnvelope = object
    numEnvSweep {.bitsize: 3.}: byte
    dir {.bitsize: 1.}: EnvelopeDir
    initVol {.bitsize: 4.}: byte
  SoundLengthWaveDuty = object
    soundLen {.bitsize: 6.}: byte
    waveDuty {.bitsize: 2.}: byte
  Shade = enum
    White
    LightGray
    DarkGray
    Black
  BgPaletteData = object
    Color0 {.bitsize: 2.}: Shade
    Color1 {.bitsize: 2.}: Shade
    Color2 {.bitsize: 2.}: Shade
    Color3 {.bitsize: 2.}: Shade
  ObjSize = enum
    os8x8
    os8x16
  LcdCtrl = object
    bgDisplay {.bitsize: 1.}: bool
    objDisplay {.bitsize: 1.}: bool
    objSize {.bitsize: 1.}: ObjSize
    bgTileMapDisplaySel {.bitsize: 1.}: byte
    bgWinTileDataSel {.bitsize: 1.}: byte
    winDisplayEn {.bitsize: 1.}: bool
    winTileMapDisplaySel {.bitsize: 1.}: byte
    lcdDisplay {.bitsize: 1.}: bool

type
  IoLoad = proc(cpu: Sm83; a: Address; s: byte; d: var byte) {.nimcall.}
  IoStore = proc(cpu: Sm83; a: Address; d: var byte; s: byte) {.nimcall.}
  IoRegEntry = tuple[load: IoLoad, store: IoStore]
  IoRegisters* = ref object of Memory
    cpu {.cursor.}: Sm83
    regs: array[IOREGS.len, byte]

proc ioLoadUnimpl(cpu: Sm83; a: Address; s: byte; d: var byte) =
  debug &"I/O load not implemented for 0x{a:04x}"
  d = s
proc ioStoreUnimpl(cpu: Sm83; a: Address; d: var byte; s: byte) =
  debug &"I/O store not implemented for 0x{a:04x}"
  d = s

const
  IoRegEntries: array[IOREGS.len, IoRegEntry] = [
    (ioLoadUnimpl, ioStoreUnimpl),            # 0
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),            # 10
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),            # 20
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),            # 30
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),            # 40
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),            # 50
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),            # 60
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),            # 70
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),            # 80
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),            # 90
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),            # 100
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),            # 110
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),            # 120
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
    (ioLoadUnimpl, ioStoreUnimpl),
  ]

proc newIoRegisters*(cpu: Sm83): IoRegisters =
  result = IoRegisters()
  Memory.init(result, IOREGS)
  result.cpu = cpu

  # trick to allow boot ROM run to its end
  result.regs[0x44] = 144

proc to(v: uint8; T: typedesc): T = cast[ptr T](unsafeAddr v)[]
proc to(v: var uint8; T: typedesc): ptr T = cast[ptr T](v)

method load*(self: IoRegisters; a: Address; dest: pointer; length: uint16) {.locks: "unknown".} =
  assert length == 1
  let off = a and 0xff
  assert off < IoRegEntries.len
  IoRegEntries[off].load(self.cpu, a, self.regs[off], cast[ptr byte](dest)[])

  #let a = a - self.region.a
  #let v = self.r[a]
  #case a
  #of 0x0f:
  #  debug &"IntrFlag: {cast[InterruptFlags](v)}"
  #of 0x44:
  #  debug &"LCDCYCoor: {v}"
  #of 0x42:
  #  debug &"BgScrollY: {v}"
  #else:
  #  debug &"I/O load not impl: 0xff{a:02x}"
  #cast[ptr byte](dest)[] = v

method store*(self: var IoRegisters; a: Address; src: pointer; length: uint16) {.locks: "unknown".} =
  assert length == 1
  let off = a and 0xff
  assert off < IoRegEntries.len
  IoRegEntries[off].store(self.cpu, a, self.regs[off], cast[ptr byte](src)[])

  #let v = cast[ptr uint8](src)[]
  #let a = a - self.region.a
  #case a
  #of 0x0f:
  #  debug &"IntrFlag: {cast[InterruptFlags](v)}"
  #of 0x11:
  #  debug &"SndLenWavPtn: {v.to(SoundLengthWaveDuty)}"
  #of 0x12:
  #  debug &"Ch1VolEnv: {v.to(VolumeEnvelope)}"
  #of 0x25:
  #  debug &"SndOutTerm: {v.to(SoundOutTerminals)}"
  #of 0x26:
  #  debug &"SndOn: {v.to(SoundOnFlags)}"
  #of 0x40:
  #  debug &"LcdCtrl: {v.to(LcdCtrl)}"
  #of 0x42:
  #  debug &"BgScrollY: {v}"
  #of 0x43:
  #  debug &"BgScrollX: {v}"
  #of 0x47:
  #  debug &"BgPalette: {v.to(BgPaletteData)}"
  #of 0x50:
  #  debug &"BootRomOn: {v == 0}"
  #  if v == 0:
  #    self.cpu.memCtrl.enableBootRom()
  #  else:
  #    self.cpu.memCtrl.disableBootRom()
  #else:
  #  debug &"I/O store not impl: 0xff{a:02x}"
  #self.r[a] = v

type
  EchoRam* = ref object of Memory
    target: Address
    mctrl {.cursor.}: MemoryCtrl

proc newEchoRam*(target: Address; mctrl: MemoryCtrl): EchoRam =
  result = EchoRam()
  Memory.init(result, ECHO)
  result.target = target
  result.mctrl = mctrl

method load*(self: EchoRam; a: Address; dest: pointer; length: uint16) {.locks: "unknown".} =
  let offset = a - self.region.a
  let mem = self.mctrl.lookup(self.target + offset)
  assert mem != nil, &"address 0x{a:04x} is not mapped"
  mem.load(offset, dest, length)

method store*(self: var EchoRam; a: Address; src: pointer; length: uint16) {.locks: "unknown".} =
  let offset = a - self.region.a
  var mem = self.mctrl.lookup(self.target + offset)
  assert mem != nil, &"address 0x{a:04x} is not mapped"
  mem.store(offset, src, length)

type
  Dmg* = ref object
    running: bool
    cart: Cartridge
    cpu: Sm83

proc newDmg*(bootRomPath: string): Dmg =
  result = Dmg(cpu: newSm83())
  let memCtrl = newMemoryCtrl()
  memCtrl.map(newRom(BOOTROM, loadFile(bootRomPath)))
  memCtrl.map(newVideoRam())
  memCtrl.map(newSpriteAttrTable())
  memCtrl.map(newRam(WRAM0))
  memCtrl.map(newRam(WRAMX))
  memCtrl.map(newEchoRam(0xc000, memCtrl))
  memCtrl.map(newHighRam())
  memCtrl.map(newIoRegisters(result.cpu))
  result.cpu.memCtrl = memCtrl

proc loadCart*(self: Dmg; path: string) =
  self.cart = newCartridge(path)
  self.cart.mount(self.cpu.memCtrl)

func running*(self: Dmg): bool = self.running

func stop*(self: Dmg) = self.running = false

proc run*(self: Dmg) =
  self.running = true
  while self.running:
    self.cpu.step()

proc run*(self: Dmg; numTicks: int) =
  self.running = true
  while self.cpu.ticks <= numTicks:
    if not self.running:
      break
    self.cpu.step()

type
  Peripheral = ref object of RootObj
  Apu = ref object of Peripheral
  Ppu = ref object of Peripheral

var dmg: Dmg

proc main =
  dmg = newDmg("DMG_ROM.bin")

  setControlCHook(proc() {.noconv.} =
    dmg.stop()
  )

  dmg.loadCart("tetris.gb")
  dmg.run(450000)

  info "bye"

when isMainModule:
  main()
