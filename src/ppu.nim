import std/[logging, strformat]
import cpu, memory, io, types, utils, setsugar
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

func r(self: Rect): int {.inline.} = self.x + self.w
func b(self: Rect): int {.inline.} = self.y + self.h

const
  SepWidth = 8
  SepHeight = 8
  DispRes = Rect(x: 0, y: 0, w: 160, h: 144)
  MainView = Rect(x: 0, y: 0, w: DispRes.w * 4, h: DispRes.h * 4)
  TilesView = Rect(x: MainView.r + SepWidth, y: 0, w: 256, h: 48)
  BgTileMapView = Rect(x: TilesView.x, y: TilesView.b + SepHeight, w: TilesView.w, h: 256)
  WinTileMapView = Rect(x: TilesView.x, y: BgTileMapView.b + SepHeight, w: TilesView.w, h: BgTileMapView.h)
  WinDimn = (w: WinTileMapView.r, h: max(MainView.b, WinTileMapView.b))

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

type
  LcdMode = enum
    lmHBlank
    lmVBlank
    lmReadOam
    lmTrans
  LcdcStatus = object
    mode {.bitsize: 2.}: LcdMode
    concidence {.bitsize: 1.}: bool
    hblankIntr {.bitsize: 1.}: bool
    vblankIntr {.bitsize: 1.}: bool
    oamIntr {.bitsize: 1.}: bool
    coincidenceIntr {.bitsize: 1.}: bool
  PpuFlag = enum
    Refresh
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
    scx, scy: byte
    wx, wy: byte
    bgp, obp0, obp1: BgPalette
    lcdc: Lcdc
    ly, lyc: byte
    stat: LcdcStatus
    vram: array[VRAM.len, byte]
    oam: array[OAM.len, byte]
    win: sdl.Window
    rend: sdl.Renderer
    main: sdl.Texture
    tiles: sdl.Texture
    bgMap: sdl.Texture
    winMap: sdl.Texture

proc `=destroy`(self: var typeof(Ppu()[])) =
  if self.bgMap != nil:
    self.bgMap.destroyTexture()

  if self.winMap != nil:
    self.winMap.destroyTexture()

  if self.tiles != nil:
    self.tiles.destroyTexture()

  if self.main != nil:
    self.main.destroyTexture()

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

proc loadBgp(self: Ppu): byte = cast[byte](self.bgp)
proc storeBgp(self: Ppu; s: byte) =
  self.bgp = cast[BgPalette](s)
  info &"BGP: {self.bgp}"

proc loadObp0(self: Ppu): byte = cast[byte](self.obp0)
proc storeObp0(self: Ppu; s: byte) =
  self.obp0 = cast[BgPalette](s)
  info &"OBP0: {self.bgp}"

proc loadObp1(self: Ppu): byte = cast[byte](self.obp1)
proc storeObp1(self: Ppu; s: byte) =
  self.obp1 = cast[BgPalette](s)
  info &"OBP1: {self.bgp}"

proc loadScy(self: Ppu): byte = self.scy
proc storeScy(self: Ppu; s: byte) =
  self.scy = s
  self.flags += Refresh
  info &"SCY: {self.scy}"

proc loadScx(self: Ppu): byte = self.scx
proc storeScx(self: Ppu; s: byte) =
  self.scx = s
  self.flags += Refresh
  info &"SCX: {self.scx}"

proc loadWy(self: Ppu): byte = self.wy
proc storeWy(self: Ppu; s: byte) =
  self.wy = s
  self.flags += Refresh
  info &"WY: {self.wy}"

proc loadWx(self: Ppu): byte = self.wx
proc storeWx(self: Ppu; s: byte) =
  self.wx = s
  self.flags += Refresh
  info &"WX: {self.wx}"

func lcdEnabled(self: Ppu): bool {.inline.} = self.lcdc.lcdEnable

proc lcdEnable(self: Ppu; cpu: Sm83) =
  self.ly = 0
  self.stat.mode = lmReadOam
  self.rend.setRenderTarget(self.main).errQuit
  self.rend.setRenderDrawColor(ColorWhite.r, ColorWhite.g, ColorWhite.b, ColorWhite.a).errQuit
  self.rend.renderFillRect(unsafeAddr DispRes).errQuit
  cpu -= ikVBlank
  cpu -= ikLcdStat
  info "LCD enabled"

proc lcdDisable(self: Ppu; cpu: Sm83) =
  self.rend.setRenderTarget(self.main).errQuit
  self.rend.setRenderDrawColor(ColorPowerOff.r, ColorPowerOff.g, ColorPowerOff.b, ColorPowerOff.a).errQuit
  self.rend.renderFillRect(unsafeAddr DispRes).errQuit
  cpu += ikVBlank
  cpu += ikLcdStat
  info "LCD disabled"

converter toByte(v: Lcdc): byte {.inline.} = cast[byte](v)
proc loadLcdc(self: Ppu): byte = self.lcdc
proc storeLcdc(self: Ppu; cpu: Sm83; s: byte) =
  if s == self.lcdc:
    return

  if not self.lcdc.lcdEnable and cast[Lcdc](s).lcdEnable:
    self.lcdEnable(cpu)
  elif self.lcdc.lcdEnable and not cast[Lcdc](s).lcdEnable:
    self.lcdDisable(cpu)

  self.flags += Refresh
  self.lcdc = cast[Lcdc](s)
  info &"LCDC: {self.lcdc}"

proc loadStat(self: Ppu): byte = cast[byte](self.stat)
proc storeStat(self: Ppu; s: byte) =
  self.stat = cast[LcdcStatus](s)
  info &"STAT: {self.stat}"

proc loadLy(self: Ppu): byte =
  debug &"LY: {self.ly}"
  self.ly
proc storeLy(self: Ppu; s: byte) = discard

proc loadLyc(self: Ppu): byte =
  info &"LYC: {self.ly}"
  self.lyc
proc storeLyc(self: Ppu; s: byte) =
  self.lyc = s
  info &"LYC: {self.lyc}"

type
  VideoRam = ref object of Memory
    ppu {.cursor.}: Ppu

proc newVideoRam(ppu: Ppu): VideoRam =
  result = VideoRam(ppu: ppu)
  Memory.init(result, VRAM)

proc assertAccess(self: VideoRam) =
  if self.ppu.lcdEnabled and self.ppu.stat.mode in {lmTrans}:
    info &"VRAM access in LCD mode {self.ppu.stat.mode.ord}"

method load(self: VideoRam; a: Address): byte {.locks: "unknown".} =
  self.assertAccess()
  self.ppu.vram[a - self.region.a]

method store(self: VideoRam; a: Address; value: byte) {.locks: "unknown".} =
  self.assertAccess()
  self.ppu.vram[a - self.region.a] = value
  self.ppu.flags.incl VRamDirty

type
  ObjAttrTable = ref object of Memory
    ppu {.cursor.}: Ppu

proc newObjAttrTable(ppu: Ppu): ObjAttrTable =
  result = ObjAttrTable(ppu: ppu)
  Memory.init(result, OAM)

proc assertAccess(self: ObjAttrTable) =
  if self.ppu.lcdEnabled and self.ppu.stat.mode notin {lmHBlank, lmVBlank}:
    info &"OAM access in LCD mode {self.ppu.stat.mode.ord}"

method load*(self: ObjAttrTable; a: Address): byte {.locks: "unknown".} =
  self.assertAccess()
  self.ppu.oam[a - OAM.a]

method store*(self: ObjAttrTable; a: Address; value: byte) {.locks: "unknown".} =
  self.assertAccess()
  self.ppu.oam[a - OAM.a] = value

proc newPpu*(cpu: Sm83; mctrl: MemoryCtrl; iom: IoMemory): Ppu =
  var ppu = Ppu(flags: {Refresh, VRamDirty})

  iom.setHandler IoBgp,
    proc(cpu: Sm83; a: Address): byte = loadBgp(ppu),
    proc(cpu: Sm83; a: Address; s: byte) = storeBgp(ppu, s)

  iom.setHandler IoObp0,
    proc(cpu: Sm83; a: Address): byte = loadObp0(ppu),
    proc(cpu: Sm83; a: Address; s: byte) = storeObp0(ppu, s)

  iom.setHandler IoObp1,
    proc(cpu: Sm83; a: Address): byte = loadObp1(ppu),
    proc(cpu: Sm83; a: Address; s: byte) = storeObp1(ppu, s)

  iom.setHandler IoLcdc,
    proc(cpu: Sm83; a: Address): byte = loadLcdc(ppu),
    proc(cpu: Sm83; a: Address; s: byte) = storeLcdc(ppu, cpu, s)

  iom.setHandler IoStat,
    proc(cpu: Sm83; a: Address): byte = loadStat(ppu),
    proc(cpu: Sm83; a: Address; s: byte) = storeStat(ppu, s)

  iom.setHandler IoScy,
    proc(cpu: Sm83; a: Address): byte = loadScy(ppu),
    proc(cpu: Sm83; a: Address; s: byte) = storeScy(ppu, s)

  iom.setHandler IoScx,
    proc(cpu: Sm83; a: Address): byte = loadScx(ppu),
    proc(cpu: Sm83; a: Address; s: byte) = storeScx(ppu, s)

  iom.setHandler IoWy,
    proc(cpu: Sm83; a: Address): byte = loadWy(ppu),
    proc(cpu: Sm83; a: Address; s: byte) = storeWy(ppu, s)

  iom.setHandler IoWx,
    proc(cpu: Sm83; a: Address): byte = loadWx(ppu),
    proc(cpu: Sm83; a: Address; s: byte) = storeWx(ppu, s)

  iom.setHandler IoLy,
    proc(cpu: Sm83; a: Address): byte = loadLy(ppu),
    proc(cpu: Sm83; a: Address; s: byte) = storeLy(ppu, s)

  iom.setHandler IoLyc,
    proc(cpu: Sm83; a: Address): byte = loadLyc(ppu),
    proc(cpu: Sm83; a: Address; s: byte) = storeLyc(ppu, s)

  let vram = newVideoRam(ppu)
  mctrl.map(vram)

  let oam = newObjAttrTable(ppu)
  mctrl.map(oam)

  ppu.win = createWindow(
    "gdnim",
    sdl.WindowPosCentered,
    sdl.WindowPosCentered,
    WinDimn.w,
    WinDimn.h,
    0).errQuit
  ppu.rend = ppu.win.createRenderer(
    -1,
    sdl.RendererAccelerated or sdl.RendererPresentVsync).errQuit
  ppu.main = ppu.rend.createTexture(
    PIXELFORMAT_RGBA8888,
    TEXTUREACCESS_TARGET,
    DispRes.w,
    DispRes.h).errQuit
  ppu.tiles = ppu.rend.createTexture(
    PIXELFORMAT_RGBA8888,
    TEXTUREACCESS_TARGET,
    TilesView.w,
    TilesView.h).errQuit
  ppu.bgMap = ppu.rend.createTexture(
    PIXELFORMAT_RGBA8888,
    TEXTUREACCESS_TARGET,
    BgTileMapView.w,
    BgTileMapView.h).errQuit
  ppu.winMap = ppu.rend.createTexture(
    PIXELFORMAT_RGBA8888,
    TEXTUREACCESS_TARGET,
    WinTileMapView.w,
    WinTileMapView.h).errQuit

  ppu.lcdDisable(cpu)

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
      self.rend.setRenderDrawColor(c.r, c.g, c.b, c.a).errQuit
      self.rend.renderDrawPoint(topLeft.x + x, topLeft.y + y).errQuit

proc drawTiles(self: Ppu) =
  for i in 0..<Tiles.len:
    let r = i shr 5         # i / 32
    let c = i and 0b11111   # i mod 32
    let p = (c shl 3, r shl 3)
    self.drawTile(byte(i), p)

proc drawTileMap(self: Ppu; tileMap: TileMap) =
  for r in 0..<TileMap.rows:
    for c in 0..<TileMap.cols:
      let p = (c shl 3, r shl 3)
      self.drawTile(tileMap[r][c], p)

proc updateTileMapView(self: Ppu) =
  self.rend.setRenderTarget(self.tiles).errQuit
  self.drawTiles()
  self.rend.setRenderTarget(self.bgMap).errQuit
  self.drawTileMap(self.bgTileMap)
  self.rend.setRenderTarget(self.winMap).errQuit
  self.drawTileMap(self.winTileMap)

proc updateMainView(self: Ppu) =
  if not self.lcdEnabled:
    return

  self.rend.setRenderTarget(self.main).errQuit
  let srcRect = Rect(x: self.scx.int32, y: self.scy.int32, w: 256, h: 256)
  let destRect = Rect(x: 0, y: 0, w: 256, h: 256)
  self.rend.renderCopy(self.bgMap, unsafeAddr srcRect, unsafeAddr destRect).errQuit

proc stepLy(self: Ppu; cpu: Sm83) =
  self.ly.inc
  self.stat.concidence = self.ly == self.lyc
  if self.ly < 144:
    self.stat.mode = lmReadOam
  elif self.ly == 144:
    self.stat.mode = lmVBlank
    cpu += ikVBlank
  elif self.ly >= 153:
    self.ly = 0
    self.stat.mode = lmReadOam
    cpu -= ikVBlank

proc processHBlankMode(self: Ppu; cpu: Sm83) =
  if self.ticks < 204:
    return
  self.ticks -= 204 
  self.stepLy(cpu)

proc processVBlankMode(self: Ppu; cpu: Sm83) =
  if self.ticks < 456:
    return
  self.ticks -= 456 
  self.stepLy(cpu)

proc processReadOamMode(self: Ppu) =
  if self.ticks < 83:
    return
  self.ticks -= 83
  self.stat.mode = lmTrans

proc processTransMode(self: Ppu) =
  if self.ticks < 169:
    return
  self.ticks -= 169 
  self.stat.mode = lmHBlank

proc process*(self: Ppu; cpu: Sm83; ticks: Tick) =
  if self.lcdEnabled:
    self.ticks += ticks

    case self.stat.mode:
    of lmHBlank: self.processHBlankMode(cpu)
    of lmVBlank: self.processVBlankMode(cpu)
    of lmReadOam: self.processReadOamMode()
    of lmTrans: self.processTransMode()

  if self.flags{Refresh}:
    self.updateTileMapView()
    self.updateMainView()

    self.rend.setRenderTarget(nil).errQuit
    self.rend.renderCopy(self.main, nil, unsafeAddr MainView).errQuit
    self.rend.renderCopy(self.tiles, nil, unsafeAddr TilesView).errQuit
    self.rend.renderCopy(self.bgMap, nil, unsafeAddr BgTileMapView).errQuit
    self.rend.renderCopy(self.winMap, nil, unsafeAddr WinTileMapView).errQuit
    self.rend.renderPresent()

    self.flags -= Refresh

  #case self.stat.mode
  #of lmHBlank:
  #  if self.ticks >= 207:
  #    self.ticks -= 207
  #    self.ly.inc
  #    self.stat.concidence = self.ly == self.lyc
  #    statIntr = statIntr or (self.stat.concidence and self.stat.coincidenceIntr)
  #    self.stat.mode =
  #      if self.ly == 144:
  #        cpu.setInterrupt(VBlank)
  #        statIntr = statIntr or self.stat.vblankIntr

  #        self.updateTileMapView()
  #        self.updateMainView()

  #        self.rend.setRenderTarget(nil).errQuit
  #        self.rend.renderCopy(self.main, nil, unsafeAddr MainView).errQuit
  #        self.rend.renderCopy(self.tiles, nil, unsafeAddr TilesView).errQuit
  #        self.rend.renderCopy(self.bgMap, nil, unsafeAddr BgTileMapView).errQuit
  #        self.rend.renderCopy(self.winMap, nil, unsafeAddr WinTileMapView).errQuit
  #        self.rend.renderPresent()

  #        lmVBlank
  #      else:
  #        statIntr = statIntr or self.stat.oamIntr
  #        lmReadOam
  #of lmVBlank:
  #  if self.ticks >= 456:
  #    self.ticks -= 456
  #    self.ly.inc
  #    if self.ly >= 153:
  #      self.stat.mode = lmReadOam
  #      statIntr = statIntr or self.stat.oamIntr
  #      cpu.clearInterrupt(VBlank)
  #of lmReadOam:
  #  if self.ticks >= 83:
  #    self.stat.mode = lmTrans
  #    self.ticks -= 83
  #of lmTrans:
  #  if self.ticks >= 229:
  #    self.stat.mode = lmHBlank
  #    statIntr = statIntr or self.stat.hblankIntr
  #    self.ticks -= 229

  #if statIntr:
  #  cpu.setInterrupt(LcdStat)
  #else:
  #  cpu.clearInterrupt(LcdStat)
