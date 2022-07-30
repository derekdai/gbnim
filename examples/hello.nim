import dmg, utils
import std/[logging, tables, os, options]
import sdl2_nim/sdl

addHandler(newConsoleLogger(fmtStr = "[$time] $levelid "))
setLogFilter(lvlInfo)

var emu: Dmg

setControlCHook(proc() {.noconv.} =
  emu.stop()
)

proc main =
  init(InitVideo or InitAudio).errQuit
  defer: sdl.quit()

  emu = newDmg("DMG_ROM.bin".some)
  if paramCount() > 0:
    emu.loadCart(commandLineParams()[0])
  emu.run()

  info "bye"

when isMainModule:
  main()
