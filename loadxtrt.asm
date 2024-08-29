		org	0x100 

CSEG		equ	0xBA00			; free RAM on CGA card
MSEG		equ	0xB200			; free RAM on Hercules card
VSEG		equ	0xA000			; free RAM on EGA/VGA card? or upper memory block

ENTRY		equ	0x5

		; mov	ax, MSEG
		; call	try_location
		; mov	ax, VSEG
		; call	try_location
		mov	ax, CSEG		
		call	try_location

no_dos_vram:
		mov	si, msg_no_vram
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

msg_no_vram:
	db	"LOADXTRT.COM: Suitable CGA/EGA/VGA video RAM not found", 13, 10, 0

try_location:
		mov	es, ax
		xor	di, di
		mov	ax, 0xa5a5
		mov	es:[di], ax
		cmp	ax, es:[di]
		je	.run_it
		ret
	
	.run_it:
		mov	si, data
		mov	cx, data_end - data
		rep	movsb

		mov	ax, es			; construct the indirect far jump
		mov	[cs:entry_seg], ax	
		jmp	far [entry]		; make the jump

entry:		dw	ENTRY		; this will hold the address to jump to
entry_seg:	dw	0		; this will hold the segment to jump to

data:
incbin "xtramtest.bin"
data_end: