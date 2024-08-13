InitBeep:
; ****************************************************************************
; Beep the speaker three times: short-long-short.
;
; >>> Yes, we are taking the chance that the circuitry involved in beeping the speaker is working. <<<
; For those without an MDA/CGA card, and without a parallel/LPT reader, and without a serial reader, 
; this beeping indicates that the code has started to execute.

	; Comment: Port direction on the 8255 chip was set up earlier.

	; Configure channel 2 of the 8253 PIT chip for a square wave output of about 904 Hz.
	; 1.193 MHz / 1320 = about 904 Hz
	mov	al,10110110b		; Square waves for channel 2
	out	PIT8253_ctrl,al
	mov	ax,0528h		; Countdown constant word = 1320 decimal
	out	PIT8253_2,al		;   send low order
	mov	al,ah			;   load high order
	out	PIT8253_2,al		;   send high order

	; One short beep.
	mov	al,00000011b
	out	PPI8255_B,al		; Start beep by setting 8255 pins PB1 and PB0 to HIGH.
	mov	al,1			; 1 = short beep.
	mov	cx, 02000h		; XXX xor	cx,cx
.L10:	loop	.L10
	dec	al
	jnz	.L10
	mov	al,0
	out	PPI8255_B,al		; Stop the beep by setting 8255 pins PB1 and PB0 to LOW.

	; Inter-beep delay.
	mov	cx, 02000h		; XXX xor	cx,cx
	loop	$

	; One long beep.
	mov	al,00000011b
	out	PPI8255_B,al		; Start beep by setting 8255 pins PB1 and PB0 to HIGH.
	mov	al,2			; 3 = long beep.
	mov	cx, 02000h		; XXX xor	cx,cx
.L30:	loop	.L30
	dec	al
	jnz	.L30
	mov	al,0
	out	PPI8255_B,al		; Stop the beep by setting 8255 pins PB1 and PB0 to LOW.

	; Inter-beep delay.
	mov	cx, 02000h		; XXX xor	cx,cx
	loop	$

	; One short beep.
	mov	al,00000011b
	out	PPI8255_B,al		; Start beep by setting 8255 pins PB1 and PB0 to HIGH.
	mov	al,1			; 1 = short beep.
	mov	cx, 02000h		; XXX xor	cx,cx
.L50:	loop	.L50
	dec	al
	jnz	.L50
	mov	al,0
	out	PPI8255_B,al		; Stop the beep by setting 8255 pins PB1 and PB0 to LOW.
