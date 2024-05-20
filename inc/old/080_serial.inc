Com1Check:
; ****************************************************************************
; If an RS-232 serial port at the base I/O address of 3F8h (i.e. COM1) exists,
; then set the 'Com1Exists' variable to 1.
;
; That variable will be checked by later code that intends to send bytes to COM1.

	; Consider it present if bits 7 to 3 of the IIR are zero.
	mov	dx,COM1_iir
	in	al,dx
	and	al,11111000b
	jnz	.EXIT		; --> COM1 does not exist
	mov	byte [ss:Com1Exists],1
.EXIT:

