; code: language=nasm tabSize=8

	; March RAM test algorithm:
	; step 0; up - w0 - write the test value
	; step 1; up - r0,w1,r1,w0
	; step 2; up - r0,w1
	; step 3; down - r1,w0,r0,w1
	; step 4; down - r1,w0


%include "defines.inc"


marchu_nostack:
; perform march-U on a single segment, no stack
; assumes:
;	ss = cs (so ss_call and RET will work properly)
; inputs:
;	es = segment to test
;	si = size of segment to test
; output:
;	dh = error bits (0 = no error)
;	es:di = address of the error
; preserves:
;	si bx dx
;	cs ss ds

		mov	al, 0		; use 0 as the test value
		xor	dh, dh		; clear the error accumulator
		
		; step 0: up - w0
		cld
		xor	di, di		; count up from start of segment in ES
		mov	cx, si		; count specified number of bytes
		rep	stosb		; [es:di++] = al; cx--  (fill the range with the test value)

		; step 1: up - r0,w1,r1,w0
		xor	di, di		; beginning of the segment
		mov	cx, si		; count specified number of bytes
		ss_call	marchu_r0w1r1w0
		; or	ah, ah		; check for errors
		; jnz	.FAIL		; if there are errors, we fail

		; step 2: up - r0,w1
		xor	di, di		; beginning of the segment
		mov	cx, si		; count specified number of bytes
		ss_call	marchu_r0w1
		; or	ah, ah		; check for errors
		; jnz	.FAIL		; if there are errors, we fail

		; step 3: down - r1,w0,r0,w1
		std
		not	al		; now INVERTED
		mov	di, si		; end of the segment
		dec	di		; adjust for the last byte
		mov	cx, si		; count specified number of bytes
		ss_call	marchu_r0w1r1w0

		; step 4: down - r1,w0
		mov	di, si		; end of the segment
		dec	di		; adjust for the last byte
		mov	cx, si		; count specified number of bytes
		ss_call	marchu_r0w1

		cld			; reset the direction flag (go up)

		; at this point, dh will be non-zero if there were errors


; section_restore