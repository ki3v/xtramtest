; code: language=nasm tabSize=8
%include "defines.inc"

; From Super PC/Turbo XT BIOS


cold_boot:
		cld
		xor	ax, ax				; Prepare to initialize
		out	IO_NMI_MASK, al			;   no NMI interrupts

		mov	al, 10011001b			; Program 8255 PIA chip
		out	IO_PPI_CTL, al 			;   Ports A & C, inputs
		mov	al, PPIB_DEFAULT		; Setup PPI port B configuration (parity, turbo, etc)
		out	IO_PPI_B, al 			;   on main board

		mov	al, 01010100b			; IC 8253 inits memory refresh
		out	IO_PIT_CTL, al 			;   chan 1 pulses IC 8237 to
		mov	al, 12h 			;   DMA every 12h clock ticks
		out	IO_PIT_CH1, al 			;   64K done in 1 millisecond
		mov	al, 01000000b			; Latch value 12h in 8253 clock
		out	IO_PIT_CTL, al 			;   chip channel 1 counter

	.init_dma:
		mov	al, 0				; Do some initialization
		out	IO_DMA_PG2, al 			;   DMA page reg, chan 2
		out	IO_DMA_PG3, al 			;   DMA page reg, chan 3
		out	IO_DMA_PG01, al 		;   DMA page reg, chan 0,1
		out	IO_DMA_TEMP_CLR, al 		; Stop DMA on 8237 chip
		mov	al, 01011000b			; Refresh auto-init dummy read
		out	IO_DMA_MODE, al 		;   on channel 0 of DMA chip
		mov	al, 01000001b			; Block verify
		out	IO_DMA_MODE, al 		;   on channel 1 of DMA chip
		mov	al, 01000010b			; Block verify
		out	IO_DMA_MODE, al 		;   on channel 2 of DMA chip
		mov	al, 01000011b			; Block verify
		out	IO_DMA_MODE, al 		;   on channel 3 of DMA chip
		mov	al, 0FFh			; Refresh byte count
		out	IO_DMA0_COUNT, al		;   send lo order
		out	IO_DMA0_COUNT, al		;   send hi order
		inc	ax				; Initialize 8237 command reg
		out	IO_DMA_CMD, al			;   with zero
		out	IO_DMA_MASK, al 		; Enable DMA on all channels

		mov	al, 00110110b			; Set up 8253 timer chip
		out	IO_PIT_CTL, al 			;   chan 0 is time of day
		mov	al, 0				; Request a divide by
		out	IO_PIT_CH0, al 			;   65536 decimal
		out	IO_PIT_CH0, al 			;   0000h or 18.2 tick/sec

		mov	dx, 213h			; Expansion unit port
		inc	ax				;   enable it
		out	dx, al				;   do the enable
