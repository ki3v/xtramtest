; code: language=nasm tabSize=8
%include "defines.inc"
; ---------------------------------------------------------------------------
section_save
; ---------------------------------------------------------------------------
section .lib ; MARK: __ .lib __
; ---------------------------------------------------------------------------

BEEP_LENGTH	equ	0x8000		; Length of beep

; input: ah = length of beep
do_beep:
		; mov	al, 00000011b
		in	al, IO_PPI_B
		or	al, PPIB_SPKR | PPIB_TIMER2
		out	IO_PPI_B, al		; Start beep by setting 8255 pins PB1 and PB0 to HIGH.

	.loop:	mov	cx, BEEP_LENGTH
		loop	$			; spin loop
		dec	ah
		jnz	.loop			; repeat spin loop ah times

		in	al, IO_PPI_B
		and	al, ~( PPIB_SPKR | PPIB_TIMER2 )
		out	IO_PPI_B, al		; Stop the beep by setting 8255 pins PB1 and PB0 to LOW.

		mov	cx, BEEP_LENGTH		; XXX xor	cx, cx
		loop	$			; inter-beep delay

		bpret


; ---------------------------------------------------------------------------
section_restore ; MARK: __ restore __
; ---------------------------------------------------------------------------
; ****************************************************************************
; Beep the speaker three times: short-long-short.

InitBeep:
		; Configure channel 2 of the 8253 PIT chip for a square wave output of about 904 Hz.
		; 1.193 MHz / 1320 = about 904 Hz
		mov	al, 10110110b		; Square waves for channel 2
		out	IO_PIT_CTL, al
		mov	ax, 0528h		; Countdown constant word = 1320 decimal
		out	IO_PIT_CH2, al		;   send low order
		mov	al, ah			;   load high order
		out	IO_PIT_CH2, al		;   send high order

		; short, long, short beeps
		mov	ah, 1
		bpcall	do_beep
		mov	ah, 3
		bpcall	do_beep
		mov	ah, 1
		bpcall	do_beep
