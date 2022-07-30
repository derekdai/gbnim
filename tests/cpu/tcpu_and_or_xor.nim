import common, gbasm

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
  assert cpu.aluFlags == {Z, H}
  cpu.step 2                # 2
  assert cpu.r(A) == 0
  assert cpu.aluFlags == {Z, H}
  cpu.step 2                # 3
  assert cpu.r(A) == 0
  assert cpu.aluFlags == {Z, H}
  cpu.step 2                # 4
  assert cpu.r(A) == 0b01010101
  assert cpu.aluFlags == {AluFlag.H}

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
  assert cpu.aluFlags == {Z}
  cpu.step 2                # 2
  assert cpu.r(A) == 1
  assert cpu.aluFlags == {}
  cpu.step 3                # 3
  assert cpu.r(C) == 0b10101010
  assert cpu.r(A) == cpu.r(C)
  assert cpu.aluFlags == {}

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
  assert cpu.aluFlags == {Z}
  cpu.step 2                # 2
  assert cpu.r(C) == 0b10101010
  assert cpu.r(A) == cpu.r(C)
  assert cpu.aluFlags == {}
  cpu.step                  # 3
  assert cpu.r(A) == 0b11111111
  assert cpu.aluFlags == {}
  cpu.step                  # 4
  assert cpu.r(A) == 0b11110000
  assert cpu.aluFlags == {}

