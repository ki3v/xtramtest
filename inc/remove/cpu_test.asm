; code: language=nasm tabSize=8
%include "defines.inc"



; ---------------------------------------------------------------------------
section_save
section .romdata
; ---------------------------------------------------------------------------
TxtTestCPU:		db  2,  2, 'Testing CPU           ', 0
; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------

; ****************************************************************************
; * ON-SCREEN TEST: Displayed is "Testing CPU".
; ****************************************************************************
TestCPU:

	; Display "Testing CPU" in inverse, with an arrow to the left of it.
	mov	si,TxtTestCPU
	call	TextToScreenInv
	call	ShowArrow

	; Do the delay that we put between on-screen tests.
	call	InterTestDelay

	; ------------------------------------------
	; SUBTEST 1 OF 2: Test the branches/flags.
	; ------------------------------------------
	xor	ax,ax
	jb	.FAIL1
	jo	.FAIL1
	js	.FAIL1
	jnz	.FAIL1
	jpo	.FAIL1

	add	ax,1
	jz	.FAIL1
	jpe	.FAIL1

	sub	ax,8002h
	js	.FAIL1

	inc	ax
	jno	.FAIL1

	shl	ax,1
	jnb	.FAIL1
	jnz	.FAIL1

	shl	ax,1
	jb	.FAIL1

	xor	ax,ax
	jnz	.FAIL1		; Jump if not zero

	add	al,80h
	jns	.FAIL1		; Jump if not sign
	jc	.FAIL1		; Jump if carry Set
	jp	.FAIL1		; Jump if parity=1

	add	al,80h
	jnz	.FAIL1		; Jump if not zero
	jno	.FAIL1		; Jump if not overflw
	jnc	.FAIL1		; Jump if carry=0

	lahf			; Load ah from flags
	or	ah,41h
	sahf			; Store ah into flags
	jnz	.FAIL1		; Jump if not zero
	jnc	.FAIL1		; Jump if carry=0

	xor	si,si		; Zero register
	lodsb			; Copy contents of [SI] into AL, then increment SI.
	dec	si
	or	si,si		; SI = zero?
	jz	.SS2		; --> if yes, all good, on to subtest 2

.FAIL1:	; Indicate failure of SUBTEST 1
; ----------------------------------------------------------------------------
	__CHECKPOINT__ 92h
; ----------------------------------------------------------------------------
	jmp	.FAIL

	; ------------------------------------------
	; SUBTEST 2 OF 2: Test the REGISTERS (except SS and SP).
	; ------------------------------------------

; ----------------------------------------------------------------------------
.SS2:	__CHECKPOINT__ 14h
; ----------------------------------------------------------------------------

	mov	bx,5555h
.L10:	mov	bp,bx
	mov	cx,bp
	mov	dx,cx
	mov	si,dx
	mov	es,si
	mov	di,es
	mov	ds,di
	mov	ax,ds
	cmp	ax,5555h	; AX = 5555h ?
	jne	.S20		; --> if no 

	not	ax		; AX := AAAAh
	mov	bx,ax
	jmp	.L10

.S20:	; Either:
	; 5555h is the test word, and that failed; or
	; AAAAh is the test word, and we have yet to see if that worked.
	xor	ax,0AAAAh	; AX = AAAAh ?
	jz	.PASS		; --> if yes

	; Indicate failure of SUBTEST 2
; ----------------------------------------------------------------------------
	__CHECKPOINT__ 94h
; ----------------------------------------------------------------------------

.FAIL:	;------------------------
	; An error/fail occurred.
	; -----------------------

	; Display FAILED, but do NOT remove the arrow.
	mov	si,TxtTestCPU
	call	DisplayFailed

	; Display ">> Critical error, diagnostics have been stopped! <<"
	mov	si,TxtTestCPU
	call	DispCritical

%ifdef USE_SERIAL
	call	SendCrlfHashToCom1	; Send a CR/LF/hash sequence to COM1, indicating CPU halt.
%endif
	; Halt the CPU
	cli
	hlt


.PASS:	;------------------------
	; Test successful.
	; -----------------------

	; Set DS back to the CS value, because it was changed earlier in this test.
	mov	ax,cs
	mov	ds,ax

	; Display PASSED and remove the arrow.
	mov	si,TxtTestCPU
	call	DisplayPassedA

	; __CHECKPOINT__ 0x16 ;++++++++++++++++++++++++++++++++++++++++
