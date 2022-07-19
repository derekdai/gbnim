import std/[logging, strformat, options]
import cpu, timer, memory, cartridge, ppu, joypad, io, types, utils
import sdl2_nim/sdl

const
  CpuFreq* = 4_194_304
  NsPerTick* = 1_000_000_000 div CpuFreq

proc newHighRam*(): Ram = newRam(HRAM)

type
  Dmg* = ref object
    running: bool
    cart: Cartridge
    cpu: Sm83
    ppu: Ppu
    timer: Timer
    joypad: Joypad

proc newDmg*(bootRomPath = none[string]()): Dmg =
  var cpu = newSm83(CpuFreq)
  let iomem = newIoMemory(cpu)

  let memCtrl = newMemoryCtrl()
  if bootRomPath.isSome():
    memCtrl.map(newRom(BOOTROM, loadFile(bootRomPath.unsafeGet)))
  else:
    cpu.pc = 0x100
  memCtrl.map(newNilRom(ROM0, 0xff))
  memCtrl.map(newNilRom(ROMX, 0xff))
  memCtrl.map(newRam(WRAM0))
  memCtrl.map(newRam(WRAMX))
  memCtrl.map(newEchoRam(WRAM0.a, memCtrl))
  memCtrl.map(newHighRam())
  cpu.memCtrl = memCtrl

  let ppu = newPpu(cpu, memCtrl, iomem)
  let joypad = newJoypad(iomem)

  memCtrl.map(iomem)

  iomem.setHandler(IoIf, loadIf, storeIf)

  result = Dmg(cpu: cpu, ppu: ppu, timer: newTimer(iomem), joypad: joypad, running: true)

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
    self.joypad.handleEvent(ev)

  let ticks = self.cpu.step()
  self.joypad.process(self.cpu)
  self.ppu.process(self.cpu, ticks)
  self.timer.process(self.cpu, ticks)

proc run*(self: Dmg) {.inline.} =
  while self.running:
    self.step

proc run*(self: Dmg; numTicks: int) {.inline.} =
  while self.running and self.cpu.ticks <= numTicks:
    self.step()

