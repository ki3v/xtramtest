; code: language=nasm tabSize=8

	; March RAM test algorithm:
	; step 0; up - w0 - write the test value
	; step 1; up - r0,w1,r1,w0
	; step 2; up - r0,w1
	; step 3; down - r1,w0,r0,w1
	; step 4; down - r1,w0


%include "defines.inc"

BITS 16
CPU 8086

[map all]

%macro ss_call 1
	mov	sp, %%addr
	jmp	%1
	%%addr: dw %%continue
	%%continue:
%endmacro

segment .text

marchu_1seg_nostack: ; XXX this needs to be run inline - nostack
; inputs:
;	al = test value
;	es = segment to test
;	si = size of segment to test

; assumes:
;	ss = cs

		mov	al, 0
		mov	bp, marchu_0	; start of the sequence
	.march_loop:
		or	bp, bp		; are there remaining steps?
		jz	.PASS		; if no, we pass

		ss_call	bp		; jump to the next step
		or	ah, ah		; check for errors
		jnz	.FAIL		; if there are errors, we fail
		jmp	.march_loop	; else continue with the next step

	.PASS:	jmp	.DONE

	.FAIL:				; report failure

	.DONE:



; This version does not try to restart after an error
	; step 0; up - w0 - write the test value
	; step 1; up - r0,w1,r1,w0
	; step 2; up - r0,w1
	; step 3; down - r1,w0,r0,w1
	; step 4; down - r1,w0

; inputs:
;	al = test value
;	es = segment to test
;	si = size of segment to test (feeds cx)
; preserves:
;	sp si bx dx
;	all segment registers
; state registers (saved between continuations):
;	al = test value (inverted at appropriate times)
;	cx = byte counter
;	di = current address under test
;	bp = return address
; output:
;	ah = error bits (0 = no error)
;	es:di = address of the error
;	bp = continuation address (0 when done)

segment .lib

marchu_0:	; up - w0
		cld			; clear direction flag (forward)
		xor	di, di		; beginning of the segment
		mov	cx, si
		rep	stosb		; [es:di++] = al; cx--  (fill the range with the test value)

		xor	ah, ah		; clear error bits
		mov	bp, marchu_1	; next step
		ret

marchu_1:	; up - r0,w1,r1,w0	
		xor	di, di		; beginning of the segment
		mov	cx, si
	.loop:	; r0
		mov	ah, [es:di]	; read the byte [r0]
		xor	ah, al		; compare the test value with the byte
		jz	.b		; OK, continue
		mov	bp, .b		; next step
		ret
	.b:	; w1
		not	al		; now INVERTED
		mov	[es:di], al	; write the inverted test value [w1]
	.c:	; r1
		mov	ah, [es:di]	; read the byte [r1]
		xor	ah, al		; compare the test value with the byte
		jz	.d		; OK, continue
		mov	bp, .d		; next step
		ret
	.d:	; w0
		not	al		; now ORIGINAL
		stosb			; write the test value [w0], inc di
		loop	.loop		; repeat for the next byte

		mov	bp, marchu_2	; next step
		ret			; step done

marchu_2:	; up - r0,w1
		xor	di, di		; beginning of the segment
		mov	cx, si
	.loop:	; r0
		mov	ah, [es:di]	; read the byte [r0]
		xor	ah, al		; compare the test value with the byte
		jz	.b		; OK, continue
		mov	bp, .b		; next step
		ret
	.b:	; w1
		not	al		; now INVERTED
		stosb			; write the test value [w1], inc di
		not	al		; now ORIGINAL
		loop	.loop	; repeat for the next byte

		mov	bp, marchu_3	; next step
		ret			; step done

marchu_3:	; down - r1,w0,r0,w1
		std 			; set direction flag (downward)
		not	al		; now INVERTED
		mov	di, si		; end of the segment
		dec	di		; adjust for the last byte
		mov	cx, si
	.loop:	; r1
		mov	ah, [es:di]	; read the byte [r1]
		xor	ah, al		; compare the test value with the byte
		jz	.b		; OK, continue
		mov	bp, .b		; next step
		ret
	.b:	; w0
		not	al		; now ORIGINAL
		mov	[es:di], al	; write the inverted test value [w0]
	.c:	; r0
		mov	ah, [es:di]	; read the byte [r0]
		xor	ah, al		; compare the test value with the byte
		jz	.d		; OK, continue
		mov	bp, .d		; next step
		ret
	.d:	; w1
		not	al		; now INVERTED
		stosb			; write the test value [w1], dec di
		loop	.loop		; repeat for the next byte (decrement cx)

		mov	bp, marchu_4	; next step
		ret			; step done

marchu_4:	; step 4; down - r1,w0
		mov	di, si		; end of the segment
		dec	di		; adjust for the last byte
		mov	cx, si
	.loop:	; r1
		mov	ah, [es:di]	; read the byte [r0]
		xor	ah, al		; compare the test value with the byte
		jz	.b		; OK, continue
		mov	bp, .b		; next step
		ret
	.b:	; w0
		not	al		; now ORIGINAL
		stosb				; write the test value [w1], inc di
		not	al		; now INVERTED
		loop	.loop		; repeat for the next byte

		xor	bp, bp		; signal done
		ret	

