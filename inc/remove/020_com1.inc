; code: language=nasm tabSize=8
%include "defines.inc"



InitCom1:
	__CHECKPOINT__NOSTACK__ 0x00
; ****************************************************************************
; If a serial port at I/O port 3F8h ('COM1') exists:
; 1. Initialise the port to: 9600 baud, no parity, 8 data bits, 1 stop bit. (9600,N,8,1), then
; 2. Send '33' to it.

	; See if a serial port at 3F8 ('COM1') is present.
	; Consider it present if bits 7 to 3 of the IIR are zero.
	mov	dx,COM1_iir
	in	al,dx
	and	al,11111000b
	jnz	.EXIT		; --> COM1 does not exist

	; Set 9600 baud.
	; Note: The DLAB bit will be restored to zero later.
	mov	dx,COM1_lcr	; Line control register (LCR).
	in	al,dx
	or	al,10000000b	; Bit 8 is the DLAB bit.
	out	dx,al		; In LCR, set the DLAB bit so that DLL and DLM are the targets.
	jmp	short $+2	; Delay for I/O.
	mov	dx,COM1_tx_rx_dll
	mov	al,0Ch    	; Divisor Latch LS (DLL) = 0Ch.
	out	dx,al
	jmp	short $+2	; Delay for I/O.
	mov	dx,COM1_ier_dlm	; Interrupt Enable Register (IER) or Divisor Latch MS (DLM).
	mov	al,0    	; Divisor Latch MS (DLM) = 0.
	out	dx,al
	jmp	short $+2	; Delay for I/O.

	; Note: At this point in time, in one of my serial configurations, 
	;       a strange character appears on the serial terminal.

	; Restore the DLAB bit to zero, and set: No parity, 8 data bits, 1 stop bit.
	mov	dx,COM1_lcr	; Line control register (LCR).
	mov 	al,00000011b
	out	dx,al
	jmp	short $+2	; Delay for I/O.

	; Delay - found to be required.
	; If not here, in one of my serial configurations, the "33 0 2" appears as strange characters.
	xor	cx,cx
	loop	$

	; Wait for the COM1 UART to indicate that it is ready for a TX byte.
	mov	dx,COM1_lsr	; Line status register (LSR).
.L10:	in	al,dx
	and	al,00100000b
	jz	.L10		; --> if UART is not ready.

	; Send first '3'
	mov	dx,COM1_tx_rx_dll
	mov	al,'3'
	out	dx,al

	; Wait for the COM1 UART to indicate that it is ready for a TX byte.
	mov	dx,COM1_lsr	; Line status register (LSR).
.L20:	in	al,dx
	and	al,00100000b
	jz	.L20		; --> if UART is not ready.

	; Send second '3'
	mov	dx,COM1_tx_rx_dll
	mov	al,'3'
	out	dx,al

.EXIT:

