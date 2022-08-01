import std/[logging, strformat]
import cpu, io, ioregs, types

const
  DivFreq = 16384
  DivIncTicks = Clock div DivFreq

type
  Timer* = ref object
    divi: byte
    tima: byte
    tma: byte
    tac: TimerControl
    diviTicks: int
    timaTicks: int
    timaIncTicks: int

proc loadDiv(self: Timer; cpu: Sm83): byte = self.divi
proc storeDiv(self: Timer; cpu: Sm83; s: byte) =
  debug &"DIV reseted"
  self.divi = 0

proc loadTima(self: Timer; cpu: Sm83): byte = self.tima
proc storeTima(self: Timer; cpu: Sm83; s: byte) =
  debug &"TIMA: {s:02x}"
  self.tima = s

proc loadTma(self: Timer; cpu: Sm83): byte = self.tma
proc storeTma(self: Timer; cpu: Sm83; s: byte) =
  debug &"TMA: {s:02x}"
  self.tma = s

func started(self: Timer): bool {.inline.} = self.tac.started

proc loadTac(self: Timer; cpu: Sm83): byte = cast[byte](self.tac)
proc storeTac(self: Timer; cpu: Sm83; s: byte) =
  let s = cast[TimerControl](s)
  debug &"TAC: {s}"

  case s.clockSel
  of tc4096:
    self.timaIncTicks = Clock shl 12
  of tc262144:
    self.timaIncTicks = Clock shl 18
  of tc65536:
    self.timaIncTicks = Clock shl 16
  of tc16384:
    self.timaIncTicks = Clock shl 14

proc newTimer*(iomem: IoMemory): Timer =
  result = Timer()
  iomem.setHandler(IoDiv, forwardLoad(result, loadDiv), forwardStore(result, storeDiv))
  iomem.setHandler(IoTima, forwardLoad(result, loadTima), forwardStore(result, storeTima))
  iomem.setHandler(IoTma, forwardLoad(result, loadTma), forwardStore(result, storeTma))
  iomem.setHandler(IoTac, forwardLoad(result, loadTac), forwardStore(result, storeTac))

proc process*(self: Timer; cpu: Sm83; ticks: Tick) =
  self.diviTicks += ticks
  if self.diviTicks >= DivIncTicks:
    self.divi.inc
    self.diviTicks -= DivIncTicks

  if not self.started:
    return

  self.timaTicks += ticks
  if self.timaTicks < self.timaIncTicks:
    return

  self.tima.inc
  self.timaTicks -= self.timaIncTicks
  if self.tima > 0:
    return

  self.tima = self.tma
  cpu{ikTimer} = true

