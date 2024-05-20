; code: language=nasm tabSize=8
%include "defines.inc"

y_tests		equ	3
y_fails		equ	y_tests+1


; ---------------------------------------------------------------------------
section_save
section .rwdata ; MARK: __ .rwdata __
; ---------------------------------------------------------------------------

	scrPos		dw	?	; pointer to current cursor position in screen memory
	scrAttr		db 	?	; current attribute for printing

	test_label	dw	?	; test label
	test_num	db	?	; test number

; ---------------------------------------------------------------------------
section .romdata ; MARK: __ .romdata __
; ---------------------------------------------------------------------------
y_grid_start	equ	6
x_grid_start	equ	7
x_grid_loffs	equ	6
; grid_head_attr	equ	30h
; grid_head_attr	equ	09h
grid_head_attr	equ	13h
; grid_seg_attr	equ	03h
grid_seg_attr	equ	13h
grid_k_attr	equ	07h

y_grid_end	equ	y_grid_start+8

scr_grid_header		asciiz	"Addrs  EM  EB"
scr_grid_space		asciiz	"   "
x_k_start		equ	x_grid_start-x_grid_loffs+1
scr_k_labels		db 	grid_k_attr, x_k_start,    y_grid_start+ 5, " 64K", 0
			db 	grid_k_attr, x_k_start,    y_grid_start+10, "128K", 0
			db 	grid_k_attr, x_k_start+16, y_grid_start+ 5, "192K", 0
			db 	grid_k_attr, x_k_start+16, y_grid_start+10, "256K", 0
			db 	grid_k_attr, x_k_start+32, y_grid_start+ 5, "320K", 0
			db 	grid_k_attr, x_k_start+32, y_grid_start+10, "384K", 0
			db 	grid_k_attr, x_k_start+48, y_grid_start+ 5, "448K", 0
			db 	grid_k_attr, x_k_start+48, y_grid_start+10, "512K", 0
			db 	grid_k_attr, x_k_start+64, y_grid_start+ 5, "576K", 0
			db 	grid_k_attr, x_k_start+64, y_grid_start+10, "640K", 0
			db	0 ; end

scr_test_normal_attr	equ	0x07
scr_test_header_attr	equ	0x0F
scr_test_header_xy:	equ	0x0200
scr_test_header:	asciiz	"Pass "
scr_test_separator:	asciiz	": "
scr_label_march:	asciiz	"March-U "
scr_label_bit:		asciiz	"Bit Pattern "

scr_err_attr		equ	0x0C
scr_ok_attr		equ	0x07
scr_arrow_attr		equ	0x0A

; ---------------------------------------------------------------------------
section .lib ; MARK: __ .lib __
; ---------------------------------------------------------------------------

; MARK: scr_get_hex
scr_get_hex:
; get the byte value of two hex digits from the screen
; inputs:
;	es:di = address of the hex digits
; outputs:
;	ah = value of the hex digits
; destroys:
;	al
		push	di
		mov	di, [ss:scrPos]	; fetch the position
		mov	al, [ss:di]	; get the 4 MSB
		call	_h_to_u8	; convert to a number
		shl	al, 1		; put in the high nibble
		shl	al, 1
		shl	al, 1
		shl	al, 1
		mov	ah, al
		mov	al, [ss:di+2]	; get the 4 LSB
		call	_h_to_u8	; convert to a number
		or	ah, al
		pop	di
		ret

; MARK: _h_to_u8
_h_to_u8:
; convert an ascii hex digit in al to a number in al
; inputs:
;	al = ascii hex digit
; outputs:
;	al = value of the hex digit
		sub	al, '0'			;  > '0'?
		jb	.no			; no, return 0
		cmp	al, 9			; <= '9'?
		jbe	.done
		sub	al, 7			; look at A-F
		cmp	al, 0x0F		; <= 'F'?
		jbe	.done			
		sub	al, 'a' - 'A'		; <= 'f'?
		cmp	al, 0x0F		; <= 'F'?
		jbe	.done
	.no	xor	al, al			; none of the above.  Return zero.
	.done	and	al, 0x0F		; strip any remaining high bits
		ret


; MARK: scr_clear_line
scr_clear_line:
	push	ax
	push	cx
	push	es
	pushf
	cld

	mov	di, ss			; get the video memory segment from SS
	mov	es, di

	push	dx
	call	scr_getxy
	xor	dl, dl
	call	scr_goto
	pop	dx

	mov	ah, [ss:scrAttr]
	mov	di, [ss:scrPos]		; get current cursor position
	mov	al, ' '
	mov	cx, 80

	rep	stosw
; .loop:	call	scr_putc
; 	loop	.loop

	popf
	pop	es
	pop	cx
	pop	ax
	ret

; MARK: scr_test_announce
scr_test_announce:
; input:
;	ds:si = test label
;	ah = test number
	push	dx
	push	ax
	push	si

	mov	ah, scr_test_normal_attr
	call	scr_set_attr

	mov	dx, scr_test_header_xy
	call	scr_goto
	call	scr_clear_line

	mov	si, scr_test_header
	call	scr_puts

	mov	ax, [ss:pass_count]
	call	scr_put_hex_ax

	mov	si, scr_test_separator
	call	scr_puts

	mov	ah, scr_test_header_attr
	call	scr_set_attr
	mov	si, [ss:test_label]
	call	scr_puts
	mov	ah, [ss:test_num]
	call	scr_put_hex_ah

	pop	si
	pop	ax
	pop 	dx
	ret

; MARK: scr_puts_labels
scr_puts_labels:
; input:
;	ds:si = struct: byte attr, byte x, byte y, string to print (null terminated), [then either more, or attr=0 to end]
	push	ax
	mov	al, [ss:scrAttr]
	push	ax
	push	di

.loop:	lodsb				; fetch the attribute
	cmp	al, 0			; check for last string
	je	.done			; if null, we're done
	mov	ah, al
	call	scr_set_attr
	lodsw				; fetch the x,y position
	mov	dx, ax			; ready the x,y pos for the goto call
	call	scr_goto
	call	scr_puts_nosave		; string will now be at [ds:si]
	jmp	.loop			; repeat

.done:	pop	di
	pop	ax
	mov	[ss:scrAttr], al
	pop	ax
	ret

; MARK: scr_puts_nosave
scr_puts_nosave:
; input:
;	ds:si = string to print (null terminated)
; output:
;	ds:si = one byte past end of string

	push	ax
	push	cx
	push	es
	pushf
	cld

	mov	di, ss			; get the video memory segment from SS
	mov	es, di
	mov	di, [ss:scrPos]

	xor	cx, cx			; no count limit (well, 64KB)
	mov	ah, [ss:scrAttr]	; white on black

.loop:	lodsb				; al := [ds:si], si += 1
	cmp	al, 0			; check for null terminator
	je	.done			; if null, we're done
	stosw				; [es:di] = ax, di += 2
	loop	.loop			; repeat 

.done:	mov	[ss:scrPos], di		; save new cursor position
	popf
	pop	es
	pop	cx
	pop	ax
	ret

; MARK: scr_puts
scr_puts:
	push 	si
	push	di
	call 	scr_puts_nosave
	pop	di
	pop	si
	ret


; MARK: scr_goto
scr_goto:
; input:
;	dh = y position
; 	dl = x position
	push	di
	call	calc_scr_pos
	mov	[ss:scrPos], di
	pop	di
	ret

; MARK: scr_getxy
scr_getxy:
; output:
;	dh = y position
; 	dl = x position
	push	ax

	mov	ax, [ss:scrPos]
	mov	dl, 160
	div	dl			; now al = y, ah = 2x
	shr	ah, 1			; now al = y, ah = x
	mov	dh, al
	mov	dl, ah

	pop	ax
	ret

; MARK: scr_newline
scr_newline:
; input: none
	push	dx
	call	scr_getxy
	mov	dl, 0
	inc	dh
scr_vmove_epilog:
	call	scr_goto
	pop	dx
	ret

; MARK: scr_rindex
scr_rindex:
; input: none
	push	dx
	call	scr_getxy
	dec	dh
	jmp	scr_vmove_epilog


; MARK: scr_set_attr
scr_set_attr:
; input:
;	ah = attribute
	mov	[ss:scrAttr], ah
	ret

; MARK: scr_putc
scr_putc:
; input:
;	al = character
	push	ax
	push	di
	push	es
	pushf
	cld

	mov	di, ss			; get the video memory segment from SS
	mov	es, di

	mov	ah, [ss:scrAttr]	; get current attribute
	mov	di, [ss:scrPos]		; get current cursor position
	stosw				; [es:di] = ax, di += 2
	mov	[ss:scrPos], di		; save new cursor position

	popf
	pop	es
	pop	di
	pop 	ax
	ret

; MARK: calc_scr_pos
calc_scr_pos:
; input:
;	dh = y position
; 	dl = x position
; output:
;	di = screen position
;	(NO:) es = segment of screen memory

	push	ax
	; push	bx
	; push	cx
	push	dx

	; push	ss		; get the video memory segment from SS
	; pop	es

	mov	al, 160		; number of columns * 2 (for attribute)
	mul	dh		; ax := y * 160
	xor	dh, dh
	shl	dl, 1		; dx := x * 2 (for character and attribute)
	add	ax, dx		; add character offset
	mov	di, ax

	pop	dx
	; pop	cx
	; pop	bx
	pop	ax
	ret


; MARK: scr_put_hex_ah_h
scr_put_hex_ah_h:
; print high nybble of ah as a hex digit
; input:
;	ah = value to print
	push	cx
	mov	cx, 1
	jmp	__scr_put_hex
; .alt:
; 	rol	ax, 1		; rol	ax, 4
; 	rol	ax, 1
; 	rol	ax, 1
; 	rol	ax, 1

; MARK: scr_put_hex_ah_l
scr_put_hex_al_l:
; print the low nybble of bh as a hex digit
; input:
;	al = value to print
	push 	ax
	call 	__i2h_al
	call 	scr_putc
	pop	ax
	ret

; MARK: __scr_put_hex_ax
scr_put_hex_ax:
; input:
;	bx = value to print
	push	cx
	mov	cx, 4		; 4 nybbles in ax
	jmp	__scr_put_hex

; MARK: __scr_put_hex_ah
scr_put_hex_ah:
; input:
;	bh = value to print
	push 	cx
	mov	cx, 2		; 2 nybbles in ah
__scr_put_hex:
; input:
;	bx = value to print (upper nybble)
;       cx = number of nybbles to print
	push 	ax
	push	bx

.loop:	rol	ax, 1		; rol	bx, 4
	rol	ax, 1
	rol	ax, 1
	rol	ax, 1

.put:	
	mov	bx, ax		; save the value
	call	__i2h_al	; convert to ASCII
	call	scr_putc
	mov	ax, bx
	loop	.loop

	pop	bx
	pop	ax
	pop	cx
	ret

; MARK: __i2h_al
__i2h_al:
; convert low nybble of al to ASCII
; input:
;	al = value to convert
	and	al,0fh
	add	al,90h
	daa
	adc	al,40h
	daa
	ret

; .alt				; this is one byte faster, but seems to rely on undocumented 8086 behaviour (AF undefined after AND)
; 	mov	al, bh
; 	and	al, 0Fh
; 	daa
; 	add	al, -16
; 	adc	al, +64
; 	ret




; y_grid_start	equ	5
; x_grid_lower	equ	4
; x_grid_upper	equ	49
; grid_head_attr	equ	03h

; y_grid_end	equ	y_grid_start+16

; scr_goto_seg:
; ; input: 
; ;	al = segment
; 	push	ax
; 	push	dx

; 	; calculate y
; 	mov	ah, al
; 	and	ah, 0Fh			; mask out the upper bits
; 	mov	dh, y_grid_end		; count bottom up
; 	sub	dh, ah			; subtract the low nybble to get row number

; 	; calculate x
; 	mov 	dl, al
; 	and	dl, 0xF0		; mask out the lower bits
; 	shr	dl, 1
; 	shr	dl, 1
; 	add	dl, x_grid_lower	; add the base x position

; 	cmp	al, 0a0h		; is it an upper segment?
; 	jb	.done			; if below, we're done
; 	add	dl, x_grid_upper-x_grid_lower-0ah*4	; adjust x offset for upper segments
; .done:
; 	call	scr_goto
; 	pop	dx
; 	pop	ax
; 	ret


; MARK: scr_goto_seg
scr_goto_seg:
; input: 
;	al = segment
	push	ax
	push	dx

	; calculate y
	mov	ah, al
	and	ah, 1Fh			; mask out the upper bits
	shr	ah, 1
	shr	ah, 1
	; mov	dh, y_grid_end		; count bottom up
	; sub	dh, ah			; subtract the low nybble to get row number
	mov	dh, y_grid_start+1
	add	dh, ah
	test	al, 10h
	jz	.not_upper
	inc	dh
.not_upper:
	; calculate x
	mov 	dl, al
	and	dl, 0xE0		; mask out the lower bits
	shr	dl, 1
	; shr	dl, 1
	add	dl, x_grid_start	; add the base x position

	call	scr_goto
	pop	dx
	pop	ax
	ret


; MARK: draw_ram_headers
; ---------------------------------------------------------------------------
draw_ram_headers:
	push	ds
	push	es

	push	cs			; set up to copy from ROM to VRAM
	pop	ds

	mov	dh, y_grid_start	; go to the start of the grid
	mov	dl, x_grid_start-x_grid_loffs
	call	scr_goto

	mov	cx, 5
.hloop:	
	mov	ah, grid_head_attr
	call	scr_set_attr
	mov	si, scr_grid_header	; print the header
	call	scr_puts
	mov	ah, 07h
	call	scr_set_attr
	mov	si, scr_grid_space	; print the space
	call	scr_puts
	loop	.hloop

	mov	ah, grid_seg_attr
	call	scr_set_attr

	; now print the block labels
	mov	cx, 40			; 16 address labels
	mov	al, 0			; segment counter
.lloop:	
	call	scr_goto_seg
	sub	byte [ss:scrPos], x_grid_loffs*2	; go back for label
	mov	ah, al
	call	scr_put_hex_ah
	mov	al, '-'		; print the dash
	call	scr_putc
	add	ah, 3
	call	scr_put_hex_ah
	mov	al, ah
	inc	al
	loop	.lloop

.klabs:	mov	si, scr_k_labels
	call	scr_puts_labels

	pop	es
	pop	ds
	ret




; ---------------------------------------------------------------------------
section_restore ; MARK: __ restore __
; ---------------------------------------------------------------------------

draw_screen:
	xor	dx, dx
	call	scr_goto
	mov	ah, title_attr
	call	scr_set_attr
	call	scr_clear_line
	inc	dl
	; mov	ah, 17h			; white on blue
	; call	scr_set_attr
	; call	scr_clear_line
	mov	si, title_text
	call	scr_puts_labels

; 	mov	ah, 0Ah			; bright green on black
; 	mov	dx, 1800h
; 	mov	cx, 4
; .loop:	
; 	call	scr_goto
; 	mov 	ah, dh
; 	call	scr_put_hex_ah
; 	dec	dh
; 	loop	.loop

	call	draw_ram_headers

