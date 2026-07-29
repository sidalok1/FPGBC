INCLUDE "hardware.inc"

DEF GBDOC equ 0
 
IF GBDOC == 1
	PRINTLN "Assembling Gameboy Doctor bootrom"
	SECTION "Boot", ROM0[$000]

	start:
		ld sp, 0xFFFE
		ld a, 0x01
		ld bc, 0xFF13 ; upon inc b will set flags appropriately
		ld de, 0x00D8
		ld hl, 0x014D
		ld SP, 0xFFFE
		scf
		inc b ; should set b to 0x00 and f to 0xB0
		jp unmap_ROM

	SECTION "Unmap", ROM0[$FE]

	unmap_ROM:
		ldh [rBANK], a ; two byte instruction ( 0xFE: OPCODE, 0xFF: IMM )
	
ELSE
	PRINTLN "Assembling custom bootrom"
	;			 R  G  B
	def CHR	 = 0xF8_00_00
	def CHG	 = 0x00_F8_00
	def CHB	 = 0x00_00_F8

	def BGC0 = 0xFF_FF_FF
	def BGC1 = 0x63_A5_FF
	def BGC2 = 0x00_00_FF
	def BGC3 = 0x00_00_00

	def O0C0 = 0xFF_FF_FF
	def O0C1 = 0xFF_84_84
	def O0C2 = 0x94_3A_3A
	def O0C3 = 0x00_00_00

	def O1C0 = 0xFF_FF_FF
	def O1C1 = 0x7B_FF_31
	def O1C2 = 0x00_84_00
	def O1C3 = 0x00_00_00

	def BGPCOL0 = ((BGC0 & CHR) >> 19) | ((BGC0 & CHG) >> 6) | ((BGC0 & CHB) << 7)
	def BGPCOL1 = ((BGC1 & CHR) >> 19) | ((BGC1 & CHG) >> 6) | ((BGC1 & CHB) << 7)
	def BGPCOL2 = ((BGC2 & CHR) >> 19) | ((BGC2 & CHG) >> 6) | ((BGC2 & CHB) << 7)
	def BGPCOL3 = ((BGC3 & CHR) >> 19) | ((BGC3 & CHG) >> 6) | ((BGC3 & CHB) << 7)

	def OP0COL0 = ((O0C0 & CHR) >> 19) | ((O0C0 & CHG) >> 6) | ((O0C0 & CHB) << 7)
	def OP0COL1 = ((O0C1 & CHR) >> 19) | ((O0C1 & CHG) >> 6) | ((O0C1 & CHB) << 7)
	def OP0COL2 = ((O0C2 & CHR) >> 19) | ((O0C2 & CHG) >> 6) | ((O0C2 & CHB) << 7)
	def OP0COL3 = ((O0C3 & CHR) >> 19) | ((O0C3 & CHG) >> 6) | ((O0C3 & CHB) << 7)

	def OP1COL0 = ((O1C0 & CHR) >> 19) | ((O1C0 & CHG) >> 6) | ((O1C0 & CHB) << 7)
	def OP1COL1 = ((O1C1 & CHR) >> 19) | ((O1C1 & CHG) >> 6) | ((O1C1 & CHB) << 7)
	def OP1COL2 = ((O1C2 & CHR) >> 19) | ((O1C2 & CHG) >> 6) | ((O1C2 & CHB) << 7)
	def OP1COL3 = ((O1C3 & CHR) >> 19) | ((O1C3 & CHG) >> 6) | ((O1C3 & CHB) << 7)

	SECTION "Boot", ROM0[$000]

	start:
		ld sp, 0xFFFE
		call pal_load
		ld a, SYS_DMG
		ld [rSYS], a
		ld a, OPRI_COORD
		ld [rOPRI], a
		ld bc, 0x0000
		ld de, 0xFF56
		ld hl, 0x000D
		ld de, 0xFF50
		ld a, 0x01
		jp Unmap_ROM
		
	SECTION "Unmap", ROM0[$0FF]

	Unmap_ROM:
		ld [de], a ; Load a to BANK (unmap)
		
	SECTION "Subroutines", ROM0[$200]

	pal_load:
	.disable_lcd:
		ld a, [rLY]
		cp 144
		jr nz, .disable_lcd
		ld a, 0
		ld [rLCDC], a
	.begin_pal_load:
		ld hl, bgp_pal_colors
		ld b, 16 ; 16 bytes to be loaded, includes blank pallete
		ld a, 0x00 | BGPI_AUTOINC
		ld [rBGPI], a
	.bgr_load:
		ld a, [hl+]
		ld [rBGPD], a
		dec b
		jr nz, .bgr_load
		ld hl, obp_pal_colors
		ld b, 16
		ld a, 0x00 | OBPI_AUTOINC
		ld [rOBPI], a
	.obp_load:
		ld a, [hl+]
		ld [rOBPD], a
		dec b
		jr nz, .obp_load
		ld a, LCDC_ON | LCDC_BG_ON ; enable lcd
		ld [rLCDC], a
		ret


	bgp_pal_colors:
		DW BGPCOL0, BGPCOL1, BGPCOL2, BGPCOL3, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF

	obp_pal_colors:
		DW OP0COL0, OP0COL1, OP0COL2, OP0COL3, OP1COL0, OP1COL1, OP1COL2, OP1COL3

	SECTION "BootRom-End", ROM0[$900]
ENDC