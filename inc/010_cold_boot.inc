; code: language=nasm tabSize=8
%include "defines.inc"

cold_boot:	

; From Super PC/Turbo XT BIOS

%define TURBO_ENABLED 1

	cld
	mov	al, 0				; Prepare to initialize
	out	0A0h, al			;   no NMI interrupts
	mov	dx, 3D8h			; Load Color Graphic port
	out	dx, al				;   no video display
	mov	dl, 0B8h			; Load Monochrome port
	inc	al				;   no video display
	out	dx, al				;   write it out
	mov	al, 10011001b			; Program 8255 PIA chip
	out	63h, al 			;   Ports A & C, inputs
%ifdef	TURBO_ENABLED
	mov	al, 10100101b			; Set (non)turbo mode
	out	61h, al 			;   on main board
%endif
	mov	al, 01010100b			; IC 8253 inits memory refresh
	out	43h, al 			;   chan 1 pulses IC 8237 to
	mov	al, 12h 			;   DMA every 12h clock ticks
	out	41h, al 			;   64K done in 1 millisecond
	mov	al, 01000000b			; Latch value 12h in 8253 clock
	out	43h, al 			;   chip channel 1 counter

.init_dma:
	mov	al, 0				; Do some initialization
	out	81h, al 			;   DMA page reg, chan 2
	out	82h, al 			;   DMA page reg, chan 3
	out	83h, al 			;   DMA page reg, chan 0,1
	out	0Dh, al 			; Stop DMA on 8237 chip
	mov	al, 01011000b			; Refresh auto-init dummy read
	out	0Bh, al 			;   on channel 0 of DMA chip
	mov	al, 01000001b			; Block verify
	out	0Bh, al 			;   on channel 1 of DMA chip
	mov	al, 01000010b			; Block verify
	out	0Bh, al 			;   on channel 2 of DMA chip
	mov	al, 01000011b			; Block verify
	out	0Bh, al 			;   on channel 3 of DMA chip
	mov	al, 0FFh			; Refresh byte count
	out	1, al				;   send lo order
	out	1, al				;   send hi order
	inc	ax				; Initialize 8237 command reg
	out	8, al				;   with zero
	out	0Ah, al 			; Enable DMA on all channels
	mov	al, 00110110b			; Set up 8253 timer chip
	out	43h, al 			;   chan 0 is time of day
	mov	al, 0				; Request a divide by
	out	40h, al 			;   65536 decimal
	out	40h, al 			;   0000h or 18.2 tick/sec
	mov	dx, 213h			; Expansion unit port
	inc	ax				;   enable it
	out	dx, al				;   do the enable
	; mov	ax, 40h 			; Get BIOS data area segment
	; mov	ds, ax				;   into ds register
	; mov	si, [ds:72h]			; Save reset flag in si reg
	; xor	ax, ax				;   cause memory check
	; mov	bp, ax				;   will clobber the flag
	; mov	bx, ax				; Start at segment 0000h
	; mov	dx, 55AAh			;   get pattern
	; cld					; Strings auto-increment


	; 	cli			; disable IRQs

	; 	mov	al, 1		; send a 1 to any POST card present to show we're running
	; 	out	0x80, al

	; .mask_nmi:
	; 	xor	al, al		; mask NMIs using the NMI control port in case the MB didn't
	; 	out	PORT_NMI_MASK, al

	; .set_segregs:
	; 	cld			; default direction is forward

	; 	mov	ax, cs		; copy CS
	; 	mov	ds, ax		; to DS
	; 	mov	ss, ax		; and SS

	; .init_8255P:	; Initialise the 8255 PPI chip.
	; 	mov	al,99h
	; 	out	PPI8255_ctrl, al	; Set port B to outputs, and ports A and C to inputs.

	; 	mov	al,0F8h
	; 	out	PPI8255_B,al		; 1. Reset/clear the two 'RAM parity error' latches.
	; 					; 2. Turns off turbo mode if the clone XT motherboard supports 
	; 					;    turbo control via bit 2.

