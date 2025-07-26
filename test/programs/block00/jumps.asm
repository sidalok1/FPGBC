# Tests for block 00 control flow

# passing if a == 0 on stop inst

jr 0
jr 1
dec a
jr 4
dec a
jr 3
dec a
jr -5
scf
jr c, 1
dec a
scf
ccf
jr nc, 1
dec a
inc b
jr nz, 1
dec a
dec b
jr z, 1
dec a
stop

# PASSING