# tests for arith operations on block 00

inc a
dec a
dec a
inc a

ld hl, 32

inc [hl]
dec [hl]
dec [hl]
inc [hl]

inc bc
dec bc
dec bc
inc bc

ld b, -1
ld c, -32
ld de, 32

add hl, bc
add hl, bc
add hl, de
add hl, de

stop

# PASSING