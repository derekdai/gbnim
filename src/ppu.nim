import std/[logging, strformat]
import cpu, memory, io, types, utils
import sdl2_nim/sdl

type
  Rgba8888 = tuple[r, g, b, a: uint8]

const
  ColorPowerOff*: Rgba8888 = (r: 181u8, g: 204u8, b: 15u8, a: 0u8)
  ColorWhite*: Rgba8888 = (r: 155u8, g: 188u8, b: 15u8, a: 0u8)
  ColorGray*: Rgba8888 = (r: 139u8, g: 172u8, b: 15u8, a: 0u8)
  ColorDarkGray*: Rgba8888 = (r: 49u8, g: 98u8, b: 49u8, a: 0u8)
  ColorBlack*: Rgba8888 = (r: 15u8, g: 56u8, b: 15u8, a: 0u8)
  Colors = [
    ColorWhite,
    ColorGray,
    ColorDarkGray,
    ColorBlack,
  ]

type
  PaletteIndex = 0..3
  Point = tuple
    x: int
    y: int
  Tile = array[16, byte]
  Tiles = array[192, Tile]
  TileMap = array[32, array[32, byte]]
  Shade = enum
    White
    LightGray
    DarkGray
    Black
  BgPalette {.bycopy.} = object
    color0 {.bitsize: 2.}: Shade
    color1 {.bitsize: 2.}: Shade
    color2 {.bitsize: 2.}: Shade
    color3 {.bitsize: 2.}: Shade
  ObjSize = enum
    ObjSize8x8
    ObjSize8x16
  BgTileMap = enum
    BgTileMap9800
    BgTileMap9c00
  WinTileMap = enum
    WinTileMap9800
    WinTileMap9c00
  BgWinTileData = enum
    BgWinTileData8800
    BgWinTileData8000
  Lcdc {.bycopy.} = object
    bgDisplay {.bitsize: 1.}: bool
    objEnable {.bitsize: 1.}: bool
    objSize {.bitsize: 1.}: ObjSize
    bgTileMap {.bitsize: 1.}: BgTileMap
    bgWinTileData {.bitsize: 1.}: BgWinTileData
    winEnable {.bitsize: 1.}: bool
    winTileMap {.bitsize: 1.}: WinTileMap
    lcdEnable {.bitsize: 1.}: bool

converter toRgba(self: Shade): lent Rgba8888 {.inline.} =
  Colors[self.ord]

converter toAddr(self: BgWinTileData): Address {.inline.} =
  const addresses = [Address(0x8800), 0x8000]
  addresses[self.ord]

proc normalize(self: BgWinTileData; num: byte): byte =
  ## convert tile number to tile index (start from 0)
  (num + ((self.byte xor 1) shl 7)) and 0xff

converter toAddr(self: WinTileMap): Address {.inline.} =
  const addresses = [Address(0x9800), 0x9c00]
  addresses[self.ord]

converter toAddr(self: BgTileMap): Address {.inline.} =
  const addresses = [Address(0x9800), 0x9c00]
  addresses[self.ord]

func byte1(self: ptr Tile; p: Point): byte {.inline.} = self[p.y shl 1]

func bit1(self: ptr Tile; p: Point): byte {.inline.} = (self.byte1(p) shr (7 - p.x)) and 1

func byte2(self: ptr Tile; p: Point): byte {.inline.} = self[(p.y shl 1) + 1]

func bit2(self: ptr Tile; p: Point): byte {.inline.} = (self.byte2(p) shr (7 - p.x)) and 1

func width(_: typedesc[Tile]): int {.inline.} = 8

func height(_: typedesc[Tile]): int {.inline.} = 8

func rows(_: typedesc[TileMap]): int {.inline.} = 32

func cols(_: typedesc[TileMap]): int {.inline.} = 32

func pixel(self: ptr Tile; p: Point): PaletteIndex {.inline.} =
  self.bit1(p) or (self.bit2(p) shl 1)

const
  DisplayResolution = (w: 160, h: 144)
  TileMapResolution = (w: 256, h: 48 + 256 + 256 + 2)

type
  LcdMode = enum
    lmHBlank
    lmVBlank
    lmReadOam
    lmTrans
  LcdcStatus = object
    mode {.bitsize: 2.}: LcdMode
    concidence {.bitsize: 1.}: bool
    mode0Intr {.bitsize: 1.}: bool
    mode1Intr {.bitsize: 1.}: bool
    mode2Intr {.bitsize: 1.}: bool
    concidenceIntr {.bitsize: 1.}: bool
  PpuFlag = enum
    Dirty
    VRamDirty
  PpuFlags = set[PpuFlag]
  SpriteAttribute = object
    cgbPalette {.bitsize: 2.}: byte
    tileVBank {.bitsize: 1.}: byte
    palette {.bitsize: 1.}: byte
    xFlip {.bitsize: 1.}: bool
    yFlip {.bitsize: 1.}: bool
    bgWinOverObj {.bitsize: 1.}: bool
  Sprite = object
    y: byte
    x: byte
    tileIndex: byte
    attrs: SpriteAttribute
  Ppu* = ref object
    flags: PpuFlags
    ticks: Tick
    win: sdl.Window
    rend: sdl.Renderer
    txt: sdl.Texture
    scx, scy: byte
    bgp: BgPalette
    lcdc: Lcdc
    ly, lyc: byte
    tileWin: sdl.Window
    tileRend: sdl.Renderer
    tileTxt: sdl.Texture
    stat: LcdcStatus
    vram: array[VRAM.len, byte]
    oam: array[OAM.len, byte]

proc `=destroy`(self: var typeof(Ppu()[])) =
  if self.txt != nil:
    self.txt.destroyTexture()

  if self.rend != nil:
    self.rend.destroyRenderer()

  if self.win != nil:
    self.rend.destroyWindow()

func bgColor(self: Ppu; i: PaletteIndex): Shade {.inline.} =
  case i:
  of 0: self.bgp.color0
  of 1: self.bgp.color1
  of 2: self.bgp.color2
  of 3: self.bgp.color3

proc loadBgp(self: Ppu; d: var byte) = d = cast[byte](self.bgp)
proc storeBgp(self: Ppu; s: byte) =
  self.bgp = cast[BgPalette](s)
  debug &"BGP={self.bgp}"

proc loadScy(self: Ppu; d: var byte) = d = self.scx
proc storeScy(self: Ppu; s: byte) =
  self.scy = s
  debug &"SCY: {self.scy}"

proc loadScx(self: Ppu; d: var byte) = d = self.scy
proc storeScx(self: Ppu; s: byte) =
  self.scx = s
  debug &"SCX: {self.scx}"

converter toByte(v: Lcdc): byte {.inline.} = cast[byte](v)
proc loadLcdc(self: Ppu; d: var byte) = d = self.lcdc
proc storeLcdc(self: Ppu; s: byte) =
  if s != self.lcdc:
    self.flags.incl Dirty
    self.flags.incl VramDirty
  self.lcdc = cast[Lcdc](s)
  debug &"LCDC: {self.lcdc}"

proc loadLy(self: Ppu; d: var byte) =
  debug &"LY: {self.ly}"
  d = self.ly
proc storeLy(self: Ppu; s: byte) =
  ## Writing will reset the counter?
  discard

type
  VideoRam = ref object of Memory
    ppu {.cursor.}: Ppu

proc newVideoRam(ppu: Ppu): VideoRam =
  result = VideoRam(ppu: ppu)
  Memory.init(result, VRAM)

method load(self: VideoRam; a: Address; dest: pointer; length: uint16) {.locks: "unknown".} =
  assert length == 1
  cast[ptr byte](dest)[] = self.ppu.vram[a - self.region.a]

method store(self: var VideoRam; a: Address; src: pointer; length: uint16) {.locks: "unknown".} =
  assert length == 1
  self.ppu.vram[a - self.region.a] = cast[ptr byte](src)[]
  self.ppu.flags.incl VRamDirty

type
  ObjAttrTable = ref object of Memory
    ppu {.cursor.}: Ppu

proc newObjAttrTable(ppu: Ppu): ObjAttrTable =
  result = ObjAttrTable(ppu: ppu)
  Memory.init(result, OAM)

method load*(self: ObjAttrTable; a: Address; dest: pointer; length: uint16) {.locks: "unknown".} =
  warn &"unhandled load from 0x{a:04x}"

method store*(self: var ObjAttrTable; a: Address; src: pointer; length: uint16) {.locks: "unknown".} =
  assert length == 1
  self.ppu.oam[a - OAM.a] = cast[ptr byte](src)[]

proc newPpu*(mctrl: MemoryCtrl; iom: IoMemory): Ppu =
  var ppu = Ppu(flags: {Dirty, VRamDirty})

  iom.setHandler IoBgp,
    proc(cpu: Sm83; a: Address; d: var byte) = loadBgp(ppu, d),
    proc(cpu: Sm83; a: Address; s: byte) = storeBgp(ppu, s)

  iom.setHandler IoLcdc,
    proc(cpu: Sm83; a: Address; d: var byte) = loadLcdc(ppu, d),
    proc(cpu: Sm83; a: Address; s: byte) = storeLcdc(ppu, s)

  iom.setHandler IoScy,
    proc(cpu: Sm83; a: Address; d: var byte) = loadScy(ppu, d),
    proc(cpu: Sm83; a: Address; s: byte) = storeScy(ppu, s)

  iom.setHandler IoScx,
    proc(cpu: Sm83; a: Address; d: var byte) = loadScx(ppu, d),
    proc(cpu: Sm83; a: Address; s: byte) = storeScx(ppu, s)

  iom.setHandler IoLy,
    proc(cpu: Sm83; a: Address; d: var byte) = loadLy(ppu, d),
    proc(cpu: Sm83; a: Address; s: byte) = storeLy(ppu, s)

  let vram = newVideoRam(ppu)
  mctrl.map(vram)

  let oam = newObjAttrTable(ppu)
  mctrl.map(oam)

  ppu.win = createWindow(
    "gdnim",
    sdl.WindowPosCentered,
    sdl.WindowPosCentered,
    DisplayResolution[0] * 5,
    DisplayResolution[1] * 5,
    0).errQuit
  ppu.rend = ppu.win.createRenderer(
    -1,
    sdl.RendererAccelerated or sdl.RendererPresentVsync).errQuit
  ppu.txt = ppu.rend.createTexture(
    PIXELFORMAT_RGBA8888,
    TEXTUREACCESS_TARGET,
    DisplayResolution[0],
    DisplayResolution[1]).errQuit

  ppu.tileWin = createWindow(
    "Tile Map",
    sdl.WindowPosCentered,
    sdl.WindowPosCentered,
    TileMapResolution.w * 2,
    TileMapResolution.h * 2,
    0).errQuit
  ppu.tileRend = ppu.tileWin.createRenderer(
    -1,
    sdl.RendererAccelerated or sdl.RendererPresentVsync).errQuit
  ppu.tileTxt = ppu.tileRend.createTexture(
    PIXELFORMAT_RGBA8888,
    TEXTUREACCESS_TARGET,
    TileMapResolution.w,
    TileMapResolution.h).errQuit

  ppu

proc tile(self: Ppu; tileNum: byte): ptr Tile {.inline.} =
  ## tile number 的解讀需要參考 Lcdc.bgWinTileData 來決定
  let offset = self.lcdc.bgWinTileData.toAddr - VRAM.a
  addr cast[ptr UncheckedArray[Tile]](addr self.vram[offset])[self.lcdc.bgWinTileData.normalize(tileNum)]

proc winTileMap(self: Ppu): lent TileMap {.inline.} =
  let offset = self.lcdc.winTileMap.toAddr - VRAM.a
  cast[ptr TileMap](addr self.vram[offset])[]

proc bgTileMap(self: Ppu): lent TileMap {.inline.} =
  let offset = self.lcdc.bgTileMap.toAddr - VRAM.a
  cast[ptr TileMap](addr self.vram[offset])[]

proc drawTile(self: Ppu; tileNum: byte; topLeft: Point) =
  let tile = self.tile(tileNum)
  for y in 0..<Tile.height:
    for x in 0..<Tile.width:
      let i = tile.pixel((x, y))
      let c = self.bgColor(i).toRgba
      setRenderDrawColor(self.tileRend, c.r, c.g, c.b, c.a).errQuit
      self.tileRend.renderDrawPoint(topLeft.x + x, topLeft.y + y).errQuit

proc drawTiles(self: Ppu; topLeft: Point) =
  for i in 0..<Tiles.len:
    let r = i shr 5         # i / 32
    let c = i and 0b11111   # i mod 32
    let p = (topLeft[0] + (c shl 3), topLeft[1] + (r shl 3))
    drawTile(self, byte(i), p)

proc drawTileMap(self: Ppu; tileMap: TileMap; topLeft: Point) =
  for r in 0..<TileMap.rows:
    for c in 0..<TileMap.cols:
      let p = (topLeft[0] + (c shl 3), topLeft[1] + (r shl 3))
      drawTile(self, tileMap[r][c], p)

proc updateTileMapView(self: Ppu) =
  if not self.lcdc.lcdEnable:
    return

  self.tileRend.setRenderTarget(self.tileTxt).errQuit
  self.drawTiles((0, 0))
  self.drawTileMap(self.bgTileMap, (0, 49))
  self.drawTileMap(self.winTileMap, (0, 306))
  self.tileRend.setRenderTarget(nil).errQuit
  self.tileRend.renderCopy(self.tileTxt, nil, nil).errQuit
  self.tileRend.renderPresent()

func lcdEnabled(self: Ppu): bool {.inline.} = self.lcdc.lcdEnable

proc updateLcdView(self: Ppu) =
  if not self.lcdEnabled:
    self.rend.setRenderDrawColor(ColorPowerOff.r, ColorPowerOff.g,
        ColorPowerOff.b, 0x00).errQuit
    self.rend.renderClear().errQuit
  else:
    self.rend.setRenderDrawColor(ColorWhite.r, ColorWhite.g, ColorWhite.b, 0x00).errQuit
    self.rend.renderClear().errQuit

  self.rend.renderPresent()

proc process*(self: Ppu; cpu: Sm83; ticks: Tick) =
  if VRamDirty in self.flags:
    self.updateTileMapView()
    self.flags.excl VRamDirty

  #if Dirty in self.flags:
  #  self.updateLcdView()
  #  self.flags.excl Dirty

  self.ticks += ticks
  case self.stat.mode
  of lmHBlank:
    if self.ticks >= 207:
      self.ticks -= 207
      self.ly.inc
      self.stat.concidence = self.ly == self.lyc
      self.stat.mode =
        if self.ly == 144:
          cpu.setInterrupt(VBlank)
          lmVBlank
        else:
          lmReadOam
  of lmVBlank:
    if self.ticks >= 456:
      self.ticks -= 456
      self.ly.inc
      if self.ly >= 153:
        self.stat.mode = lmReadOam
        cpu.clearInterrupt(VBlank)
  of lmReadOam:
    if self.ticks >= 83:
      self.stat.mode = lmTrans
      self.ticks -= 83
  of lmTrans:
    if self.ticks >= 229:
      self.stat.mode = lmHBlank
      self.ticks -= 229
