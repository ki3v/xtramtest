; code: language=nasm tabSize=8
%include "defines.inc"
; ---------------------------------------------------------------------------
section_save
section .romdata
; ---------------------------------------------------------------------------

; Tables with data to initialise the MDA and CGA screen
TBL_MDA_CRTC:	db 061h, 050h, 052h, 00Fh, 019h, 006h, 019h, 019h
		db 002h, 00Dh, 02Bh, 00Ch, 000h, 000h, 000h, 000h

TBL_CGA_CRTC:	db 071h		; 6845 register 0 (00h) - 'Horizontal Total'
		db 050h		; 6845 register 1 (01h) - 'Horizontal Displayed'
		db 05Ah		; 6845 register 2 (02h) - 'Horizontal Sync Position'
		db 00Ah		; 6845 register 3 (03h) - 'Horizontal Sync Width'
		db 01Fh		; 6845 register 4 (04h) - 'Vertical Total'
		db 006h		; 6845 register 5 (05h) - 'Vertical Total Adjust'
		db 019h		; 6845 register 6 (06h) - 'Vertical Displayed'
		db 01Ch		; 6845 register 7 (07h) - 'Vertical Sync Position'
		db 002h		; 6845 register 8 (08h) - 'Interlace Mode'
		db 007h		; 6845 register 9 (09h) - 'Maximum Scan Line'
		db 026h		; 6845 register 10 (0Ah) - 'Cursor Start' (was 6)
		db 007h		; 6845 register 11 (0Bh) - 'Cursor End'
		db 000h		; 6845 register 12 (0Ch) - 'Start Address High'
		db 000h		; 6845 register 13 (0Dh) - 'Start Address Low'
		db 000h		; 6845 register 14 (0Eh) - 'Cursor Address High'
		db 000h		; 6845 register 15 (0Fh) - 'Cursor Address Low'

; ---------------------------------------------------------------------------
section .lib

; input:
;	dx = port of the 6845 index register
;	si = table of setup values
init_6845: ; Initialize a 6845 CRT controller
		mov	cx, 16			; 16 registers to do
		xor	bx, bx			; Start our register counter (BL) at 0
	.loop:	mov	al, bl
		out	dx, al			; Specify target register (0 to 15)
		lodsb				; Get the value for that register into AL  {Copy contents of [DS:SI] into AL, then increment SI}
		inc	dl			; DL now pointing to the 6845 Data Register
		out	dx, al			; Send value
		dec	dl			; DL back to pointing to the 6845 Index Register
		inc	bx			; Next register
		loop	.loop

		add	dx, 4			; Point to the 6845 Control Register
		mov	al, 00101001b		; High Resolution/80 col mode, with blinking enabled, and enable the video signal
		out	dx, al

		bpret				; return

; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------


; Initialize the MDA card and CGA card (blindly, even if they don't exist)

init_cga_mda:
		mov	ax, cs
		mov	ds, ax			; DS := CS

		; 1 must be sent to the 'CRT control port 1' before the card is accessed 
		;     - see IBM's technical documentation for the IBM MDA.
		; According to a book, if this is not done: "Otherwise the computer goes into an infinite wait loop."
		mov	dx, IO_MDA_CTL	; MDA control register ('CRT Control Port 1')
		mov	al, 1
		out	dx, al

		; Set appropriate values into the 6845 controller's internal data registers.
		mov	dx, IO_MDA_IDX		; 6845 Index Register, on MDA card
		mov	si, TBL_MDA_CRTC
		bpcall	init_6845

		mov	dx, IO_CGA_IDX		; 6845 Index Register, on CGA card
		mov	si, TBL_CGA_CRTC
		bpcall	init_6845

		; Set the CGA palette.
		mov	dx, IO_CGA_PAL		; CGA palette register ('Color Select Register')
		mov	al, 00110000b
		out	dx, al
