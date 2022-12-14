import gbasm
import common
import std/logging

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
  LD (0xff80),A
  XOR A,A                     # 10
  LD A,(0xff80)
  LD C,0x88                   # 11
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
assert cpu[HL] == 0xc000
assert cpu.aluFlags == {}
cpu.step                      # 2
assert cpu[HL] == 0xc000
assert cpu[0xc000] == 0x1b
cpu.step                      # 3
assert cpu[HL] == 0xc001
assert cpu[0xc000] == 0
assert cpu.aluFlags == {}
cpu[A] = 0xcc
cpu.step                      # 4
assert cpu[HL] == 0xc000
assert cpu[0xc001] == 0xcc
cpu.step 2                    # 5
assert cpu[BC] == 0xc100
assert cpu[0xc100] == 0xcc
cpu.step                      # 6
assert cpu[C] == 0x1b
cpu.step                      # 7
assert cpu[D] == 0
cpu.step                      # 8
assert cpu[H] == cpu[B]
cpu.step 2                    # 9
assert cpu[A] == 0xdd
assert cpu[0xff80] == cpu[A]
cpu.step                      # 10
assert cpu[A] == 0
cpu.step
assert cpu[A] == 0xdd
assert cpu[A] == cpu[0xff80]
cpu.step                      # 11
assert cpu[0xff88] == 0
assert cpu[C] == 0x88
cpu.step
assert cpu[0xff88] == 0xdd
cpu.step                      # 12
assert cpu[A] == 0
cpu.step
assert cpu[A] == 0xdd
cpu.step                      # 13
assert cpu[SP] == 0x5678
cpu.step
assert cpu[0xc050] == 0x78
assert cpu[0xc051] == 0x56
cpu.step                      # 14
assert cpu[HL] == 0x5679
cpu.step                      # 15
assert cpu[SP] == 0x5679
cpu.step 4                    # 16
assert cpu[A] == 0xfe
assert cpu[0xc123] == 0xfe
cpu.step 5                    # 17
assert cpu[E] == 0x7c
assert cpu[HL] == 0xc321
assert cpu[0xc321] == 0x7c

