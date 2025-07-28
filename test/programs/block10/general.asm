# block 10 general test

start:
	ld c, 1
	ld b, 1
	ld d, 2
	ld a, c
	add a, b
	cp a, d
	jr nz, fail
	ld b, 0x01
	ld c, 0xff
	ld a, 1
	add a, c
	adc a, b
	cp a, d
	jr nz, fail
	ld a, 5
	ld b, 10
	ld d, -5
	sub a, b
	cp a, d
	jr nz, fail
	ld bc, 0x0300
	ld de, 0x0101
	ld a, c
	sub a, e
	ld a, b
	sbc a, d
	ld b, 1
	cp a, b
	jr nz, fail
	ld hl, 0xff00
	ld [hl], 0x01
	cp a, [hl]
	jr nz, fail
	ld a, 0xaa
	ld b, 0x55
	and a, b
	jr nz, fail
	ld a, 0xff
	ld b, 0xaa
	xor a, b
	cpl
	cp a, b
	jr nz, fail
	ld a, 0xaa
	ld b, 0x55
	ld c, 0xff
	or a, b
	cp a, c
	jr nz, fail
	stop

fail:
	ld a, 0x00
	stop