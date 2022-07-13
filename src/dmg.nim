import std/[logging, strformat, options]
import cpu, timer, memory, cartridge, ppu, io, types, utils
import sdl2_nim/sdl

const
  CpuFreq* = 4_194_304
  NsPerTick* = 1_000_000_000 div CpuFreq

proc newHighRam*(): Ram = newRam(HRAM)

type
  SpriteAttrTable* = ref object of Memory

proc newSpriteAttrTable*(): SpriteAttrTable =
  result = SpriteAttrTable()
  Memory.init(result, OAM)

method load*(self: SpriteAttrTable; a: Address; dest: pointer;
    length: uint16) {.locks: "unknown".} =
  debug "OAM.load"

method store*(self: var SpriteAttrTable; a: Address; src: pointer;
    length: uint16) {.locks: "unknown".} =
  debug "OAM.store"

type
  Dmg* = ref object
    running: bool
    cart: Cartridge
    cpu: Sm83
    ppu: Ppu
    timer: Timer

proc newDmg*(bootRomPath = none[string]()): Dmg =
  var cpu = newSm83(CpuFreq)
  let iomem = newIoMemory(cpu)

  let memCtrl = newMemoryCtrl()
  if bootRomPath.isSome():
    memCtrl.map(newRom(BOOTROM, loadFile(bootRomPath.unsafeGet)))
  else:
    cpu.pc = 0x100
  memCtrl.map(newSpriteAttrTable())
  memCtrl.map(newRam(WRAM0))
  memCtrl.map(newRam(WRAMX))
  memCtrl.map(newEchoRam(WRAM0.a, memCtrl))
  memCtrl.map(newHighRam())
  cpu.memCtrl = memCtrl

  let ppu = newPpu(iomem)
  memCtrl.map(ppu)

  memCtrl.map(iomem)

  iomem.setHandler(IoIf, loadIf, storeIf)

  result = Dmg(cpu: cpu, ppu: ppu, timer: newTimer(iomem), running: true)

proc loadCart*(self: Dmg; path: string) =
  self.cart = newCartridge(path)
  self.cart.mount(self.cpu.memCtrl)

func running*(self: Dmg): bool = self.running

func stop*(self: Dmg) = self.running = false

proc step*(self: Dmg) =
  if not self.running:
    return

  var ev: sdl.Event
  while pollEvent(addr ev) != 0:
    if ev.kind == QUIT:
      self.stop()
    elif ev.kind == WINDOWEVENT and ev.window.event == WINDOWEVENT_CLOSE:
      let ev = Event(kind: QUIT)
      pushEvent(unsafeAddr ev).errQuit

  let ticks = self.cpu.step()
  self.ppu.process(self.cpu, ticks)
  self.timer.process(self.cpu, ticks)

proc run*(self: Dmg) {.inline.} =
  while self.running:
    self.step

proc run*(self: Dmg; numTicks: int) {.inline.} =
  while self.running and self.cpu.ticks <= numTicks:
    self.step()

