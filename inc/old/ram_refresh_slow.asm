; ---------------------------------------------------------------------------
section_save
section .romdata
; ---------------------------------------------------------------------------
TxtEmptyLine15:		db 15,  0, '                                        ', 0
TxtTestRamSlowRefr:	db 15,  2, 'Testing RAM - Slow Refresh', 0


; ---------------------------------------------------------------------------
section .lib
; ---------------------------------------------------------------------------

; ****************************************************************************
; Fill found RAM with the byte passed in DL.
;
;   INPUTS: - DL contains the byte.
;
;  OUTPUTS: {nothing}
;
; DESTROYS: AX, BX, CX, DI, ES
;
; ****************************************************************************
FillRamWithByte:

	; Calculate the number of 16 KB blocks to fill.
	; Put into BX.
	mov	word bx,[ss:SegTopOfRam]	; Get top of RAM as a segment (e.g. A000h corresponds to 640 KB)(e.g. 0400h corresponds to 16 KB).
	mov	cl,10			; 2^10 = 1024
	shr	bx,cl			; Divide by 1024 to get count of 16 KB blocks to test (e.g. A000h corresponds to 40 [28h] blocks).

	; Starting segment is 0000.
	xor	ax,ax
	mov	es,ax

.L10:	; Write the specified byte into the 16 KB sized block at segment in ES.
	mov	ah,dl
	mov	al,dl
	mov	di,0
	mov	cx,2000h		; 8K words = 16 KB
	rep	stosw			; STOSW: AX-->[ES:DI], then DI=DI+2

	; Point to segment of next 16 KB block address.
	mov	ax,es
	add	ax,0400h
	mov	es,ax

	; If there are more blocks to fill, go do them.
	dec	bx			; Decrement our block counter.
	jnz	.L10			; --> if more blocks to do

	ret


; ****************************************************************************
; Read all addresses of found RAM, expecting to read the byte passed in DL.
; If all bytes are read as expected, pass, otherwise fail.
;
;   INPUTS: - DL contains the byte.
;
;  OUTPUTS: - Carry flag, clear (NC) = SUCCESS, set (C) = ERROR
;           - If data or parity error, the segment of the failing address is in variable 'BadAddrSegment'.
;           - If data or parity error, the offset of the failing address is in variable 'BadAddrOffset'.
;           - If data or parity error, the pattern of bad data bits (a byte) and parity bit indicator (a byte) are stored at [ss:BadDataParity]
;
; DESTROYS: AX, BX, CX, DI, DL, ES
;
; ****************************************************************************
TestRamWithByte:

	; Calculate the number of 16 KB blocks to read.
	; Put into BX.
	mov	word bx,[ss:SegTopOfRam]	; Get top of RAM as a segment (e.g. A000h corresponds to 640 KB)(e.g. 0400h corresponds to 16 KB).
	mov	cl,10			; 2^10 = 1024
	shr	bx,cl			; Divide by 1024 to get count of 16 KB blocks to test (e.g. A000h corresponds to 40 [28h] blocks).

	; Starting segment is 0000.
	xor	ax,ax
	mov	es,ax

.L10:	; In the bottom right corner, display the address of the 16 KB block that we are about to test.
	push	dx
	mov	dx,0
	call	DispEsDxInBrCorner	; { Destroys: nothing }
	pop	dx			; get back DL (the byte to look for).
	;
	; Read the 16 KB sized block at segment in ES.
	mov	si,0
.L15:	mov	al,byte [es:si]
	cmp	al,dl
	je	.S10			; --> compare good
	; Failure
	; For the caller, store the segment and offset of the address, and the bad data bits.
	mov	word [ss:BadAddrSegment],es
	mov	word [ss:BadAddrOffset],si
	xor	al,dl
	mov	ah,0
	xchg	al,ah			; bad bit pattern into AH, 0 into AL.
	mov	word [ss:BadDataParity],ax
	stc				; Set carry flag to indicate ERROR.
	ret

.S10:	inc	si
	cmp	si,4000h
	jb	.L15			; --> not all 16 KB done yet

	; Point to segment of next 16 KB block address.
	mov	ax,es
	add	ax,0400h
	mov	es,ax

	; If there are more blocks to read, go do them.
	dec	bx			; Decrement our block counter.
	jnz	.L10			; --> if more blocks to do

	; Erase the address in the bottom right corner.
	call	ClearBrCorner

 	; Clear carry flag to indicate SUCCESS.
	clc

	ret

; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------

TestRamSlowRefresh:
; ****************************************************************************
; ON-SCREEN TEST: Displayed is "Testing RAM - Slow Refresh".
; 
; Intended to expose 'weak' chips.

	; Display "Testing RAM - Slow Refresh" in inverse, with an arrow to the left of it.
	mov	si,TxtEmptyLine15	; Line 15: "                                        "
	call	TextToScreen
	mov	si,TxtTestRamSlowRefr	; Line 15: "Testing RAM - Slow Refresh"
	call	TextToScreenInv
	call	ShowArrow

	; Do the delay that we put between on-screen tests.
	call	InterTestDelay

	; Set timer 1 to 2 ms
	; 1.193 MHz / 2355 (933H) = 0.506 kHz = 2 ms
	mov	al,74h			; Timer 1, LSB then MSB, mode 2, binary counter 16-bit
	out	PIT8253_ctrl,al
	mov	al,33h
	out	PIT8253_1,al
	jmp	short $+2		; Delay for I/O.
	mov	al,09h
	out	PIT8253_1,al

	; Do count-down set up
	mov	bp,20			; Initial value.

	; Fill the found RAM with 55h.
	mov	dl,55h
	call	FillRamWithByte		; ( Destroys: AX, BX, CX, DI, ES )

	; Wait 10 seconds.
	mov	bx,10
.L33:	mov	si,TxtTestRamSlowRefr
	mov	ax,31			; 31 chars from the start of "Testing RAM - Slow Refresh"
	mov	dx,bp			; DX := on-screen count-down.
	call	DispDecimal_1		; Display DL in decimal.        { Destroys: nothing }
	call	OneSecDelay		; One second delay              { Destroys: CX, DL }
	dec	bp			; Decrement count-down.
	dec	bx			; Decrement second count.
	jnz	.L33			; -->

	; Read back was what written, expecting 55h.
	mov	dl,55h
	call	TestRamWithByte		; ( Destroys: AX, BX, CX, DI, DL, DS, ES )
	jc	.FAIL			; --> bad compare

	; Fill the found RAM with AAh.
	mov	dl,0AAh
	call	FillRamWithByte

	; Wait 10 seconds.
	mov	bx,10
.L66:	mov	si,TxtTestRamSlowRefr
	mov	ax,31			; 31 chars from the start of "Testing RAM - Slow Refresh"
	mov	dx,bp			; DX := on-screen count-down.
	call	DispDecimal_1		; Display DL in decimal.        { Destroys: nothing }
	call	OneSecDelay		; One second delay              { Destroys: CX, DL }
	dec	bp			; Decrement count-down.
	dec	bx			; Decrement second count.
	jnz	.L66			; -->

	; Read back was what written, expecting AAh.
	mov	dl,0AAh
	call	TestRamWithByte
	jc	.FAIL			; --> bad compare

	jmp	.PASS			; -->

.FAIL:	
	__CHECKPOINT__ 0xBA ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	; Display FAILED, but do NOT remove the arrow.
	mov	si,TxtTestRamSlowRefr
	call	DisplayFailed

	; Display ">> Critical error ...", then display error (address + data) details, then halt the CPU.
	mov	si,TxtTestRamSlowRefr
	jmp	CriticalErrorCond_1

.PASS:	;------------------------
	; Test successful.
	; -----------------------

	; Set DS back to the CS value, because it was changed earlier in this test. (By 'TestRamWithByte')
	mov	ax,cs
	mov	ds,ax

	; Remove the dots (actually the line).
	mov	si,TxtEmptyLine15
	call	TextToScreen

	; Put "Testing  - Slow Refresh" back up.
	mov	si,TxtTestRamSlowRefr
	call	TextToScreen

	; Display PASSED and remove the arrow.
	mov	si,TxtTestRamSlowRefr
	call	DisplayPassedA

	; Erase the address (shown in various formats) that is currently displayed in the bottom right corner of the screen.
	call	ClearBrCorner

	; The CPU interrupt 2 vector (used for NMI) was altered as part of the RAM testing.
	; Set the vector back to pointing to our NMI handler code for an unexpected NMI.
	call	SetUnexpNmi

	; Restore timer 1 back to normal operation.
	mov	al,54h			; Timer 1, LSB only, mode 2, binary counter 16-bit
	out	PIT8253_ctrl,al
	mov	al,12h			; 1.193 MHz / 18 (12H) = 66.3 kHz = 15.1 uS
	out	PIT8253_1,al

	__CHECKPOINT__ 0x3E ;++++++++++++++++++++++++++++++++++++++++

