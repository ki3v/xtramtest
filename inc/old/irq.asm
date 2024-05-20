; code: language=nasm tabSize=8
%include "defines.inc"


; ---------------------------------------------------------------------------
section_save
section .romdata
; ---------------------------------------------------------------------------
TxtPIC8259:		db 16,  2, '8259 interrupt controller', 0
TxtCheckHotIrq:		db 17,  2, 'Hot IRQ interrupts', 0
TxtCheckInt0:		db 18,  2, 'Checking interrupt IRQ0', 0

; ---------------------------------------------------------------------------
section .lib
; ---------------------------------------------------------------------------

; ****************************************************************************
; Handle an interrupt triggered by an IRQ.
; Do that by recording the 8259's ISR.
; ****************************************************************************
IrqHandler:

	; Record the ISR in the variable that we use for that purpose.
	mov	al,0Bh
	out	PIC8259_cmd,al		; OCW3 = read ISR on next RD pulse.
	jmp	short $+2		; Delay for I/O.
	in	al,PIC8259_cmd
	or	byte [es:IntIsrRecord],al

	; 8259 - Send an end-of-interrupt command.
	mov	al,20h
	out	PIC8259_cmd,al

	iret	

; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------

CheckPIC8259:
; ****************************************************************************
; ON-SCREEN TEST: Displayed is "8259 interrupt controller".

	; Display "8259 interrupt controller" in inverse, with an arrow to the left of it.
	mov	si,TxtPIC8259
	call	TextToScreenInv
	call	ShowArrow

	; Do the delay that we put between on-screen tests.
	call	InterTestDelay

	; Initialise the 8259.
	mov	al,13h			; ICW1 = ICW4 needed, single 8259, call address interval = 8, edge triggered
	out	PIC8259_cmd,al
	jmp	short $+2		; Delay for I/O.
	mov	al,8			; ICW2 = Interrupts's start at interrupt 8
	out	PIC8259_imr,al 
	jmp	short $+2		; Delay for I/O.
	mov	al,9			; ICW4 = buffered, normal EOI, 8086 mode
	out	PIC8259_imr,al
	jmp	short $+2		; Delay for I/O.

	; Do a check of the In-Service Register (ISR).
	mov	al,0Bh			; OCW3 = read ISR on next RD pulse
	out	PIC8259_cmd,al
	jmp	short $+2		; Delay for I/O.
	in	al,PIC8259_cmd		; Should be zero
	and	al,al			; Is it?
	jne	.FAIL			; --> if no

	; Do a check of the Interrupt Enable Register (interrupt mask register).
	out	PIC8259_imr,al		; AL := zero
	jmp	short $+2		; Delay for I/O.
	in	al,PIC8259_imr		; Should be zero
	and	al,al			; Is it?
	jne	.FAIL			; --> if no
	dec	al			; AL := 0FFh
	out	PIC8259_imr,al		;  also disables all IRQs
	jmp	short $+2		; Delay for I/O.
	in	al,PIC8259_imr		; Should be 0FFh
	cmp	al,0FFh			; Is it?
	je	.PASS			; --> if yes 

.FAIL:	
	__CHECKPOINT__ 0xBE ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


	; Display FAILED, update the test's error counter, and remove the arrow.
	mov	si,TxtPIC8259
	mov	bx,Err8259PIC
	call	DisplayFailedA

	jmp	.EXIT			; -->


.PASS:	;------------------------
	; Test successful.
	; -----------------------

	; Display PASSED and remove the arrow.
	mov	si,TxtPIC8259
	call	DisplayPassedA

.EXIT:
	__CHECKPOINT__ 0x40 ;++++++++++++++++++++++++++++++++++++++++




CheckHotInterrupts:
; ****************************************************************************
; ON-SCREEN TEST: Displayed is "Hot IRQ interrupts".
;
; In the period of about a second, see if an IRQ interrupt occurs.
; None is expected.
;
; Note: In the previous test, all IRQ's were masked out in the 8259.

	; Display "Hot IRQ interrupts" in inverse, with an arrow to the left of it.
	mov	si,TxtCheckHotIrq
	call	TextToScreenInv
	call	ShowArrow

	; Do the delay that we put between on-screen tests.
	call	InterTestDelay

	; IRQ0 through IRQ7 map to CPU interrupts 8 through 15 (0F hex).
	; Point the vectors for CPU interrupts 8 through 15 to our 'IrqHandler' routine.
	xor	ax,ax
	mov	es,ax			; ES := first segment
	mov	di,0020h		; Start at 0000:0020h (vector for CPU interrupt 8)
	mov	cx,0008h		; 8 interrupt vectors (4 bytes each) to set.
.L10:	lea	ax,IrqHandler
	stosw				; STOSW: AX-->[ES:DI], then DI=DI+2
	mov	ax,cs
	stosw				; STOSW: AX-->[ES:DI], then DI=DI+2
	loop	.L10

	; Clear our interrupt ISR recorder.
	mov	byte [es:IntIsrRecord],0	; 0000:0400 (i.e. in low RAM, which has been tested good)

	; 8259A interrupt controller
	mov	al,0Bh
	out	PIC8259_cmd,al		; OCW3 = read ISR on next RD pulse
	mov	al,0FFh
	out	PIC8259_imr,al		; Disable all IRQ interrupts.

	; CPU - Enable maskable interrupts.
	sti

	; Delay.
	xor	cx,cx
	mov	bl,4
.L20:	loop	.L20
	dec	bl
	jnz	.L20

	; CPU - Disable maskable interrupts.
	cli

	; Did any of the enabled CPU interrupts occur ?
	; None are expected, because the corresponding IRQ interrupts are disabled.
	cmp	byte [es:IntIsrRecord],0
	je	.PASS			; --> if no (none expected)

.FAIL:	
	__CHECKPOINT__ 0xC0 ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	; Display FAILED, update the test's error counter, and remove the arrow.
	mov	si,TxtCheckHotIrq
	mov	bx,ErrHotInterrupt
	call	DisplayFailedA

	jmp	.EXIT			; -->

.PASS:	;------------------------
	; Test successful.
	; -----------------------

	; Display PASSED and remove the arrow.
	mov	si,TxtCheckHotIrq
	call	DisplayPassedA

.EXIT:
	__CHECKPOINT__ 0x42 ;++++++++++++++++++++++++++++++++++++++++




CheckINT0:
; ****************************************************************************
; ON-SCREEN TEST: Displayed is "Checking interrupt IRQ0".
;
; - IRQ0 is the trigger for a 'system timer' interrupt.
; - Earlier, the "Hot IRQ interrupts" test had set up the interrupt vector in low RAM.

	; Display "Checking interrupt IRQ0" in inverse, with an arrow to the left of it.
	mov	si,TxtCheckInt0
	call	TextToScreenInv
	call	ShowArrow

	; Do the delay that we put between on-screen tests.
	call	InterTestDelay

	; Clear our interrupt ISR recorder.
	xor	ax,ax
	mov	es,ax
	mov	byte [es:IntIsrRecord],0	; 0000:0400 (i.e. in low RAM, which has been tested good)

	; 8259 - Enable IRQ0 (used by the system timer) and disable all other IRQ's.
	mov	al,11111110b
	out	PIC8259_imr,al

	; 8253 timer
	mov	al,10h
	out	PIT8253_ctrl,al		; Select timer 0, LSB, mode 0, binary.
	mov	al,0FFh
	out	PIT8253_0,al		; Initial count of FF into timer 0.

	; CPU - Enable maskable interrupts (the ones that we earlier unmasked).
	sti

	; Within a SHORT time period, see if the 8259's ISR showed IRQ0.
	; IRQ0 is not expected.
	mov	cx,10h
.L10:	test byte [es:IntIsrRecord],1	; Bit 0 = IRQ0
	jnz	.FAIL			; --> if IRQ0 occurred
	loop	.L10

	; CPU - Disable maskable interrupts.
	cli

	; Clear our interrupt ISR recorder.
	mov	byte [es:IntIsrRecord],0	; 0000:0400 (i.e. in low RAM, which has been tested good)

	; 8253 timer
	mov	al,10h
	out	PIT8253_ctrl,al		; Select timer 0, LSB, mode 0, binary.
	mov	al,0FFh
	out	PIT8253_0,al		; Initial count of FF into timer 0.

	; CPU - Enable maskable interrupts (the ones that we earlier unmasked).
	sti

	; Within a LONG time period, see if the 8259's ISR showed IRQ0.
	; IRQ0 is expected.
	mov	cl,2Eh
.L20:	test byte [es:IntIsrRecord],1	; Bit 0 = IRQ0
	jnz	.PASS			; --> if IRQ0 occurred
	loop	.L20

.FAIL:	
	__CHECKPOINT__ 0xC2 ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	; 8259 - Disable all IRQ's.
	mov	al,11111111b
	out	PIC8259_imr,al
	cli

	; Display FAILED, update the test's error counter, and remove the arrow.
	mov	si,TxtCheckInt0
	mov	bx,ErrInterrupt0
	call	DisplayFailedA

	jmp	.EXIT			; -->

.PASS:	;------------------------
	; Test successful.
	; -----------------------

	; 8259 - Disable all IRQ's.
	mov	al,11111111b
	out	PIC8259_imr,al
	cli

	; 8253 timer - Set it to output a square wave of about 18.2 Hz.
	; ( 1.193160 MHz / FFFFh count = about 18.2 Hz )
	mov	al,36h
	out	PIT8253_ctrl,al		; Select timer 0, LSB/MSB, mode 3, binary.
	mov	al,0
	out	PIT8253_0,al		; Write LSB of 00.
	jmp	short $+2		; Delay for I/O.
	out	PIT8253_0,al		; Write MSB of 00.

	; Display PASSED and remove the arrow.
	mov	si,TxtCheckInt0
	call	DisplayPassedA

.EXIT:
	__CHECKPOINT__ 0x46 ;++++++++++++++++++++++++++++++++++++++++


