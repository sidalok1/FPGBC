INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]

	jp EntryPoint

	ds $150 - @, 0 ; Make room for the header

EntryPoint:
	ld a, TAC_START | TAC_262KHZ
	ldh [rTAC], a
	ld a, 0
	ldh [rTIMA], a
	ld a, 0
	ldh [rIF], a
	halt
	nop
	ldh a, [rIF]
	and IF_TIMER
	jp z, Failed
	jp Passed


Passed:
	ld a, '0'
	ldh [rSB], a
	ld a, SC_START | SC_INTERNAL | SC_FAST
	ldh [rSC], a
	jp WaitSerial

Failed:
	ld a, '1'
	ldh [rSB], a
	ld a, SC_START | SC_INTERNAL | SC_FAST
	ldh [rSC], a
	jp WaitSerial

WaitSerial:
	ld hl, rSC
:	bit B_SC_START, [hl]
	jr nz, :-
	stop

