; ---------------------------------------------------------------------------
section_save
section .romdata
; ---------------------------------------------------------------------------
TxtCheckNMI:		db 19,  2, 'Hot NMI', 0

; ---------------------------------------------------------------------------
section .lib
; ---------------------------------------------------------------------------
; ****************************************************************************
; NMI handler for the "Hot NMI" test.
; ****************************************************************************
NmiHandler_1:

	; Disable NMI interrupts from reaching the CPU.
	xor	ax,ax
	out	PORT_NMI_MASK,al

	; Flag that an NMI happened.
	mov	es,ax
	mov	byte [es:NmiFlag],1

	iret

; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------

CheckNMI:
; ****************************************************************************
; ON-SCREEN TEST: Displayed is "Hot NMI".
;
;  Check the non maskable interrupt.
;
;  This test is is known to fail if either:
;  - Math coprocessor (8087 chip) is absent and switch 2 in switch block SW1 is in the wrong position for that (off).
;  - Math coprocessor (8087 chip) is present and is faulty. 

	; Display "Hot NMI" in inverse, with an arrow to the left of it.
	mov	si,TxtCheckNMI
	call	TextToScreenInv
	call	ShowArrow

	; Do the delay that we put between on-screen tests.
	call	InterTestDelay

	; An NMI triggers CPU interrupt 2.
	; Change the CPU interrupt 2 vector to point to our NMI handler code for this test.
	xor	ax,ax
	mov	es,ax			; ES := 0000
	mov	di,0008h		; Offset of vector for CPU interrupt 2. (2 x 4 bytes)
	mov	ax,NmiHandler_1
	stosw				; STOSW: AX-->[ES:DI], then DI=DI+2
	mov	ax,cs
	stosw				; STOSW: AX-->[ES:DI], then DI=DI+2

	; Clear our NMI recorder/flag.
	mov	byte [es:NmiFlag],0

	; Reset/clear and disable the two 'RAM parity error' latches.
	; Because if either set, that would trigger an NMI.
	in	al,PPI8255_B
	or	al,00110000b		; Done by setting bits 5 and 4 on 8255 port B.
	out	PPI8255_B,al

	; Enable NMI interrupts to reach CPU.
	mov	al,80h
	out	PORT_NMI_MASK,al

	; Delay
	xor	cx,cx
	mov	bx,4
.L10:	loop	.L10
	dec	bx
	jnz	.L10

	; Disable NMI interrupts from reaching the CPU.
	xor	al,al
	out	PORT_NMI_MASK,al

	; Did an NMI occur ?
	; We are not expecting one.
	cmp	byte [es:NmiFlag],0
	je	.PASS			; --> if no

.FAIL:	
; ----------------------------------------------------------------------------
; An interrupt occurred.

	__CHECKPOINT__ 0xC6 ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	; Display FAILED, update the test's error counter, and remove the arrow.
	mov	si,TxtCheckNMI
	mov	bx,ErrNMI
	call	DisplayFailedA

	jmp	.EXIT			; -->

.PASS:	;------------------------
	; Test successful.
	; -----------------------

	; Display PASSED and remove the arrow.
	mov	si,TxtCheckNMI
	call	DisplayPassedA

	; Set CPU interrupt 2 vector (used for NMI) back to pointing to our NMI handler code for an unexpected NMI.
	call	SetUnexpNmi

.EXIT:
	__CHECKPOINT__ 0x4E ;++++++++++++++++++++++++++++++++++++++++

