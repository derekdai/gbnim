import memory, utils, types
import std/[logging, strformat]

const
  NintendoLogo* = [
    0xceu8, 0xed, 0x66, 0x66, 0xcc, 0x0d, 0x00, 0x0b, 0x03, 0x73, 0x00, 0x83, 0x00, 0x0c, 0x00, 0x0d,
    0x00,   0x08, 0x11, 0x1f, 0x88, 0x89, 0x00, 0x0e, 0xdc, 0xcc, 0x6e, 0xe6, 0xdd, 0xdd, 0xd9, 0x99,
    0xbb,   0xbb, 0x67, 0x63, 0x6e, 0x0e, 0xec, 0xcc, 0xdd, 0xdc, 0x99, 0x9f, 0xbb, 0xb9, 0x33, 0x3e,
  ]
  RomBankSize* = 16 * Kilo
  RamBankSize* = 8 * Kilo

type
  CgbFlag* = distinct byte
  SgbFlag* = distinct byte
  MbcId* = distinct byte
  MbcFeature* = enum
    Rom
    Mbc1
    Mbc2
    Mbc3
    Mbc5
    Mbc6
    Mbc7
    Ram
    Battery
    Mmm01
    Timer
    Rumble
    Sensor
    PocketCamera
    BandaiTama5
    HuC1
    HuC3
  MbcFeatures* = set[MbcFeature]
  RomSize* = distinct byte
  RamSize* = distinct byte
  Destination* = distinct byte
  Licensee* = distinct uint16
  OldLicensee* = distinct byte
  Title* = distinct array[0x13e-0x134+1, char]
  Header* {.packed.}= object
    entryPoint*: array[0x0103-0x0100+1, byte]
    logo*: array[0x133-0x104+1, byte]
    title*: Title
    manufacture: array[0x142-0x013f+1, char]
    cgbFlag*: CgbFlag
    licensee*: Licensee
    sgbFlag*: SgbFlag
    mbc*: MbcId
    romSize*: RomSize
    ramSize*: RamSize
    destination*: Destination
    oldLicensee*: OldLIcensee
    maskRomVer*: byte
    checksum*: byte
    globalChecksum*: uint16

const
  CgbBackCompatible* = CgbFlag(0x80)
  CgbOnly* = CgbFlag(0xc0)
  SgbDisabled* = SgbFlag(0x80)
  SgbEnabled* = SgbFlag(0xc0)

func validateLogo*(self: Header): bool =
  self.logo == NintendoLogo

func validateChecksum*(self: Header): bool =
  var sum = 0u8
  let bytes = cast[ptr UncheckedArray[byte]](unsafeAddr self.title)
  for i in 0..(0x14c-0x134):
    sum = (sum - bytes[i] - 1) and 0xff
  sum == self.checksum

func `$`*(v: CgbFlag): string =
  case v
  of CgbBackCompatible: "CGB Back Comp"
  of CgbOnly: "CGB Only"
  else: &"0x{v.ord:02x}(Bad Flag)"

func `$`*(v: SgbFlag): string =
  case v
  of SgbDisabled: "No SGB Functions"
  of SgbEnabled: "Use SGB Functions"
  else: &"0x{v.ord:02x}(Bad Flag)"

converter bytes*(rs: RomSize): int =
  case byte(rs)
  of 0x00..0x08:
    return (RomBankSize * 2) shl byte(rs);
  of 0x52:
    return RomBankSize * 72;
  of 0x53:
    return RomBankSize * 80;
  of 0x54:
    return RomBankSize * 96;
  else:
    return 0

func `$`*(rs: RomSize): string = &"0x{byte(rs):02x}({rs.bytes div RomBankSize} Banks, {rs.bytes div Kilo}K bytes)"

converter bytes*(rs: RamSize): int =
  case byte(rs)
  of 0x2:
    return RamBankSize * 1;
  of 0x3:
    return RamBankSize * 4;
  of 0x4:
    return RamBankSize * 16;
  of 0x5:
    return RamBankSize * 8;
  else:
    return 0

func `$`*(rs: RamSize): string = &"0x{byte(rs):02x}({rs.bytes div RamBankSize} Banks, {rs.bytes div Kilo}K bytes)"

func `$`*(d: Destination): string =
  case byte(d)
  of 0: "Japanese"
  of 1: "Non-Japanese"
  else: &"Bad Desination (0x{byte(d):02x})"

func `$`*(t: Title): string =
  for c in array[sizeof(Title), char](t):
    if c < ' ': break
    result.add c

func features*(m: MbcId): MbcFeatures =
  case byte(m)
  of 0x00: {Rom}
  of 0x01: {Mbc1}
  of 0x02: {Mbc1, Ram}
  of 0x03: {Mbc1, Ram, Battery}
  of 0x05: {Mbc2}
  of 0x06: {Mbc2, Battery}
  of 0x08: {Rom, Ram}
  of 0x09: {Rom, Ram, Battery}
  of 0x0b: {Mmm01}
  of 0x0c: {Mmm01, Ram}
  of 0x0d: {Mmm01, Ram, Battery}
  of 0x0f: {Mbc3, Timer, Battery}
  of 0x10: {Mbc3, Timer, Ram, Battery}
  of 0x11: {Mbc3}
  of 0x12: {Mbc3, Ram}
  of 0x13: {Mbc3, Ram, Battery}
  of 0x19: {Mbc5}
  of 0x1a: {Mbc5, Ram}
  of 0x1b: {Mbc5, Ram, Battery}
  of 0x1c: {Mbc5, Rumble}
  of 0x1d: {Mbc5, Rumble, Ram}
  of 0x1e: {Mbc5, Rumble, Ram, Battery}
  of 0x20: {Mbc6}
  of 0x22: {Mbc7, Sensor, Rumble, Ram, Battery}
  of 0xfc: {PocketCamera}
  of 0xfd: {BandaiTama5}
  of 0xfe: {HuC3}
  of 0xff: {HuC1, Ram, Battery}
  else: {}

func `$`*(m: MbcId): string = &"0x{byte(m):02x}{m.features}"

func `$`*(l: Licensee): string =
  case ((uint16(l) shr 4) and 0xf0) and (uint16(l) and 0xf)
  of 0x00: "None"
  of 0x01: "Nintendo R&D1"
  of 0x08: "Capcom"
  of 0x13: "Electronic Arts"
  of 0x18: "Hudson Soft"
  of 0x19: "b-ai"
  of 0x20: "kss"
  of 0x22: "pow"
  of 0x24: "PCM Complete"
  of 0x25: "san-x"
  of 0x28: "Kemco Japan"
  of 0x29: "seta"
  of 0x30: "Viacom"
  of 0x31: "Nintendo"
  of 0x32: "Bandai"
  of 0x33: "Ocean/Acclaim"
  of 0x34: "Konami"
  of 0x35: "Hector"
  of 0x37: "Taito"
  of 0x38: "Hudson"
  of 0x39: "Banpresto"
  of 0x41: "Ubi Soft"
  of 0x42: "Atlus"
  of 0x44: "Malibu"
  of 0x46: "angel"
  of 0x47: "Bullet-Proof"
  of 0x49: "irem"
  of 0x50: "Absolute"
  of 0x51: "Acclaim"
  of 0x52: "Activision"
  of 0x53: "American sammy"
  of 0x54: "Konami"
  of 0x55: "Hi tech entertainment"
  of 0x56: "LJN"
  of 0x57: "Matchbox"
  of 0x58: "Mattel"
  of 0x59: "Milton Bradley"
  of 0x60: "Titus"
  of 0x61: "Virgin"
  of 0x64: "LucasArts"
  of 0x67: "Ocean"
  of 0x69: "Electronic Arts"
  of 0x70: "Infogrames"
  of 0x71: "Interplay"
  of 0x72: "Broderbund"
  of 0x73: "sculptured"
  of 0x75: "sci"
  of 0x78: "THQ"
  of 0x79: "Accolade"
  of 0x80: "misawa"
  of 0x83: "lozc"
  of 0x86: "Tokuma Shoten Intermedia"
  of 0x87: "Tsukuda Original"
  of 0x91: "Chunsoft"
  of 0x92: "Video system"
  of 0x93: "Ocean/Acclaim"
  of 0x95: "Varie"
  of 0x96: "Yonezawa/s’pal"
  of 0x97: "Kaneko"
  of 0x99: "Pack in soft"
  of 0xA4: "Konami (Yu-Gi-Oh!)"
  else: "0x{uint16(l):04x}(unknown)"

func `$`*(o: OldLicensee): string =
  case byte(o)
  of 0x00: "none"
  of 0x01: "nintendo"
  of 0x08: "capcom"
  of 0x09: "hot-b"
  of 0x0a: "jaleco"
  of 0x0b: "coconuts"
  of 0x0c: "elite systems"
  of 0x13: "electronic arts"
  of 0x18: "hudsonsoft"
  of 0x19: "itc entertainment"
  of 0x1a: "yanoman"
  of 0x1d: "clary"
  of 0x1f: "virgin"
  of 0x24: "pcm complete"
  of 0x25: "san-x"
  of 0x28: "kotobuki systems"
  of 0x29: "seta"
  of 0x30: "infogrames"
  of 0x31: "nintendo"
  of 0x32: "bandai"
  of 0x33: "Unused"
  of 0x34: "konami"
  of 0x35: "hector"
  of 0x38: "capcom"
  of 0x39: "banpresto"
  of 0x3c: "*entertainment i"
  of 0x3e: "gremlin"
  of 0x41: "ubi soft"
  of 0x42: "atlus"
  of 0x44: "malibu"
  of 0x46: "angel"
  of 0x47: "spectrum holoby"
  of 0x49: "irem"
  of 0x4a: "virgin"
  of 0x4d: "malibu"
  of 0x4f: "u.s. gold"
  of 0x50: "absolute"
  of 0x51: "acclaim"
  of 0x52: "activision"
  of 0x53: "american sammy"
  of 0x54: "gametek"
  of 0x55: "park place"
  of 0x56: "ljn"
  of 0x57: "matchbox"
  of 0x59: "milton bradley"
  of 0x5a: "mindscape"
  of 0x5b: "romstar"
  of 0x5c: "naxat soft"
  of 0x5d: "tradewest"
  of 0x60: "titus"
  of 0x61: "virgin"
  of 0x67: "ocean"
  of 0x69: "electronic arts"
  of 0x6e: "elite systems"
  of 0x6f: "electro brain"
  of 0x70: "infogrames"
  of 0x71: "interplay"
  of 0x72: "broderbund"
  of 0x73: "sculptered soft"
  of 0x75: "the sales curve"
  of 0x78: "t*hq"
  of 0x79: "accolade"
  of 0x7a: "triffix entertainment"
  of 0x7c: "microprose"
  of 0x7f: "kemco"
  of 0x80: "misawa entertainment"
  of 0x83: "lozc"
  of 0x86: "*tokuma shoten i"
  of 0x8b: "bullet-proof software"
  of 0x8c: "vic tokai"
  of 0x8e: "ape"
  of 0x8f: "i'max"
  of 0x91: "chun soft"
  of 0x92: "video system"
  of 0x93: "tsuburava"
  of 0x95: "varie"
  of 0x96: "yonezawa/s'pal"
  of 0x97: "kaneko"
  of 0x99: "arc"
  of 0x9a: "nihon bussan"
  of 0x9b: "tecmo"
  of 0x9c: "imagineer"
  of 0x9d: "banpresto"
  of 0x9f: "nova"
  of 0xa1: "hori electric"
  of 0xa2: "bandai"
  of 0xa4: "konami"
  of 0xa6: "kawada"
  of 0xa7: "takara"
  of 0xa9: "technos japan"
  of 0xaa: "broderbund"
  of 0xac: "toei animation"
  of 0xad: "toho"
  of 0xaf: "namco"
  of 0xb0: "acclaim"
  of 0xb1: "ascii or nexoft"
  of 0xb2: "bandai"
  of 0xb4: "enix"
  of 0xb6: "hal"
  of 0xb7: "snk"
  of 0xb9: "pony canyon"
  of 0xba: "*culture brain o"
  of 0xbb: "sunsoft"
  of 0xbd: "sony imagesoft"
  of 0xbf: "sammy"
  of 0xc0: "taito"
  of 0xc2: "kemco"
  of 0xc3: "squaresoft"
  of 0xc4: "*tokuma shoten i"
  of 0xc5: "data east"
  of 0xc6: "tonkin house"
  of 0xc8: "koei"
  of 0xc9: "ufl"
  of 0xca: "ultra"
  of 0xcb: "vap"
  of 0xcc: "use"
  of 0xcd: "meldac"
  of 0xce: "*pony canyon or"
  of 0xcf: "angel"
  of 0xd0: "taito"
  of 0xd1: "sofel"
  of 0xd2: "quest"
  of 0xd3: "sigma enterprises"
  of 0xd4: "ask kodansha"
  of 0xd6: "naxat soft"
  of 0xd7: "copya systems"
  of 0xd9: "banpresto"
  of 0xda: "tomy"
  of 0xdb: "ljn"
  of 0xdd: "ncs"
  of 0xde: "human"
  of 0xdf: "altron"
  of 0xe0: "jaleco"
  of 0xe1: "towachiki"
  of 0xe2: "uutaka"
  of 0xe3: "varie"
  of 0xe5: "epoch"
  of 0xe7: "athena"
  of 0xe8: "asmik"
  of 0xe9: "natsume"
  of 0xea: "king records"
  of 0xeb: "atlus"
  of 0xec: "epic/sony records"
  of 0xee: "igs"
  of 0xf0: "a wave"
  of 0xf3: "extreme entertainment"
  of 0xff: "ljn"
  else: &"0x{uint8(o):02x}"

type
  Bytes* = ptr UncheckedArray[byte]
  RomBank = ref object of Memory
    data: Bytes

proc newRomBank(region: MemoryRegion; data: Bytes): RomBank =
  result = RomBank()
  Memory.init(result, region)
  result.data = data

func switch*(self: RomBank; data: Bytes) =
  self.data = data

method load*(self: RomBank; a: Address; dest: pointer; length: uint16) {.locks: "unknown".} =
  copyMem(dest, unsafeAddr self.data[a - self.region.a], length)

method store*(self: var RomBank; a: Address; src: pointer; length: uint16) {.locks: "unknown".} =
  warn &"unhandled store to ROM: 0x{a:04x}"

type
  Cartridge* = ref object
    data: seq[byte]

func header*(self: Cartridge): lent Header {.inline.} = 
  cast[ptr Header](unsafeAddr self.data[0x100])[]

func validateChecksum*(self: Cartridge): bool =
  var sum = 0u16
  for i in 0..<0x14e:
    sum = (sum + self.data[i]) and 0xffff

  for i in 0x150..<self.data.len:
    sum = (sum + self.data[i]) and 0xffff

  sum == self.header.globalChecksum

proc newCartridge*(path: string): Cartridge =
  result = Cartridge(data: loadFile(path))
  echo &"Loading ROM: {path}"
  echo &"  Size: {result.data.len} bytes"
  echo &"  Logo is valid: {result.header.validateLogo}"
  echo &"  Header is valid: {result.header.validateChecksum}"
  echo &"  Header: {result.header}"

func numRomBanks*(self: Cartridge): int = self.header.romSize div RomBankSize

func numRamBanks*(self: Cartridge): int = self.header.ramSize div RamBankSize

proc mount*(self: Cartridge; mctrl: MemoryCtrl) =
  let rom0 = newRomBank(ROM0, cast[ptr UncheckedArray[byte]](unsafeAddr self.data[ROM0.a]))
  mctrl.map(rom0) 

  if self.data.len >= ROMX.a.int:
    let romx = newRomBank(ROMX, cast[ptr UncheckedArray[byte]](unsafeAddr self.data[ROMX.a]))
    mctrl.map(romx) 

  if self.header.mbc.features == {Mbc1}:
    ## `cpu_instrs.gb` 會直接寫入這區, 未先進行 enable 的動作
    mctrl.map(newRam(SRAM))

proc unmount*(self: Cartridge; mctrl: MemoryCtrl) =
  if self.data.len >= ROMX.a.int:
    mctrl.unmap(ROMX) 
  mctrl.unmap(ROM0) 

