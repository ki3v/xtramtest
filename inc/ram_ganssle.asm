; code: language=nasm tabSize=8
%include "defines.inc"

; ---------------------------------------------------------------------------
section_save
; ---------------------------------------------------------------------------
section .lib ; MARK: __ .lib __
; ---------------------------------------------------------------------------






; MARK: ram_test_ganssle
ram_test_ganssle: ; perform bit tests, using stack, with error reporting
		mov	[ss:test_label], word scr_label_bit

		mov	al, 0xFF
		call	ganssle_one_test
		mov 	al, 0x00
		call	ganssle_one_test
		mov	al, 0x55
		call	ganssle_one_test
		mov	al, 0xAA
		call	ganssle_one_test
		mov	al, 0x01
		call	ganssle_one_test

		ret

ganssle_one_test:
		mov	[ss:test_num], al
		call	scr_test_announce
		mov	bp, ganssle_segment
		call	ram_test_upwards
		ret


; inputs:
;	al = test value
;	ds,es = segment to test
;	cx = number of bytes to test
; 	dh = accumulated error bits
; preserves:
;	sp bp
;	all segment registers
; state registers (saved between continuations):
;	al = test value (inverted at appropriate times)
;	cx = byte counter
;	es:di = current address under test
; output:
;	dh = accumulated error bits
;	es:di = address of the error
;
; this test attempts to use some of the concepts introduced by this article:
; https://www.ganssle.com/testingram.htm
;
; MARK: ganssle_segment
ganssle_segment:
		mov	ah, al		; save the test value into ah

		xor	si, si		; start SI at the beginning of the segment
		mov	di, cx		; start DI at (just past) the end of the segment
		clc			; clear the carry flag (error indication)

	.loop:	cmp	dh, 0xFF	; check for all bits in error
		je	.end		; if so, give up on this segment
		dec	di		; decrement DI to next lower value
		mov	[di], al	; write [es:di] with original test value
		mov	ah, [di]	; read back [es:di]
		not	ah		; invert the value
		mov	[si], ah	; write inverted to [es:si]
		movsb			; copy [es:di] := [ds:si], si++, di++ (read, write)
		dec	di		; rewind to just-written value
		mov	ah, [di]	; read the final inverted value back
		not	ah		; invert the value (back to original)
		xor	ah, al		; compare the final value to the test value
		or	dh, ah		; accumulate errors
		loop	.loop		; continue until the segment is done

	.end:	xor	bp, bp		; indicate done with the segment
		ret			; done

; ---------------------------------------------------------------------------
section_restore ; MARK: __ restore __
; ---------------------------------------------------------------------------





; MARK: test_ganssle
test_ganssle:
		mov	byte [ss:test_offset], 4	; set the column offset for the test
		call	ram_test_ganssle
