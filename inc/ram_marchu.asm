; code: language=nasm tabSize=8

	; March RAM test algorithm:
	; step 0; up - w0 - write the test value
	; step 1; up - r0,w1,r1,w0
	; step 2; up - r0,w1
	; step 3; down - r1,w0,r0,w1
	; step 4; down - r1,w0


%include "defines.inc"

%define marchu_startseg startseg
%define marchu_endseg endseg

; ---------------------------------------------------------------------------
section_save ; MARK: __ save __





; ---------------------------------------------------------------------------
section .lib ; MARK: __ .lib __
; ---------------------------------------------------------------------------
; %define MARCHU_DELAY 8

%ifdef MARCHU_DELAY
marchu_delay:
		push	cx
		push	dx

		mov	dl, MARCHU_DELAY
		sub	cx,cx
	.dloop:	loop	.dloop
		dec	dl
		jnz	.dloop

		pop	dx
		pop	cx
		ret
%endif


; ---------------------------------------------------------------------------
; MARK: marchu
; perform march-U on 4k chunks, using stack, with error reporting
; inputs:
;	al = test value
;	bx = start segment
; 	dl = number of segments to test (will test dl*si bytes total)
; 	si = size of segment to test 
; state registers:
;	ah = scratch holding error bits (0 = no error)
;	cx = counter of bytes and segments
;	si = size of segment to test (1000h)
;	es:di = current address under test
; output:
;	ah = error bits at current error (0 = no error)
;	dh = running error bits for current segment
;	es:di = address of the error
marchu:
		xor	al, al			; test value for march is always 0

		mov	[ss:test_num], byte 0
		call	marchu_announce

	.s0:	mov	bp, marchu_w0
		call	ram_test_upwards

		simulate_errors

		call	marchu_announce
	.s1:	mov	bp, marchu_r0w1r1w0
		call	ram_test_upwards

		simulate_errors

		call	marchu_announce
	.s2:	mov	bp, marchu_r0w1
		call	ram_test_upwards
		not	al

		simulate_errors

		call	marchu_announce
	.s3:	mov	bp, marchu_r0w1r1w0
		call	ram_test_downwards

		simulate_errors

		call	marchu_announce
	.s4:	mov	bp, marchu_r0w1
		call	ram_test_downwards

		ret

; ---------------------------------------------------------------------------
; MARK: marchu_announce
marchu_announce:
	%ifdef MARCHU_DELAY
		cmp	[ss:test_num], byte 0
		jz	nodelay
		call	marchu_delay
	nodelay:
	%endif
		mov	[ss:test_label], word scr_label_march
		call	scr_test_announce
		add	[ss:test_num], word 1
		ret


; march test components
; inputs:
;	al = test value (possibly inverted for second half of march test)
;	es:di = start address
;	cx = number of bytes to test
; preserves:
;	sp si bx dx
;	all segment registers
; state registers (saved between continuations):
;	al = test value (inverted at appropriate times)
;	cx = byte counter
;	es:di = current address under test
;	bp = return address
; output:
;	ah = error bits (0 = no error)
;	es:di = address of the error
;	bp = continuation address (for after errors)

; ---------------------------------------------------------------------------
; MARK: marchu_w0
marchu_w0:	; w0
		rep 	stosb		; fill the range with the test value
		; xor	ah, ah		; no errors possible
		; xor	dh, dh		; clear the error bits
		xor	bp, bp		; indicate finshed (no continuation)
		ret

; ---------------------------------------------------------------------------
; MARK: marchu_r0w1r1w0
marchu_r0w1r1w0:	; r0,w1,r1,w0	
	.loop:	; r0
		mov	ah, [es:di]	; read the byte [r0]
		xor	ah, al		; compare the test value with the byte
		jnz	.b.cont		; if error, break out
	.b:	; w1
		not	al		; now INVERTED
		mov	[es:di], al	; write the inverted test value [w1]
	.c:	; r1
		mov	ah, [es:di]	; read the byte [r1]
		xor	ah, al		; compare the test value with the byte
		jnz	.d.cont		; if error, break out
	.d:	; w0
		not	al		; now ORIGINAL
		stosb			; write the test value [w0], inc di
		loop	.loop		; repeat for the next byte

		xor	bp, bp		; indicate finshed (no continuation)
	.done	or	dh, ah		; accumulate errors
		ret			; segment done

	; use these stubs for the error conditions
	; this speeds up the loop - not taking the conditional jump saves several cycles per iteration
	.b.cont:
		mov	bp, .b		; set continuation address
		jmp	.done		; save a few bytes
	.d.cont:
		mov	bp, .d		; set continuation address
		jmp	.done		; save a few bytes

; ---------------------------------------------------------------------------
; MARK: marchu_r0w1
marchu_r0w1:	; r0,w1
	.loop:	; r0
		mov	ah, [es:di]	; read the byte [r0]
		xor	ah, al		; compare the test value with the byte
		jnz	.b.cont		; if error, break out
	.b:	; w1
		not	al		; now INVERTED
		stosb			; write the test value [w1], inc di
		not	al		; now ORIGINAL
		loop	.loop	; repeat for the next byte

		xor	bp, bp		; indicate finshed (no continuation)
	.done	or	dh, ah		; accumulate errors
		ret			; segment done

	; use these stubs for the error conditions
	; this speeds up the loop - not taking the conditional jump saves several cycles per iteration
	.b.cont:
		mov	bp, .b		; set continuation address
		jmp	.done		; save a few bytes

; ---------------------------------------------------------------------------
section_restore ; MARK: __ restore __
; ---------------------------------------------------------------------------





; ---------------------------------------------------------------------------
; MARK: test_dram
test_dram:
		mov	byte [ss:test_offset], 0	; set the column offset for the test
		call	marchu

