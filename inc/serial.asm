; code: language=nasm tabSize=8
%include "defines.inc"


; ---------------------------------------------------------------------------
section_save
section .lib
; ---------------------------------------------------------------------------

; ****************************************************************************
; Send the failing address to the RS-232 serial port at I/O port 3F8h ('COM1').
; Preceed that with a space character.
;
;   INPUTS: - Variable 'BadAddrSegment' contains the segment of the failing address.
;           - Variable 'BadAddrOffset' contains the offset of the failing address.
;
; REQUIREMENT: For XLATB, DS is set to the CS (where Tbl_ASCII is). This is normally the case in this program.
;
;     OUTPUTS: {nothing}
;
;    DESTROYS: AX, BP, BX, CL, DX
;
; ****************************************************************************
SendBadAddressToCom1:

	; ---------------------------------------
	; Send a space character.
	; ---------------------------------------
	mov	al,' '
	call	SendAlToCom1Raw	; ( Destroys: AX, DX )

	; ---------------------------------------
	; Calculate the absolute address from variables 'BadAddrSegment' and 'BadAddrOffset'.
	; Store the result (eg. 084A3F hex) in the 3-byte variable named 'AbsoluteAddress'.
	; ---------------------------------------
	mov	word ax,[ss:BadAddrSegment]
	mov	word dx,[ss:BadAddrOffset]
	call	CalcAbsFromSegOff	; From AX:DX  ( Destroys: BX, CL )

	; ---------------------------------------
	; Send the failing address.
	; Variable 'AbsoluteAddress' is 3 bytes, e.g. address 084A3F, 6 digits.
	; But this computer is a PC or XT, and so the first digit will always be zero.
	; So in sending the address, do not send the first digit.
	; ---------------------------------------
	;
	; Send the second digit of the six.
	mov	byte al,[ss:AbsoluteAddress+0]
	and	al,0Fh		; AL only has low nibble.
	mov	bx,Tbl_ASCII
	xlatb			; Convert AL into ASCII.
	call	SendAlToCom1Raw	; ( Destroys: AX, DX )
	;
	; Send the third and fourth digits of the six.
	mov	byte al,[ss:AbsoluteAddress+1]
	call	SendAlToCom1Ascii	; ( Destroys: AX, BP, BX, CL, DX )
	;
	; Send the fifth and sixth digits of the six.
	mov	byte al,[ss:AbsoluteAddress+2]
	call	SendAlToCom1Ascii	; ( Destroys: AX, BP, BX, CL, DX )

.EXIT:  ; ---------------------------------------
	; Return to caller.
	; ---------------------------------------
	ret



; ****************************************************************************
; Send the stored bad data bits (Bit Error Pattern) to the RS-232 serial port at I/O port 3F8h ('COM1').
; Preceed that with a space character.
;
;   INPUTS: Variable 'BadDataParity' contains the bad data bits (upper byte) and parity bit indicator (lower byte).
;
;  OUTPUTS: {nothing}
;
; DESTROYS: AX, BP, BX, CL, DX
;
; ****************************************************************************
SendBadDataToCom1:

	; Send a space character.
	mov	al,' '
	call	SendAlToCom1Raw	; ( Destroys: AX, DX )

	; Send the bad data bits.
	mov	word ax,[ss:BadDataParity]	; High byte is the bad data bits (the Bit Error Pattern).
	mov	al,ah
	call	SendAlToCom1Ascii	; ( Destroys: AX, BP, BX, CL, DX )

	; Return to caller.
	ret


; ****************************************************************************
; In ASCII form, send the byte in AL to the RS-232 serial port at I/O port 3F8h ('COM1').
; For example, 8Ah would be converted to two bytes: 38h for the '8' followed by 42h for the 'A'.
;
;   INPUTS: AL contains the byte/code to output.
;
; REQUIREMENT: For XLATB, DS is set to the CS (where Tbl_ASCII is). This is normally the case in this program.
;
;  OUTPUTS: {nothing}
;
; DESTROYS: AX, BP, BX, CL, DX
;
; ****************************************************************************
SendAlToCom1Ascii:

	; See if we earier detected a serial port at I/O port 3F8h ('COM1').
	cmp	byte [ss:Com1Exists],1
	jne	.EXIT		; --> COM1 does not exist

	; Save the passed byte for later.
	mov	bp,ax

	; Send the first byte; the high nibble of the passed byte.
	mov	cl,4
	shr	al,cl		; High nibble to low nibble.
	mov	bx,Tbl_ASCII
	xlatb			; Convert AL into ASCII.
	call	SendAlToCom1Raw	; ( Destroys: AX, DX )

	; Send the second byte; the low nibble of the passed byte.
	mov	ax,bp		; Get the passed byte back.
	and	al,0Fh		; AL only has low nibble of passed AL.
	mov	bx,Tbl_ASCII
	xlatb			; Convert AL into ASCII.
	call	SendAlToCom1Raw	; ( Destroys: AX, DX )

	; Return to caller.
.EXIT	ret


; ****************************************************************************
; In RAW form, send the byte in AL to the RS-232 serial port at I/O port 3F8h ('COM1').
;
;   INPUTS: AL contains the byte/code to output.
;
;  OUTPUTS: {nothing}
;
; DESTROYS: AX, DX
;
; ****************************************************************************
SendAlToCom1Raw:

	; See if we earier detected a serial port at I/O port 3F8h ('COM1').
	cmp	byte [ss:Com1Exists],1
	jne	.EXIT		; --> COM1 does not exist

	; Save the byte in AL for later.
	mov	ah,al

	; Wait for the COM1 UART to indicate that it is ready for a TX byte.
	; Implement a timeout, just in case.
	mov	dx,COM1_lsr	; Line status register (LSR).
	xor	cx,cx		; Our timeout.
.L10:	in	al,dx
	and	al,00100000b
	jnz	.S10		; --> UART is ready
	dec	cx		; Decrement our timeout.
	jnz	.L10		; If not timed out, see again if UART is ready.
.S10:	; UART is ready, or the timeout occurred.

	; Send the byte.
	mov	al,ah		; Get the byte to send back into AL.
	mov	dx,COM1_tx_rx_dll
	out	dx,al

	; Return to caller.
.EXIT	ret


; ****************************************************************************
; Send a CR/LF/hash sequence to the RS-232 serial port at I/O port 3F8h ('COM1').
;
;   INPUTS: {nothing}
;
;  OUTPUTS: {nothing}
;
; DESTROYS: AX, DX
;
; ****************************************************************************
SendCrlfHashToCom1:

	; Send a CRLF sequence.
	call	SendCrlfToCom1	; ( Destroys: AX, DX )

	; Send the hash.
	mov	al,'#'
	call	SendAlToCom1Raw	; ( Destroys: AX, DX )

	; Send another CRLF sequence.
	call	SendCrlfToCom1	; ( Destroys: AX, DX )

	; Return to caller.
	ret


; ****************************************************************************
; Send a CR/LF/hash sequence to the RS-232 serial port at I/O port 3F8h ('COM1').
;
;   INPUTS: {nothing}
;
;  OUTPUTS: {nothing}
;
; DESTROYS: AX, DX
;
; ****************************************************************************
SendCrlfToCom1:

	mov	al,0Dh		; Carriage return (CR)
	call	SendAlToCom1Raw	; ( Destroys: AX, DX )
	mov	al,0Ah		; Line feed (LF)
	call	SendAlToCom1Raw	; ( Destroys: AX, DX )
	ret


; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------
