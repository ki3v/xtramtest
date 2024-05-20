; code: language=nasm tabSize=8
%include "defines.inc"


; ---------------------------------------------------------------------------
section_save
section .romdata
; ---------------------------------------------------------------------------
TxtChkFDC:		db 22,  2, 'Check floppy controller', 0
TxtReadFloppy:		db 23,  2, 'Trying to read a floppy', 0


; ---------------------------------------------------------------------------
section .lib
; ---------------------------------------------------------------------------

; ****************************************************************************
; Floppy Disk Controller:
; Reset.
;
;   INPUTS: {nothing}
;
;  OUTPUTS: Carry flag, clear (NC) = SUCCESS, set (C) = ERROR
;
; DESTROYS: ??????????????????
;
; ****************************************************************************
FdcReset:

	xor	ax,ax
	mov	es,ax

	; Up to 5 attempts.
	mov	byte [es:FdcResetCount],5

	; FDC - DOR - enable interrupts and DMA (bit 3 = 1), normal operation (bit 2 = 1)
.L10:	mov	dx,FdcDor		; Digital Output Register (DOR)
	mov	al,00001100b
	out	dx,al

	; Delay
	xor	cx,cx
	loop	$

	; Reset.
	; FDC - DOR - enable interrupts and DMA (bit 3 = 1), reset (bit 2 = 0)
	mov	al,00001000b
	out	dx,al

	; Delay
	loop	$

	; FDC - DOR - enable interrupts and DMA (bit 3 = 1), normal operation (bit 2 = 1)
	mov	al,00001100b
	out	dx,al

	; Clear our interrupt ISR recorder.
	mov	byte [es:IntIsrRecord],0

	; Did IRQ6 happen?
	call	FdcIntStatus
	test	byte [es:IntIsrRecord],40h	; Bit 6 = IRQ6
	jnz	.CONT			; --> if interrupt 6 happened
	dec	byte [es:FdcResetCount]
	jnz	.L10

	stc				; Set carry flag to indicate ERROR.
	ret

.CONT:	; Perform the Specify command so that the FDC de-asserts IRQ6.
	mov	ah,3			; Specify
	call	FdcProgram
	mov	ah,0CFh			; Step rate time: 12 ms.
	call	FdcProgram
	mov	ah,2			; Head load time: 6 ms
	call	FdcProgram
	clc				; Clear carry flag to indicate success.
	ret



; ****************************************************************************
; Floppy Disk Controller:
; Sense interrupt status.
;
;   INPUTS: {nothing}
;
;  OUTPUTS: Carry flag, clear (NC) = SUCCESS, set (C) = ERROR
;
; DESTROYS: ??????????????????
;
; ****************************************************************************
FdcIntStatus:

	; See if an interrupt occur within a certain period of time.
	call	CheckForINT
	jnc	.CONT			; --> if yes
	ret				; otherwise return with carry flag set

.CONT:	mov	ah,8			; Sense interrupt status.
	call	FdcProgram
	jc	.ERROR			; --> if a problem
	;
	call	FdcReadResults		; Read the result bytes.
	jc	.ERROR			; --> if a problem

	clc				; Clear carry flag to indicate SUCCESS.
	ret

.ERROR:	stc				; Set carry flag to indicate ERROR.
	ret



; ****************************************************************************
; Floppy Disk Controller:
; Program command/data register 0 with the passed byte.
;
;   INPUTS: - AH = byte for command/data register 0.
;
;  OUTPUTS: - Carry flag, clear (NC) = SUCCESS, set (C) = ERROR
;
; DESTROYS: ??????????????????
;
; ****************************************************************************
FdcProgram:

; Via bit 6 (DIO), wait for controller to indicate ready to receive commands.
	xor	cx,cx
	mov	dx,FdcMsr	; Main status register (MSR)
	mov	si,4
.L10:	in	al,dx
	test	al,40h		; Bit 6 (DIO)
	jz	.S20		; --> if 0 (ready to receive)
	loop	.L10
	dec	si
	jnz	.L10
	; Timeout - Never came ready.
	jmp	.TIMEOUT

; Via bit 7 (RQM), wait for controller to indicate that CPU allowed to interact with data register. 
.S20:	xor	cx,cx
	mov	si,4
.L20:	in	al,dx
	test	al,80h		; Bit 7 (RQM)
	jnz	.S30		; --> if 1
	loop	.L20
	dec	si
	jnz	.L20
	; Timeout - Never came ready.

.TIMEOUT:
	stc			; Set carry flag to indicate ERROR.
	ret

; Now send the command that was passed in AH.
.S30:	mov	dx,FdcCdr0	; Command/data register 0
	mov	al,ah
	out	dx,al

	clc			; Clear carry flag to indicate SUCCESS.
	ret



; ****************************************************************************
; Floppy Disk Controller:
; Read the result bytes (but no need to store them anywhere).
;
;   INPUTS: {nothing}
;
;  OUTPUTS: Carry flag, clear (NC) = SUCCESS, set (C) = ERROR
;
; DESTROYS: ??????????????????
;
; ****************************************************************************
FdcReadResults:

	xor	cx,cx
	mov	ds,cx		; DS points to first segment

	mov	dx,FdcMsr	; Main status register (MSR)

	; Wait for RQM bit (bit 7) to go HIGH, i.e. CPU allowed to interact with data register
	mov	si,4
.L10:	in	al,dx
	test	al,10000000b
	jnz	.S15		; --> if bit is HIGH
	loop	.L10
	dec	si
	jnz	.L10
	; Timeout - Never came ready.
	jmp	.ERROR		; -->

	; Verify that DIO bit (bit 6) is HIGH, i.e. controller --> CPU
.S15:	in	al,dx
	test	al,01000000b
	jnz	.READY		; --> if bit is HIGH
	jmp	.ERROR		; -->

	; Read the result bytes.
.READY:	mov	bl,7		; 7 result bytes at most to be read.
	xor	si,si
.L40:	mov	dx,FdcCdr0	; Command/data register 0
	in	al,dx
	inc	si		; Point to next storage location.
	;
	; Delay
	mov	cx,0Fh
	loop	$
	;
	mov	dx,FdcMsr	; Main status register (MSR)
	in	al,dx
	test	al,00010000b	; Busy ?
	jz	.EXIT		; --> if no longer busy
	dec	bx
	jnz	.L40

.ERROR:
	stc			; Set carry flag to indicate ERROR.
	ret

.EXIT:
	; Set DS to the CS value, because it was changed earlier in this test.
	mov	ax,cs
	mov	ds,ax

	clc			; Clear carry flag to indicate SUCCESS.	
	ret

; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------


CheckFDC:
; ****************************************************************************
; ON-SCREEN TEST: Displayed is "Check floppy controller".
;
; Look for and check the Floppy Disk Controller (FDC).

	__CHECKPOINT__ 0x52 ;++++++++++++++++++++++++++++++++++++++++

	; Display "Check floppy controller" in inverse, with an arrow to the left of it.
	mov	si,TxtChkFDC
	call	TextToScreenInv
	call	ShowArrow

	; Do the delay that we put between on-screen tests.
	call	InterTestDelay

	; 8259 - Enable IRQ6 (the FDC interrupt) and disable all other IRQ's.
	mov	al,10111111b
	out	PIC8259_imr,al

	; Attempt to reset the FDC.
	call	FdcReset
	jnc	.PASS			; --> reset successful

.FAIL:	
	__CHECKPOINT__ 0xD2 ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	; Display FAILED, update the test's error counter, and remove the arrow.
	mov	si,TxtChkFDC
	mov	bx,ErrFDC
	call	DisplayFailedA

	jmp	.EXIT			; -->

.PASS:	;------------------------
	; Test successful.
	; -----------------------

	; Display PASSED and remove the arrow.
	mov	si,TxtChkFDC
	call	DisplayPassedA

.EXIT:
	__CHECKPOINT__ 0x54 ;++++++++++++++++++++++++++++++++++++++++



ChkReadFloppy:
; ****************************************************************************
; ON-SCREEN TEST: Displayed is "Trying to read a floppy".
; On floppy drive 0 (A:), see if the first track on a 360K floppy can be read.
; Only do this if the controller test passed.

	; Display "Trying to read a floppy" in inverse, with an arrow to the left of it.
	mov	si,TxtReadFloppy
	call	TextToScreenInv
	call	ShowArrow

	; Do the delay that we put between on-screen tests.
	call	InterTestDelay

	; Set DS and ES to point to the first segment.
	xor	ax,ax
	mov	ds,ax
	mov	es,ax

	; Get failure count of 'Check floppy controller' test.
	; If non-zero, then:
	;   - Put N/A in place where Passed/FAILED normally goes; then
	;   - Remove the arrow; then
	;   - Abort this test.
	mov	byte al,[ss:ErrFDC]
	cmp	al,0
	je	.CONT			; --> if no controller errors
	mov	si,TxtReadFloppy
	call	TextToScreen		; Undo the inverse text on the original message.
	mov	dx,TxtNA
	call	DispSecondMsg
	mov	si,TxtReadFloppy
	call	RemoveArrow
	jmp	.EXIT			; -->

.CONT:	mov	byte [es:FloppyReadCount],3	; Maximum of 3 read attempts

.L05:	; Clear our interrupt ISR recorder.
	xor	ax,ax
	mov	es,ax
	mov	byte [es:IntIsrRecord],0

	; Floppy drive 0 - Activate the motor
	mov	dx,FdcDor
	mov	al,00011100b	; Motor 0 = 1, /Reset = 1, Drive = 00
	out	dx,al

	; Delay.
	xor	cx,cx
	loop	$

	; 8237 DMA - Program
	mov	al,46h			; Read command for DMA.
	out	DMA8237_cmlff,al	;   clear LSB/MSB flip-flop.
	jmp	short $+2		; Delay for I/O.
	out	DMA8237_mode,al		; Send it to the 8237.

	; Configure things so that the read data will go to the area starting 0000:2000
	; 1. 8237 DMA - Set address where to store the read data = 2000h
	; 2. Set the page register for DMA chan 2 to zero.
	xor	al,al
	out	DMA8237_2_ar,al		; 00h
	jmp	short $+2		; Delay for I/O.
	mov	al,20h			; 20h
	out	DMA8237_2_ar,al
	jmp	short $+2		; Delay for I/O.
	;
	xor	al,al
	out	DmaPageRegCh2,al

	; 8237 DMA - Number of bytes to read = 511 = 01FFh 
	dec	al
	out	DMA8237_2_wc,al		; FF
	inc	al
	inc	al
	out	DMA8237_2_wc,al		; 01

	; Floppy controller uses DMA channel 2.
	; 8237 DMA - Unmask channel 2.
	mov	al,2
	out	DMA8237_mask,al

	; ---------------------------------------------------
	; Floppy drive 0 - Recalibrate
	; Try twice.
	mov	di,2
.L20:	mov	ah,7			; RECALIBRATE command
	call	FdcProgram
	mov	ah,0			; Drive = 0
	call	FdcProgram
	; Now wait for completion (via interrupt IRQ6), then read the result bytes.
	; (Although in the case of a recalibrate command, there are no result bytes.)
	call	FdcIntStatus
	jc	.S55			; --> if no interrupt
	dec	di
	jnz	.L20

	; ---------------------------------------------------
	; Floppy drive 0 - Seek
	mov	ah,0Fh			; SEEK command
	call	FdcProgram
	mov	ah,0			; Head = 0, Drive = 0
	call	FdcProgram
	mov	ah,5			; Cylinder 5
	call	FdcProgram
	; Now wait for completion (via interrupt IRQ6), then read the result bytes.
	; (Although in the case of a seek command, there are no result bytes.)
	call	FdcIntStatus
	jc	.FAIL			; --> if no interrupt

	; Delay
	xor	cx,cx
	loop	$

	; ---------------------------------------------------
	; Floppy drive 0 - Read 9 sectors from head 0 on cylinder 0.
	mov	ah,66h			; READ DATA command: One side, MFM, skip deleted data
	call	FdcProgram
	mov	ah,0			; Head = 0, Drive = 0
	call	FdcProgram
	mov	ah,0			; Cylinder 0
	call	FdcProgram
	mov	ah,0			; Head 0
	call	FdcProgram
	mov	ah,1			; Start at sector 1
	call	FdcProgram
	mov	ah,2			; 512 bytes/sector
	call	FdcProgram
	mov	ah,9			; 9 sectors to transfer
	call	FdcProgram
	mov	ah,2Ah			; Gap length
	call	FdcProgram
	mov	ah,0FFh			; Data length := non-user defined
	call	FdcProgram
	call	CheckForINT
	pushf				; Push flags
	call	FdcReadResults		; Read the result bytes
	jc	.S55
	popf				; Pop flags
	jc	.S55
	xor	ax,ax
	mov	es,ax
	test	byte [es:IntIsrRecord],40h	; Bit 6 = IRQ6
	jnz	.PASS			; --> if IRQ6 happened
.S55:
	dec	byte [es:FloppyReadCount]
	jz	.FAIL
	call	FdcReset
	jmp	.L05			; -->

.FAIL:	
	__CHECKPOINT__ 0xD4 ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	; Display FAILED, update the test's error counter, and remove the arrow.
	mov	si,TxtReadFloppy
	mov	bx,ErrFdcRead
	call	DisplayFailedA

	jmp	.EXIT			; -->

.PASS:	;------------------------
	; Test successful.
	; -----------------------

	; Display PASSED and remove the arrow.
	mov	si,TxtReadFloppy
	call	DisplayPassedA


.EXIT:	; Floppy drive 0 - Stop the motor
	mov	al,00001100b	; Motor 0 = 0, /Reset = 1, Drive = 00
	mov	dx,FdcDor
	out	dx,al

	; Set DS to the CS value, because it was changed earlier in this test.
	mov	ax,cs
	mov	ds,ax

	__CHECKPOINT__ 0x60 ;++++++++++++++++++++++++++++++++++++++++


