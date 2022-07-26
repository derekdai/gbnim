import std/[strformat, strutils]
import gbasm
import cpu
import memory

proc newCpu(opcodes: seq[byte]): Sm83 =
  result = newSm83()
  result.memCtrl = newMemoryCtrl()
  let bootrom = newRom(BootRom, opcodes)
  result.memCtrl.map(bootrom)
  let wram = newRam(WRAM0)
  result.memCtrl.map(wram)
  let io = newRam(IOREGS)
  result.memCtrl.map(io)

proc step(self: Sm83; n: int) =
  for i in 0..<n:
    self.step()

proc dump[T: SomeInteger](self: openArray[T]): string =
  result = "["
  for v in self:
    result.add &"0x{v:x}, "
  if result.endsWith(", "):
    result.setLen(result.len - 2)
  result.add "]"

block:
  let cpu = newSm83()
  assert cpu.ticks == 0
  assert cpu.ime == false

block:
  let ops = gbasm:
    LD HL,0xc000                # 1
    LD (HL),0x1b                # 2
    LD (+HL),A                  # 3
    LD (-HL),A                  # 4
    LD BC,0xc100                # 5
    LD (BC),A
    LD C,0x1b                   # 6
    LD D,(HL)                   # 7
    LD H,B                      # 8
    LD A,0xdd                   # 9
    LD (0xff00),A
    XOR A,A                     # 10
    LD A,(0xff00)
    LD C,0x7f                   # 11
    LD (0xff00+C),A
    XOR A,A                     # 12
    LD A,(0xff00+C)
    LD SP,0x5678                # 13
    LD (0xc050),SP
    LD HL,SP+0x1                # 14
    LD SP,HL                    # 15
    LD A,0xfe                   # 16
    LD (0xc123),A
    XOR A,A
    LD A,(0xc123)
    LD HL,0xc321                # 17
    LD E,0x7c
    LD (HL),E
    LD E,0
    LD E,(HL)
  let cpu = newCpu(ops)
  cpu.step                      # 1
  assert cpu.r(HL) == 0xc000
  assert cpu.f == {}
  cpu.step                      # 2
  assert cpu.r(HL) == 0xc000
  assert cpu[0xc000] == 0x1b
  cpu.step                      # 3
  assert cpu.r(HL) == 0xc001
  assert cpu[0xc000] == 0
  assert cpu.f == {}
  cpu.r(A) = 0xcc
  cpu.step                      # 4
  assert cpu.r(HL) == 0xc000
  assert cpu[0xc001] == 0xcc
  cpu.step 2                    # 5
  assert cpu.r(BC) == 0xc100
  assert cpu[0xc100] == 0xcc
  cpu.step                      # 6
  assert cpu.r(C) == 0x1b
  cpu.step                      # 7
  assert cpu.r(D) == 0
  cpu.step                      # 8
  assert cpu.r(H) == cpu.r(B)
  cpu.step 2                    # 9
  assert cpu.r(A) == 0xdd
  assert cpu[0xff00] == cpu.r(A)
  cpu.step                      # 10
  assert cpu.r(A) == 0
  cpu.step
  assert cpu.r(A) == 0xdd
  assert cpu.r(A) == cpu[0xff00]
  cpu.step                      # 11
  assert cpu[0xff7f] == 0
  assert cpu.r(C) == 0x7f
  cpu.step
  assert cpu[0xff7f] == 0xdd
  cpu.step                      # 12
  assert cpu.r(A) == 0
  cpu.step
  assert cpu.r(A) == 0xdd
  cpu.step                      # 13
  assert cpu.r(SP) == 0x5678
  cpu.step
  assert cpu[0xc050] == 0x78
  assert cpu[0xc051] == 0x56
  cpu.step                      # 14
  assert cpu.r(HL) == 0x5679
  cpu.step                      # 15
  assert cpu.r(SP) == 0x5679
  cpu.step 4                    # 16
  assert cpu.r(A) == 0xfe
  assert cpu[0xc123] == 0xfe
  cpu.step 5                    # 17
  assert cpu.r(E) == 0x7c
  assert cpu.r(HL) == 0xc321
  assert cpu[0xc321] == 0x7c

block:
  let ops = gbasm:
    NOP
  let cpu = newCpu(ops)
  cpu.step()
  assert cpu.ticks == 4
  assert cpu.pc == 1

block:
  let ops = gbasm:
    NOP
    NOP
  let cpu = newCpu(ops)
  cpu.step()
  cpu.step()
  assert cpu.ticks == 8
  assert cpu.pc == 2

block:
  let ops = gbasm:
    HALT
  let cpu = newCpu(ops)
  cpu.step()
  assert cpu.ticks == 4
  assert cpu.pc == 1
  cpu.step()
  assert cpu.ticks == 4
  assert cpu.pc == 1

block:
  let ops = gbasm:
    STOP
  let cpu = newCpu(ops)
  cpu.step()
  assert cpu.ticks == 4
  assert cpu.pc == 1
  cpu.step()
  assert cpu.ticks == 4
  assert cpu.pc == 1

block:
  let ops = gbasm:
    JR 0
  let cpu = newCpu(ops)
  cpu.step()
  assert cpu.ticks == 12
  assert cpu.pc == 2

block:
  let ops = gbasm:
    JR -2
  let cpu = newCpu(ops)
  cpu.step()
  assert cpu.ticks == 12
  assert cpu.pc == 0

block:
  let ops = gbasm:
    JR 2 
  let cpu = newCpu(ops)
  cpu.step()
  assert cpu.ticks == 12
  assert cpu.pc == 4

block:
  let ops = gbasm:
    JR NZ, 2 
  let cpu = newCpu(ops)
  cpu.step()
  assert cpu.ticks == 12
  assert cpu.pc == 4

block:
  let ops = gbasm:
    JR NZ, 2 
  let cpu = newCpu(ops)
  cpu.f{Z} = true
  cpu.step()
  assert cpu.ticks == 8
  assert cpu.pc == 2

block:
  let ops = gbasm:
    JR Z, 2 
    JR NZ, 2 
  let cpu = newCpu(ops)
  cpu.step()
  assert cpu.ticks == 8
  assert cpu.pc == 2
  cpu.step()
  assert cpu.ticks == 20
  assert cpu.pc == 6

block:
  let ops = gbasm:
    JR NZ, 2 
    JR Z, 2 
  let cpu = newCpu(ops)
  cpu.f{Z} = true
  cpu.step()
  assert cpu.ticks == 8
  assert cpu.pc == 2
  cpu.step()
  assert cpu.ticks == 20
  assert cpu.pc == 6

block:
  let ops = gbasm:
    JR C, 2 
    JR NC, 2 
  let cpu = newCpu(ops)
  cpu.step()
  assert cpu.ticks == 8
  assert cpu.pc == 2
  cpu.step()
  assert cpu.ticks == 20
  assert cpu.pc == 6

block:
  let ops = gbasm:
    JR NC, 2 
    JR C, 2 
  let cpu = newCpu(ops)
  cpu.f{C} = true
  cpu.step()
  assert cpu.ticks == 8
  assert cpu.pc == 2
  cpu.step()
  assert cpu.ticks == 20
  assert cpu.pc == 6

block:
  let ops = gbasm:
    JP HL
    [50]
    JP 60
    [60]
    JP C, 70
    JP C, 70
    [70]
    JP NC, 80
    JP NC, 80
    [80]
    JP Z, 90
    JP Z, 90
    [90]
    JP NZ, 100
    JP NZ, 100
  let cpu = newCpu(ops)
  cpu.r(HL) = 50
  cpu.step()
  assert cpu.ticks == 4
  assert cpu.pc == 50
  cpu.step()
  assert cpu.ticks == 20
  assert cpu.pc == 60

  cpu.step()
  assert cpu.ticks == 32
  assert cpu.pc == 63
  cpu.f{C} = true
  cpu.step()
  assert cpu.ticks == 48
  assert cpu.pc == 70
  cpu.step()
  assert cpu.ticks == 60
  assert cpu.pc == 73
  cpu.f{C} = false
  cpu.step()
  assert cpu.ticks == 76
  assert cpu.pc == 80

  cpu.step()
  assert cpu.ticks == 88
  assert cpu.pc == 83
  cpu.f{Z} = true
  cpu.step()
  assert cpu.ticks == 104
  assert cpu.pc == 90
  cpu.step()
  assert cpu.ticks == 116
  assert cpu.pc == 93
  cpu.f{Z} = false
  cpu.step()
  assert cpu.ticks == 132
  assert cpu.pc == 100

block:
  let ops = gbasm:
    LD A,0xf
    LD B,1
    ADD A,B
    LD B,0xf0
    ADD A,B
    LD B,0xff
    ADD A,B
    LD L,1
    ADD A,L
  let cpu = newCpu(ops)
  cpu.step()
  assert cpu.r(A) == 0xf
  cpu.step()
  assert cpu.r(B) == 0x1
  cpu.step()
  assert cpu.r(A) == 0x10
  assert cpu.r(B) == 0x1
  assert cpu.f == {Flag.H}
  cpu.step(2)
  assert cpu.r(A) == 0x00
  assert cpu.f == {Flag.C, Z}
  cpu.step(2)
  assert cpu.r(A) == 0xff
  assert cpu.f == {}
  cpu.step(2)
  assert cpu.r(A) == 0
  assert cpu.f == {Flag.C, Flag.H, Z}

block:
  let ops = gbasm:
    ADC A,H             # 1
    ADC A,H             # 2
    XOR A,A             # 3
    LD H,0xf
    ADC A,H
    LD H,0xff           # 4
    ADC A,H
    LD A,0b10101010     # 5
    LD H,0b01010101
    ADC A,H
  let cpu = newCpu(ops)
  cpu.f{H} = true
  cpu.step()                # 1
  assert cpu.r(A) == 0
  assert cpu.f == {Z}
  cpu.f{C} = true
  cpu.step()                # 2
  assert cpu.r(A) == 1
  assert cpu.f == {}
  cpu.step()                # 3
  assert cpu.r(A) == 0
  assert cpu.f == {Z}
  cpu.f{C} = true
  cpu.step(2)
  assert cpu.r(A) == 0x10
  assert cpu.f == {Flag.H}
  cpu.f{C} = true           # 4
  cpu.r(A) = 0
  cpu.step(2)
  assert cpu.r(A) == 0x00
  assert cpu.f == {Flag.C, Flag.H, Z}
  cpu.f{C} = true           # 5
  cpu.step(3)
  assert cpu.r(A) == 0x00
  assert cpu.f == {Flag.C, Flag.H, Z}

block:
  let ops = gbasm:
    INC A                   # 1
    JR NZ,-3
    LD A,0xf                # 2
    INC A
  let cpu = newCpu(ops)
  cpu.step()                # 1
  assert cpu.r(A) == 1
  assert cpu.f == {}
  while true:
    cpu.step()
    if cpu.pc > 2:
      break
    cpu.step()
    if cpu.f{Flag.H}:
      assert (cpu.r(A) and 0xf) == 0
  assert cpu.r(A) == 0
  assert cpu.f == {Flag.H, Z}
  cpu.step 2                # 2
  assert cpu.r(A) == 0x10
  assert cpu.f == {Flag.H}

block:
  let ops = gbasm:
    SUB A,A                 # 1
    LD A,1                  # 2
    LD B,1
    SUB A,B
    SUB A,B                 # 3
    LD A,0x10               # 4
    SUB A,B
    XOR A,A                 # 5
    LD B,0x10
    SUB A,B
  let cpu = newCpu(ops)
  cpu.step                  # 1
  assert cpu.r(A) == 0
  assert cpu.f == {Z, N}
  cpu.step 3                # 2
  assert cpu.r(A) == 0
  assert cpu.f == {Z, N}
  cpu.step                  # 3
  assert cpu.r(A) == 0xff
  assert cpu.f == {Flag.C, Flag.H, N}
  cpu.step 2                # 4
  assert cpu.r(A) == 0xf
  assert cpu.f == {Flag.H, N}
  cpu.step 3                # 5
  assert cpu.r(A) == 0xf0
  assert cpu.f == {Flag.C, N}

block:
  let ops = gbasm:
    SBC A,A                 # 1
    LD L,1                  # 2
    SBC A,L
    LD A,0                  # 3
    SBC A,0
    SBC A,0xf               # 4
  let cpu = newCpu(ops)
  cpu.step                  # 1
  assert cpu.r(A) == 0
  assert cpu.f == {Z, N}
  cpu.step 2                # 2
  assert cpu.r(A) == 0xff
  assert cpu.f == {Flag.C, H, N}
  cpu.step 2                # 3
  assert cpu.r(A) == 0xff
  assert cpu.f == {Flag.C, H, N}
  cpu.step                  # 4
  assert cpu.r(A) == 0xef
  assert cpu.f == {N, H}

block:
  let ops = gbasm:
    DEC A                   # 1
    LD B,0x10               # 2
    DEC B
    LD C,1                  # 3
    DEC C
  let cpu = newCpu(ops)
  cpu.step                  # 1
  assert cpu.r(A) == 0xff
  assert cpu.f == {N, H}
  cpu.step 2                # 2
  assert cpu.r(B) == 0xf
  assert cpu.f == {N, H}
  cpu.step 2                # 3
  assert cpu.r(C) == 0
  assert cpu.f == {N, Z}

block:
  let ops = gbasm:
    AND A,A                 # 1
    LD B,1                  # 2
    AND A,B
    LD A,0b10101010         # 3
    AND A,0b01010101
    LD A,0b11111111         # 4
    AND A,0b01010101

  let cpu = newCpu(ops)
  cpu.step                  # 1
  assert cpu.r(A) == 0
  assert cpu.f == {Z, H}
  cpu.step 2                # 2
  assert cpu.r(A) == 0
  assert cpu.f == {Z, H}
  cpu.step 2                # 3
  assert cpu.r(A) == 0
  assert cpu.f == {Z, H}
  cpu.step 2                # 4
  assert cpu.r(A) == 0b01010101
  assert cpu.f == {Flag.H}

block:
  let ops = gbasm:
    OR A,A                  # 1
    LD B,1                  # 2
    OR A,B
    LD C,0b10101010         # 3
    XOR A,A
    OR A,C
  let cpu = newCpu(ops)
  cpu.step                  # 1
  assert cpu.r(A) == 0
  assert cpu.f == {Z}
  cpu.step 2                # 2
  assert cpu.r(A) == 1
  assert cpu.f == {}
  cpu.step 3                # 3
  assert cpu.r(C) == 0b10101010
  assert cpu.r(A) == cpu.r(C)
  assert cpu.f == {}

block:
  let ops = gbasm:
    XOR A,A                 # 1
    LD C,0b10101010         # 2
    XOR A,C
    XOR A,0b01010101        # 3
    XOR A,0b1111            # 4
  let cpu = newCpu(ops)
  cpu.step                  # 1
  assert cpu.r(A) == 0
  assert cpu.f == {Z}
  cpu.step 2                # 2
  assert cpu.r(C) == 0b10101010
  assert cpu.r(A) == cpu.r(C)
  assert cpu.f == {}
  cpu.step                  # 3
  assert cpu.r(A) == 0b11111111
  assert cpu.f == {}
  cpu.step                  # 4
  assert cpu.r(A) == 0b11110000
  assert cpu.f == {}

block:
  let ops = gbasm:
    RLCA                    # 1
    LD A,0b1000_0001        # 2
    RLCA 
    RLCA                    # 3
    RLA                     # 4
    RLA                     # 5
    RLC L                   # 6
    LD D,0xf                # 7
    RLC D
    RLC D                   # 8
    LD HL,0xc000            # 9
    LD (HL),0xf0
    RLC (HL)
    LD L,0x70               # 10
    RL L
    RL L                    # 11
  let cpu = newCpu(ops)
  cpu.step                  # 1
  assert cpu.r(A) == 0
  assert cpu.f == {}
  cpu.step 2                # 2
  assert cpu.r(A) == 0b0000_0011
  assert cpu.f == {Flag.C}
  cpu.step                  # 3
  assert cpu.r(A) == 0b0000_0110
  assert cpu.f == {}
  cpu.step                  # 4
  assert cpu.r(A) == 0b0000_1100
  assert cpu.f == {}
  cpu.f{C} = true
  cpu.step                  # 5
  assert cpu.r(A) == 0b0001_1001
  assert cpu.f == {}
  cpu.step                  # 6
  assert cpu.r(L) == 0
  assert cpu.f == {Z}
  cpu.step 2                # 7
  assert cpu.r(D) == 0b0001_1110
  assert cpu.f == {}
  cpu.f{C} = true           # 8
  cpu.step
  assert cpu.r(D) == 0b0011_1100
  assert cpu.f == {}
  cpu.f{C} = true           # 9
  cpu.step 3
  assert cpu[0xc000] == 0b1110_0001
  assert cpu.f == {Flag.C}
  cpu.f{C} = false          # 10
  cpu.step 2
  assert cpu.r(L) == 0b1110_0000
  assert cpu.f == {}
  cpu.f{C} = true           # 11
  cpu.step  
  assert cpu.r(L) == 0b1100_0001
  assert cpu.f == {Flag.C}

block:
  let ops = gbasm:
    RRCA                    # 1
    RRA                     # 2
    RRC D                   # 3
    RR E                    # 4
    RRCA                    # 5
    RRA                     # 6
    RRC D                   # 7
    RR E                    # 8
    LD A,1                  # 9
    RRCA
    LD A,1                  # 10
    RRA
    LD D,1                  # 11
    RRC D
    LD E,1                  # 12
    RR E
    LD A,1                  # 13
    RRCA
    LD A,1                  # 14
    RRA
    LD D,1                  # 15
    RRC D
    LD E,1                  # 16
    RR E
  let cpu = newCpu(ops)
  cpu.step                  # 1
  assert cpu.r(A) == 0
  assert cpu.f == {}
  cpu.step                  # 2
  assert cpu.r(A) == 0
  assert cpu.f == {}
  cpu.step                  # 3
  assert cpu.r(D) == 0
  assert cpu.f == {Z}
  cpu.step                  # 4
  assert cpu.r(E) == 0
  assert cpu.f == {Z}
  cpu.f{C} = true           # 5
  cpu.step
  assert cpu.r(A) == 0
  assert cpu.f == {}
  cpu.f{C} = true           # 6
  cpu.step
  assert cpu.r(A) == 0b1000_0000
  assert cpu.f == {}
  cpu.f{C} = true           # 7
  cpu.step
  assert cpu.r(D) == 0
  assert cpu.f == {Z}
  cpu.f{C} = true           # 8
  cpu.step
  assert cpu.r(E) == 0b1000_0000
  assert cpu.f == {}
  cpu.f{C} = false          # 9
  cpu.step 2
  assert cpu.r(A) == 0b1000_0000
  assert cpu.f == {Flag.C}
  cpu.f{C} = false          # 10
  cpu.step 2
  assert cpu.r(A) == 0b0000_0000
  assert cpu.f == {Flag.C}
  cpu.f{C} = false          # 11
  cpu.step 2
  assert cpu.r(D) == 0b1000_0000
  assert cpu.f == {Flag.C}
  cpu.f{C} = false          # 12
  cpu.step 2
  assert cpu.r(E) == 0b0000_0000
  assert cpu.f == {Z, C}
  cpu.f{C} = true          # 13
  cpu.step 2
  assert cpu.r(A) == 0b1000_0000
  assert cpu.f == {Flag.C}
  cpu.f{C} = true          # 14
  cpu.step 2
  assert cpu.r(A) == 0b1000_0000
  assert cpu.f == {Flag.C}
  cpu.f{C} = true          # 15
  cpu.step 2
  assert cpu.r(D) == 0b1000_0000
  assert cpu.f == {Flag.C}
  cpu.f{C} = true          # 16
  cpu.step 2
  assert cpu.r(E) == 0b1000_0000
  assert cpu.f == {Flag.C}
