; --- refresh time delay ---
%define REFRESH_DELAY 5

; ************************************************************************************************
%include "defines.inc"
 
[map all xtramtest.map]

; START		equ	0E000h
; RESET		equ	0FFF0h
; BASESEG		equ	0F000h

; section .romdata	start=START align=1
; section .lib		follows=.romdata align=1
; section .text		follows=.lib align=1
; section .resetvec 	start=RESET align=1

START		equ	00000h
RESET		equ	01FF0h
BASESEG		equ	0FE00h

section .text		start=START align=1
section .lib		follows=.text align=1
section .romdata	follows=.lib align=1
section .resetvec 	start=RESET align=1

; .rwdata section in the unused portion of MDA/CGA video RAM, starting at 4000 DECIMAL - 96 bytes.
; variables at the bottom, stack at the top.
section .rwdata		start=InvScreenRAM align=1 nobits
rwdata_start:

; %define num_segments 8
%define first_segment 0
%define num_segments 40
%define bytes_per_segment 0x4000

; ---------------------------------------------------------------------------
section .rwdata ; MARK: __ .rwdata __
; ---------------------------------------------------------------------------
;Variables stored in unused MDA/CGA video RAM, or 4 KB at A0000.
; ---------------------------------------------------------------------------
	pass_count	dw	?			; The number of passes completed. Incremented by 1 each time a pass is completed.

	do_not_use	equ	InvScreenRAM+38		; Do not use this location. It caused a problem if a Mini G7 video card was used.

; ---------------------------------------------------------------------------
section .romdata ; MARK: __ .romdata __

; title_attr	equ	1Fh
title_attr	equ	0Fh
; title_attr	equ	71h
subtitle_attr	equ	07h
byline_attr	equ	02h

title_text: ; attr, x, y, text, 0 (terminate with 0 for attr)
			db 	title_attr,   1,  1
		title_only:	db	"XTRAMTEST ", 0
			db	subtitle_attr, 11, 1
			%include "version.inc"
			db " (", __DATE__, ")", 0
			; db 0
			db	title_attr,  54,  1, "github.com/ki3v/xtramtest", 0
			db	byline_attr,  0,  3, "by Dave Giller - with Adrian Black - https://youtube.com/@AdriansDigitalBasement", 0
			db	0

; ---------------------------------------------------------------------------
section .lib ; MARK: __ .lib __
; ---------------------------------------------------------------------------

; procedures to include in the ROM
%include "delay.asm"
%include "postcodes_out.asm"

; ---------------------------------------------------------------------------
section .text ; MARK: __ .text __
; ---------------------------------------------------------------------------

; MARK: DiagStart
DiagStart:
; ************************************************************************************************
; Initialization modules
	%include "010_cold_boot.inc"
	%include "030_video.inc"
	%include "050_beep.inc"
	%include "060_vram.inc"

; MARK: DiagLoop
DiagLoop:
; ************************************************************************************************
; MAIN DIAGNOSTIC LOOP
; ************************************************************************************************
	__CHECKPOINT__ 0x10 ;++++++++++++++++++++++++++++++++++++++++

	; Disable maskable interrupts, and set the direction flag to increment.
	cli
	cld

	add	word [ss:pass_count], 1		; Increment the pass count.

	; __CHECKPOINT__ 0x12 ;++++++++++++++++++++++++++++++++++++++++
	%include "screen.asm"

	%include "ram_common.asm"
	%include "ram_marchu.asm"
	%include "ram_bitpat.asm"
	jmp	DiagLoop


;------------------------------------------------------------------------------
; Power-On Entry Point
;------------------------------------------------------------------------------
; ---------------------------------------------------------------------------
section .resetvec ; MARK: __ .resetvec __
; ---------------------------------------------------------------------------
PowerOn:
	jmp	BASESEG:cold_boot	; CS will be 0F000h

 
S_FFF5:
	db __DATE__		; Assembled date (YYYY-MM-DD)
	db 0			; space for checksum byte
	

section .rwdata
	rwdata_end: