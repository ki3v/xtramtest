; ---------------------------------------------------------------------------
section_save
section .romdata
; ---------------------------------------------------------------------------
TxtEmptyLine13:		db 13,  0, '                                        ', 0
TxtTestRamAddr:		db 13,  2, 'Testing RAM - Address', 0
; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------

TestRamAddr:
; ****************************************************************************
; ON-SCREEN TEST: Displayed is "Testing RAM - Address".
; 
; ( See the following URL for an explantion of an addressing problem:
;   https://minuszerodegrees.net/memory/Addressing%20problem/Memory%20addressing%20problem.htm )
; 
; If a test address is found faulty, report details, then halt the CPU.
;
; Divided into two subtests.
;
; SUBTEST 1
;
; The first subtest uses the same code that IBM uses in the IBM 5160. That way, if the IBM BIOS ROM detected
; a RAM addressing problem, then so should SUBTEST 1.
; Done in 16 KB sized blocks, just like what the IBM BIOS ROM does.
; In this code, the IBM code is routine STGTST_CNT, copied from the source listing of the IBM BIOS ROM for the 5160.
; However, because the IBM code only address tests within each 16 KB block, that is only a partial addressing test.
;
; SUBTEST 2
;
; The second subtest expands on the first.
; For example, in most cases (not all), it will throw an error if a 4164 type RAM chip has been accidentally put into a socket that requires a 41256 type.
; Divide all RAM into 1 KB blocks. At the first address of each block, write a word that is unique to the block number.
; Then read back all written words, verifying that each one matches with what was written.

	; Display "Testing RAM - Address" in inverse, with an arrow to the left of it.
	mov	si,TxtEmptyLine13	; Line 13: "                                        "
	call	TextToScreen
	mov	si,TxtTestRamAddr	; Line 13: "Testing RAM - Address"
	call	TextToScreenInv
	call	ShowArrow

	; Do the delay that we put between on-screen tests.
	call	InterTestDelay

	;----------------
	; SUBTEST 1 OF 2
	; ---------------
.TEST1:	; For the progress dots, calculate the offset into MDA/CGA video RAM.
	; Store in DI.
	mov	si,TxtTestRamAddr	; Line 13: "Testing RAM - Address"
	mov	al,[cs:si]
	xor	ah,ah
	mov	ch,160
	mul	ch
	mov	di,ax			; DI (offset in MDA/CGA video RAM) now at start of line on screen .
	add	di,48			; DI now at position where first dot to be displayed.
	; Calculate the number of 16 KB blocks we will be testing.
	; Put into BX.
	mov	word bx,[ss:SegTopOfRam]	; Get top of RAM as a segment (e.g. A000h corresponds to 640 KB)(e.g. 0400h corresponds to 16 KB).
	mov	cl,10			; 2^10 = 1024
	shr	bx,cl			; Divide by 1024 to get count of 16 KB blocks to test (e.g. A000h corresponds to 40 [28h] blocks).
	;
	; Other preparation.
	xor	ax,ax
	mov	es,ax			; ES := segment of first test RAM address, which is 0000.  Required by STGTST_CNT
	mov	ds,ax			; DS := segment of first test RAM address, which is 0000.  Required by STGTST_CNT
	mov	bp,0			; Zero our dot count.
	;
	; Do one dot now.
	mov	ax,8700h+254		; Blinking dot character.
	mov	[ss:di],ax		; Display the dot.
	inc	bp			; Increment our dot counter.

.L50:	; Display the block count-down.
	mov	si,TxtTestRamAddr
	mov	ax,31			; 31 chars from the start of "Testing RAM - Address"
	mov	dx,bx			; DX := block count-down.
	call	DispDecimal_1		; Display DL in decimal.        { Destroys: nothing }

	; In the bottom right corner, display the address of the 16 KB block that we are about to test.
	push	ds			; Save DS - what STGTST_CNT relies on.
	mov	ax,cs
	mov	ds,ax			; DispEsDxInBrCorner requires DS pointing to the CS.
	mov	dx,0
	call	DispEsDxInBrCorner	; { Destroys: nothing }
	pop	ds			; Restore DS - what STGTST_CNT relies on.

	; Test the 16 KB sized block. (Using IBM code.)
	push	di
	push	bx
	mov	cx,2000h		; 16 KB sized block : a word count required for STGTST_CNT : 2000H words = 8192 words = 16 KB
	call	STGTST_CNT		; Test block at ES/DS, sized at CX words.   ( Destroys: AX,BX,CX,DX,DI, AND SI )
	pop	bx
	pop	di
	jnz	.FAIL1			; --> if STGTST_CNT reported an error

	; At this point, the 16 KB block was tested good.
	; Display a progress dot.
	add	di,2			; Next dot position.
	mov	ax,8700h+254		; Blinking dot character.
	mov	[ss:di],ax		; Display the dot.
	inc	bp			; Increment our dot counter.

	; If 8 dots displayed, reset back to one dot.
	cmp	bp,8
	jb	.L55			; --> if less than 8
	mov	ax,0700h+' '		; Space character.
	push	cx
	mov	cx,7			; 7 characters (leave one dot in place).
.L52:	mov	[ss:di],ax		; Display the space.
	sub	di,2			; Go back one character position.
	dec	bp			; Decrement our dot counter.
	loop	.L52
	pop	cx

.L55:	; Point to segment of next 16 KB block address.
	mov	ax,es
	add	ax,0400h
	mov	es,ax			; Required by STGTST_CNT.
	mov	ds,ax			; Required by STGTST_CNT.

	; If there are more blocks to do, go do them.
	dec	bx			; Decrement our block counter.
	jnz	.L50			; --> if more blocks to do

	; All blocks done
	mov	ax,cs
	mov	ds,ax			; Restore DS pointing to the CS.
	jmp	.TEST2			; -->

.FAIL1:	mov	ax,cs
	mov	ds,ax			; Restore DS pointing to the CS.

	__CHECKPOINT__ 0xB7 ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	jmp	.FAIL			; -->

	;----------------
	; SUBTEST 2 OF 2
	; ---------------
.TEST2:	; Calculate the number of 1 KB blocks that we will be testing.
	; Put into CX.
	mov	word bx,[ss:SegTopOfRam]	; Get top of RAM as a segment (e.g. A000h corresponds to 640 KB)(e.g. 0400h corresponds to 16 KB).
	mov	cl,6			; 2^6 = 64
	shr	bx,cl			; Divide by 64 to get count of 1 KB blocks to test (e.g. A000h corresponds to 640 [0280h] blocks).
	mov	cx,bx			; CX will be the count of 1 KB blocks.
	mov	bp,cx			; Save for the read back phase.
	;
	; Write out the unique numbers.
	xor	ax,ax
	mov	es,ax			; Starting segment is 0.
.L60:	mov	word [es:0],cx		; Write the unique number (which is a block number in a word).
	mov	ax,es
	add	ax,0040h
	mov	es,ax			; Point to segment of next 1 KB block.
	loop	.L60			; loop until all 1K blocks done.
	;
	; Read back the unique numbers, seeing how they compare to what was written.
	xor	ax,ax
	mov	es,ax			; Starting segment is 0.
	mov	cx,bp			; Get back the count of 1 KB blocks
.L70:	mov	word ax,[es:0]		; Read back the unique number (which is a block number).
	cmp	ax,cx			; As expected ?
	jne	.FAIL2			; --> if not
	mov	ax,es
	add	ax,0040h		; Point to segment of next 1 KB block.
	mov	es,ax
	loop	.L70			; loop until all 1K blocks done.
	jmp	.PASS			; -->

.FAIL2:	
	__CHECKPOINT__ 0xB8 ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!				

	; Indicate that it was SUBTEST 2 that failed.
	mov	word [ss:BadAddrSegment],es	; Save segment of address in error.
	mov	word [ss:BadAddrOffset],0	; Save  offset of address in error.
	xor	ax,cx				; AX := bit error pattern (at this time, a word).
	; AX is the bit error pattern (a word).
	; If both AH and AL are non-zero, that means that both test bytes (written/read as a word) are in error - choose either.
	; Otherwise, the non-zero register is the bit error pattern.
	cmp	ah,0
	jne	.S10				; --> if AH has a one somewhere in its bit error pattern, use AH
	mov	ah,al				; AL has bit error pattern, move into AH
.S10:	mov	al,0				; Indicate no parity error.
	mov	word [ss:BadDataParity],ax	; High_byte={discovered bit error pattern}, low_byte={no parity bit error occured}

.FAIL:	; Display FAILED, but do NOT remove the arrow.
	mov	si,TxtTestRamAddr
	call	DisplayFailed

	; Display ">> Critical error ...", then display error (address + BEP) details, then halt the CPU.
	mov	si,TxtTestRamAddr
	jmp	CriticalErrorCond_1

.PASS:	;------------------------
	; Test successful.
	; -----------------------

	; Remove the dots (actually the line).
	mov	si,TxtEmptyLine13
	call	TextToScreen

	; Put "Testing RAM - Address" back up.
	mov	si,TxtTestRamAddr
	call	TextToScreen

	; Display PASSED and remove the arrow.
	mov	si,TxtTestRamAddr
	call	DisplayPassedA

	; Set DS to the CS value, because it was changed earlier in this test.
	mov	ax,cs
	mov	ds,ax

	; Erase the address (shown in various formats) that is currently displayed in the bottom right corner of the screen.
	call	ClearBrCorner

	; The CPU interrupt 2 vector (used for NMI) was altered as part of the RAM testing.
	; Set the vector back to pointing to our NMI handler code for an unexpected NMI.
	call	SetUnexpNmi

	__CHECKPOINT__ 0x39 ;++++++++++++++++++++++++++++++++++++++++


