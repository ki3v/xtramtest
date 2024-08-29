; code: language=nasm tabSize=8
%include "defines.inc"

; ****************************************************************************
; From here on, we need RAM for variables and for the stack.
;
; Look for RAM in the following locations:
;    - Address B0000 - MDA video RAM.
;    - Address B8000 - CGA video RAM.
;    - Address A0000 - A RAM card configured to put RAM there.
;
; If any of those found, set ES to it.

test_vram:
		mov	si, 4096		; size of VRAM to test
		mov	ax, cs
		mov	ss, ax			; SS := CS

		; First, see if MDA video RAM is present.
	.MDA:	mov	ax, SEG_MDA_VRAM		; Start with MDA
		jmp	.test_marchu

		; No MDA - See if CGA video RAM present.
	.CGA:	mov	ax, SEG_CGA_VRAM		; Try CGA.
		jmp	.test_marchu

		; No CGA - See if RAM at address A0000 is present.
	.A0000:	mov	ax, 0A000h
		mov	es, ax
		; jmp	.test_marchu

	.test_marchu:
		mov	es, ax			; set up ES and DS to the segment we are testing
		mov 	ds, ax

		bpcall	marchu_nostack

		or	dh, dh			; did the RAM pass?
		jz	.pass			; --> if yes, we have video RAM

		mov	ax, es			; which did we just test?
		cmp	ax, SEG_MDA_VRAM
		je	.CGA			; --> if MDA, try CGA
		cmp	ax, SEG_CGA_VRAM
		je	.A0000			; --> if CGA, try RAM at A0000

		; XXX: Report that there is no video RAM.  Beeps?

		cli
		hlt				; No MDA/CGA/A0000 video RAM found.  Halt the CPU.


	.pass:	;------------------------
		; Test successful.
		; -----------------------
		; MDA/CGA: Set the stack top to near the top of video RAM.
		;   A0000: Set the stack top at 4094 bytes into RAM.

		mov	ax,es
		mov	ss,ax			; SS = ES = segment address of video RAM (either MDA or CGA or A0000).
		mov	sp,rwdata_init_sp	; 4096

	; Info:	SS won't change anymore and will serve as a permanent pointer to the video RAM segment.


