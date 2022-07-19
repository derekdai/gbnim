import std/[logging, strformat, strutils]
import sdl2_nim/sdl
import io, cpu, types, setsugar

type
  InputSelect = enum
    DirectionKeys
    ButtonKeys
  InputSelects = set[InputSelect]
  JoypadKey {.size: 1.} = enum
    rightOrA
    leftOrB
    upOrSelect
    downOrStart
  JoypadKeys = iset[JoypadKey]
  JoypadStatus = object
    keys {.bitsize: 4.}: JoypadKeys
    inputSelect {.bitsize: 2.}: InputSelects
    padding {.bitsize: 2.}: byte
  Joypad* = ref object
    keyPressed: bool
    joyp: JoypadStatus
    kbState: ptr array[NUM_SCANCODES.int, byte]

proc loadJoyp(self: Joypad; cpu: Sm83): byte =
  debug &"JOYP: < {self.joyp}"
  cast[byte](self.joyp)

proc storeJoyp(self: Joypad; cpu: Sm83; s: byte) =
  self.joyp = cast[JoypadStatus](s)
  debug &"JOYP: > {self.joyp}"

proc newJoypad*(iomem: IoMemory): Joypad =
  result = Joypad(joyp: JoypadStatus(keys: setsugar.default(JoypadKeys)), kbState: getKeyboardState(nil))
  iomem.setHandler(IoJoyp, forwardLoad(result, loadJoyp), forwardStore(result, storeJoyp))

proc handleEvent*(self: Joypad; ev: Event) =
  if ev.kind != KEYDOWN or ev.key.repeat != 0:
    self.keyPressed = false
    return

  debug &"key pressed: {getScancodeName(ev.key.keysym.scancode)}"
  case ev.key.keysym.scancode:
  of SCANCODE_W, SCANCODE_S, SCANCODE_A, SCANCODE_D,
     SCANCODE_G, SCANCODE_H, SCANCODE_J, SCANCODEK:
    self.keyPressed = true
  else:
    discard

proc process*(self: Joypad; cpu: Sm83) =
  if self.keyPressed:
    cpu.setInterrupt(Interrupt.Joypad)
  else:
    cpu.clearInterrupt(Interrupt.Joypad)

  if self.joyp.inputSelect{DirectionKeys} and self.joyp.inputSelect{ButtonKeys}:
    self.joyp.keys{upOrSelect} = (self.kbState[SCANCODE_W] or self.kbState[SCANCODE_G]) == 1
    self.joyp.keys{downOrStart} = (self.kbState[SCANCODE_S] or self.kbState[SCANCODE_H]) == 1
    self.joyp.keys{leftOrB} = (self.kbState[SCANCODE_A] or self.kbState[SCANCODE_J]) == 1
    self.joyp.keys{rightORA} = (self.kbState[SCANCODE_D] or self.kbState[SCANCODE_K]) == 1
  elif self.joyp.inputSelect{DirectionKeys}:
    self.joyp.keys{upOrSelect} = self.kbState[SCANCODE_W] == 1
    self.joyp.keys{downOrStart} = self.kbState[SCANCODE_S] == 1
    self.joyp.keys{leftOrB} = self.kbState[SCANCODE_A] == 1
    self.joyp.keys{rightORA} = self.kbState[SCANCODE_D] == 1
  elif self.joyp.inputSelect{ButtonKeys}:
    self.joyp.keys{upOrSelect} = self.kbState[SCANCODE_G] == 1
    self.joyp.keys{downOrStart} = self.kbState[SCANCODE_H] == 1
    self.joyp.keys{leftOrB} = self.kbState[SCANCODE_J] == 1
    self.joyp.keys{rightORA} = self.kbState[SCANCODE_K] == 1