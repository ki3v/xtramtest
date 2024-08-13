; code: language=nasm tabSize=8
[list -]
%ifndef DEFINES_INC
%define DEFINES_INC

BITS 16
CPU 8086

%include "macros.inc"

;-------------------------------------------------------------------------------
; I/O port information
;-------------------------------------------------------------------------------
DMA8237_0_ar	equ	0		; channel 0 address register
DMA8237_0_wc	equ	1		; channel 0 word count
DMA8237_1_ar	equ	2		; channel 1 address register
DMA8237_1_wc	equ	3		; channel 1 word count
DMA8237_2_ar	equ	4		; channel 2 address register
DMA8237_2_wc	equ	5		; channel 2 word count
DMA8237_3_ar	equ	6		; channel 3 address register
DMA8237_3_wc	equ	7		; channel 3 word count
DMA8237_scr	equ	8		; status/command register
DMA8237_req	equ	9		; Request register
DMA8237_mask	equ	0Ah		; Mask register
DMA8237_mode	equ	0Bh		; Mode register
DMA8237_cmlff	equ	0Ch		; Clear MSB/LSB flip flop
DMA8237_mc	equ	0Dh		; Master clear

; Programmable Interrupt Controller
PIC8259_cmd	equ	20h		; command port
PIC8259_imr	equ	21h		; interrupt mask register

; Programmable Interval Timer
PIT8253_0	equ	40h		; channel 0
PIT8253_1	equ	41h		; channel 1
PIT8253_2	equ	42h		; channel 2
PIT8253_ctrl	equ	43h		; control

; Programmable Peripheral Interface 8255
PPI8255_A	equ	60h		; port A
PPI8255_B	equ	61h		; port B
PPI8255_C	equ	62h		; port C
PPI8255_ctrl	equ	63h		; control

DebugIO		equ	80h

; DMA page register
DmaPageRegCh2	equ	81h
DmaPageRegCh3	equ	82h
DmaPageRegCh1	equ	83h

PORT_NMI_MASK	equ	0A0h

MDA_index	equ	3B4h		; 6845 Index Register
MDA_data	equ	3B5h		; 6845 Data Register
MDA_ctrl	equ	3B8h		; CRT Control Port 1

CGA_index	equ	3D4h		; 6845 Index Register
CGA_data	equ	3D5h		; 6845 Data Register
CGA_ctrl	equ	3D8h		; Mode Control Register
CGA_pal		equ	3D9h		; Color Select Register

CGA_CTRL_VSVS	equ	0x08		; Vertical Sync bit

SegMdaRam	equ	0B000h
SegCgaRam	equ	0B800h


;-------------------------------------------------------------------------------
; Variables stored in low motherboard RAM (after that RAM has been FULLY tested).
;-------------------------------------------------------------------------------
IntIsrRecord	equ	0400h		; Address = 0000:0400 - Where the ISR record is stored.
KybTestResult	equ	0401h		; Address = 0000:0401 - Where the result of the keyboard test is stored.
FdcResetCount	equ	0402h		; Address = 0000:0402 - Used by the FDC reset subroutine.
FloppyReadCount	equ	0403h		; Address = 0000:0403 - Used by the 'read a floppy' test.
NmiFlag		equ	0404h		; Address = 0000:0404 - Normally 0. NMI handler will set this to 1.

; ;-------------------------------------------------------------------------------
; ;Variables stored in unused MDA/CGA video RAM, or 4 KB at A0000.
; ;-------------------------------------------------------------------------------
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