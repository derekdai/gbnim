import common, gbasm

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
  assert cpu[A] == 0xf
  cpu.step()
  assert cpu[B] == 0x1
  cpu.step()
  assert cpu[A] == 0x10
  assert cpu[B] == 0x1
  assert cpu.aluFlags == {AluFlag.H}
  cpu.step(2)
  assert cpu[A] == 0x00
  assert cpu.aluFlags == {AluFlag.C, Z}
  cpu.step(2)
  assert cpu[A] == 0xff
  assert cpu.aluFlags == {}
  cpu.step(2)
  assert cpu[A] == 0
  assert cpu.aluFlags == {AluFlag.C, AluFlag.H, Z}

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
  cpu{H} = true
  cpu.step()                # 1
  assert cpu[A] == 0
  assert cpu.aluFlags == {Z}
  cpu{C} = true
  cpu.step()                # 2
  assert cpu[A] == 1
  assert cpu.aluFlags == {}
  cpu.step()                # 3
  assert cpu[A] == 0
  assert cpu.aluFlags == {Z}
  cpu{C} = true
  cpu.step(2)
  assert cpu[A] == 0x10
  assert cpu.aluFlags == {AluFlag.H}
  cpu{C} = true           # 4
  cpu[A] = 0
  cpu.step(2)
  assert cpu[A] == 0x00
  assert cpu.aluFlags == {AluFlag.C, AluFlag.H, Z}
  cpu{C} = true           # 5
  cpu.step(3)
  assert cpu[A] == 0x00
  assert cpu.aluFlags == {AluFlag.C, AluFlag.H, Z}

block:
  let ops = gbasm:
    INC A                   # 1
    JR NZ,-3
    LD A,0xf                # 2
    INC A
  let cpu = newCpu(ops)
  cpu.step()                # 1
  assert cpu[A] == 1
  assert cpu.aluFlags == {}
  while true:
    cpu.step()
    if cpu.pc > 2:
      break
    cpu.step()
    if cpu{AluFlag.H}:
      assert (cpu[A] and 0xf) == 0
  assert cpu[A] == 0
  assert cpu.aluFlags == {AluFlag.H, Z}
  cpu.step 2                # 2
  assert cpu[A] == 0x10
  assert cpu.aluFlags == {AluFlag.H}

