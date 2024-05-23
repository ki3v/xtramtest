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
	; ram_col_header	db	"A  ErrM ErrB"


section .rwdata ; MARK: __ .rwdata __
; ---------------------------------------------------------------------------

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


; %define SIMULATE_ERRORS 1

%ifdef SIMULATE_ERRORS
	%define simulate_errors call _do_sim_errors

	%macro _sim_error 3 0,1
		mov	ax, %1
		mov	es, ax
		xor	[es:%2], byte %3
	%endmacro

_do_sim_errors:
		push	ax
		push	es
		
		_sim_error 0x0C00, 0, 2
		_sim_error 0x1000, 0, 0xFE

		pop	es
		pop	ax
		ret
%else
	%define simulate_errors 
%endif

; MARK: marchu
marchu:
; perrom march-U on 4k chunks, using stack, with error reporting
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
		mov	al, 0
		push	bx		; save the start segment overall
		push	bx		; save the start segment

		mov	[ss:test_num], byte 0
		call	marchu_announce

	.s0:	mov	bp, marchu_w0
		call	marchu_count_up
		pop	bx		; restore the start segment

		simulate_errors

		call	marchu_announce
		push	bx		; save the start segment
	.s1:	mov	bp, marchu_r0w1r1w0
		call	marchu_count_up
		pop	bx		; restore the start segment

		simulate_errors

		call	marchu_announce
	.s2:	mov	bp, marchu_r0w1
		call	marchu_count_up
		not	al

		simulate_errors

		call	marchu_announce
		push	bx		; save the start segment
	.s3:	mov	bp, marchu_r0w1r1w0
		call	marchu_count_down
		pop	bx		; restore the start segment

		simulate_errors

		call	marchu_announce
	.s4:	mov	bp, marchu_r0w1
		call	marchu_count_down
		pop	bx		; restore the start segment overall

		ret

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

; MARK: marchu_count_up
marchu_count_up:
; run the march test in bp (including continuations on error) over the specified segments
; inputs:
;	bp = march test step function
		push	dx		; save the number of segments to test
		cld			; clear the direction flag (go up)

	.segment_loop:
		xor	di, di		; start at the beginning of the segment

		call	_marchu_count_common

		add	bx, cx		; increment the segment based on the size of the test
		dec	dl		; decrement the number of segments to test
		jnz	.segment_loop	; if not, continue

		sub	bx, cx		; restore the segment to the last one
		pop	dx		; restore the number of segments to test
		ret

; MARK: marchu_count_down
marchu_count_down:
; run the march test in bp (including continuations on error) over the specified segments
; inputs:
;	bp = march test step function
		push	dx		; save the number of segments to test
		std			; set the direction flag (go down)

	.segment_loop:
		mov	di, si		; start at the end of the segment
		dec	di		; adjust for the last byte

		call	_marchu_count_common

		sub	bx, cx		; increment the segment based on the size of the test
		dec	dl		; decrement the number of segments to test
		jnz	.segment_loop	; if not, continue

		add	bx, cx		; restore the segment to the last one
		pop	dx		; restore the number of segments to test
		ret

; MARK: _marchu_count_common
_marchu_count_common:
		push	bp		; save the march test step function
		mov	cx, si
		mov	es, bx		; set the segment to test

		call	marchu_startseg
	.continue:
		cmp	dh, 0xFF	; check if this segment is all errors (probably missing)
		je	.nextseg	; if so, don't bother testing it again
		xor	ah, ah		; clear the error bits for the restart

		call	bp		; start or continue the specified step

		or	dh, ah		; accumulate errors in dh
		cmp	ah, 0		; check for errors
		jne	.continue	; if errors, continue testing at the continuation address
					; else we are done with this segment, so go on to the next

	.nextseg:
		pop	bp		; restore the march test step function
		call	marchu_endseg

		mov	cx, si		; calculate next segment
		shr	cx, 1		; divide by 16
		shr	cx, 1
		shr	cx, 1
		shr	cx, 1

		ret

; MARK: marchu_startseg
marchu_startseg:
		; XXX - show on the screen that we are starting this segment
		push	ax

		mov	ax, es
		mov	al, ah
		call	scr_goto_seg

		; sub	[ss:scrPos], word 2
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

; MARK: marchu_endseg
marchu_endseg:
		; XXX - show on the screen that we have finished this segment
		push	ax

		mov	ax, es
		mov	al, ah
		call	scr_goto_seg	; position the cursor for the report for this segment

		; sub	[ss:scrPos], word 2
		; mov	[ss:scrAttr], byte 0x08		; dark grey on black
		mov	[ss:scrAttr], byte scr_arrow_attr

		mov	al, " "
		call	scr_putc

		or	dh, dh		; any errors?
		jz	.ok

	.err:	
		mov	[ss:scrAttr], byte scr_err_attr
		; mov	[ss:scrAttr], byte 0x70
		mov	ah, dh
		call	scr_put_hex_ah	; print the error bits
		jmp 	.done

	.ok:	mov	[ss:scrAttr], byte scr_ok_attr
		mov	al, '-'
		call	scr_putc
		call	scr_putc

	.done:	
		mov	[ss:scrAttr], byte scr_arrow_attr
		mov	al, " "
		call	scr_putc
		
		pop	ax
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

; MARK: marchu_w0
marchu_w0:	; w0
		rep 	stosb		; fill the range with the test value
		xor	ah, ah		; no errors possible
		ret

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
		ret			; step done

	.b.cont:
		mov	bp, .b		; next step
		ret
	.d.cont:
		mov	bp, .d		; next step
		ret

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
		ret			; step done

	.b.cont:
		mov	bp, .b		; next step
		ret

; ---------------------------------------------------------------------------
section_restore ; MARK: __ restore __
; ---------------------------------------------------------------------------


; MARK: test_dram
test_dram:
; inputs:
;	al = test value
;	bx = start segment
; 	dl = number of segments to test (will test dl*si bytes total)
; 	si = size of segment to test (must be a multiple of 16)
		xor	al, al
		xor	bx, bx
		mov	dl, num_segments
		mov	si, 0x4000
		call	marchu

	; .hlt:	hlt
	; 	jmp	.hlt
