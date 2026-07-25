INCLUDE "hardware.inc" 

SECTION "Header", ROM0[$100]

Entry:
	ld hl, Message
	ld b, [hl]
	inc hl
	call PrintSerial
	jr Done


PrintSerial:
	ld a, [hl+]
	ld [rSB], a
	ld a, 0x81
	ld [rSC], a
	call AwaitSerial
	dec b
	jr nz, PrintSerial
	ret

AwaitSerial:
	ld a, [rSC]
	bit B_SC_START, a
	jr z, AwaitSerial
	ret

Message:
	DB 13, "hello world!\n"

Done:
	jr Done

