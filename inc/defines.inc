; code: language=nasm tabSize=8
[list -]
%ifndef DEFINES_INC
%define DEFINES_INC

; %define TURBO_ENABLED 1

BITS 16
CPU 8086

%include "macros.inc"

;-------------------------------------------------------------------------------
; I/O port information
;-------------------------------------------------------------------------------

; DMA controller 8237
IO_DMA0_ADDR	equ	0x00		; channel 0 address
IO_DMA0_COUNT	equ	0x01		; channel 0 count
IO_DMA1_ADDR	equ	0x02		; channel 1 address
IO_DMA1_COUNT	equ	0x03		; channel 1 count
IO_DMA2_ADDR	equ	0x04		; channel 2 address
IO_DMA2_COUNT	equ	0x05		; channel 2 count
IO_DMA3_ADDR	equ	0x06		; channel 3 address
IO_DMA3_COUNT	equ	0x07		; channel 3 count
IO_DMA_CMD	equ	0x08		; command register
IO_DMA_REQ	equ	0x09		; request register
IO_DMA_MASK	equ	0x0A		; mask register
IO_DMA_MODE	equ	0x0B		; mode register
IO_DMA_MSB_FF	equ	0x0C		; Clear MSB/LSB flip-flop
IO_DMA_TEMP_CLR	equ	0x0D		; Master clear temp register
IO_DMA_MASK_CLR	equ	0x0E		; Clear mask register
IO_DMA_MASK_MLT	equ	0x0F		; Multiple mask register

; Programmable Interval Timer 8253
IO_PIT_CH0	equ	0x40		; channel 0
IO_PIT_CH1	equ	0x41		; channel 1
IO_PIT_CH2	equ	0x42		; channel 2
IO_PIT_CTL	equ	0x43		; control

; Programmable Peripheral Interface 8255
IO_PPI_A	equ	0x60		; port A
IO_PPI_B	equ	0x61		; port B
IO_PPI_C	equ	0x62		; port C
IO_PPI_CTL	equ	0x63		; control

PPIB_KBREAD	equ	(1<<7)		; 0 = enable keyboard read, 1 = disable
PPIB_KBCLOCK	equ	(1<<6)		; 0 = hold kb clock low, 1 = enable clock
PPIB_IO		equ	(1<<5)		; 0 = enable I/O check, 1 = disable
PPIB_NOPARITY	equ	(1<<4)		; 0 = enable parity check, 1 = disable
PPIB_SW		equ	(1<<3)		; 0 = read sw1-4, 1 = read sw5-8
PPIB_TURBO	equ	(1<<2)		; 0 = turbo mode, 1 = normal
PPIB_SPKR	equ	(1<<1)		; 0 = speaker off, 1 = speaker on
PPIB_TIMER2	equ	(1<<0)		; 0 = timer 2 off, 1 = timer 2 on

%ifdef TURBO_ENABLED
PPIB_DEFAULT	equ	PPIB_KBREAD | PPIB_IO | PPIB_NOPARITY | PPIB_SW | PPIB_TURBO
%else
PPIB_DEFAULT	equ	PPIB_KBREAD | PPIB_IO | PPIB_NOPARITY | PPIB_SW
%endif

; DMA controller 8237 page registers
IO_DMA_PG2	equ	0x81		; page register, channel 2
IO_DMA_PG3	equ	0x82		; page register, channel 3
IO_DMA_PG01	equ	0x83		; page register, channel 0,1

; NMI Mask Register
IO_NMI_MASK	equ	0xA0		; NMI mask register

; MDA CRT controller 6845
IO_MDA_IDX	equ	0x3B4		; index register
IO_MDA_DATA	equ	0x3B5		; data register
IO_MDA_CTL	equ	0x3B8		; control register
IO_MDA_STAT	equ	0x3BA		; status register

SEG_MDA_VRAM	equ	0xB000		; MDA video RAM segment

; CGA CRT controller 6845
IO_CGA_IDX	equ	0x3D4		; index register
IO_CGA_DATA	equ	0x3D5		; data register
IO_CGA_CTL	equ	0x3D8		; control register
IO_CGA_PAL	equ	0x3D9		; color select register
IO_CGA_STAT	equ	0x3DA		; status register

SEG_CGA_VRAM	equ	0xB800		; CGA video RAM segment


;-------------------------------------------------------------------------------
;Variables stored in unused MDA/CGA video RAM, or 4 KB at A0000.
;-------------------------------------------------------------------------------
%ifndef SHOWSTACK
%define SHOWSTACK 0
%endif

%if SHOWSTACK
rwdata_base	equ	4000-96			; Offset of unused portion of MDA/CGA video RAM
rwdata_init_sp	equ	1000h-96		; What we will set the stack pointer to.
%else
rwdata_base	equ	4000			; Offset of unused portion of MDA/CGA video RAM
rwdata_init_sp	equ	1000h			; What we will set the stack pointer to.
%endif


%endif
[list +]