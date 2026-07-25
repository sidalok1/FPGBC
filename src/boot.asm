INCLUDE "hardware.inc"

SECTION "Boot", ROM0[$000]

start:
	ld bc, 0x0000
	ld de, 0xFF56
	ld sp, 0xFFFE
	ld hl, 0x000D
	ld de, 0xFF50
	ld a, 0x11
	jp Unmap_ROM
	
SECTION "Unmap", ROM0[$0FF]

Unmap_ROM:
	ld [de], a ; Load $11 to BANK (unmap)
	