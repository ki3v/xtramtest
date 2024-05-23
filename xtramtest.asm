; --- refresh time delay ---
%define REFRESH_DELAY 5

; ************************************************************************************************
%include "defines.inc"
 
[map all xtramtest.map]

START		equ	0E000h
RESET		equ	0FFF0h

section .romdata	start=START align=1
section .lib		follows=.romdata align=1
section .text		follows=.lib align=1
section .resetvec 	start=RESET align=1

; .rwdata section in the unused portion of MDA/CGA video RAM, starting at 4000 DECIMAL - 96 bytes.
; variables at the bottom, stack at the top.
section .rwdata		start=InvScreenRAM align=1 nobits
rwdata_start:

; %define num_segments 8
%define num_segments 40

; ---------------------------------------------------------------------------
section .rwdata ; MARK: __ .rwdata __
; ---------------------------------------------------------------------------
;Variables stored in unused MDA/CGA video RAM, or 4 KB at A0000.
; ---------------------------------------------------------------------------
	; ControlWord	db	?
	; Err8253Ch0	db	?
	; Err8253Ch1	db	?
	; Err8253Ch2	db	?
	; Err8237DMA	db	?
	; ErrHotTimer1	db	?
	; Err8255Parity	db	?
	; Err2KbRAM	db	?
	; Err8259PIC	db	?
	; ErrHotInterrupt	db	?
	; ErrInterrupt0	db	?
	; ErrNMI		db	?
	; ErrMemoryMDA	db	?
	; ErrMemoryCGA	db	?
	; Err8087	db	?
	; ErrKeybReset	db	?
	; ErrKeybStuck	db	?
	; ErrFDC	db	?
	; ErrFdcRead	db	?
	; ErrRomF4000	db	?
	; ErrRomF6000	db	?
	; ErrRomF8000	db	?
	; ErrRomFA000	db	?
	; ErrRomFC000	db	?
	; PassCount	db	?
	pass_count	dw	?		; The number of passes completed. Incremented by 1 each time a pass is completed.

	; SegTopOfRam	dw	?		; The segment address of the top-of-RAM found. E.g. A000 for 640 KB.
	; BadAddrSegment	dw	?		; For addressing or data error, the segement of the 'bad' address.
	; BadAddrOffset	dw	?		; For addressing or data error, the offset of the 'bad' address.
	; BadDataParity	dw	?		; If a data error, the high byte = 'bad' bits, low byte (parity) = 00.
        ;                                         ; If a parity error, the high byte = 00, the low byte (parity) will be 01.

	; Com1Exists	db	?		; Will be set to 1 if COM1 exists.
	; AbsoluteAddress	db	3 dup ?		; an absolute address (eg. 084A3F hex). Populated by subroutine 'CalcAbsFromSegOff'

do_not_use	equ	InvScreenRAM+38		; Do not use this location. It caused a problem if a Mini G7 video card was used.



; ---------------------------------------------------------------------------
section .romdata ; MARK: __ .romdata __
; ---------------------------------------------------------------------------
; TxtTitle: ; 01234567890123456789012345678901234567890123456789012345678901234567890123456789
; 	db	"KI3V XTDIAG (", __DATE__, ")", 0
; 	; db "XTDIAG by KI3V + Adrian Black + Ruud Baltissen    ("
; 	; db __DATE__		; Compiled date (YYYY-MM-DD)
; 	; db ')', 0

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
			db	byline_attr,  4,  3, "by Dave Giller - with Adrian Black - youtube.com/@adriansdigitalbasement", 0
			db	0

; ---------------------------------------------------------------------------
section .lib ; MARK: __ .lib __
; ---------------------------------------------------------------------------

; procedures to include in the ROM
%ifdef USE_SERIAL
	%include "serial.asm"
%endif
use "delay.asm"
; %include "delay.asm"
; %include "console.asm"
; %include "interrupts.asm"
; %include "old/ram_ruud.asm"
%include "postcodes_out.asm"

; %include "old/ibm_memtest.asm"


; ---------------------------------------------------------------------------
section .text ; MARK: __ .text __
; ---------------------------------------------------------------------------

; MARK: DiagStart
DiagStart:
; ************************************************************************************************
; Initialization modules
	%include "init/010_cold_boot.inc"

	; %ifdef USE_SERIAL
	; 	%include "old/020_com1.inc"
	; %endif

	%include "old/030_video.inc"
	; %include "old/040_NMI.inc"
	%include "old/050_beep.inc"
	%include "old/060_vram.inc"

	; ; now we have stack and data segments
	; %ifdef USE_SERIAL
	; 	%include "old/080_serial.inc"
	; %endif


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

	%include "diag/ram_bitpat.asm"
	%include "diag/ram_marchu.asm"

	; %include "old/cpu_test.asm"
	; %include "old/bios.asm"
	; %include "old/timers.asm"
	; %include "old/dma.asm"
	; %include "old/timer1_hot.asm"
	; %include "old/init_refresh.asm"
	; %include "old/parity_latch.asm"
	; %include "old/low2k.asm"
	; %include "old/ram_size.asm"
	; %include "old/ram_data.asm"
	; %include "old/ram_address.asm"
	; %include "old/ram_refresh.asm"
	; %include "old/ram_refresh_slow.asm"
	; %include "old/irq.asm"
	; %include "old/nmi.asm"
	; %include "old/keyboard.asm"
	; %include "old/fdc.asm"
	; %include "old/roms.asm"
	; %include "old/dipswitches.asm"

	jmp	DiagLoop



;------------------------------------------------------------------------------
; Power-On Entry Point
;------------------------------------------------------------------------------
; ---------------------------------------------------------------------------
section .resetvec ; MARK: __ .resetvec __
; ---------------------------------------------------------------------------
PowerOn:
	jmp	0F000h:cold_boot	; CS will be 0F000h

 
S_FFF5:
	db __DATE__		; Assembled date (YYYY-MM-DD)
	db 0			; space for checksum byte
	

section .rwdata
	rwdata_end: