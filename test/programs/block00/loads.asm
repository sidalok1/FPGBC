# test loads for block 00

ld bc, 1000
ld de, -2000
ld hl, 64
ld sp, 12345
ld [64], sp
ld a, 1
ld [hl+], a
ld a, 2
ld [hl-], a
ld b, 0
ld c, 1
ld d, 2
ld e, 3
ld [hl], 4
stop

# PASSING