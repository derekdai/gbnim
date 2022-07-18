import std/[logging, strformat]
import cpu, io, types

type
  TimerClock = enum
    tc4096
    tc262144
    tc65536
    tc16384
  TimerControl {.size: sizeof(byte).} = object
    clockSel {.bitsize: 2.}: TimerClock
    started {.bitsize: 1.}: bool
  Timer* = ref object
    divi: byte
    tima: byte
    tma: byte
    tac: TimerControl
    targetTick: Tick

proc loadDiv(self: Timer; cpu: Sm83): byte = self.divi
proc storeDiv(self: Timer; cpu: Sm83; s: byte) =
  debug &"DIV: {s:02x}"
  self.divi = s

proc loadTima(self: Timer; cpu: Sm83): byte = self.tima
proc storeTima(self: Timer; cpu: Sm83; s: byte) =
  debug &"TIMA: {s:02x}"
  self.tima = s

proc loadTma(self: Timer; cpu: Sm83): byte = self.tma
proc storeTma(self: Timer; cpu: Sm83; s: byte) =
  debug &"TMA: {s:02x}"
  self.tma = s

func started(self: Timer): bool {.inline.} = self.tac.started

func updateTargetTick(self: Timer; cpu: Sm83) =
  discard

proc loadTac(self: Timer; cpu: Sm83): byte = cast[byte](self.tac)
proc storeTac(self: Timer; cpu: Sm83; s: byte) =
  let s = cast[TimerControl](s)
  debug &"TAC: {s}"
  if self.tac != s and self.started:
    self.tac = s
    self.updateTargetTick(cpu)

proc newTimer*(iomem: IoMemory): Timer =
  result = Timer()
  iomem.setHandler(IoDiv, forwardLoad(result, loadDiv), forwardStore(result, storeDiv))
  iomem.setHandler(IoTima, forwardLoad(result, loadTima), forwardStore(result, storeTima))
  iomem.setHandler(IoTma, forwardLoad(result, loadTma), forwardStore(result, storeTma))
  iomem.setHandler(IoTac, forwardLoad(result, loadTac), forwardStore(result, storeTac))

proc process*(self: Timer; cpu: Sm83; ticks: Tick) =
  if not self.started: return

  if cpu.ticks > self.targetTick:
    cpu.setInterrupt(Interrupt.Timer)
    self.updateTargetTick(cpu)

