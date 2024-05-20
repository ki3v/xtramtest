; ---------------------------------------------------------------------------
section_save
section .romdata
; ---------------------------------------------------------------------------
TxtHotTimer1:		db  8,  2, 'Hot timer channel 1', 0
; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------

CheckHotTimer1:
; ****************************************************************************
; * ON-SCREEN TEST: Displayed is "Hot timer channel 1".
; *
; * Look for a 'hot timer 1'.
; * This check is one that the POST in an IBM 5160 does.
; * Done by seeing if the 8237 DMA controller is seeing a HIGH on its 'DREQ 0' pin (pin 19).

	; Display "Hot timer channel 1" in inverse, with an arrow to the left of it.
	mov	si,TxtHotTimer1
	call	TextToScreenInv
	call	ShowArrow

	; Do the delay that we put between on-screen tests.
	call	InterTestDelay

	in	al,DMA8237_scr		; Status command register
	and	al, 00010000b		; DREQ0 pin is HIGH ?
	jz	.PASS			; --> if no

.FAIL:	
	__CHECKPOINT__ 0xA5 ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	; Display FAILED, update the test's error counter, and remove the arrow.
	mov	si,TxtHotTimer1
	mov	bx,ErrHotTimer1
	call	DisplayFailedA

	jmp	.EXIT			; -->

.PASS:	;------------------------
	; Test successful.
	; -----------------------

	; Display PASSED and remove the arrow.
	mov	si,TxtHotTimer1
	call	DisplayPassedA

	__CHECKPOINT__ 0x26 ;++++++++++++++++++++++++++++++++++++++++

.EXIT:

