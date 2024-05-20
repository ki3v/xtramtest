; code: language=nasm tabSize=8
%include "defines.inc"


; ---------------------------------------------------------------------------
section_save
section .romdata
; ---------------------------------------------------------------------------
TxtUnexpNmi:		db  2,  2, '*** UNEXPECTED NMI ***', 0
; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------


; ****************************************************************************
; See if an interrupt has occurred.
;
;   INPUTS: {nothing}
;
;  OUTPUTS: Carry flag, clear (NC) = interrupt occurred, set (C) = no interrupt
;
; DESTROYS: BL, CX, ES
;
; ****************************************************************************
CheckForINT:

	; CPU - Enable maskable interrupts (the ones that we earlier unmasked).
	sti

	; ES := 0000
	xor	ax,ax
	mov	es,ax

	; See if an interrupt occurred within a certain period of time.
	mov	bl,4			; Delay amount.
.L10:	xor	cx,cx
	loop	$
	cmp	byte [es:IntIsrRecord],0	; Has there been an interrupt?
	jne	.YES			; --> if yes 
	dec	bl
	jnz	.L10

	; No interrupt occurred.
	cli				; CPU - Disable maskable interrupts.
	stc				; For caller, set carry flag to indicate no interrupt.
	ret

	; An interrupt occurred.
.YES:	cli				; CPU - Disable maskable interrupts.
	clc				; For caller, clear carry flag to indicate an interrupt.
	ret	






; ****************************************************************************
; NMI handler for an unexpected NMI.
;
; Step 1: Send the checkpoint of 99h.
; Step 2: Clear the MDA/CGA screen then display '*** UNEXPECTED NMI ***'.
;
; Note that this code could potentially be called very early, before the stack has been set up.
; Therefore, do not assume that the stack has been set up.
;
; Note that if this handler gets called, it indicates that low RAM must be present (i.e. required for the NMI vector).
;
; ****************************************************************************
NmiHandler_2:

	; CPU - Disable maskable interrupts, and set the direction flag to increment.
	cli
	cld

	; For the following, set up the stack in low RAM.
	xor	ax,ax
	mov	ss,ax
	mov	sp,0100h

	; Send checkpoint 99h
	__CHECKPOINT__ 99h

	; Clear the MDA/CGA screen.
	mov	ax,ss
	mov	es,ax			; Point ES to segment address of MDA/CGA video RAM.
	mov	ax,0700h+' '		; Attribute + space
	xor	di,di			; Start at first screen position
	mov	cx,4000			; 4000 words.
	rep	stosw			; STOSW: AX-->[ES:DI], then DI=DI+2

	; Go to the second line and write "*** UNEXPECTED NMI ***"
	; mov	si,TxtUnexpNmi
	; call	TextToScreen

	; Halt the CPU
	cli
	hlt



; ****************************************************************************
; An NMI triggers CPU interrupt 2.
; Point the CPU interrupt 2 vector to our NMI handler for an unexpected NMI.
; ****************************************************************************
SetUnexpNmi:

	xor	ax,ax
	mov	es,ax			; ES := 0000
	mov	di,0008h		; Offset of vector for CPU interrupt 2. (2 x 4 bytes)
	mov	ax,NmiHandler_2
	stosw				; STOSW: AX-->[ES:DI], then DI=DI+2
	mov	ax,cs
	stosw				; STOSW: AX-->[ES:DI], then DI=DI+2
	ret


