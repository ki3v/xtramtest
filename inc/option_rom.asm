; code: language=nasm tabSize=8
%include "defines.inc"

int19_vec equ (0x19*4)
int19_save equ 0xDC

; ---------------------------------------------------------------------------
section_save
; ---------------------------------------------------------------------------
section .romdata ; MARK: __ .rwdata __
; ---------------------------------------------------------------------------

option_prompt: db 13, 10, " XTRAMTEST - Press T to start ", 0
; option_start: db "Starting RAM test...", 13, 10, 0
option_skip: db "(skipping)", 13, 10, 0


; ---------------------------------------------------------------------------
section .lib ; MARK: __ .lib __
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
section_restore ; MARK: __ restore __
; ---------------------------------------------------------------------------

option_signature:
	dw	0xAA55
option_rom_size:
	db	(RESET+0x10)/512
option_rom:
	pushf
	; push	ax
	push	bx
	; push	cx
	; push	dx
	push	si
	push	ds
	; push	es

	xor	bx,bx
	mov	ds,bx			; set DS to the interrupt table

	mov	bx, (int19_save*4)
	mov	si, [int19_vec]

	cmp	si, int_19_handler	; if the interrupt vector is already set to ours, skip
	je	.done

	mov	word [bx], si		; save the original interrupt vector offset
	mov	si, [int19_vec+2]
	mov	word [bx+2], si		; save the original interrupt vector segment

	mov	word [int19_vec], int_19_handler	; set the new interrupt vector offset
	mov	word [int19_vec+2], cs			; set the new interrupt vector segment

.done:	
	; pop 	es
	pop	ds
	pop 	si
	; pop	dx
	; pop	cx
	pop	bx
	; pop	ax
	popf
	retf

bios_puts:
	mov	ah, 0x0E
.loop:
	mov	al, [cs:si]
	inc	si
	or	al, al
	jz	.done
	int	0x10
	jmp	.loop
.done:
	ret


bios_read_input:
	mov	bx, 3 * 18 			; 3 seconds timeout
	; fall through
delay_keypress:
	sti					; Enable interrupts so timer can run
	add	bx, [0x46C]			; Add pause ticks to current timer ticks
.delay:
	mov	ah, 01h
	int	16h				; Check for keypress
	jnz	.keypress			; End pause if key pressed

	mov	cx, [0x46C]			; Get current ticks
	sub	cx, bx				; See if pause is up yet
	jc	.delay				; Nope

.done:
	cli					; Disable interrupts
	ret

.keypress:
	xor	ah, ah
	int	16h				; Flush keystroke from buffer
	jmp	short .done


int_19_handler:
	; pushf
	; push	ax			; save registers
	; push	bx
	; push	cx
	; push	dx
	; push	si
	; push	ds
	; push	es

	xor	ax,ax
	mov	ds,ax			; set DS to the interrupt table

	mov	si, option_prompt
	call	bios_puts
	call	bios_read_input
	cmp	al, 'T'
	je	.runtest
	cmp	al, 't'
	je	.runtest

	mov	si, option_skip
	call	bios_puts

	; pop 	es
	; pop	ds
	; pop 	si
	; pop	dx
	; pop	cx
	; pop	bx
	; pop	ax
	; popf
	int	int19_save
	iret

.runtest:
	; mov	si, option_start
	; call	bios_puts

	mov	ah, 0x0F		; get current video mode
	int	0x10			; al now has current video mode (need for certain BIOS bugs)

	mov	ah, 1			; hide cursor using BIOS call
	mov	cx, 0x2000		
	int	0x10
	jmp	InitBeep


