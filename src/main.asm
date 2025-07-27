# use asmgb.py to compiler (link) this file

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
	jr z, pass
	jr nz, fail

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
