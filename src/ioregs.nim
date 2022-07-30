import setsugar
export setsugar

type
  InterruptKind* = enum
    ## IE: 0xffff
    ## IF: 0xff0f
    ikVBlank
    ikLcdStat
    ikTimer
    ikSerial
    ikJoypad
  InterruptFlags* = set[InterruptKind]

type
  TimerClock* = enum
    tc4096
    tc262144
    tc65536
    tc16384
  TimerControl* {.size: sizeof(byte).} = object
    clockSel* {.bitsize: 2.}: TimerClock
    started* {.bitsize: 1.}: bool

type
  InputSelect* = enum
    DirectionKeys
    ButtonKeys
  InputSelects* = set[InputSelect]
  JoypadKey* {.size: 1.} = enum
    rightOrA
    leftOrB
    upOrSelect
    downOrStart
  JoypadKeys* = iset[JoypadKey]
  JoypadStatus* = object
    keys* {.bitsize: 4.}: JoypadKeys
    inputSelect* {.bitsize: 2.}: InputSelects
    padding* {.bitsize: 2.}: byte

type
  Shade* = enum
    White
    LightGray
    DarkGray
    Black
  BgPalette* {.bycopy.} = object
    color0* {.bitsize: 2.}: Shade
    color1* {.bitsize: 2.}: Shade
    color2* {.bitsize: 2.}: Shade
    color3* {.bitsize: 2.}: Shade
  ObjSize* = enum
    ObjSize8x8
    ObjSize8x16
  BgTileMap* = enum
    BgTileMap9800
    BgTileMap9c00
  WinTileMap* = enum
    WinTileMap9800
    WinTileMap9c00
  BgWinTileData* = enum
    BgWinTileData8800
    BgWinTileData8000
  Lcdc* {.bycopy.} = object
    bgDisplay* {.bitsize: 1.}: bool
    objEnable* {.bitsize: 1.}: bool
    objSize* {.bitsize: 1.}: ObjSize
    bgTileMap* {.bitsize: 1.}: BgTileMap
    bgWinTileData* {.bitsize: 1.}: BgWinTileData
    winEnable* {.bitsize: 1.}: bool
    winTileMap* {.bitsize: 1.}: WinTileMap
    lcdEnable* {.bitsize: 1.}: bool
  LcdMode* = enum
    lmHBlank
    lmVBlank
    lmReadOam
    lmTrans
  LcdcStatus* = object
    mode* {.bitsize: 2.}: LcdMode
    concidence* {.bitsize: 1.}: bool
    hblankIntr* {.bitsize: 1.}: bool
    vblankIntr* {.bitsize: 1.}: bool
    oamIntr* {.bitsize: 1.}: bool
    coincidenceIntr* {.bitsize: 1.}: bool
  SpriteAttribute* = object
    cgbPalette* {.bitsize: 2.}: byte
    tileVBank* {.bitsize: 1.}: byte
    palette* {.bitsize: 1.}: byte
    xFlip* {.bitsize: 1.}: bool
    yFlip* {.bitsize: 1.}: bool
    bgWinOverObj* {.bitsize: 1.}: bool
  Sprite* = object
    y*: byte
    x*: byte
    tileIndex*: byte
    attrs*: SpriteAttribute
