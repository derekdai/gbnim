import common, gbasm

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
  assert cpu[A] == 0
  assert cpu.aluFlags == {}
  cpu.step 2                # 2
  assert cpu[A] == 0b0000_0011
  assert cpu.aluFlags == {AluFlag.C}
  cpu.step                  # 3
  assert cpu[A] == 0b0000_0110
  assert cpu.aluFlags == {}
  cpu.step                  # 4
  assert cpu[A] == 0b0000_1100
  assert cpu.aluFlags == {}
  cpu{C} = true
  cpu.step                  # 5
  assert cpu[A] == 0b0001_1001
  assert cpu.aluFlags == {}
  cpu.step                  # 6
  assert cpu[L] == 0
  assert cpu.aluFlags == {Z}
  cpu.step 2                # 7
  assert cpu[D] == 0b0001_1110
  assert cpu.aluFlags == {}
  cpu{C} = true           # 8
  cpu.step
  assert cpu[D] == 0b0011_1100
  assert cpu.aluFlags == {}
  cpu{C} = true           # 9
  cpu.step 3
  assert cpu[0xc000] == 0b1110_0001
  assert cpu.aluFlags == {AluFlag.C}
  cpu{C} = false          # 10
  cpu.step 2
  assert cpu[L] == 0b1110_0000
  assert cpu.aluFlags == {}
  cpu{C} = true           # 11
  cpu.step  
  assert cpu[L] == 0b1100_0001
  assert cpu.aluFlags == {AluFlag.C}

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
  assert cpu[A] == 0
  assert cpu.aluFlags == {}
  cpu.step                  # 2
  assert cpu[A] == 0
  assert cpu.aluFlags == {}
  cpu.step                  # 3
  assert cpu[D] == 0
  assert cpu.aluFlags == {Z}
  cpu.step                  # 4
  assert cpu[E] == 0
  assert cpu.aluFlags == {Z}
  cpu{C} = true           # 5
  cpu.step
  assert cpu[A] == 0
  assert cpu.aluFlags == {}
  cpu{C} = true           # 6
  cpu.step
  assert cpu[A] == 0b1000_0000
  assert cpu.aluFlags == {}
  cpu{C} = true           # 7
  cpu.step
  assert cpu[D] == 0
  assert cpu.aluFlags == {Z}
  cpu{C} = true           # 8
  cpu.step
  assert cpu[E] == 0b1000_0000
  assert cpu.aluFlags == {}
  cpu{C} = false          # 9
  cpu.step 2
  assert cpu[A] == 0b1000_0000
  assert cpu.aluFlags == {AluFlag.C}
  cpu{C} = false          # 10
  cpu.step 2
  assert cpu[A] == 0b0000_0000
  assert cpu.aluFlags == {AluFlag.C}
  cpu{C} = false          # 11
  cpu.step 2
  assert cpu[D] == 0b1000_0000
  assert cpu.aluFlags == {AluFlag.C}
  cpu{C} = false          # 12
  cpu.step 2
  assert cpu[E] == 0b0000_0000
  assert cpu.aluFlags == {Z, C}
  cpu{C} = true          # 13
  cpu.step 2
  assert cpu[A] == 0b1000_0000
  assert cpu.aluFlags == {AluFlag.C}
  cpu{C} = true          # 14
  cpu.step 2
  assert cpu[A] == 0b1000_0000
  assert cpu.aluFlags == {AluFlag.C}
  cpu{C} = true          # 15
  cpu.step 2
  assert cpu[D] == 0b1000_0000
  assert cpu.aluFlags == {AluFlag.C}
  cpu{C} = true          # 16
  cpu.step 2
  assert cpu[E] == 0b1000_0000
  assert cpu.aluFlags == {AluFlag.C}

