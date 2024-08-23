; code: language=nasm tabSize=8
%include "defines.inc"

; ---------------------------------------------------------------------------
section_save
; ---------------------------------------------------------------------------
section .lib ; MARK: __ .lib __
; ---------------------------------------------------------------------------

; assumes:
;	ss = cs (so romcall and RET will work properly)
; inputs:
;	es = segment to test
;	si = size of segment to test
; output:
;	dh = error bits (0 = no error)
;	es:di = address of the error
; preserves:
;	bx dx si 
;	cs ss ds es
; destroys:
;	ax bp cx di
marchu_nostack:				; perform march-U on a single segment, no stack

		mov	al, 0		; use 0 as the test value
		xor	dh, dh		; clear the error accumulator
		xor	di, di		; count up from start of segment in ES

		; shortcut step: test first byte before writing all of this RAM segment in step 0
		mov	ah, al		; save the comparison value
		mov	[es:di], al	; write the test value
		mov	ah, [es:di]	; read it back
		xor	ah, al		; compare the test value with the byte
		jnz	.done		; if error, break out

		; step 0: up - w0
		cld
		mov	cx, si		; count specified number of bytes
		rep	stosb		; [es:di++] = al; cx--  (fill the range with the test value)


	.step1:	; step 1: up - r0,w1,r1,w0
		xor	di, di		; beginning of the segment
		mov	cx, si		; count specified number of bytes

		; mov	bp, .step2
		bpcall	.r0w1r1w0	; jump to the common code

	.step2:	; step 2: up - r0,w1
		xor	di, di		; beginning of the segment
		mov	cx, si		; count specified number of bytes

		; mov	bp, .step3
		bpcall	.r0w1		; jump to the common code

	.step3:	; step 3: down - r1,w0,r0,w1
		std
		not	al		; now INVERTED
		mov	di, si		; end of the segment
		dec	di		; adjust for the last byte
		mov	cx, si		; count specified number of bytes

		; mov	bp, .step4
		bpcall	.r0w1r1w0	; jump to the common code

	.step4:	; step 4: down - r1,w0
		mov	di, si		; end of the segment
		dec	di		; adjust for the last byte
		mov	cx, si		; count specified number of bytes

		; mov	bp, .done
		bpcall	.r0w1		; jump to the common code

	.done:
		or	dh, ah		; accumulate errors
		cld			; reset the direction flag (go up)
		ret

	.r0w1r1w0:
		; r0
		mov	ah, [es:di]	; read the byte [r0]
		xor	ah, al		; compare the test value with the byte
		jnz	.done		; if error, break out
		; w1
		not	al		; now INVERTED
		mov	[es:di], al	; write the inverted test value [w1]
		; r1
		mov	ah, [es:di]	; read the byte [r1]
		xor	ah, al		; compare the test value with the byte
		jnz	.done		; if error, break out
		; w0
		not	al		; now ORIGINAL
		stosb			; write the test value [w0], inc di
		loop	.r0w1r1w0	; repeat for the next byte

		bpret			; continue with the next step


	.r0w1:
		; r0
		mov	ah, [es:di]	; read the byte [r0]
		xor	ah, al		; compare the test value with the byte
		jnz	.done		; if error, break out
		; w1
		not	al		; now INVERTED
		stosb			; write the test value [w1], inc di
		not	al		; now ORIGINAL
		loop	.r0w1		; repeat for the next byte

		bpret			; continue with the next step



; ---------------------------------------------------------------------------
section_restore ; MARK: __ restore __
; ---------------------------------------------------------------------------
