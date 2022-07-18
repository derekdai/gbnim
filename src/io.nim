import std/[logging, strformat]
import cpu, memory, types

const
  IoJoyp* = Address(0xff00)
  ## Timer and divider registers
  IoDiv* = Address(0xff04)
  IoTima* = Address(0xff05)
  IoTma* = Address(0xff06)
  IoTac* = Address(0xff07)
  ## Interrupts
  IoIf* = Address(0xff0f)
  ## LCD control registers
  IoLcdc* = Address(0xff40)
  IoScy* = Address(0xff42)
  IoScx* = Address(0xff43)
  IoLy* = Address(0xff44)
  IoLyc* = Address(0xff45)
  IoBgp* = Address(0xff47)
  IoBootRom* = Address(0xff50)

type
  IoLoad* = proc(cpu: Sm83; a: Address; d: var byte)
  IoStore* = proc(cpu: Sm83; a: Address; s: byte)
  IoMemEntry = tuple[load: IoLoad; store: IoStore]
  IoMemory* = ref object of Memory
    cpu {.cursor.}: Sm83
    entries: array[IOREGS.len, IoMemEntry]

proc ioLoadUnimpl(a: Address) =
  debug &"I/O load not implemented for 0x{a:04x}"

proc ioStoreUnimpl(a: Address) =
  debug &"I/O store not implemented for 0x{a:04x}"

proc loadBootRomState(cpu: Sm83; a: Address; d: var byte) = discard

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
    IoLoad(proc(cpu: Sm83; a: Address; d: var byte) = ioLoadUnimpl(a)),
    IoStore(proc(cpu: Sm83; a: Address; s: byte) = ioStoreUnimpl(a))
  )
  for e in result.entries.mitems:
    e = unimpl

  result.setHandler(IoBootRom, loadBootRomState, storeBootRomState)

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

proc forwardLoad*[T](o: T; p: proc): IoLoad =
  result = proc(cpu: Sm83; a: Address; d: var byte) =
    p(o, cpu, d)

proc forwardStore*[T](o: T; p: proc): IoStore =
  result = proc(cpu: Sm83; a: Address; d: byte) =
    p(o, cpu, d)

