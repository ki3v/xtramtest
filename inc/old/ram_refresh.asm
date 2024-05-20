%ifndef REFRESH_DELAY
%define REFRESH_DELAY 90
%endif

; ---------------------------------------------------------------------------
section_save
section .romdata
; ---------------------------------------------------------------------------
TxtEmptyLine14:		db 14,  0, '                                        ', 0
TxtTestRamRefr:		db 14,  2, 'Testing RAM - Refresh', 0
; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------

TestRamRefr:
; ****************************************************************************
; ON-SCREEN TEST: Displayed is "Testing RAM - Refresh".
; 
; Verify that test values written to RAM are not damaged when they are read back 90 seconds later.
; 
; This test is designed to cater for the fact that a fault could result in some RAM banks being refreshed and not others.
; 
; SUBTEST 2 of the previous test had written a unique block number to the first word of each 1 KB sized block.
; We will take advantage of that.
;    Step 1: Wait 90 seconds.
;    Step 2: Verify that the unique block numbers written by SUBTEST 2 are still intact.
;
;
;  NOTE: The figure of 90 seconds is based on a motherboard owned by modem7 of the Vintage Computer Forums.
;        It is an IBM 5160 motherboard of type 256-640KB.
;        Experimentation shows that with RAM refresh disabled, RAM holds its contents for between 60 and 70 seconds.
;        90 seconds allows for a buffer, and the fact that someone may have a motherboard that holds contents for a little longer.

	; Display "Testing RAM - Refresh" in inverse, with an arrow to the left of it.
	mov	si,TxtEmptyLine14	; Line 14: "                                        "
	call	TextToScreen
	mov	si,TxtTestRamRefr	; Line 14: "Testing RAM - Refresh"
	call	TextToScreenInv
	call	ShowArrow

	; Do the delay that we put between on-screen tests.
	call	InterTestDelay

	; ---------------------------------------------------
	; 90 second delay, with progress dots being displayed.
	; ---------------------------------------------------
	; For the progress dots, calculate the offset into MDA/CGA video RAM.
	; Store in DI.
	mov	si,TxtTestRamRefr	; Line 14: "Testing RAM - Refresh"
	mov	al,[cs:si]
	xor	ah,ah
	mov	ch,160
	mul	ch
	mov	di,ax			; DI (offset in MDA/CGA video RAM) now at start of line on screen.
	add	di,48			; DI now at position where first dot to be displayed.
	;
	; Other preparation.
	mov	bp,0			; Zero our dot count.
	mov	bx,REFRESH_DELAY	; We will be waiting 90 seconds.
	;
	; Do one dot now.
	mov	ax,8700h+254		; Blinking dot character.
	mov	[ss:di],ax		; Display the dot.
	inc	bp			; Increment our dot counter.

.L50:	; Display the second count-down.
	mov	si,TxtTestRamRefr
	mov	ax,31			; 31 chars from the start of "Testing RAM - Address"
	mov	dx,bx			; DX := second count-down.
	 call	DispDecimal_1		; Display DL in decimal.        { Destroys: nothing }

	; Wait one second.
	call	OneSecDelay		; { Destroys: CX, DL }

	; Display a progress dot.
	add	di,2			; Next dot position.
	mov	ax,8700h+254		; Blinking dot character.
	mov	[ss:di],ax		; Display the dot.
	inc	bp			; Increment our dot counter.

	; If 8 dots displayed, reset back to one dot.
	cmp	bp,8
	jb	.S70			; --> if less than 8
	mov	ax,0700h+' '		; Space character.
	push	cx
	mov	cx,7			; 7 characters (leave one dot in place)
.L60:	mov	[ss:di],ax		; Display the space.
	sub	di,2			; Go back one character position.
	dec	bp			; Decrement our dot counter.
	loop	.L60
	pop	cx

	; If there are more seconds to wait, go do them.
.S70:	dec	bx			; Decrement our second counter.
	jnz	.L50			; --> if more seconds to do

	; ---------------------------------------------------
	; 90 seconds have passed.
	; Now read back the unique numbers, seeing how they compare to what was written.
	; ---------------------------------------------------
	mov	word bx,[ss:SegTopOfRam]	; Get top of RAM as a segment (e.g. A000h corresponds to 640 KB)(e.g. 0400h corresponds to 16 KB).
	mov	cl,6			; 2^6 = 64
	shr	bx,cl			; Divide by 64 to get count of 1 KB blocks to test (e.g. A000h corresponds to 640 [0280h] blocks).
	mov	cx,bx			; CX will be the count of 1 KB blocks.
	;
	xor	dx,dx
	mov	es,dx			; Starting segment is 0.
.L70:	mov	word ax,[es:0]		; Read back the unique number (which is a block number).
	cmp	ax,cx			; As expected ?
	jne	.FAIL			; --> if not
	mov	ax,es
	add	ax,0040h		; Point to segment of next 1 KB block.
	mov	es,ax
	loop	.L70			; loop until all 1K blocks done.
	jmp	.PASS			; -->

.FAIL:	
	__CHECKPOINT__ 0xB9 ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


	; Record the failing address.	
	mov	word [ss:BadAddrSegment],es	; Save segment of address in error.
	mov	word [ss:BadAddrOffset],0	; Save  offset of address in error.

	; Display FAILED, but do NOT remove the arrow.
	mov	si,TxtTestRamRefr
	call	DisplayFailed

	; Display ">> Critical error ...", then display address details, then halt the CPU.
	mov	si,TxtTestRamRefr
	jmp	CriticalErrorCond_2

.PASS:	;------------------------
	; Test successful.
	; -----------------------

	; Remove the dots (actually the line).
	mov	si,TxtEmptyLine14
	call	TextToScreen

	; Put "Testing RAM - Refresh" back up.
	mov	si,TxtTestRamRefr
	call	TextToScreen

	; Display PASSED and remove the arrow.
	mov	si,TxtTestRamRefr
	call	DisplayPassedA

	; Restore ES (normally points to segment address of MDA/CGA video RAM).
	mov	ax,ss
	mov	es,ax

	__CHECKPOINT__ 0x3A ;++++++++++++++++++++++++++++++++++++++++

