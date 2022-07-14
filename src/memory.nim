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

method load*(self: Memory; a: Address; dest: pointer; length: uint16) {.base,
    locks: "unknown".} =
  assert false

method store*(self: var Memory; a: Address; src: pointer;
    length: uint16) {.base, locks: "unknown".} =
  assert false

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

proc enableBootRom*(self: MemoryCtrl) {.inline.} =
  self.map(self.bootrom)
  debug "Boot ROM mapped"

proc disableBootRom*(self: MemoryCtrl) {.inline.} =
  self.unmap(BOOTROM)
  debug "Boot ROM unmapped"

when not declared(getBacktrace):
  func getBacktrace*(): string {.inline.} = discard

proc load*[T: SomeInteger](self: MemoryCtrl; a: Address): T {.inline.} =
  var mem = self.lookup(a)
  if mem != nil:
    mem.load(a, addr result, sizeof(result).uint16)
    debug &"| {result.hex} < {a.hex}"
  else:
    warn &"unhandled load from 0x{a:04x}"

proc store*[T: SomeInteger](self: var MemoryCtrl; a: Address; v: T) {.inline.} =
  var mem = self.lookup(a)
  if mem != nil:
    mem.store(a, unsafeAddr v, sizeof(v).uint16)
    debug &"| {v.hex} > {a.hex}"
  else:
    warn &"unhandled store to 0x{a:04x}"

proc `[]`*(self: MemoryCtrl; a: Address): byte {.inline.} = load[typeof(
    result)](self, a)

proc `[]=`*(self: var MemoryCtrl; a: Address; v: byte) {.inline.} = self.store(a, v)

proc `[]=`*(self: var MemoryCtrl; a: Address;
    v: uint16) {.inline.} = self.store(a, v)

type
  EchoRam* = ref object of Memory
    target: Address
    mctrl {.cursor.}: MemoryCtrl

proc newEchoRam*(target: Address; mctrl: MemoryCtrl): EchoRam =
  result = EchoRam()
  Memory.init(result, ECHO)
  result.target = target
  result.mctrl = mctrl

method load*(self: EchoRam; a: Address; dest: pointer;
    length: uint16) {.locks: "unknown".} =
  let offset = a - self.region.a
  let mem = self.mctrl.lookup(self.target + offset)
  if mem != nil:
    mem.load(offset, dest, length)
  else:
    warn &"address 0x{a:04x} is not mapped"

method store*(self: var EchoRam; a: Address; src: pointer;
    length: uint16) {.locks: "unknown".} =
  let offset = a - self.region.a
  var mem = self.mctrl.lookup(self.target + offset)
  if mem != nil:
    mem.store(offset, src, length)
  else:
    warn &"address 0x{a:04x} is not mapped"

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

method load*(self: Rom; a: Address; dest: pointer;
    length: uint16) {.locks: "unknown".} =
  copyMem(dest, addr self.data[a - self.region.a], length)

method store*(self: var Rom; a: Address; src: pointer;
    length: uint16) {.locks: "unknown".} =
  warn &"unhandled store to 0x{a:04x}"

type
  Ram* = ref object of Memory
    buf: seq[byte]

proc newRam*(region: MemoryRegion): Ram =
  result = Ram()
  Memory.init(result, region)
  result.buf = newSeq[byte](region.b - region.a + 1)

method load*(self: Ram; a: Address; dest: pointer;
    length: uint16) {.locks: "unknown".} =
  copyMem(dest, addr self.buf[a - self.region.a], length)

method store*(self: var Ram; a: Address; src: pointer;
    length: uint16) {.locks: "unknown".} =
  copyMem(addr self.buf[a - self.region.a], src, length)

