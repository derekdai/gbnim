import common, gbasm

let ops = gbasm:
  LD SP,0xcfff          # 1
  CALL 10
  [10]
  CALL NZ,20            # 2
  CALL NZ,20            # 3
  [20]
  CALL Z,30             # 4
  CALL Z,30             # 5
  [30]
  CALL NC,40            # 6
  CALL NC,40            # 7
  [40]
  CALL C,50             # 8
  CALL C,50             # 9
let cpu = newCpu(ops)
cpu.step 2              # 1
assert cpu.sp == 0xcfff - 2
assert cpu.pc == 10
cpu{Z} = true         # 2
cpu.step
assert cpu.pc == 13
cpu{Z} = false        # 3
cpu.step
assert cpu.pc == 20
cpu{Z} = false        # 4
cpu.step
assert cpu.pc == 23
cpu{Z} = true         # 5
cpu.step
assert cpu.pc == 30
cpu{C} = true         # 6
cpu.step
assert cpu.pc == 33
cpu{C} = false        # 7
cpu.step
assert cpu.pc == 40
cpu{C} = false        # 8
cpu.step
assert cpu.pc == 43
cpu{C} = true         # 9
cpu.step
assert cpu.pc == 50
assert cpu[SP] == 0xcff5

