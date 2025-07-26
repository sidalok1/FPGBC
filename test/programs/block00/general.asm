# block 00 test

ld sp, 10
ld [128], sp
ld bc, 128
ld a, [bc]
ld b, 0
ld c, 5
ld de, -3
ld hl, 32
inc hl
add hl, bc
add hl, de
dec a
jr 3
inc bc
dec de
jr nz, -6
stop
