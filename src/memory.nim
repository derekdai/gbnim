import types, utils
import std/[logging, strformat]

type
  MemoryRegion* = Slice[Address]

const
  BOOTROM* = MemoryRegion(0x0000.Address..0x00ff.Address)
  ROM0* = MemoryRegion(0x0000.Address..0x3fff.Address)
  ROMX* = MemoryRegion(0x4000.Address..0x7fff.Address)
  VRAM* = MemoryRegion(0x8000.Address..0x9fff.Address)
  SRAM* = MemoryRegion(0xa000.Address..0xbfff.Address)
  WRAM0* = MemoryRegion(0xc000.Address..0xcfff.Address)
  WRAMX* = MemoryRegion(0xd000.Address..0xdfff.Address)
  ECHO* = MemoryRegion(0xe000.Address..0xfdff.Address)
  OAM* = MemoryRegion(0xfe00.Address..0xfe9f.Address)
  UNUSED* = MemoryRegion(0xfe00.Address..0xfe9f.Address)
  IOREGS* = MemoryRegion(0xff00.Address..0xff7f.Address)
  HRAM* = MemoryRegion(0xff80.Address..0xfffe.Address)
  IEREGS* = MemoryRegion(0xffff.Address..0xffff.Address)
  MemoryRegions = [BOOTROM, ROM0, ROMX, VRAM, SRAM, WRAM0, WRAMX, ECHO, OAM, UNUSED,
      IOREGS, HRAM, IEREGS, ]

type
  Memory* = ref object of RootObj
    region: MemoryRegion

func `region`(self: Memory): lent MemoryRegion = self.region
func `region=`(self: var Memory; region: MemoryRegion) = self.region = region

method load*(self: Memory; a: Address; dest: pointer;
    length: uint16) {.base.} = debug "Memory.load"

method store*(self: var Memory; a: Address; src: pointer;
    length: uint16) {.base.} = debug "Memory.store"

type
  Rom* = ref object of Memory
    buf: seq[byte]

proc newRom*(buf: sink seq[byte]): Rom =
  Rom(buf: buf)

method load*(self: Rom; a: Address; dest: pointer; length: uint16) =
  copyMem(dest, addr self.buf[a - self.region.a], length)

method store*(self: var Rom; a: Address; src: pointer; length: uint16) =
  debug &"no ROM region specific implemention: {self.region}"

type
  MemoryCtrl* = ref object
    offset: int
    regions: array[MemoryRegions.len, Memory]

proc newMemoryCtrl*(): MemoryCtrl = result = MemoryCtrl()

func lookup(a: Address; offset: int): int {.inline.} =
  ## `binarySearch` is too expensive for this small array
  for i in offset..<MemoryRegions.len:
    if a in MemoryRegions[i]:
      return i

func enableBootRom*(self: var MemoryCtrl) = self.offset = 0

func disableBootRom*(self: var MemoryCtrl) = self.offset = 1

func region*(self: MemoryCtrl; a: Address): Memory {.inline.} =
  self.regions[a.lookup(self.offset)]

func map*(self: MemoryCtrl; region: MemoryRegion; m: sink Memory) {.inline.} =
  m.region = region
  self.regions[(region.b - 1).lookup(self.offset)] = m

when not declared(getBacktrace):
  func getBacktrace*(): string {.inline.} = discard

proc load*[T: SomeInteger](self: MemoryCtrl; a: Address): T {.inline.} =
  var mem = self.region(a)
  assert mem != nil, &"address 0x{a:04x} is not mapped: {getBacktrace()}"
  mem.load(a - mem.region.a, addr result, sizeof(result).uint16)
  debug &"| {result.hex:10} < {a.hex}"

proc store*[T: SomeInteger](self: var MemoryCtrl; a: Address; v: T) {.inline.} =
  var mem = self.region(a)
  assert mem != nil, &"address 0x{a:04x} is not mapped: {getBacktrace()}"
  mem.store(a - mem.region.a, unsafeAddr v, sizeof(v).uint16)
  debug &"| {v.hex:10} > {a.hex}"

proc `[]`*(self: MemoryCtrl; a: Address): byte {.inline.} = load[typeof(result)](self, a)

proc `[]=`*(self: var MemoryCtrl; a: Address; v: byte) {.inline.} = self.store(a, v)

proc `[]=`*(self: var MemoryCtrl; a: Address; v: uint16) {.inline.} = self.store(a, v)
