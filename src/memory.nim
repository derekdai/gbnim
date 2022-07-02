import types, utils
import std/[logging, strformat, options]

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
  IE* = MemoryRegion(0xffff.Address..0xffff.Address)

type
  Memory* = ref object of RootObj
    region: MemoryRegion

func init*(T: typedesc[Memory]; self: T; region: MemoryRegion) =
  self.region = region

func `region`*(self: Memory): lent MemoryRegion = self.region
func `region=`*(self: var Memory; region: MemoryRegion) = self.region = region

method load*(self: Memory; a: Address; dest: pointer;
    length: uint16) {.base, locks: "unknown".} = assert false, &"Memory.load(0x{a:04x}) not implemented"

method store*(self: var Memory; a: Address; src: pointer;
    length: uint16) {.base, locks: "unknown".} = assert false, &"Memory.store(0x{a:04x}) not implemented"

type
  Rom* = ref object of Memory
    data: seq[byte]

func initRom*(self: Rom; region: MemoryRegion; data: sink seq[byte]) =
  Memory.init(self, region)
  self.data = data

proc newRom*(region: MemoryRegion; data: sink seq[byte]): Rom =
  result = Rom()
  initRom(result, region, data)

func data*(self: Rom): lent seq[byte] = self.data

method load*(self: Rom; a: Address; dest: pointer; length: uint16) {.locks: "unknown".} =
  copyMem(dest, addr self.data[a - self.region.a], length)

method store*(self: var Rom; a: Address; src: pointer; length: uint16) {.locks: "unknown".} =
  debug &"no ROM region specific implemention: {self.region}"

type
  MemoryCtrl* = ref object
    bootrom: Memory
    mappings: seq[Memory]

proc newMemoryCtrl*(): MemoryCtrl = result = MemoryCtrl()

func lookup*(self: MemoryCtrl; a: Address): Memory =
  for m in self.mappings:
    if a in m.region:
      return m

func maped*(self: MemoryCtrl; a: Address): bool =
  self.lookup(a) != nil

func map*(self: MemoryCtrl; mem: sink Memory) =
  assert(mem.region.b != 0)
  if mem.region == BOOTROM:
    self.bootrom = mem
  for i, m in self.mappings:
    if mem.region == m.region:
      self.mappings[i] = mem
      return
  self.mappings.add mem

func unmap*(self: MemoryCtrl; region: MemoryRegion) =
  for i, m in self.mappings:
    if region == m.region:
      self.mappings.del(i)
      break

func enableBootRom*(self: var MemoryCtrl) {.inline.} =
  self.map(self.bootrom)

func disableBootRom*(self: var MemoryCtrl) {.inline.} =
  self.unmap(BOOTROM)

when not declared(getBacktrace):
  func getBacktrace*(): string {.inline.} = discard

proc load*[T: SomeInteger](self: MemoryCtrl; a: Address): T {.inline.} =
  var mem = self.lookup(a)
  assert mem != nil, &"address 0x{a:04x} is not mapped: {getBacktrace()}"
  mem.load(a, addr result, sizeof(result).uint16)
  debug &"| {result.hex} < {a.hex}"

proc store*[T: SomeInteger](self: var MemoryCtrl; a: Address; v: T) {.inline.} =
  var mem = self.lookup(a)
  assert mem != nil, &"address 0x{a:04x} is not mapped: {getBacktrace()}"
  debug &"| {v.hex} > {a.hex}"
  mem.store(a, unsafeAddr v, sizeof(v).uint16)

proc `[]`*(self: MemoryCtrl; a: Address): byte {.inline.} = load[typeof(result)](self, a)

proc `[]=`*(self: var MemoryCtrl; a: Address; v: byte) {.inline.} = self.store(a, v)

proc `[]=`*(self: var MemoryCtrl; a: Address; v: uint16) {.inline.} = self.store(a, v)
