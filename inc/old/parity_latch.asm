; ---------------------------------------------------------------------------
section_save
section .romdata
; ---------------------------------------------------------------------------
TxtRamParityErr:	db  9,  2, 'RAM parity error latches', 0
; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------

Check8255Par:
; ****************************************************************************
; ON-SCREEN TEST: Displayed is "RAM parity error latches".
;
; With the two 'RAM parity error' latches disabled, both latches are expected to be in a clear state.
; There is a problem if either read in a set state (could be the latches, could be the 8255, etc.)

	; Display "RAM parity error latches" in inverse, with an arrow to the left of it.
	mov	si,TxtRamParityErr
	call	TextToScreenInv
	call	ShowArrow

	; Do the delay that we put between on-screen tests.
	call	InterTestDelay

	; Reset/clear and disable the two 'RAM parity error' latches.
	in	al,PPI8255_B
	or	al,00110000b		; Set 8255 pins PB5 and PB4.
	jmp	short $+2		; delay for I/O
	jmp	short $+2		; delay for I/O
	out	PPI8255_B,al

	; Delay
	xor	cx,cx
	loop	$

	; Neither latch should be indicating a parity error.
	in	al,PPI8255_C
	and	al,11000000b		; Are either bits 7 and 6 on 8255 port C in a set state ?
	jz	.PASS			; --> if no

.FAIL:	
	__CHECKPOINT__ 0xA7 ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	; Display FAILED, update the test's error counter, and remove the arrow.
	mov	si,TxtRamParityErr
	mov	bx,Err8255Parity
	call	DisplayFailedA

	jmp	.EXIT			; -->

.PASS:	;------------------------
	; Test successful.
	; -----------------------
	; Display PASSED and remove the arrow.
	mov	si,TxtRamParityErr
	call	DisplayPassedA


.EXIT:
	__CHECKPOINT__ 0x2A ;++++++++++++++++++++++++++++++++++++++++
