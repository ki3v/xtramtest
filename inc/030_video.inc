; code: language=nasm tabSize=8
%include "defines.inc"


; ---------------------------------------------------------------------------
section_save
section .romdata
; ---------------------------------------------------------------------------

; Tables with data to initialise the MDA and CGA screen
; Tbl_dataMDA:		db 061h, 050h, 052h, 00Fh, 019h, 006h, 019h, 019h
; 			db 002h, 00Dh, 00Bh, 00Ch, 000h, 000h, 000h, 000h
Tbl_dataMDA:		db 061h, 050h, 052h, 00Fh, 019h, 006h, 019h, 019h
			db 002h, 00Dh, 00Bh, 00Ch, 000h, 000h, 000h, 000h

; Tbl_dataCGA:		db 071h, 050h, 05Ah, 00Ah, 01Fh, 006h, 019h, 01Ch
; 			db 002h, 007h, 006h, 007h, 000h, 000h, 000h, 000h
Tbl_dataCGA:		db 071h		; 6845 register 0 (00h) - 'Horizontal Total'
			db 050h		; 6845 register 1 (01h) - 'Horizontal Displayed'
			db 05Ah		; 6845 register 2 (02h) - 'Horizontal Sync Position'
			db 00Ah		; 6845 register 3 (03h) - 'Horizontal Sync Width'
			db 01Fh		; 6845 register 4 (04h) - 'Vertical Total'
			db 006h		; 6845 register 5 (05h) - 'Vertical Total Adjust'
			db 019h		; 6845 register 6 (06h) - 'Vertical Displayed'
			db 01Ch		; 6845 register 7 (07h) - 'Vertical Sync Position'
			db 002h		; 6845 register 8 (08h) - 'Interlace Mode'
			db 007h		; 6845 register 9 (09h) - 'Maximum Scan Line'
			db 006h		; 6845 register 10 (0Ah) - 'Cursor Start'
			db 007h		; 6845 register 11 (0Bh) - 'Cursor End'
			db 000h		; 6845 register 12 (0Ch) - 'Start Address High'
			db 000h		; 6845 register 13 (0Dh) - 'Start Address Low'
			db 000h		; 6845 register 14 (0Eh) - 'Cursor Address High'
			db 000h		; 6845 register 15 (0Fh) - 'Cursor Address Low'

; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------

InitMdaCga:
	__CHECKPOINT__NOSTACK__ 0x01
; ****************************************************************************
; Initialise the MDA card or CGA card.
; 
; At this point in time, we do not know which is present, MDA or CGA.
; Maybe neither (e.g. user is using a serial port to see checkpoints).
; Just assume that an MDA or CGA is fitted.
; 
; Note that earlier, is some initialisation code specifically targeting the IBM made MDA.

	mov	ax,cs
	mov	ds,ax			; DS := CS

	; ------------------------
	; First, do MDA.
	; This will result in 8Ox25 text mode.
	; ------------------------

	; ----------------------------------------------------------------------------
	; Cater for the IBM made MDA card.
	; 1 must be sent to the 'CRT control port 1' before the card is accessed 
	;     - see IBM's technical documentation for the IBM MDA.
	; According to a book, if this is not done: "Otherwise the computer goes into an infinite wait loop."
	; I experienced that myself.
	; 
	;  We will do this pre-initialisation now, because the next step sends 33h to the MDA's parallel port.
	mov	dx,MDA_ctrl	; MDA control register ('CRT Control Port 1')
	mov	al,1
	out	dx,al

	; Set appropriate values into the 6845 controller's internal data registers.

	mov	dx,MDA_index		; 6845 Index Register, on MDA card
	mov	si,Tbl_dataMDA		; 16 values
	mov	cx,16			; 16 registers to do
	xor	bx,bx			; Start our register counter (BL) at 0
.L10:	mov	al,bl
	out	dx,al			; Specify target register (0 to 15)
	lodsb				; Get the value for that register into AL  {Copy contents of [DS:SI] into AL, then increment SI}
	inc	dl			; DL now pointing to the 6845 Data Register
	out	dx,al			; Send value
	dec	dl			; DL back to pointing to the 6845 Index Register
	inc	bx			; Next register
	loop	.L10

	; Set the mode, and enable video signal.
	mov	dx,MDA_ctrl		; MDA control register ('CRT Control Port 1')
	mov	al,00101001b		; High Resolution mode, with blinking enabled, and enable the video signal
	out	dx,al

	; ------------------------
	; Next, do CGA.
	; This will result in 8Ox25 text mode.
	; ------------------------
	; Set appropriate values into the 6845 controller's internal data registers.

	mov	dx,CGA_index		; 6845 Index Register, on CGA card
	mov	si,Tbl_dataCGA		; 16 values
	mov	cx,16			; 16 registers to do
	xor	bx,bx			; Start our register counter (BL) at 0
.L20:	mov	al,bl
	out	dx,al			; Specify target register (0 to 15)
	lodsb				; Get the value for that register into AL  {Copy contents of [DS:SI] into AL, then increment SI}
	inc	dl			; DL now pointing to the 6845 Data Register
	out	dx,al			; Send value
	dec	dl			; DL back to pointing to the 6845 Index Register
	inc	bx			; Next register
	loop	.L20

	; Set the mode, and enable video signal.
	mov	dx,CGA_ctrl		; CGA mode control register
	mov	al,00101001b		; 80 by 25 text mode, with blinking enabled, and enable the video signal
	out	dx,al

	; Set the palette.
	mov	dx,CGA_pal		; CGA palette register ('Color Select Register')
	mov	al,00110000b
	out	dx,al

	; __CHECKPOINT__NOSTACK__ 0x01 ;++++++++++++++++++++++++++++++++++++++++



SetVideoMode:
; ****************************************************************************
; Make the cursor invisible.
; 
; At this point in time, we do not know which is present, MDA or CGA.
; Maybe neither (e.g. user is using a serial port to see checkpoints).
; Just assume that an MDA or CGA is fitted.

	; ------------------------
	; First, do MDA.
	; ------------------------
	mov	cx,2607h
	;
	; Send 26h to 6845 register 10
	mov	ah,10			; 6845 register 10 (0Ah) - 'Cursor start'
	mov	al,ch			; 26h
	mov	dx,MDA_index		; 6845 Index Register, on MDA card
	xchg	al,ah
	out	dx,al			; Send register number, which is 10 (0Ah)
	xchg	al,ah
	inc	dl			; DL now pointing to the 6845 Data Register
	out	dx,al			; Send 26h for that register
	;
	; Send 07h to 6845 register 11
	inc	ah			; 6845 register 11 (0Bh) - 'Cursor end'
	mov	al,cl			; 07h
	mov	dx,MDA_index		; 6845 Index Register, on MDA card
	xchg	al,ah
	out	dx,al			; Send register number, which is 11 (0Bh)
	xchg	al,ah
	inc	dl			; DL now pointing to the 6845 Data Register
	out	dx,al			; Send 07h for that register

	; ------------------------
	; Next, do CGA.
	; ------------------------
	mov	cx,2607h
	;
	; Send 26h to 6845 register 10
	mov	ah,10			; 6845 register 10 (0Ah) - 'Cursor start'
	mov	al,ch			; 26h
	mov	dx,CGA_index		; 6845 Index Register, on CGA card
	xchg	al,ah
	out	dx,al			; Send register number, which is 10 (0Ah)
	xchg	al,ah
	inc	dl			; DL now pointing to the 6845 Data Register
	out	dx,al			; Send 26h for that register
	;
	; Send 07h to 6845 register 11
	inc	ah			; 6845 register 11 (0Bh) - 'Cursor end'
	mov	al,cl			; 07h
	mov	dx,CGA_index		; 6845 Index Register, on CGA card
	xchg	al,ah
	out	dx,al			; Send register number, which is 11 (0Bh)
	xchg	al,ah
	inc	dl			; DL now pointing to the 6845 Data Register
	out	dx,al			; Send 07h for that register

	; __CHECKPOINT__NOSTACK__ 0x02 ;++++++++++++++++++++++++++++++++++++++++


	; ----------------------------------------------------------------------------
	; Clear the MDA/CGA video screen.
	; 
	; At this point in time, we do not know which is present, MDA or CGA.
	; Maybe neither (e.g. user is using a serial port to see checkpoints).
	; Just assume that an MDA or CGA is fitted.

	mov	ax,SegMdaRam	; MDA
	mov	es,ax		; Point ES to segment address of MDA video RAM.
	mov	ax,0700h+' '	; Attribute + space
	xor	di,di		; Start at first screen position.
	mov	cx,4000		; 4000 words.
	rep	stosw		; STOSW: AX-->[ES:DI], then DI=DI+2

	mov	ax,SegCgaRam	; CGA
	mov	es,ax		; Point ES to segment address of MDA/CGA video RAM.
	mov	ax,0700h+' '	; Attribute + space
	xor	di,di		; Start at first screen position.
	mov	cx,4000		; 4000 words.
	rep	stosw		; STOSW: AX-->[ES:DI], then DI=DI+2

	; __CHECKPOINT__NOSTACK__ 0x03 ;++++++++++++++++++++++++++++++++++++++++

DispRdr:
; ****************************************************************************
; Display "Ruud's Diagnostic ROM for PC/XT ......"
; 
; At this point in time, we do not know which is present, MDA or CGA.
; Maybe neither (e.g. user is using a serial port to see checkpoints).
; Just assume that an MDA or CGA is fitted.

	; ------------------------
	; First, do MDA.
	; ------------------------
	mov	si,title_only
	mov	di,2			; DI := starting postion of text (offset into MDA/CGA video RAM)
	mov	ax,SegMdaRam
	mov	es,ax			; Point ES to segment address of MDA video RAM
	mov	ah,07h			; Char attribute = normal
.L10:	mov	al,[cs:si]		; Read character
	inc	si
	and	al,al			; End of the text?
	jz	.S10			; --> if yes 
	stosw				; Write character plus attribute { STOSW: AX-->[ES:DI], then DI=DI+2 }
	jmp	.L10			; -->

.S10:	; ------------------------
	; Next, do CGA.
	; ------------------------
	mov	si,title_only
	mov	di,2			; DI := starting postion of text (offset into MDA/CGA video RAM)
	mov	ax,SegCgaRam
	mov	es,ax			; Point ES to segment address of CGA video RAM
	mov	ah,07h			; Char attribute = normal
.L20:	mov	al,[cs:si]		; Read character
	inc	si
	and	al,al			; End of the text?
	jz	.EXIT			; --> if yes 
	stosw				; Write character plus attribute { STOSW: AX-->[ES:DI], then DI=DI+2 }
	jmp	.L20			; -->

.EXIT:

	; __CHECKPOINT__NOSTACK__ 0x04 ;++++++++++++++++++++++++++++++++++++++++

