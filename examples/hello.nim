import cpu, memory, types
import libbacktrace
import std/[logging, strformat]

addHandler(newConsoleLogger(fmtStr = "[$time] $levelid "))
setLogFilter(lvlDebug)

type
  SpriteAttrTable* = ref object of Memory

proc newSpriteAttrTable*(): SpriteAttrTable = SpriteAttrTable()

method load*(self: SpriteAttrTable; a: Address; dest: pointer; length: uint16) =
  discard

method store*(self: var SpriteAttrTable; a: Address; src: pointer; length: uint16) =
  discard

type
  Ram* = ref object of Memory
    buf: seq[byte]

proc newRam*(size: int): Ram =
  Ram(buf: newSeq[byte](size))

method load*(self: Ram; a: Address; dest: pointer; length: uint16) =
  copyMem(dest, addr self.buf[a], length)

method store*(self: var Ram; a: Address; src: pointer; length: uint16) =
  copyMem(addr self.buf[a], src, length)

proc newVideoRam*(): Ram = newRam(8 * 1024)

proc newHighRam*(): Ram = newRam(0xfffe - 0xff80 + 1)

type
  IoRegisters* = ref object of Memory
    cpu {.cursor.}: Sm83
    r: array[0..0x7f, byte]

proc newIoRegisters*(cpu: Sm83): IoRegisters =
  result = IoRegisters(cpu: cpu)
  result.r[0x44] = 144

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

proc to(v: uint8; T: typedesc): T = cast[ptr T](unsafeAddr v)[]
proc to(v: var uint8; T: typedesc): ptr T = cast[ptr T](v)

method load*(self: IoRegisters; a: Address; dest: pointer; length: uint16) =
  debug "IoRegisters.load"
  assert length == 1
  case a
  of 0x44:
    debug &"LCDCYCoor: {self.r[a]}"
  of 0x42:
    debug &"BgScrollY: {self.r[a]}"
  else:
    debug &"undefined I/O: 0xff{a:02x}"
  cast[ptr byte](dest)[] = self.r[a]

method store*(self: var IoRegisters; a: Address; src: pointer; length: uint16) =
  debug "IoRegisters.store"
  assert length == 1
  let v = cast[ptr uint8](src)[]
  case a
  of 0x11:
    debug &"SndLenWavPtn: {v.to(SoundLengthWaveDuty)}"
  of 0x12:
    debug &"Ch1VolEnv: {v.to(VolumeEnvelope)}"
  of 0x25:
    debug &"SndOutTerm: {v.to(SoundOutTerminals)}"
  of 0x26:
    debug &"SndOn: {v.to(SoundOnFlags)}"
  of 0x40:
    debug &"LcdCtrl: {v.to(LcdCtrl)}"
  of 0x42:
    debug &"BgScrollY: {v}"
  of 0x43:
    debug &"BgScrollX: {v}"
  of 0x47:
    debug &"BgPalette: {v.to(BgPaletteData)}"
  of 0x50:
    debug &"BootRomOn: {v == 0}"
    if v == 0:
      self.cpu.memCtrl.enableBootRom()
    else:
      self.cpu.memCtrl.disableBootRom()
  else:
    debug &"undefined I/O: 0xff{a:02x}"
  copyMem(addr self.r[a], src, length)

type
  Cartridges* = ref object of Memory

proc newCartridges*(): Cartridges = Cartridges()

method load*(self: Cartridges; a: Address; dest: pointer;
    length: uint16) = debug "Cartridges.load"

method store*(self: var Cartridges; a: Address; src: pointer;
    length: uint16) = debug "Cartridges.store"

proc loadFile(path: string): seq[byte] =
  let f = open(path)
  defer: f.close()

  let fileSize = f.getFileSize()
  result = newSeq[byte](fileSize)
  assert f.readBytes(result, 0, fileSize) == fileSize

type
  EchoRam* = ref object of Memory
    target: Address
    mctrl {.cursor.}: MemoryCtrl

proc newEchoRam*(target: Address; mctrl: MemoryCtrl): EchoRam =
  EchoRam(target: target, mctrl: mctrl)

method load*(self: EchoRam; a: Address; dest: pointer; length: uint16) =
  let mem = self.mctrl.region(self.target + a)
  assert mem != nil, &"address 0x{a:04x} is not mapped"
  mem.load(a, dest, length)

method store*(self: var EchoRam; a: Address; src: pointer; length: uint16) =
  var mem = self.mctrl.region(self.target + a)
  assert mem != nil, &"address 0x{a:04x} is not mapped"
  mem.store(a, src, length)

type
  Peripheral = ref object of RootObj
  Apu = ref object of Peripheral
  Ppu = ref object of Peripheral

var running = true

proc main =
  setControlCHook(proc() {.noconv.} =
    running = false
  )

  let bootrom = newRom(loadFile("DMG_ROM.bin"))
  let cartridge = newRom(loadFile("20y.gb"))
  var c = newSm83()
  let mc = newMemoryCtrl()
  mc.map(BOOTROM, bootrom)
  mc.map(ROM0, cartridge)
  mc.map(VRAM, newVideoRam())
  mc.map(SRAM, newRam(8 * 1024))
  mc.map(OAM, newSpriteAttrTable())
  mc.map(WRAM0, newRam(4 * 1024))
  mc.map(WRAMX, newRam(4 * 1024))
  mc.map(ECHO, newEchoRam(0xc000, mc))
  mc.map(HRAM, newHighRam())
  mc.map(IOREGS, newIoRegisters(c))
  c.memCtrl = mc 

  while running and c.ticks < 400000:
    c.step()

  info "bye"

when isMainModule:
  main()
