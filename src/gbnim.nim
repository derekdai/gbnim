import cpu

proc main() =
  var cpu = newCpu()
  echo cpu.r(A)
  echo cpu.r(0.toRegs)

when isMainModule:
  main()
