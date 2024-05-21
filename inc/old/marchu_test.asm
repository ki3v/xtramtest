; code: language=nasm tabSize=8

BITS 16
CPU 8086


; test program for march_u

org 0x100

		lea dx, [msg]
		mov ah,9
		int 21h
		mov ax, 4c00h
		int 21h

		msg: DB 'HELLO WORLD$'

		mov cx, [0x80]		; size of the command line
		mov ah, 0x40		; DOS function 40h - write to file or device
		mov bx, 1			; file handle 1 - standard output
		mov dx, 0x81		; offset of the command line
		int 0x21			; call DOS
		mov ah, 4ch			; DOS function 4Ch - terminate program
		int 21h




; march_u
; registers in:
;   al - test value
;   ds - start segment
;   dx - number of 16-byte segments to test
;   bp - callback for reporting errors
; registers used:
;   ah - value read from memory
;   cx - byte counter
;   di - write index
;   si - continuation address
;   bx - scratch
;   cx - scratch

march_u:
	.init:
		cld					; clear direction flag (forward)
		lea	bp, .bad		; XXX set the error callback

	; step 0; up - w0 - write the test value
	.step0:
		mov	bx, dx			; bx is a temporary segment counter
	.s0_seg_loop:
		test	bh, 0F0h		; check high 4 bits of bx
		jz	.s0_lt64k		; if high 4 bits of bx are 0, then there is less than 64k left
		sub	bx, 1000h		; remove 64k from the counter
		xor	cx, cx			; we have more than 64k, so do the next 64k
		jmp	.s0_fill		; fill the range with the test value
	.s0_lt64k:
		sub	bx, 0			; test if BX is zero
		jz	.s0_done			; if BX is zero, we are done
		mov	cl, 4			; we have less than 64k, so do the rest
		shl	bx, cl			; convert pages to bytes
		mov	cx, bx			; set byte counter

	.s0_fill:
		mov	di, 0			; beginning of the segment
		rep	stosb			; [di++] = al; cx--  (fill the range with the test value)
		jmp	.s0_seg_loop		; repeat for the next segment

	.s0_done:

	
	; step 1; up - r0,w1,r1,w0
	.step1:
		mov	bx, dx			; bx is a temporary segment counter
	.s1_seg_loop:
		test	bh, 0F0h		; check high 4 bits of bx
		jz	.s1_lt64k		; if high 4 bits of bx are 0, then there is less than 64k left
		sub	bx, 1000h		; remove 64k from the counter
		xor	cx, cx			; we have more than 64k, so do the next 64k
		jmp	.s1_test		; fill the range with the test value
	.s1_lt64k:
		sub bx, 0			; test if BX is zero
		jz .s1_done			; if BX is zero, we are done
		mov cl, 4			; we have less than 64k, so do the rest
		shl bx, cl			; convert pages to bytes
		mov cx, bx			; set byte counter

	.s1_test:				; cx is the byte counter
		mov di, 0			; beginning of the segment
	.s1_byte_loop:
		mov ah, [di]		; read the byte [r0]
		cmp al, ah			; compare the test value with the byte
		jne .bad			; if not equal, error

	.s1_w1:
		xor al, 0ffh		; invert the test value
		mov [di], al		; write the inverted test value [w1]

		mov ah, [di]		; read the byte [r1]
		cmp al, ah			; compare the test value with the byte
		jne .bad			; if not equal, error

		xor al, 0ffh		; invert the test value back to original
		stosb				; write the test value [w0], inc di
		loop .s1_byte_loop	; repeat for the next byte
		jmp .s1_seg_loop	; repeat for the 64k

	.s1_done:

	; step 2; up - r0,w1
	.step2:
		mov bx, dx			; bx is a temporary segment counter
	.s2_seg_loop:
		test bh, 0F0h		; check high 4 bits of bx
		jz .s2_lt64k		; if high 4 bits of bx are 0, then there is less than 64k left
		sub bx, 1000h		; remove 64k from the counter
		xor cx, cx			; we have more than 64k, so do the next 64k
		jmp .s2_test		; fill the range with the test value
	.s2_lt64k:
		sub bx, 0			; test if BX is zero
		jz .s2_done			; if BX is zero, we are done
		mov cl, 4			; we have less than 64k, so do the rest
		shl bx, cl			; convert pages to bytes
		mov cx, bx			; set byte counter

	.s2_test:				; cx is the byte counter
		mov di, 0			; beginning of the segment
	.s2_byte_loop:
		mov ah, [di]		; read the byte [r0]
		cmp al, ah			; compare the test value with the byte
		jne .bad			; if not equal, error

	.s2_w1:
		xor al, 0ffh		; invert the test value
		stosb				; write the test value [w1], inc di
		xor al, 0ffh		; invert the test value back to original
		loop .s2_byte_loop	; repeat for the next byte
		jmp .s2_seg_loop	; repeat for the 64k

	.s2_done:

	; step 3; down - r1,w0,r0,w1
	.step3:
		std 				; set direction flag (backward)
		xor al, 0ffh		; invert the test value back to original
		mov bx, dx			; bx is a temporary segment counter
	.s3_seg_loop:
		test bh, 0F0h		; check high 4 bits of bx
		jz .s3_lt64k		; if high 4 bits of bx are 0, then there is less than 64k left
		sub bx, 1000h		; remove 64k from the counter
		xor cx, cx			; we have more than 64k, so do the next 64k
		jmp .s3_test		; fill the range with the test value
	.s3_lt64k:
		sub bx, 0			; test if BX is zero
		jz .s3_done			; if BX is zero, we are done
		mov cl, 4			; we have less than 64k, so do the rest
		shl bx, cl			; convert pages to bytes
		mov cx, bx			; set byte counter

	.s3_test:				; cx is the byte counter
		mov di, cx			; end of the segment
		dec di 				; adjust for the last byte
	.s3_byte_loop:
		mov ah, [di]		; read the byte [r1]
		cmp al, ah			; compare the test value with the byte
		jne .bad			; if not equal, error

	.s3_w1:
		xor al, 0ffh		; invert the test value back to original
		mov [di], al		; write the inverted test value [w0]

		mov ah, [di]		; read the byte [r0]
		cmp al, ah			; compare the test value with the byte
		jne .bad			; if not equal, error

		xor al, 0ffh		; invert the test value
		stosb				; write the test value [w1], dec di
		loop .s3_byte_loop	; repeat for the next byte (decrement cx)
		jmp .s3_seg_loop	; repeat for the 64k

	.s3_done:

	; step 4; down - r1,w0
	.step4:
		mov bx, dx			; bx is a temporary segment counter
	.s4_seg_loop:
		lea si, .s4_test	; set the continuation address
		lea di, .s4_done	; set the continuation address
		jmp .segment_count	; count segments/bytes

	; 	test bh, 0F0h		; check high 4 bits of bx
	; 	jz .s4_lt64k		; if high 4 bits of bx are 0, then there is less than 64k left
	; 	sub bx, 1000h		; remove 64k from the counter
	; 	xor cx, cx			; we have more than 64k, so do the next 64k
	; 	jmp .s4_test		; fill the range with the test value
	; .s4_lt64k:
	; 	sub bx, 0			; test if BX is zero
	; 	jz .s4_done			; if BX is zero, we are done
	; 	mov cl, 4			; we have less than 64k, so do the rest
	; 	shl bx, cl			; convert pages to bytes
	; 	mov cx, bx			; set byte counter

	.s4_test:				; cx is the byte counter
		mov di, 0			; beginning of the segment
	.s4_byte_loop:
		mov ah, [di]		; read the byte [r0]
		cmp al, ah			; compare the test value with the byte
		jne .bad			; if not equal, error

	.s4_w1:
		xor al, 0ffh		; invert the test value
		stosb				; write the test value [w1], inc di
		xor al, 0ffh		; invert the test value back to original
		loop .s4_byte_loop	; repeat for the next byte
		jmp .s4_seg_loop	; repeat for the 64k

	.s4_done:

	; now, determine whether to repeat with a new test value

	; broken out segment counting
	.segment_count:
		test bh, 0F0h		; check high 4 bits of bx
		jz .seg_lt64k		; if high 4 bits of bx are 0, then there is less than 64k left
		sub bx, 1000h		; remove 64k from the counter
		xor cx, cx			; we have more than 64k, so do the next 64k
		jmp .sc_next		; now setup to run a test range
	.seg_lt64k:
		sub bx, 0			; test if BX is zero
		jz .sc_done			; if BX is zero, we are done
		mov cl, 4			; we have less than 64k, so do the rest
		shl bx, cl			; convert pages to bytes
		mov cx, bx			; set byte counter
	.sc_next:
		jmp si				; go to the next block
	.sc_done:
		jmp di				; go to the next test stage



	; error
	.bad:
		ret