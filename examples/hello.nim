import dmg, utils
import std/[logging, tables, os]
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
  if paramCount() > 0:
    emu.loadCart(commandLineParams()[0])
  emu.run()

  info "bye"

when isMainModule:
  main()
