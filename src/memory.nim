import std/[strformat]
import ./types

type
  MemoryRegion* = HSlice[Address, Address]

const
  NumMemoryRegions = 12
  ROM0* = MemoryRegion(0x0000.Address..0x3fff.Address)
  ROMX* = MemoryRegion(0x4000.Address..0x7fff.Address)
  VRAM* = MemoryRegion(0x8000.Address..0x9fff.Address)
  SRAM* = MemoryRegion(0xa000.Address..0xbfff.Address)
  WRAM0* = MemoryRegion(0xc000.Address..0xcfff.Address)
  WRAMX* = MemoryRegion(0xd000.Address..0xdfff.Address)
  ECHO* = MemoryRegion(0xd000.Address..0xdfff.Address)
  OAM* = MemoryRegion(0xfe00.Address..0xfe9f.Address)
  UNUSED* = MemoryRegion(0xfe00.Address..0xfe9f.Address)
  IOREGS* = MemoryRegion(0xff00.Address..0xff7f.Address)
  HRAM* = MemoryRegion(0xff80.Address..0xfffe.Address)
  IEREGS* = MemoryRegion(0xffff.Address..0xffff.Address)

type
  Memory* = ref object of RootObj

method load*(self: Memory; a: Address; dest: pointer; length: uint16) {.base.} = discard

method store*(self: var Memory; a: Address; src: pointer; length: uint16) {.base.} = discard

type
  Rom* = ref object of Memory
    buf: seq[byte]

proc newRom*(buf: sink seq[byte]): Rom =
  Rom(buf: buf)

method load*(self: Rom; a: Address; dest: pointer; length: uint16) =
  copyMem(dest, addr self.buf[a], length)

method store*(self: var Rom; a: Address; src: pointer; length: uint16) = discard

type
  MemoryCtrl* = ref object
    regions: array[NumMemoryRegions, Memory]

proc newMemoryCtrl*(): MemoryCtrl =
  MemoryCtrl()

func toIndex(a: var Address): int {.inline.} =
  if a in ROM0:
    a -= ROM0.a
    return 0
  elif a in ROMX:
    a -= ROMX.a
    return 1
  elif a in VRAM:
    a -= VRAM.a
    return 2
  elif a in SRAM:
    a -= SRAM.a
    return 3
  elif a in WRAM0:
    a -= WRAM0.a
    return 4
  elif a in WRAMX:
    a -= WRAMX.a
    return 5
  elif a in ECHO:
    a -= ECHO.a
    return 6
  elif a in OAM:
    a -= OAM.a
    return 7
  elif a in UNUSED:
    a -= UNUSED.a
    return 8
  elif a in IOREGS:
    a -= IOREGS.a
    return 9
  elif a in HRAM:
    a -= HRAM.a
    return 10
  elif a in IEREGS:
    a -= IEREGS.a
    return 11

func region(self: MemoryCtrl; a: var Address): Memory {.inline.} =
  self.regions[a.toIndex]

func map*(self: MemoryCtrl; region: MemoryRegion; m: Memory) {.inline.} =
  var a = region.a
  self.regions[a.toIndex] = m

func load*[T: SomeInteger](self: MemoryCtrl; a: Address): T {.inline.} =
  var a = a
  self.region(a).load(a, addr result, sizeof(result).uint16)

func store*[T: SomeInteger](self: var MemoryCtrl; a: Address; v: T) {.inline.} =
  var a = a
  self.regions(a).store(a, addr v, sizeof(v).uint16)

