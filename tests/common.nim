import std/[strformat, strutils]
import cpu, memory, io, ioregs, timer
export cpu, memory

type
  FeatureFlag* = enum
    ffWRam0
    ffHRam
    ffTimer
    ffInterrupt
  FeatureFlags* = set[FeatureFlag]

proc newCpu*(opcodes: seq[byte]; flags: FeatureFlags = {ffHram, ffWRam0}): Sm83 =
  result = newSm83()
  result.memCtrl = newMemoryCtrl()
  let bootrom = newRom(BootRom, opcodes)
  result.memCtrl.map(bootrom)
  if ffWRam0 in flags:
    let wram = newRam(WRAM0)
    result.memCtrl.map(wram)
  if ffHRam in flags:
    let hram = newRam(HRAM)
    result.memCtrl.map(hram)

  let iomem = newIoMemory(result)
  if ffInterrupt in flags:
    iomem.setHandler(IoIf, loadIf, storeIf)
  if ffTimer in flags:
    discard newTimer(iomem)
  result.memCtrl.map(iomem)

proc step*(self: Sm83; n: int) =
  for i in 0..<n:
    self.step()

proc dump*[T: SomeInteger](self: openArray[T]): string =
  result = "["
  for v in self:
    result.add &"0x{v:x}, "
  if result.endsWith(", "):
    result.setLen(result.len - 2)
  result.add "]"

