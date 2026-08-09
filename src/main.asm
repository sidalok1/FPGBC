INCLUDE "hardware.inc" 

SECTION "Header", ROM0[$100]

Entry:
	ld hl, Message
	ld b, [hl]
	inc hl
	call PrintSerial
	call Make_Beep
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
	jr nz, AwaitSerial
	ret

Message:
	DB 13, "hello world!\n"

Make_Beep:
	ld a, AUDENA_ON
	ldh [rAUDENA], a
	ld a, 0xFF
	ldh [rAUDTERM], a
	ldh [rAUDVOL], a
	ld a, 0xF1
	ldh [rAUD1ENV], a
	ld a, 0x86
	ldh [rAUD1HIGH], a
	ret

Done:
	jr Done

 