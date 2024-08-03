; code: language=nasm tabSize=8

	; March RAM test algorithm:
	; step 0; up - w0 - write the test value
	; step 1; up - r0,w1,r1,w0
	; step 2; up - r0,w1
	; step 3; down - r1,w0,r0,w1
	; step 4; down - r1,w0


%include "defines.inc"

; [map all]


; ---------------------------------------------------------------------------
section_save
; ---------------------------------------------------------------------------
section .text
; ---------------------------------------------------------------------------

; 		; XXX - test the stack march
; 		mov	bx, 0x4000	; start at segment 0x3000
; 		mov	dl, 2		; test 2 segments
; 		mov	si, 0x4000	; set the size of the segment to test
; 		call	marchu
; 	.halt:	hlt
; 		jmp	.halt


; 		; XXX - test the stackless march
; 		mov ax, cs		; set the data segment to the code segment
; 		mov ss, ax		; so our fake stack returns work
; 		mov ax, 0x3000		; test a small amount of RAM here
; 		mov es, ax
; 		mov si, 0x10

marchu_nostack:
; perrom march-U on a single segment, no stack
; assumes:
;	ss = cs (so ss_call and RET will work properly)
; inputs:
;	al = test value
;	es = segment to test
;	si = size of segment to test
; output:
;	ah = error bits (0 = no error)
;	es:di = address of the error
; preserves:
;	si bx dx
;	cs ss ds

		; step 0: up - w0
		mov	al, 0
		cld
		xor	di, di
		mov	cx, si
		rep	stosb		; [es:di++] = al; cx--  (fill the range with the test value)

		; step 1: up - r0,w1,r1,w0
		xor	di, di		; beginning of the segment
		mov	cx, si
		ss_call	marchu_r0w1r1w0
		or	ah, ah		; check for errors
		jnz	.FAIL		; if there are errors, we fail

		; step 2: up - r0,w1
		xor	di, di		; beginning of the segment
		mov	cx, si
		ss_call	marchu_r0w1
		or	ah, ah		; check for errors
		jnz	.FAIL		; if there are errors, we fail

		; step 3: down - r1,w0,r0,w1
		std
		not	al		; now INVERTED
		mov	di, si		; end of the segment
		dec	di		; adjust for the last byte
		mov	cx, si
		ss_call	marchu_r0w1r1w0

		; step 4: down - r1,w0
		mov	di, si		; end of the segment
		dec	di		; adjust for the last byte
		mov	cx, si
		ss_call	marchu_r0w1

	.PASS:	jmp	.DONE

	.FAIL:				; report failure
		; ah = error bits
		; es:di = address of the error
		hlt
		jmp	.FAIL
	.DONE:

section_restore