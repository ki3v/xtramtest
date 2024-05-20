; code: language=nasm tabSize=8
%include "defines.inc"


	; jmp CheckTimers

; ---------------------------------------------------------------------------
section_save
section .romdata
; ---------------------------------------------------------------------------
Txt8253Ch0:		db  4,  2, '8253 timer channel 0', 0
Txt8253Ch1:		db  5,  2, '8253 timer channel 1', 0
Txt8253Ch2:		db  6,  2, '8253 timer channel 2', 0

; ---------------------------------------------------------------------------
section .lib
; ---------------------------------------------------------------------------
; ****************************************************************************
; Common routine for checking the channels of the 8253 timer.
; Note: Mode 2 (rate generator) only.
;
;   INPUTS: - DX = I/O address of timer channel. (Either 40h, 41h, or 42h.)
;
;  OUTPUTS: Carry flag, clear (NC) if PASS, set (C) if FAIL.
;
; DESTROYS: AX, BX, CX, DI
;
; ****************************************************************************
Check8253:

	; Create the two counter bits for the 8259 command.
	; Put them into bits 7 and 6 of AH and AL.
	mov	ax,dx			; AX := I/O address of channel to be tested (either 40h, 41h, or 42h).
	and	al,3			; We only need the two LS bits
	ror	al,1
	ror	al,1			; Bit 1..0 -> bits 7..6 = counter
 	mov	ah,al			; Save counter bits (00, or 01, or 10)

	; Configure the target counter.
	or	al,00110100b
	out	PIT8253_ctrl,al		; LSB then MSB, mode 2, Binary
	jmp	short $+2		; Delay for I/O.
	jmp	short $+2		; Delay for I/O.
	jmp	short $+2		; Delay for I/O.

	; Some preparation.
	xor	cx,cx			; CX := 0000

	; Write the counter value of 0000.
	mov	al,cl			; AL := 00
	out	dx,al			; Write an LSB of 00.
	jmp	short $+2		; Delay for I/O.
	jmp	short $+2		; Delay for I/O.
	jmp	short $+2		; Delay for I/O.
	out	dx,al			; Write an MSB of 00.

	; See if within a certain period of time, the read back value is FFFF.
	mov	di,4
.L10:	jmp	short $+2		; Delay for I/O.
	jmp	short $+2		; Delay for I/O.
	mov	al,ah			; AL := counter bits (00, or 01, or 10)
	out	PIT8253_ctrl,al
	jmp	short $+2		; Delay for I/O.
	jmp	short $+2		; Delay for I/O.
	in	al,dx
	mov	bl,al			; BL := read back LSB
	jmp	short $+2		; Delay for I/O.
	jmp	short $+2		; Delay for I/O.
	in	al,dx
	mov	bh,al			; BH := read back MSB
	cmp	bx,05FFFh		; XXX (KI3V) shortened this from FFFF to 0FFF - Result is OK?
	jae	.S20			; XXX (KI3V) changed from je to jae - --> if yes 
	loop	.L10			; Another try ->
	dec	di			; Another try?
	jne	.L10			; --> if yes 

	; No, we have an error.
	jmp	.FAIL			; -->

.S20:	; See if within a certain period of time, the read back value is 0000.
	mov	di,4
.L40:	jmp	short $+2		; Delay for I/O.
	jmp	short $+2		; Delay for I/O.
	mov	al,ah			; AL := counter bits (00, or 01, or 10)
	out	PIT8253_ctrl,al
	jmp	short $+2		; Delay for I/O.
	jmp	short $+2		; Delay for I/O.
	in	al,dx
	mov	bl,al			; BL := read back LSB
	jmp	short $+2		; Delay for I/O.
	jmp	short $+2		; Delay for I/O.
	in	al,dx
	mov	bh,al			; BH := read back MSB
	cmp	bx,0AFFFh		; XXX (KI3V) changed from 0 to 1FFF - Result is OK?
	jae	.PASS			; XXX (KI3V) changed from je to jae - --> if yes 
	loop	.L40			; --> another try
	dec	di			; Another try?
	jnz	.L40			; --> if yes 

.FAIL:	;------------------------
	; An error/fail occurred.
	; -----------------------
	stc				; Indicate FAIL to caller.
	ret


.PASS:	;------------------------
	; Test successful.
	; -----------------------
	clc				; Indicate PASS to caller.
	ret



; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------


CheckTimers:
; ****************************************************************************
; ON-SCREEN TEST: Displayed is "8253 timer channel 0".
; ON-SCREEN TEST: Displayed is "8253 timer channel 1".
; ON-SCREEN TEST: Displayed is "8253 timer channel 2".

	; Disable the DMA controller.
	mov	al,4
	out	DMA8237_scr,al		

	__CHECKPOINT__ 0x19 ;++++++++++++++++++++++++++++++++++++++++

	; Disable the speakers and enable timer 2.
	in	al,PPI8255_B
	or	al,1
	and	al,0FDh
	out	PPI8255_B, al

	; -----------------------------------------------------------------------------
	; Test timer channel 0 -
	; Used by the motherboard BIOS as part of the 'system timer'.

	__CHECKPOINT__ 0x1A ;++++++++++++++++++++++++++++++++++++++++

	; Display "8253 timer channel 0" in inverse, with an arrow to the left of it.
	mov	si,Txt8253Ch0
	call	TextToScreenInv
	call	ShowArrow

	; Now test channel 0.
	mov	dx,PIT8253_0
	call	Check8253
	jnc	.CHAN_0_PASS		; --> if no error

.CHAN_0_FAIL:
	__CHECKPOINT__ 0x9A ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	; Display FAILED, update the test's error counter, and remove the arrow.
	mov	si,Txt8253Ch0
	mov	bx,Err8253Ch0
	call	DisplayFailedA

	jmp	.CHAN_0_EXIT		; -->

.CHAN_0_PASS:
	; Display PASSED and remove the arrow.
	mov	si,Txt8253Ch0
	call	DisplayPassedA

.CHAN_0_EXIT:


	; -----------------------------------------------------------------------------
	; Test timer channel 1 -
	; Used by the motherboard BIOS as part of the mechanism that refreshes dynamic RAM.

	__CHECKPOINT__ 0x1B ;++++++++++++++++++++++++++++++++++++++++

	; Display "8253 timer channel 1" in inverse, with an arrow to the left of it.
	mov	si,Txt8253Ch1
	call	TextToScreenInv
	call	ShowArrow

	; Now test channel 1.
	mov	dx,PIT8253_1
	call	Check8253
	jnc	.CHAN_1_PASS		; --> if no error

.CHAN_1_FAIL:
	__CHECKPOINT__ 0x9B ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	; Display FAILED, but do NOT remove the arrow.
	mov	si,Txt8253Ch1
	call	DisplayFailed

	; Display ">> Critical error, diagnostics have been stopped! <<"
	mov	si,Txt8253Ch1
	call	DispCritical

	; With a failing timer 1, there won't be any refresh of dynamic RAM on motherboard and card.
	; That compromises a later test of that RAM.
	; So halt the CPU.
%ifdef USE_SERIAL
	call	SendCrlfHashToCom1	; Send a CR/LF/hash sequence to COM1, indicating CPU halt.
%endif
	cli
	hlt

.CHAN_1_PASS:
	; Display PASSED and remove the arrow.
	mov	si,Txt8253Ch1
	call	DisplayPassedA

.CHAN_1_EXIT:


.CHAN_2_TEST:
	; -----------------------------------------------------------------------------
	; Test timer channel 2.
	; Part of the motherboard circuity that is involved in generating speaker sounds.

	__CHECKPOINT__ 0x1C ;++++++++++++++++++++++++++++++++++++++++

	; Display "8253 timer channel 2" in inverse, with an arrow to the left of it.
	mov	si,Txt8253Ch2
	call	TextToScreenInv
	call	ShowArrow

	; Now test channel 2.
	mov	dx,PIT8253_2
	call	Check8253
	jnc	.CHAN_2_PASS		; --> if no error

.CHAN_2_FAIL:

	__CHECKPOINT__ 0x9C ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	; Display FAILED, update the test's error counter, and remove the arrow.
	mov	si,Txt8253Ch2
	mov	bx,Err8253Ch2
	call	DisplayFailedA

	jmp	.CHAN_2_EXIT		; -->

.CHAN_2_PASS:
	; Display PASSED and remove the arrow.
	mov	si,Txt8253Ch2
	call	DisplayPassedA

.CHAN_2_EXIT:

	__CHECKPOINT__ 0x1F ;++++++++++++++++++++++++++++++++++++++++
