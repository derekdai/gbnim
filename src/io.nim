import std/[logging, strformat]
import cpu, memory, ioregs, types

type
  IoLoad* = proc(cpu: Sm83; a: Address): byte
  IoStore* = proc(cpu: Sm83; a: Address; s: byte)
  IoMemEntry = tuple[load: IoLoad; store: IoStore]
  IoMemory* = ref object of Memory
    cpu {.cursor.}: Sm83
    entries: array[IOREGS.len, IoMemEntry]

proc loadBootRomState(cpu: Sm83; a: Address): byte = discard

proc storeBootRomState(cpu: Sm83; a: Address; s: byte) =
  if s == 0:
    cpu.memCtrl.enableBootRom()
  else:
    cpu.memCtrl.disableBootRom()

func setHandler*(self: IoMemory; a: Address; load: IoLoad; store: IoStore)

proc newIoMemory*(cpu: Sm83): IoMemory =
  result = IoMemory()
  Memory.init(result, IOREGS)
  result.cpu = cpu

  let unimpl: IoMemEntry = (
    IoLoad(proc(cpu: Sm83; a: Address): byte = error &"I/O load not implemented for 0x{a:04x}"),
    IoStore(proc(cpu: Sm83; a: Address; s: byte) = error &"I/O store not implemented for 0x{a:04x}")
  )
  for e in result.entries.mitems:
    e = unimpl

  result.setHandler(IoBootRom, loadBootRomState, storeBootRomState)

method load*(self: IoMemory; a: Address): byte {.locks: "unknown".} =
  self.entries[a and 0x7f].load(self.cpu, a)

method store*(self: IoMemory; a: Address; value: byte) {.locks: "unknown".} =
  self.entries[a and 0x7f].store(self.cpu, a, value)

func setHandler*(self: IoMemory; a: Address; load: IoLoad; store: IoStore) =
  assert a in IOREGS
  self.entries[a and 0x7f] = (load, store)

proc forwardLoad*[T](o: T; p: proc): IoLoad =
  result = proc(cpu: Sm83; a: Address): byte =
    p(o, cpu)

proc forwardStore*[T](o: T; p: proc): IoStore =
  result = proc(cpu: Sm83; a: Address; d: byte) =
    p(o, cpu, d)

