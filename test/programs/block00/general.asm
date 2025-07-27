# block 00 test

test:
	ld a, 0
	rlca
	jr c, fail
	jr z, fail
	ld a, 0b10000000
	rlca
	jr nc, fail
	ccf
	jr c, fail
	rla
	scf
	rra
	scf
	rrca
	jr nc, fail
	ld a, -1
	cpl
	inc a
	jr z, fail
	dec a
	jr nz, fail
	ld bc, 0x0100
	ld de, 0
	inc bc
	dec de
	ld hl, 0
	add hl, bc
	add hl, de
	ld a, 1
	ld [hl+], a
	dec hl
	dec [hl]
	ld a, 0x89
	scf
	ccf
	jr z, bcd_loop_first
	jr nz, fail

bcd_loop_first:
	inc a
	daa
	jr nc, bcd_loop_first
	ld a, 0x11
	ccf
bcd_loop_second:
	dec a
	daa
	jr nz, bcd_loop_second
	jr pass

fail:
	ld a, 0
	stop

pass:
	ld a, 0xff
	jr done
	scf
	jr c, fail

done:
	stop