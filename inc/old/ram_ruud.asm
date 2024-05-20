; code: language=nasm tabSize=8
%include "defines.inc"


; ---------------------------------------------------------------------------
section_save
section .romdata
; ---------------------------------------------------------------------------

TblTestData:		db 0FFh, 0, 055h, 0AAh, 1	
			; The 1 is required - odd (not even) to cater for most parity chip failures.

; ---------------------------------------------------------------------------
section .lib
; ---------------------------------------------------------------------------

; ****************************************************************************
; Reset/clear then re-arm the two 'RAM parity error' latches.
;
;   INPUTS: {nothing}
;
;  OUTPUTS: {nothing}
;
; DESTROYS: AL
;
; ****************************************************************************
BounceParityDetection:

	in	al,PPI8255_B
	or	al,00110000b		; Reset/clear by setting bits 5 and 4 on 8255 port B.
	out	PPI8255_B,al
	nop				; Delay for I/O.
	nop				; Delay for I/O.
	nop				; Delay for I/O.
	nop				; Delay for I/O.
	nop				; Delay for I/O.
	nop				; Delay for I/O.
	and	al,11001111b		; Re-arm by clearing bits 5 and 4 on 8255 port B.
	out	PPI8255_B,al
	ret



; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------

; ****************************************************************************
; Test the specified block of RAM.
;
;   INPUTS: - ES is segment of first test RAM address.
;           - CX is size to check (i.e. most possible is FFFF, which is 64K-1).
;           - SS points to the base of MDA or CGA video RAM, as applicable. (We also store some variables there.)
;
;  OUTPUTS: - Carry flag, clear (NC) = SUCCESS, set (C) = ERROR
;           - If data or parity error, the segment of the failing address is in variable 'BadAddrSegment'.
;           - If data or parity error, the offset of the failing address is in variable 'BadAddrOffset'.
;           - If data or parity error, the pattern of bad data bits (a byte) and parity bit indicator (a byte) are stored at [ss:BadDataParity]
;
; DESTROYS: SI, AX, CX, DX    (CX via the loop)
;
; ****************************************************************************
TESTRAMBLOCK:

	; Save BX
	push bx

	; Prepare for the actual check
	mov	word [ss:BadAddrSegment],0	; Clear the variable containing: segment of address in error
	mov	word [ss:BadAddrOffset],0	; Clear the variable containing: offset of address in error
	mov	word [ss:BadDataParity],0	; Clear the variable containing: bad data bits (in high byte) and parity bit indicator (in low byte)
	xor	dx,dx				; Clear our record of the bad bits for current address.
	mov	si,dx				; SI = offset of first test RAM address, which is 0000

	; Remove any existing RAM parity error indication that may have been latched earlier.
	call	BounceParityDetection

.NEWADDRESS:
	; Address loop. We are now pointing to next test address.

	; Zero pattern of bad data bits for the current test address.
	xor	dh,dh

	; Get the first test value (of five) into AH
	mov	word bx,TblTestData
	mov	byte ah,[cs:bx]

.NEWVAL:	; Value loop. We are now using a new test value. 

	; Write the current test value (in AH) to the current test address.
	mov	byte es:[si],ah

	; Read the byte back into AL.
	nop				; Delay for I/O.
	mov	byte al,es:[si]

	; Add 
	xor	al,ah			; AL = bad bit pattern for the current test value
	or	dh,al			; Add that to our record of the bad bits for current address.

	; Do next test value for current test address.
	inc	bx
	mov	ah,[cs:bx]
	cmp	bx,TblTestData+5	; 5th check value done?
	jne	.NEWVAL			; --> if no, do same test address with our new test value

	; All five test values done for the current test address.
	; If a problem was detected, jump to the error code.
	cmp	dx,0
	jne	.FAIL

	; No problem at the current test address - on to next address.
	inc	si
	loop	.NEWADDRESS

	; At this point, the complete block tested good from a data perspective.
	; But maybe the parity chip (or circuitry) is faulty.
	in	al,PPI8255_C
	and	al,11000000b		; A RAM parity error (either motherboard or card) ?
	jz	.PASS			; --> if no 
	mov	dl,1			; Temporarily record the parity error.
	mov	si,0			; SI will be final address of block. Point SI to starting address in block.
	; Fall through to FAIL.


.FAIL:	; Either:
	; - A data test of an address failed; or
	; - A data test of the block passed, but a parity related problem was detected.
	;
	; For the caller, store the segment and offset of the address.
	mov	word [ss:BadAddrSegment],es
	mov	word [ss:BadAddrOffset],si
	;
	; For the caller, save bad data bits (in high byte) and parity bit indicator (in low byte).
	mov	word [ss:BadDataParity],dx
	;
	; Set carry flag to indicate ERROR.
	stc
	jmp	.EXIT		; -->

.PASS: 	; Clear carry flag to indicate SUCCESS.
	clc

.EXIT:	pop	bx
	ret


