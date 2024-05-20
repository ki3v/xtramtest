; ---------------------------------------------------------------------------
section_save
section .romdata
; ---------------------------------------------------------------------------
TxtEmptyLine12:		db 12,  0, '                                        ', 0
TxtTestRamData:		db 12,  2, 'Testing RAM - Data', 0
; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------

TestRamData:
; ****************************************************************************
; ON-SCREEN TEST: Displayed is "Testing RAM - Data".
; 
; Now test the found RAM, including the first 2 KB.
; Use the same technique as the 2 KB RAM test.
; If a test address is found faulty, report details, then halt the CPU.

	; Display "Testing RAM - Data" in inverse, with an arrow to the left of it.
	mov	si,TxtEmptyLine12	; Line 12: "                                        "
	call	TextToScreen
	mov	si,TxtTestRamData	; Line 12: "Testing RAM - Data"
	call	TextToScreenInv
	call	ShowArrow

	; Do the delay that we put between on-screen tests.
	call	InterTestDelay

	; For the progress dots, calculate the offset into MDA/CGA video RAM.
	; Store in DI.
	mov	si,TxtTestRamData	; Line 12: "Testing RAM - Data"
	mov	al,[cs:si]
	xor	ah,ah
	mov	ch,160
	mul	ch
	mov	di,ax			; DI (offset in MDA/CGA video RAM) now at start of line on screen.
	add	di,42			; DI now at position where first dot to be displayed.

	; Calculate the number of 16 KB blocks that we will be testing.
	; Put into BX.
	mov	word bx,[ss:SegTopOfRam]	; Get top of RAM as a segment (e.g. A000h corresponds to 640 KB)(e.g. 0400h corresponds to 16 KB).
	mov	cl,10			; 2^10 = 1024
	shr	bx,cl			; Divide by 1024 to get count of 16 KB blocks to test (e.g. A000h corresponds to 40 [28h] blocks).
	;
	; Other preparation.
	xor	ax,ax
	mov	es,ax			; ES := segment of first test RAM address, which is 0000.
	mov	bp,0			; Zero our dot count.
	;
	; Do one dot now.
	mov	ax,8700h+254		; Blinking dot character.
	mov	[ss:di],ax		; Display the dot.
	inc	bp			; Increment our dot counter.

.L50:	; Display the block count-down.
	mov	si,TxtTestRamData
	mov	ax,31			; 31 chars from the start of "Testing RAM - Data"
	mov	dx,bx			; DX := block count-down.
	call	DispDecimal_1		; Display DL in decimal.        { Destroys: nothing }

	; In the bottom right corner, display the address of the 16 KB block that we are about to test.
	mov	dx,0
	call	DispEsDxInBrCorner	; { Destroys: nothing }

	; Test the 16 KB sized block.
	mov	cx,4000h		; 16 KB sized block : a byte count required for TESTRAMBLOCK : 4000H bytes = 16384 bytes = 16 KB
	call	TESTRAMBLOCK		; Test block at ES, sized at CX.   ( Destroys: SI, AX, CX, DX )
	jc	.FAIL			; --> if TESTRAMBLOCK reported an error

	; At this point, the 16 KB block was tested good.
	; Display a progress dot.
	add	di,2			; Next dot position.
	mov	ax,8700h+254		; Blinking dot character.
	mov	[ss:di],ax		; Display the dot.
	inc	bp			; Increment our dot counter.

	; If 11 dots displayed, reset back to one dot.
	cmp	bp,11
	jb	.S10			; --> if less than 11
	mov	ax,0700h+' '		; Space character.
	mov	cx,10			; 10 characters (leave one dot in place).
.L52:	mov	[ss:di],ax		; Display the space.
	sub	di,2			; Go back one character position.
	dec	bp			; Decrement our dot counter.
	loop	.L52

.S10:	; Point to segment of next 16 KB block address.
	mov	ax,es
	add	ax,400h
	mov	es,ax

	; If there are more blocks to do, go do them.
	dec	bx			; Decrement our block counter.
	jnz	.L50			; --> if more blocks to do
	jmp	.PASS			; -->

.FAIL:	
	__CHECKPOINT__ 0xB5 ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	; Display FAILED, but do NOT remove the arrow.
	mov	si,TxtTestRamData
	call	DisplayFailed

	; Display ">> Critical error ...", then display error (address + BEP) details, then halt the CPU.
	mov	si,TxtTestRamData
	jmp	CriticalErrorCond_1

.PASS:	;------------------------
	; Test successful.
	; -----------------------

	; Remove the dots (actually the line).
	mov	si,TxtEmptyLine12
	call	TextToScreen

	; Put "Testing  - Data" back up.
	mov	si,TxtTestRamData
	call	TextToScreen

	; Display PASSED and remove the arrow.
	mov	si,TxtTestRamData
	call	DisplayPassedA

	; Erase the address (shown in various formats) that is currently displayed in the bottom right corner of the screen.
	call	ClearBrCorner

	; The CPU interrupt 2 vector (used for NMI) was altered as part of the RAM testing.
	; Set the vector back to pointing to our NMI handler code for an unexpected NMI.
	call	SetUnexpNmi


	__CHECKPOINT__ 0x37 ;++++++++++++++++++++++++++++++++++++++++


