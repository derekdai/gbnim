import std/[logging, strformat]
import cpu, memory, cartridge, ppu, memory, io, types, utils
import sdl2_nim/sdl

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

proc newDmg*(bootRomPath: string): Dmg =
  result = Dmg(cpu: newSm83(), running: true)
  let memCtrl = newMemoryCtrl()
  memCtrl.map(newRom(BOOTROM, loadFile(bootRomPath)))
  memCtrl.map(newSpriteAttrTable())
  memCtrl.map(newRam(WRAM0))
  memCtrl.map(newRam(WRAMX))
  memCtrl.map(newEchoRam(WRAM0.a, memCtrl))
  memCtrl.map(newHighRam())

  let iomem = newIoMemory(result.cpu)
  memCtrl.map(iomem)

  result.ppu = newPpu(result.cpu, iomem)
  memCtrl.map(result.ppu)

  result.cpu.memCtrl = memCtrl

proc loadCart*(self: Dmg; path: string) =
  self.cart = newCartridge(path)
  self.cart.mount(self.cpu.memCtrl)

func running*(self: Dmg): bool = self.running

func stop*(self: Dmg) = self.running = false

func ticks(self: Dmg): int {.inline.} = self.cpu.ticks

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

  self.cpu.step()
  self.ppu.process()

proc run*(self: Dmg) {.inline.} =
  while self.running:
    self.step

proc run*(self: Dmg; numTicks: int) =
  while self.cpu.ticks <= numTicks:
    if not self.running:
      break
    self.step()

