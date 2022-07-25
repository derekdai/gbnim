import std/[logging]
import gbasm
import cpu
import memory

proc newCpu(opcodes: seq[byte]): Sm83 =
  result = newSm83()
  result.memCtrl = newMemoryCtrl()
  let bootrom = newRom(BootRom, opcodes)
  result.memCtrl.map(bootrom)

proc step(self: Sm83; n: int) =
  for i in 0..<n:
    self.step()

block:
  let cpu = newSm83()
  assert cpu.ticks == 0
  assert cpu.ime == false

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
