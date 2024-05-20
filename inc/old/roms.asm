; ---------------------------------------------------------------------------
section_save
section .romdata
; ---------------------------------------------------------------------------

TxtRomF4000:		db  2, 42, 'Check ROM at F4000', 0
TxtRomF6000:		db  3, 42, 'Check ROM at F6000', 0
TxtRomF8000:		db  4, 42, 'Check ROM at F8000', 0
TxtRomFA000:		db  5, 42, 'Check ROM at FA000', 0
TxtRomFC000:		db  6, 42, 'Check ROM at FC000', 0

; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------

CheckExtraROMs:
; ****************************************************************************
; ON-SCREEN TEST: Displayed is "Check ROM at F4000".
; ON-SCREEN TEST: Displayed is "Check ROM at F6000".
; ON-SCREEN TEST: Displayed is "Check ROM at F8000".
; ON-SCREEN TEST: Displayed is "Check ROM at FA000".
; ON-SCREEN TEST: Displayed is "Check ROM at FC000".
;
; Note: Function 'DoCheck8kbRom' will take care of screen updates.

	cli				; CPU - Disable maskable interrupts

	; ---------------------------------------------------
	; F4000
	; ---------------------------------------------------
	mov	si,TxtRomF4000
	push	si
	call	TextToScreenInv		; Display "Check ROM at F4000" in inverse.
	call	ShowArrow		; Put an arrow to the left of that.
	pop	si

	call	InterTestDelay		; Do the delay that we put between on-screen tests.

	mov	bx,ErrRomF4000		; The address of the error count
	mov	di,0F400h		; F400:0000
	call	DoCheck8kbRom		; Check out the ROM.

	__CHECKPOINT__ 0x61 ;++++++++++++++++++++++++++++++++++++++++

	; ---------------------------------------------------
	; F6000
	; ---------------------------------------------------
	mov	si,TxtRomF6000
	push	si
	call	TextToScreenInv		; Display "Check ROM at F6000" in inverse.
	call	ShowArrow		; Put an arrow to the left of that.
	pop	si

	call	InterTestDelay		; Do the delay that we put between on-screen tests.

	mov	bx,ErrRomF6000		; The address of the error count
	mov	di,0F600h		; F600:0000
	call	DoCheck8kbRom		; Check out the ROM.

	__CHECKPOINT__ 0x62 ;++++++++++++++++++++++++++++++++++++++++

	; ---------------------------------------------------
	; F8000
	; ---------------------------------------------------
	mov	si,TxtRomF8000
	push	si
	call	TextToScreenInv		; Display "Check ROM at F8000" in inverse.
	call	ShowArrow		; Put an arrow to the left of that.
	pop	si

	call	InterTestDelay		; Do the delay that we put between on-screen tests.

	mov	bx,ErrRomF8000		; The address of the error count
	mov	di,0F800h		; F800:0000
	call	DoCheck8kbRom		; Check out the ROM.

	__CHECKPOINT__ 0x63 ;++++++++++++++++++++++++++++++++++++++++

	; ---------------------------------------------------
	; FA000
	; ---------------------------------------------------
	mov	si,TxtRomFA000
	push	si
	call	TextToScreenInv		; Display "Check ROM at F8000" in inverse.
	call	ShowArrow		; Put an arrow to the left of that.
	pop	si

	call	InterTestDelay		; Do the delay that we put between on-screen tests.

	mov	bx,ErrRomFA000		; The address of the error count
	mov	di,0FA00h		; FA00:0000
	call	DoCheck8kbRom		; Check out the ROM.

	__CHECKPOINT__ 0x64 ;++++++++++++++++++++++++++++++++++++++++

	; ---------------------------------------------------
	; FC000
	; ---------------------------------------------------
	mov	si,TxtRomFC000
	push	si
	call	TextToScreenInv		; Display "Check ROM at FC000" in inverse.
	call	ShowArrow		; Put an arrow to the left of that.
	pop	si

	call	InterTestDelay		; Do the delay that we put between on-screen tests.

	mov	bx,ErrRomFC000		; The address of the error count
	mov	di,0FC00h		; FC00:0000
	call	DoCheck8kbRom		; Check out the ROM.


	__CHECKPOINT__ 0x6A ;++++++++++++++++++++++++++++++++++++++++

