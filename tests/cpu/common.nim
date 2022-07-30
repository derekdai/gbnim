import std/[strformat, strutils]
import cpu, memory
export cpu, memory

proc newCpu*(opcodes: seq[byte]): Sm83 =
  result = newSm83()
  result.memCtrl = newMemoryCtrl()
  let bootrom = newRom(BootRom, opcodes)
  result.memCtrl.map(bootrom)
  let wram = newRam(WRAM0)
  result.memCtrl.map(wram)
  let io = newRam(IOREGS)
  result.memCtrl.map(io)

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

