; code: language=nasm tabSize=8

	; March RAM test algorithm:
	; step 0; up - w0 - write the test value
	; step 1; up - r0,w1,r1,w0
	; step 2; up - r0,w1
	; step 3; down - r1,w0,r0,w1
	; step 4; down - r1,w0


%include "defines.inc"

; ---------------------------------------------------------------------------
section_save
section .romdata ; MARK: __ .romdata __
	; bit_table	db	0x00, 0xFF, 0x55, 0xAA, 0x01
	; bit_table_len	equ	$-bit_table
	; ram_col_header	db	"A  ErrM ErrB"


section .rwdata ; MARK: __ .rwdata __
; ---------------------------------------------------------------------------



; ---------------------------------------------------------------------------
section .lib ; MARK: __ .lib __
; ---------------------------------------------------------------------------

; MARK: ram_test_bitpat
ram_test_bitpat:
; perrom bit tests, using stack, with error reporting
; inputs:
;	al = test valuefff
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
		mov	[ss:test_label], word scr_label_bit

		mov	bp, bitpat_segment_all
		call	bitpat_one_test

		; mov	bp, bitpat_segment
		; mov 	al, 0x00
		; call	bitpat_one_test
		; mov	al, 0xFF
		; call	bitpat_one_test
		; mov	al, 0x55
		; call	bitpat_one_test
		; mov	al, 0xAA
		; call	bitpat_one_test
		; mov	al, 0x01
		; call	bitpat_one_test

		ret

bitpat_one_test:
		mov	[ss:test_num], al
		xor	bx, bx
		call	scr_test_announce
		call	ram_test_upwards
		ret




; bitpat test components
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
; MARK: bitpat_segment
bitpat_segment:	; w0
		mov	ah, al		; save the test value into ah
		; xor	dh, dh		; clear the error bits

		xor	si, si		; start SI at the beginning of the segment
		mov	di, cx		; start DI at (just past) the end of the segment
		clc			; clear the carry flag (error indication)

	.loop:	cmp	dh, 0xFF	; check for all bits in error
		je	.end		; if so, give up on this segment
		dec	di		; decrement DI to next lower value
		mov	[di], ah	; write [es:di] with oritinal test value
		mov	al, [di]	; read back [es:di]
		not	al		; invert the value
		mov	[si], al	; write inverted to [es:si]
		movsb			; copy [es:di] := [ds:si], si++, di++ (read, write)
		dec	di		; rewind to just-written value
		mov	al, [di]	; read the final inverted value back
		not	al		; invert the value (back to original)
		xor	al, ah		; compare the final value to the test value
		or	dh, al		; accumulate errors
		loop	.loop		; continue until the segment is done

	.end:	xor	bp, bp		; indicate done with the segment
		ret			; done


	; .loop2:	cmp	dh, 0xFF	; check for all bits in error
	; 	je	.end		; if so, give up on this segment
	; 	dec	di		; decrement DI to next lower value
	; 	mov	ah, al		; copy the test value into ah
	; 	mov	[si], al	; write [es:si] with original test value 
	; 	mov	[di], al	; write [es:di] with original test value (invert address lines)
	; 	not	[si], 0xFF	; invert [es:si] (invert address and data lines)
	; 	movsb			; copy [es:di] := [ds:si], si++, di++ (read, write)
	; 	dec	di		; rewind to just-written value
	; 	xor	ah, [di]	; read the final inverted value back and compare it to the test value
	; 	not	ah		; invert the value (back to original)
	; 	xor	ah, al		; compare the final value to the test value
	; 	or	dh, ah		; accumulate errors
	; 	loop	.loop		; continue until the segment is done

	; .loop3:	cmp	dh, 0xFF	; check for all bits in error
	; 	je	.end		; if so, give up on this segment
	; 	dec	di		; decrement DI to next lower value
	; 	mov	ah, al		; copy the test value into ah
	; 	mov	[si], al	; write [es:si] with original test value 
	; 	mov	[di], al	; write [es:di] with original test value (invert address lines)
	; 	not	[si]		; invert [es:si] (invert address and data lines)
	; 	movsb			; copy [es:di] := [ds:si], si++, di++ (read, write)
	; 	dec	di		; rewind to just-written value
	; 	not	[di]		; invert [es:di], should now be the original test value
	; 	xor	ah, [di]	; read the final inverted value back and compare it to the test value
	; 	or	dh, ah		; accumulate errors
	; 	loop	.loop		; continue until the segment is done

bitpat_segment_all:
		xchg	bp, sp
		xchg	bp, sp
		push	cx
		mov	al, 0x00
		call 	bitpat_segment
		pop	cx
		push	cx
		mov	al, 0xFF
		call 	bitpat_segment
		pop	cx
		push	cx
		mov	al, 0x55
		call 	bitpat_segment
		pop	cx
		push	cx
		mov	al, 0xAA
		call 	bitpat_segment
		pop	cx
		push	cx
		mov	al, 0x01
		call 	bitpat_segment
		pop	cx
		ret


; ---------------------------------------------------------------------------
section_restore ; MARK: __ restore __
; ---------------------------------------------------------------------------


; MARK: test_dram
test_bitpat:
; inputs:
;	al = test value
;	bx = start segment
; 	dl = number of segments to test (will test dl*si bytes total)
; 	si = size of segment to test (must be a multiple of 16)
		mov	byte [ss:test_offset], 4	; set the column offset for the test
		; xor	al, al
		mov	al, 0xFF			; don't print a test value (code FF)
		; mov	bx, first_segment
		; mov	dl, num_segments
		; mov	si, bytes_per_segment
		call	ram_test_bitpat

	; .hlt:	hlt
	; 	jmp	.hlt
