; General test for block 01
; I am unsure on halt's true behaviour
;so I am not considering it fully tested

start:
	ld a, -1
	ld b, a
	ld c, b
	ld d, c
	ld h, d
	ld l, h
	ld [hl], l
	inc [hl]
	ld a, [hl]
	jr z, pass
	stop

pass:
	ld a, 0xff
	ld [hl], [hl] 		; should halt
	ld a, 0
	stop



