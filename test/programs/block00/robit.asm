# Tests for rotate and bit ops in block 00

ld a, 170
scf
rla

ld a, 170
scf
ccf
rla

nop

ld a, 85
scf
rra

ld a, 85
scf
ccf
rra

nop

ld a, 170
rlca

ld a, 85
rlca

nop

ld a, 170
rrca

ld a, 85
rrca

nop

cpl

ld a, -1
cpl
cpl

stop

# PASSING