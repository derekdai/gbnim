import cpu, memory, types
import libbacktrace
import std/logging

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
  debug "Ram.load"
  copyMem(dest, addr self.buf[a], length)

method store*(self: var Ram; a: Address; src: pointer; length: uint16) =
  debug "Ram.store"
  copyMem(addr self.buf[a], src, length)

proc newVideoRam*(): Ram = newRam(8 * 1024)

proc newHighRam*(): Ram = newRam(0xfffe - 0xff80 + 1)

type
  IoRegisters* = ref object of Memory

proc newIoRegisters*(): IoRegisters = IoRegisters()

method load*(self: IoRegisters; a: Address; dest: pointer;
    length: uint16) = debug "IoRegisters.load"

method store*(self: var IoRegisters; a: Address; src: pointer;
    length: uint16) = debug "IoRegisters.store"

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

proc main =
  let bootrom = newRom(loadFile("DMG_ROM.bin"))
  let cartridge = newRom(loadFile("20y.gb"))
  let mc = newMemoryCtrl()
  mc.map(BOOTROM, bootrom)
  mc.map(ROM0, cartridge)
  mc.map(VRAM, newVideoRam())
  mc.map(SRAM, newRam(8 * 1024))
  mc.map(OAM, newSpriteAttrTable())
  mc.map(WRAM0, newRam(4 * 1024))
  mc.map(WRAMX, newRam(4 * 1024))
  mc.map(HRAM, newHighRam())
  mc.map(IOREGS, IoRegisters())
  var c = newSm83(mc)

  while true:
    c.step()

when isMainModule:
  main()
