import common, gbasm

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

