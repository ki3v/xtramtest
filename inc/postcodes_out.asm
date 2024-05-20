; code: language=nasm tabSize=8
%include "defines.inc"


; ****************************************************************************
; Subroutine for outputting a byte to:
;     - the three standard LPT ports; and
;     - the RS-232 serial port at I/O port 3F8h ('COM1'); and
;     - IBM's debug port.
;
; For the serial port, send a CRLF sequence BEFORE the byte, and convert the byte to two ASCII bytes.
;
;   INPUTS: AL contains the byte/code to output.
;
;  OUTPUTS: {nothing}
;
; DESTROYS: AX, CL, DI, DX
;
; ****************************************************************************
CheckpointStack:

%ifdef USE_LPT
	;--------------------------------------------
	; Output to the standard parallel/LPT ports.
	;--------------------------------------------
	mov	dx,LPT1
	out	dx,al
	mov	dx,LPT2
	out	dx,al
	mov	dx,LPT3			; I/O port 3BCh. Parallel/LPT port on most MDA cards.
	out	dx,al
%endif

	;--------------------------------------------
	; Output the byte to IBM AT's debug port.  Rarely works for PC's and XT's.
	;--------------------------------------------
	out	80h,al
	
	;--------------------------------------------
	; Display the byte in the top-right corner of the screen.
	;--------------------------------------------
	; call	DispAlTopCorner		; ( Destroys: BX, CL, DI )

	;--------------------------------------------
	; Output the byte to the serial port of 3F8h ('COM1').
	; Start with a CRLF sequence, then the byte.
	;
	; The byte needs to be converted to ASCII.
	; For example, 8Ah would be converted to two bytes: 38h for the '8' followed by 42h for the 'A'.
	;--------------------------------------------

%ifdef	USE_SERIAL
	; Save the byte for later.
	mov	bp,ax

	; Send a CRLF sequence.
	call	SendCrlfToCom1	; ( Destroys: AX, DX )

	; Send the byte as two ASCII bytes.
	mov	ax,bp			; Get the byte to send back into AL.
	call	SendAlToCom1Ascii	; ( Destroys: AX, BP, BX, CL, DX )
%endif

	;------------------------
	; Return to caller.
	;------------------------
	ret


