; code: language=nasm tabSize=8
%include "defines.inc"


; ---------------------------------------------------------------------------
section_save
section .romdata
; ---------------------------------------------------------------------------
Txt8237DMA:		db  7,  2, '8237A DMA controller', 0
; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------


Check8237DMA:
; ****************************************************************************
; ON-SCREEN TEST: Displayed is "8237A DMA controller".
;
; Do a read/write test of the first 8 registers of the 8237A DMA controller chip.

	; Display "8237A DMA controller" in inverse, with an arrow to the left of it.
	mov	si,Txt8237DMA
	call	TextToScreenInv
	call	ShowArrow

	; Do the delay that we put between on-screen tests.
	call	InterTestDelay

	; Now do the test.

 	cli
	mov	al,0
	out	DMA8237_mc,al		; Stop all DMA activities.
	nop				; Delay for I/O.
	nop				; Delay for I/O.
	nop				; Delay for I/O.
	out	DMA8237_scr,al
	mov	ax,0FF00h
	mov	di,1

.L10:	; Test with value in AX.
	xor	dx,dx
	mov	cx,8

.L20:	; First fill registers 0..7 with the value in AL.
	out	dx,al
	nop			; Delay for I/O.
	nop			; Delay for I/O.
	nop			; Delay for I/O.
	out	dx,al
	inc	dx
	loop	.L20
	xor	si,si		; SI := zero
	xchg	ah,al
	mov	bx,ax

.L24:	; Now test with the value that was original in AH.
	mov	dx,si
	out	dx,al
	nop			; Delay for I/O.
	nop			; Delay for I/O.
	nop			; Delay for I/O.
	out	dx,al
	mov	cx,8
	xor	dx,dx
.L28:	cmp	dx,si		; DX = SI?
	je	.S36		; --> if yes
	in	al,dx
	cmp	al,bh		; Same as the original value?
	je	.S32		; --> if yes = OK, continue
	jmp	.FAIL

.S32:	in	al,dx
	cmp	al,bh		; Same as the original value?
	je	.S40		; --> if yes = OK, continue
	jmp	.FAIL

.S36:	in	al,dx
	cmp	al,bl		; Same as the original value?
	jne	.FAIL		; --> if no error

	in	al,dx
	cmp	al,bl		; Same as the original value?
	jne	.FAIL		; --> if no error

.S40:	inc	dx
	loop	.L28
	mov	dx,si
	mov	al,bh
	out	dx,al
	nop			; Delay for I/O.
	nop			; Delay for I/O.
	nop			; Delay for I/O.
	out	dx,al
	mov	ax,bx
	inc	si
	cmp	si,8		; We tested all eight registers?
	je	.S44		; --> if yes, next phase
	jmp	.L24		; --> next register

.S44:	mov	ax,00FFh
	dec	di		; Did we test with 00FFh already?
	je	.L10		; --> if no test again with new value
	in	al,08h
	nop			; Delay for I/O.
	nop			; Delay for I/O.
	nop			; Delay for I/O.
	in	al,08h
	test	al,0Fh		; Low nibble all zero?
	je	.PASS		; --> if yes

.FAIL:	
	__CHECKPOINT__ 0x9F ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	; Display FAILED, but do NOT remove the arrow.
	mov	si,Txt8237DMA
	call	DisplayFailed

	; Display ">> Critical error, diagnostics have been stopped! <<"
	mov	si,Txt8237DMA
	call	DispCritical

	; Without DMA, the motherboard RAM cannot be refreshed and therefore I halt the diagnostic.
%ifdef USE_SERIAL
	call	SendCrlfHashToCom1	; Send a CR/LF/hash sequence to COM1, indicating CPU halt.
%endif
	cli
	hlt
	
.PASS:	;------------------------
	; Test successful.
	; -----------------------
	; Display PASSED and remove the arrow.
	mov	si,Txt8237DMA
	call	DisplayPassedA

	__CHECKPOINT__ 0x22 ;++++++++++++++++++++++++++++++++++++++++


Init8237DMA:
; ****************************************************************************
; Configure the 8237 DMA controller.
;
; In particular, channel #0 is configured to support the refresh mechanism for dynamic RAM.
; Note that RAM refreshing will not actually start until we later initialise channel #1 on the 8253 timer chip.

	; Stop DMA operations on 8237 DMA controller.
	xor	al,al
	out	DMA8237_mc,al
	jmp	short $+2		; delay for I/O
	jmp	short $+2		; delay for I/O

	; Configure DMA channel #0 (RAM refresh) - Single transfer mode / Address increment / Auto-init / Read transfer
	mov	al,58h
	out	DMA8237_mode,al
	jmp	short $+2		; delay for I/O
	jmp	short $+2		; delay for I/O
	; Configure DMA channel #0 (RAM refresh) - Word count of FFFF hex (65535).
	mov	al,0FFh
	out	DMA8237_0_wc,al
	jmp	short $+2		; delay for I/O
	jmp	short $+2		; delay for I/O
	jmp	short $+2		; delay for I/O
	out	DMA8237_0_wc,al
	jmp	short $+2		; delay for I/O
	jmp	short $+2		; delay for I/O

	; Configure DMA channel #1 - Block verify.
	mov	al,41h
	out	DMA8237_mode,al
	jmp	short $+2		; delay for I/O
	jmp	short $+2		; delay for I/O

	; Configure DMA channel #2 - Block verify.
	mov	al,42h
	out	DMA8237_mode,al
	jmp	short $+2		; delay for I/O
	jmp	short $+2		; delay for I/O

	; Configure DMA channel #3 - Block verify.
	mov	al,43h
	out	DMA8237_mode,al
	jmp	short $+2		; delay for I/O
	jmp	short $+2		; delay for I/O

	; Enable DMA operations on all channels.
	xor	al,al
	out	DMA8237_mask,al
	jmp	short $+2		; delay for I/O
	jmp	short $+2		; delay for I/O
	jmp	short $+2		; delay for I/O

	; Initialize DMA command register with zero.
	out	DMA8237_scr,al

	__CHECKPOINT__ 0x24 ;++++++++++++++++++++++++++++++++++++++++
