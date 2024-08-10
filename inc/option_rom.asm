; code: language=nasm tabSize=8
%include "defines.inc"

int19_vec equ (0x19*4)
int19_save equ 0xDC

; ---------------------------------------------------------------------------
section_save
; ---------------------------------------------------------------------------
section .rwdata ; MARK: __ .rwdata __
; ---------------------------------------------------------------------------



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
	push	ax			; save registers
	push	bx
	push	cx
	push	dx
	push	si
	push	ds
	push	es

	xor	ax,ax
	mov	ds,ax			; set DS to the interrupt table

	mov	bx, (int19_save*4)
	mov	si, [int19_vec]
	mov	word [bx], si		; save the original interrupt vector offset
	mov	si, [int19_vec+2]
	mov	word [bx+2], si		; save the original interrupt vector segment

	mov	word [int19_vec], int_19_handler	; set the new interrupt vector offset
	mov	word [int19_vec+2], cs			; set the new interrupt vector segment

	pop 	es
	pop	ds
	pop 	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	popf
	retf

start_it:
	mov	si, option_start
	call	bios_puts
	jmp	DiagStart


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

; bios_read_input:
; 	sti
; 	mov	ah, 1
; 	int	0x16
; 	jz	bios_read_input
; 	; jz	.kbhit
; ; 	mov	cx, 0
; ; .loop:
; ; 	nop
; ; 	nop
; ; 	loop	.loop
; ; 	jmp 	bios_read_input

; .kbhit:
; 	; mov	ah, 0
; 	; int	0x16

; 	ret

bios_read_input:
	mov	bx, 3 * 18 			; 3 seconds timeout
	; fall through

delay_keypress:
	sti					; Enable interrupts so timer can run
	; add	bx, [es:46Ch]			; Add pause ticks to current timer ticks
	add	bx, [0x46C]			; Add pause ticks to current timer ticks
						;   (0000:046C = 0040:006C)
.delay:
	mov	ah, 01h
	int	16h				; Check for keypress
	jnz	.keypress			; End pause if key pressed

	; mov	cx, [es:46Ch]			; Get current ticks
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
	pushf
	push	ax			; save registers
	push	bx
	push	cx
	push	dx
	push	si
	push	ds
	push	es

	xor	ax,ax
	mov	ds,ax			; set DS to the interrupt table
	; mov	ax,0x40
	; mov	es,ax			; set ES to the BDA

	; sti

	mov	si, option_prompt
	call	bios_puts
	call	bios_read_input
	cmp	al, 'T'
	je	start_it
	cmp	al, 't'
	je	start_it
	; jnz	start_it

	mov	si, option_skip
	call	bios_puts

	pop 	es
	pop	ds
	pop 	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	popf
	int	int19_save
	iret



option_prompt: db "XTRAMTEST", 13, 10, "Press T to run the RAM test, or any other key to continue.", 13, 10, 0
option_start: db "Starting RAM test...", 13, 10, 0
option_skip: db "Skipping RAM test...", 13, 10, 0
have_key: db "got a key", 13, 10, 0