import std/[logging, strformat]
import cpu, memory, types

type
  IoLoad = proc(cpu: Sm83; a: Address; d: var byte)
  IoStore = proc(cpu: Sm83; a: Address; s: byte)
  IoMemEntry = tuple[load: IoLoad; store: IoStore]
  IoMemory* = ref object of Memory
    cpu {.cursor.}: Sm83
    entries: array[IOREGS.len, IoMemEntry]

proc ioLoadUnimpl(cpu: Sm83; a: Address; d: var byte) =
  debug &"I/O load not implemented for 0x{a:04x}"

proc ioStoreUnimpl(cpu: Sm83; a: Address; s: byte) =
  debug &"I/O store not implemented for 0x{a:04x}"

proc newIoMemory*(cpu: Sm83): IoMemory =
  result = IoMemory()
  Memory.init(result, IOREGS)
  result.cpu = cpu

  let unimpl: IoMemEntry = (
    IoLoad(proc(cpu: Sm83; a: Address; d: var byte) = ioLoadUnimpl(cpu, a, d)),
    IoStore(proc(cpu: Sm83; a: Address; s: byte) = ioStoreUnimpl(cpu, a, s))
  )
  for e in result.entries.mitems:
    e = unimpl

method load*(self: IoMemory; a: Address; dest: pointer;
    length: uint16) {.locks: "unknown".} =
  assert length == 1
  self.entries[a and 0x7f].load(self.cpu, a, cast[var byte](dest))

method store*(self: var IoMemory; a: Address; src: pointer;
    length: uint16) {.locks: "unknown".} =
  assert length == 1
  self.entries[a and 0x7f].store(self.cpu, a, cast[ptr byte](src)[])

func setHandler*(self: IoMemory; a: Address; load: IoLoad; store: IoStore) =
  assert a in IOREGS
  self.entries[a and 0x7f] = (load, store)

