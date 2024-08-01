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
		call	bitpat_count_up
		ret

bitpat_announce:
		; push	ds
		; push	cs
		; pop	ds
		mov	[ss:test_label], word scr_label_bit
		call	scr_test_announce
		add	[ss:test_num], word 1
		; pop	ds
		ret

; MARK: bitpat_count_up
bitpat_count_up:
; run the march test in bp (including continuations on error) over the specified segments
; inputs:
;	bp = march test step function
		push	dx		; save the number of segments to test
		cld			; clear the direction flag (go up)

	.segment_loop:
		xor	di, di		; start at the beginning of the segment

		call	_bitpat_count_common

		add	bx, cx		; increment the segment based on the size of the test
		dec	dl		; decrement the number of segments to test
		jnz	.segment_loop	; if not, continue

		sub	bx, cx		; restore the segment to the last one

		pop	dx		; restore the number of segments to test
		ret

; MARK: _bitpat_count_common
_bitpat_count_common:
		push	bp		; save the march test step function
		mov	cx, si
		mov	es, bx		; set the segment to test
		mov	ds, bx

		call	bitpat_startseg
	.continue:
		cmp	dh, 0xFF	; check if this segment is all errors (probably missing)
		je	.nextseg	; if so, don't bother testing it again

		push	bx
		push	cx
		push	si
		push	di

		call	bp		; start or continue the specified step

		pop	di
		pop	si
		pop	cx
		pop	bx

		cmp	bp, 0		; check for done with the segment
		jne	.continue	; if not, continue testing

		; or	dh, ah		; accumulate errors in dh
		; cmp	ah, 0		; check for errors
		; jne	.continue	; if errors, continue testing at the continuation address
					; else we are done with this segment, so go on to the next

	.nextseg:
		pop	bp		; restore the march test step function
		call	bitpat_endseg

		mov	cx, si		; calculate next segment
		shr	cx, 1		; divide by 16
		shr	cx, 1
		shr	cx, 1
		shr	cx, 1

		ret

; MARK: bitpat_startseg
bitpat_startseg:
		; XXX - show on the screen that we are starting this segment
		push	ax

		mov	ax, es
		mov	al, ah
		call	scr_goto_seg

		; add	[ss:scrPos], word 8
		mov	[ss:scrAttr], byte scr_arrow_attr
		mov	al, 10h
		call	scr_putc

		call	scr_get_hex	; get the byte value of the hex digits at that screen location
		mov	dh, ah		; save the error bits

		add	[ss:scrPos], word 4
		mov	al, 11h
		call	scr_putc

		pop	ax
		xor	ah, ah		; clear the error bits for the next test
		ret

; MARK: bitpat_endseg
bitpat_endseg:
		; XXX - show on the screen that we have finished this segment
		push	ax

		mov	ax, es
		mov	al, ah
		call	scr_goto_seg	; position the cursor for the report for this segment

		; add	[ss:scrPos], word 8
		; mov	[ss:scrAttr], byte 0x08		; dark grey on black
		mov	[ss:scrAttr], byte scr_arrow_attr
		mov	al, " "
		call	scr_putc

		or	dh, dh		; any errors?
		jz	.ok

	.err:	
		; mov	[ss:scrAttr], byte 0x4F
		mov	[ss:scrAttr], byte scr_err_attr
		mov	ah, dh
		call	scr_put_hex_ah	; print the error bits
		jmp 	.done

	.ok:	mov	[ss:scrAttr], byte scr_ok_attr
		mov	al, '-'
		call	scr_putc
		call	scr_putc

	.done:	mov	[ss:scrAttr], byte scr_arrow_attr
		mov	al, " "
		call	scr_putc
		
		pop	ax
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


	; .loop:	dec	di		; decrement DI to next lower value
	; 	mov	bx, ax		; make a copy of the test value to XOR against
	; 	mov	[si], al	; write the test value (write)
	; 	movsb			; [es:di] := [ds:si], si++, di++ (read, write)
	; 	xor	bl, [si-1]	; read the first value back (read)
	; 	dec	di		; rewind to just-written value
	; 	xor	bh, [di]	; read the second value back (read)
	; 	or	dh, bl		; accumulate errors
	; 	or	dh, bh		; accumulate errors
	; 	loop	.loop		; continue until the segment is done
	; 	ret

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
		xor	al, al
		xor	bx, bx
		mov	dl, num_segments
		mov	si, 0x4000
		call	ram_test_bitpat

	; .hlt:	hlt
	; 	jmp	.hlt
