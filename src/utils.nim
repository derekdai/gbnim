import std/strformat

const
  Byte* = 1
  Kilo* = Byte shl 10
  Mega* = Kilo shl 10

proc hex*(v: uint8): string = &"0x{v:02x}"

proc hex*(v: uint16): string = &"0x{v:04x}"

proc loadFile*(path: string): seq[byte] =
  let f = open(path)
  defer: f.close()

  let fileSize = f.getFileSize()
  result = newSeq[byte](fileSize)
  assert f.readBytes(result, 0, fileSize) == fileSize

proc errQuit*[T](ret: T): auto {.inline.} =
  when T is SomeInteger:
    if ret != 0:
      fatal sdl.getError()
      quit(1)
  else:
    if ret == nil:
      fatal sdl.getError()
      quit(1)
    ret

