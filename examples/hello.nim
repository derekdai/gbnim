import dmg, cpu, memory, cartridge, utils, ppu, io, types
import std/[logging, strformat, strutils, tables]
import sdl2_nim/sdl

addHandler(newConsoleLogger(fmtStr = "[$time] $levelid "))
setLogFilter(lvlDebug)

var emu: Dmg

setControlCHook(proc() {.noconv.} =
  emu.stop()
)

proc main =
  init(InitVideo or InitAudio).errQuit
  defer: sdl.quit()

  emu = newDmg()
  emu.loadCart("cpu_instrs.gb")
  emu.run()

  info "bye"

when isMainModule:
  main()
