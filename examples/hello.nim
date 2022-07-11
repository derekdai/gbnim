import dmg, cpu, memory, cartridge, utils, ppu, io, types
import std/[logging, strformat, strutils, tables]
import sdl2_nim/sdl

addHandler(newConsoleLogger(fmtStr = "[$time] $levelid "))
setLogFilter(lvlDebug)

type
  SoundOnFlag {.size: 1.} = enum
    Sound1
    Sound2
    Sound3
    Sound4
    Pad0
    Pad1
    Pad2
    SoundAll
  SoundOnFlags = set[SoundOnFlag]
  SoundOutTerminal {.size: 1.} = enum
    Sound1ToSo1
    Sound2ToSo1
    Sound3ToSo1
    Sound4ToSo1
    Sound1ToSo2
    Sound2ToSo2
    Sound3ToSo2
    Sound4ToSo2
  SoundOutTerminals = set[SoundOutTerminal]
  EnvelopeDir = enum
    Decrease
    Increase
  VolumeEnvelope {.bycopy.} = object
    numEnvSweep {.bitsize: 3.}: byte
    dir {.bitsize: 1.}: EnvelopeDir
    initVol {.bitsize: 4.}: byte
  SoundLengthWaveDuty {.bycopy.} = object
    soundLen {.bitsize: 6.}: byte
    waveDuty {.bitsize: 2.}: byte

var emu: Dmg

setControlCHook(proc() {.noconv.} =
  emu.stop()
)

proc main =
  init(InitVideo or InitAudio).errQuit
  defer: sdl.quit()

  emu = newDmg("DMG_ROM.bin")
  emu.loadCart("tetris.gb")
  emu.run()

  info "bye"

when isMainModule:
  main()
