; code: language=nasm tabSize=8

	; March RAM test algorithm:
	; step 0; up - w0 - write the test value
	; step 1; up - r0,w1,r1,w0
	; step 2; up - r0,w1
	; step 3; down - r1,w0,r0,w1
	; step 4; down - r1,w0


%include "defines.inc"

; ---------------------------------------------------------------------------
section_save ; MARK: __ save __





; ---------------------------------------------------------------------------
section .lib ; MARK: __ .lib __
; ---------------------------------------------------------------------------


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
		mov	[ss:test_label], word scr_label_march
		mov	[ss:test_num], byte 0

		xor	al, al			; test value for march is always 0

	.s0:	mov	bp, marchu_w0
		call	.test_up
	
	.s1:	mov	bp, marchu_r0w1r1w0
		call	.test_up
	
	.s2:	mov	bp, marchu_r0w1
		call	.test_up

		not	al
	
	.s3:	mov	bp, marchu_r0w1r1w0
		call	.test_down
	
	.s4:	mov	bp, marchu_r0w1	
		call	.test_down

		ret

.test_up:
		call	scr_test_announce
		call	ram_test_upwards
		jmp	.finish

.test_down:
		call	scr_test_announce
		call	ram_test_downwards
.finish:
		simulate_errors
		inc	word [ss:test_num]
		ret


; ; ---------------------------------------------------------------------------
; ; MARK: marchu_announce
; marchu_announce:
; 		call	scr_test_announce
; 		; add	[ss:test_num], word 1
; 		inc	word [ss:test_num]
; 		ret


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
		ret

; ---------------------------------------------------------------------------
; assumes DS=ES (stosb writes to ES:DI, [di] means [ds:di] by default
; MARK: marchu_r0w1r1w0
marchu_r0w1r1w0:	; r0,w1,r1,w0	
	.loop:	; r0
		mov	ah, [di]	; read the byte [r0]
		xor	ah, al		; compare the test value with the byte
		or	dh, ah		; accumulate errors
		; w1
		not	al		; now INVERTED
		mov	[di], al	; write the inverted test value [w1]
		; r1
		mov	ah, [di]	; read the byte [r1]
		xor	ah, al		; compare the test value with the byte
		or	dh, ah		; accumulate errors
		; w0
		not	al		; now ORIGINAL
		stosb			; write the test value [w0], inc di

		cmp	dh, 0xFF	; check for all bits in error to fail fast on empty banks
		je	.end		; if so, give up on this segment

		loop	.loop		; repeat for the next byte

	.end:	ret			; segment done

; ---------------------------------------------------------------------------
; MARK: marchu_r0w1
marchu_r0w1:	; r0,w1
	.loop:	; r0
		mov	ah, [di]	; read the byte [r0]
		xor	ah, al		; compare the test value with the byte
		or	dh, ah		; accumulate errors
		; w1
		not	al		; now INVERTED
		stosb			; write the test value [w1], inc di
		not	al		; now ORIGINAL
		loop	.loop		; repeat for the next byte

	.end:	ret			; segment done


; ---------------------------------------------------------------------------
section_restore ; MARK: __ restore __
; ---------------------------------------------------------------------------





; ---------------------------------------------------------------------------
; MARK: test_dram
test_dram:
		mov	byte [ss:test_offset], 0	; set the column offset for the test
		call	marchu

