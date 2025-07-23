# use asmgb.py to compiler (link) this file

# block 00 test

ld sp, 10
ld [128], sp
ld bc, 128
ld a, [bc]
ld b, 0
ld c, 5
ld de, -3
ld hl, 32
dec a
ld [hl+], a
add hl, bc
ld [hl-], a
add hl, de
jr 3
inc bc
dec de
jr nz, -8
stop
