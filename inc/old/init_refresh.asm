; code: language=nasm tabSize=8
%include "defines.inc"


InitRefresh:
; ****************************************************************************
; Initialise channel 1 on the 8253 timer chip to produce a negative-going pulse about every 15.1 uS.
; This is done as part of the refresh mechanism for dynamic RAM.
; The other part is suitably configuring channel #0 on the DMA controller, and that was done earlier.
;
; Do this channel 1 initialisation now, a reasonable time before we start testing dynamic RAM.
; This is due to a particular requirement of dynamic RAM.
	mov	al,54h			; Timer 1, LSB only, mode 2, binary counter 16-bit
	out	PIT8253_ctrl,al
	jmp	short $+2		; delay for I/O
	jmp	short $+2		; delay for I/O
	; mov	al,12h			; 1.193 MHz / 18 (12H) = 66.3 kHz = 15.1 uS
	mov	al,09h			; 1.193 MHz / 9 (9H) = 132.6 kHz = 7.55 uS
	out	PIT8253_1,al

	__CHECKPOINT__ 0x28 ;++++++++++++++++++++++++++++++++++++++++
