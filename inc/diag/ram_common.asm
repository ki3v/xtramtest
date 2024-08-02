; code: language=nasm tabSize=8
%include "defines.inc"

; ---------------------------------------------------------------------------
section_save

; ---------------------------------------------------------------------------
section .lib ; MARK: __ .lib __
; ---------------------------------------------------------------------------


%define SIMULATE_ERRORS 1

%if SIMULATE_ERRORS
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
		_sim_error 0x5000, 0, 0xFF

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
		push	dx		; save the number of segments to test
		cld			; clear the direction flag (go up)

	.segment_loop:
		xor	di, di		; start at the beginning of the segment

		call	ram_test_loop

		add	bx, cx		; increment the segment based on the size of the test
		dec	dl		; decrement the number of segments to test
		jnz	.segment_loop	; if not, continue

		sub	bx, cx		; restore the segment to the last one
		pop	dx		; restore the number of segments to test
		ret


; MARK: ram_test_downwards
ram_test_downwards:
; run the march test in bp (including continuations on error) over the specified segments
; inputs:
;	bp = march test step function
		push	dx		; save the number of segments to test
		std			; set the direction flag (go down)

	.segment_loop:
		mov	di, si		; start at the end of the segment
		dec	di		; adjust for the last byte

		call	ram_test_loop

		sub	bx, cx		; increment the segment based on the size of the test
		dec	dl		; decrement the number of segments to test
		jnz	.segment_loop	; if not, continue

		add	bx, cx		; restore the segment to the last one
		pop	dx		; restore the number of segments to test
		ret


; MARK: ram_test_loop
ram_test_loop:
		push	bp		; save the march test step function
		mov	cx, si
		mov	es, bx		; set the segment to test
		mov	ds, bx

		call	startseg
	.continue:
		cmp	dh, 0xFF	; check if this segment is all errors (probably missing)
		je	.nextseg	; if so, don't bother testing it again
		xor	ah, ah		; clear the error bits for the restart

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

	.nextseg:
		pop	bp		; restore the march test step function
		call	endseg

		mov	cx, si		; calculate next segment
		shr	cx, 1		; divide by 16
		shr	cx, 1
		shr	cx, 1
		shr	cx, 1

		ret



; MARK: startseg
startseg:
		; XXX - show on the screen that we are starting this segment
		push	ax

		mov	ax, es
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
