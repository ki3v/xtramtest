	__CHECKPOINT__NOSTACK__ 0x09
	
; ; ****************************************************************************
; ; Initialise the 8255 PPI chip.

; 	mov	al,99h
; 	out	PPI8255_ctrl,al		; Set port B to outputs, and ports A and C to inputs.

; 	mov	al,0F8h
; 	out	PPI8255_B,al		; 1. Reset/clear the two 'RAM parity error' latches.
; 					; 2. Turns off turbo mode if the clone XT motherboard supports 
; 					;    turbo control via bit 2.

	; __CHECKPOINT__NOSTACK__ 0x08 ;++++++++++++++++++++++++++++++++++++++++


; ****************************************************************************
; At power-on, NMI's are prevented from reaching the CPU.
; But a motherboard can fail in a way that the NMI pin of the CPU goes HIGH intermittently. 
; Or perhaps it is the 8088 that is faulty, internally trigging an NMI.
; That would be very very rare, but we will attempt to cater for that by pointing the NMI vector 
; to our NMI handler code for an unexpected NMI.
; If an unexpected NMI happens, that code will clear the screen and display '*** UNEXPECTED NMI ***'.
; 
; At this time, the low RAM where the CPU interrupt 2 vector is, has not been tested.
; Take a chance that the RAM is there and good.
; If missing or bad, we will not be able to detect unexpected NMI's happening during the many tests done.

	; An NMI triggers CPU interrupt 2.
	; Change the CPU interrupt 2 vector to point to our NMI handler code for this test.
	xor	ax,ax
	mov	es,ax			; ES := 0000
	mov	di,0008h		; Offset of vector for CPU interrupt 2. (2 x 4 bytes)
	mov	ax,NmiHandler_2
	stosw				; STOSW: AX-->[ES:DI], then DI=DI+2
	mov	ax,cs
	stosw				; STOSW: AX-->[ES:DI], then DI=DI+2

	; __CHECKPOINT__NOSTACK__ 0x09 ;++++++++++++++++++++++++++++++++++++++++
