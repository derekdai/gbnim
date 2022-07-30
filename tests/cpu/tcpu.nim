import common, gbasm

#[
v NOP
v LD
v INC
v RLCA
v ADD
v DEC
v RRCA
v STOP
v RLA
v JR
v RRA
v ADC
v SUB
v SBC
v AND
v XOR
v OR
v JP
v RLC
v RRC
v RL
v RR
v DI
v EI
v CP
v POP
v PUSH
v CALL
v RET
v CPL
v SCF
v CCF
v SWAP
v SET
v BIT
v RES
v SLA
v SRL
v SRA
v RST
  DAA
]#

let cpu = newSm83()
assert cpu.ticks == 0
assert cpu.ime == false
