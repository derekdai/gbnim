type
  Address* = uint16
  InterruptFlag* = enum
    VBlank
    LcdStat
    Timer
    Serial
    Joypad
  InterruptFlags* = set[InterruptFlag]
