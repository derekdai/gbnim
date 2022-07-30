import common, gbasm

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
  cpu{Z} = true
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
  cpu{Z} = true
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
  cpu{C} = true
  cpu.step()
  assert cpu.ticks == 8
  assert cpu.pc == 2
  cpu.step()
  assert cpu.ticks == 20
  assert cpu.pc == 6

