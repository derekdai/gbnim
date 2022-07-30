import common, gbasm

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
cpu{C} = true
cpu.step()
assert cpu.ticks == 48
assert cpu.pc == 70
cpu.step()
assert cpu.ticks == 60
assert cpu.pc == 73
cpu{C} = false
cpu.step()
assert cpu.ticks == 76
assert cpu.pc == 80

cpu.step()
assert cpu.ticks == 88
assert cpu.pc == 83
cpu{Z} = true
cpu.step()
assert cpu.ticks == 104
assert cpu.pc == 90
cpu.step()
assert cpu.ticks == 116
assert cpu.pc == 93
cpu{Z} = false
cpu.step()
assert cpu.ticks == 132
assert cpu.pc == 100

