; code: language=nasm tabSize=8
%include "defines.inc"

seg_start	equ	0

; ---------------------------------------------------------------------------
section_save
; ---------------------------------------------------------------------------
section .romdata ; MARK: __ .romdata __
; ---------------------------------------------------------------------------
; scr_000		asciiz	"00:0-", 0
; scr_FFF		asciiz	"00:FFF", 0

; ---------------------------------------------------------------------------
section .lib ; MARK: __ .lib __
; ---------------------------------------------------------------------------

; %define SIMULATE_ERRORS

%ifdef SIMULATE_ERRORS
	%define simulate_errors call _do_sim_errors

	%macro _sim_error 1-3 0,1
		mov	ax, %1
		mov	es, ax
		xor	[es:%2], byte %3
	%endmacro

_do_sim_errors:
		push	ax
		push	es
		
		; _sim_error 0x0C00, 0, 2
		; _sim_error 0x1000, 0, 0xFE
		_sim_error 0x0000, 1, 0x80

		pop	es
		pop	ax
		ret
%else
	%define simulate_errors 
%endif


; MARK: ram_test_upwards
ram_test_upwards:
; run the march test in bp (including continuations on error) over the specified segments
; inputs:
;	bp = march test step function
;	bx = start segment
; 	dl = number of segments to test (will test dl*si bytes total)
; 	si = size of segment to test
; state variables:
;	bx = segment under test
;	dh = scratch holding error bits (0 = no error)
;	cx = counter of bytes and segments
; outputs:
;	dh = error bits

		push	dx		; save the number of segments to test
		cld			; clear the direction flag (go up)

		mov	bx, first_segment
		mov	dl, num_segments

	.segment_loop:
		mov	si, bytes_per_segment
		xor	di, di		; start at the beginning of the segment

		call	ram_test_segment

		add	bx, bytes_per_segment/16		; increment the segment based on the size of the test
		dec	dl		; decrement the number of segments to test
		jnz	.segment_loop	; if not, continue

		sub	bx, bytes_per_segment/16		; restore the segment to the last one
		pop	dx		; restore the number of segments to test
		ret


; MARK: ram_test_downwards
ram_test_downwards:
; run the march test in bp (including continuations on error) over the specified segments

		push	dx		; save the number of segments to test
		std			; set the direction flag (go down)

		mov	bx, (num_segments-1)*(bytes_per_segment/16)		; start at last segment
		mov	dl, num_segments

	.segment_loop:
		mov	si, bytes_per_segment
		mov	di, si		; start at the end of the segment
		dec	di		; adjust for the last byte

		call	ram_test_segment

		sub	bx, bytes_per_segment/16		; increment the segment based on the size of the test
		dec	dl		; decrement the number of segments to test
		jnz	.segment_loop	; if not, continue

		add	bx, bytes_per_segment/16		; restore the segment to the last one
		pop	dx		; restore the number of segments to test
		ret


; MARK: ram_test_segment
ram_test_segment:
		push	bp		; save the test step function
		mov	cx, si
		mov	es, bx		; set the segment to test
		mov	ds, bx

		call	startseg

	.continue:
		cmp	dh, 0xFF	; check if this segment is all errors (probably missing)
		je	.nextseg	; if so, don't bother testing it again
		xor	ah, ah		; clear the error bits for the restart

		call	bp		; start or continue the specified step

		cmp	bp, 0		; check for done with the segment
		jne	.continue	; if not, continue testing

	.nextseg:
		pop	bp		; restore the test step function
		call	endseg
		ret



; MARK: startseg
startseg:
		; XXX - show on the screen that we are starting this segment
		push	ax
		push	si
		push	ds
		push 	dx		; print the test addresses

		mov	dx, scr_addrs_xy
		call	scr_goto

		mov	[ss:scrAttr], byte scr_test_header_attr
		mov	ax, es
		call	scr_put_hex_ah

		call	scr_getxy
		add	dl, 5
		call	scr_goto

		add	ax, 0x0300
		call	scr_put_hex_ah

		pop	dx
		pop	ds
		pop	si

		mov	al, ah
		call	scr_goto_seg

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

; MARK: endseg
endseg:
		; XXX - show on the screen that we have finished this segment
		push	ax

		mov	ax, es
		mov	al, ah
		call	scr_goto_seg	; position the cursor for the report for this segment

		mov	[ss:scrAttr], byte scr_arrow_attr
		mov	al, " "
		call	scr_putc

		or	dh, dh		; any errors?
		jz	.ok

	.err:	
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

; ---------------------------------------------------------------------------
section_restore ; MARK: __ restore __
; ---------------------------------------------------------------------------
