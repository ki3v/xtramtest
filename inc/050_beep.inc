; code: language=nasm tabSize=8
%include "defines.inc"
; ---------------------------------------------------------------------------
section_save
; ---------------------------------------------------------------------------
section .lib ; MARK: __ .lib __
; ---------------------------------------------------------------------------

; BEEP_LENGTH	equ	3		; Length of beep in 18.2Hz clock ticks - 3 -> ~155ms

; input: 
;	cl = length of beep in clock ticks 
;	ch = tone frequency (0 = silence)
bpc_beep:
		; Configure channel 2 of the 8253 PIT chip for a square wave output of about 904 Hz.
		; 1.193 MHz / 1320 = about 904 Hz
		mov	al, PIT_SEL_CH2 | PIT_RW_BOTH | PIT_MODE3 ; Square waves for channel 2
		out	IO_PIT_CTL, al
		mov	al, 0			; load LSB of period (0)
		out	IO_PIT_CH2, al		
		mov	al, ch			; load MSB or period (ch)
		out	IO_PIT_CH2, al

		in	al, IO_PPI_B
		or	al, PPIB_SPKR | PPIB_TIMER2
		out	IO_PPI_B, al		; Start beep by setting 8255 pins PB1 and PB0 to HIGH.

bpc_timer_delay:
		; wait for the beep to finish: count system timer ticks
		mov	ah, cl				; save the beep counter
		mov	dx, 0xFFFF			; compare value for the latched value
	.loop:
		mov	al, PIT_LATCH | PIT_SEL_CH0	; latch counter 0
		out	IO_PIT_CTL, al
		jmp	$+2				; delay
		in	al, IO_PIT_CH0			; read low byte
		mov	bl, al				; save low byte
		jmp	$+2				; delay
		in	al, IO_PIT_CH0			; read high byte
		mov	bh, al				; save high byte
		cmp	dx, bx				; compare to the latched value
		mov	dx, bx				; save the latched value
		jge	.loop				; keep polling until the timer has reset (greater than last read)
		dec	ah				; decrement the beep counter
		jnz	.loop				; keep beeping until the beep counter is zero

		in	al, IO_PPI_B
		and	al, ~( PPIB_SPKR | PPIB_TIMER2 )
		out	IO_PPI_B, al		; Stop the beep by setting 8255 pins PB1 and PB0 to LOW.
	.done:
		bpret


; ---------------------------------------------------------------------------
section_restore ; MARK: __ restore __
; ---------------------------------------------------------------------------
; ****************************************************************************
; Beep the speaker three times: short-long-short.

InitBeep:
		mov	cx, 0x0D04
		bpcall	bpc_beep
		mov	ch, 0x08
		bpcall	bpc_beep
		mov	ch, 0x04
		bpcall	bpc_beep
