; code: language=nasm tabSize=8
%include "defines.inc"


; ---------------------------------------------------------------------------
section_save
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
section .romdata
; ---------------------------------------------------------------------------
TxtChkKeybReset:	db 20,  2, 'Keyboard responds to reset', 0
TxtChkKeybStuck:	db 21,  2, 'Keyboard stuck key', 0
TxtStuckKey:		db 21, 42, ' Stuck key found:  ', 0


; ---------------------------------------------------------------------------
section .lib
; ---------------------------------------------------------------------------
; ****************************************************************************
; Reset the keyboard interface circuitry on the motherboard.
;   - This clears the 74LS322 shift register. 
;   - This clears IRQ1 (hardware interrupt 1 request).
;
; Done by positive-pulsing the PB7 pin on the 8255.
;
;   INPUTS: {nothing}
;
;  OUTPUTS: {nothing}
;
; DESTROYS: AL
;
; ****************************************************************************
ResetKybInterface:

	mov	al,11001000b		; Clear (bit 7) = high, CLK (bit 6) = high
	out	PPI8255_B,al
	jmp	short $+2		; Small delay.
	jmp	short $+2		; Small delay.
	jmp	short $+2		; Small delay.
	mov	al,01001000b		; Clear (bit 7) = low, CLK (bit 6) = high
	out	PPI8255_B,al
	ret



; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------

CheckKybReset:
; ****************************************************************************
; ON-SCREEN TEST: Displayed is "Keyboard responds to reset".
;
; Check if a keyboard is present, by sending it a software reset,
; then expecting the keyboard to send AA in response.

	; Display "Keyboard responds to reset" in inverse, with an arrow to the left of it.
	mov	si,TxtChkKeybReset
	call	TextToScreenInv
	call	ShowArrow

	; Do the delay that we put between on-screen tests.
	call	InterTestDelay

	; Clear our interrupt ISR recorder.
	xor	ax,ax
	mov	es,ax
	mov	byte [es:IntIsrRecord],0	; 0000:0400 (i.e. in low RAM, which has been tested good)

	; 8259 - Enable IRQ1 (the keyboard interrupt) and disable all other IRQ's.
	mov	al,11111101b
	out	PIC8259_imr,al

	; CPU - Enable maskable interrupts.
	sti	

	; Software reset the keyboard.
	; Done by taking the CLK line low for a while.
	mov	al,00001000b		; Clear (bit 7) = low, CLK (bit 6) = low
	out	PPI8255_B,al
	xor	cx,cx
	loop	$			; Main delay.
	mov	al,11001000b		; Clear (bit 7) = high, CLK (bit 6) = high
	out	PPI8255_B,al
	jmp	short $+2		; Small delay.
	jmp	short $+2		; Small delay.
	jmp	short $+2		; Small delay.
	mov	al,01001000b		; Clear (bit 7) = low, CLK (bit 6) = high
	out	PPI8255_B,al

	; Did IRQ1 occur (triggered by the keyboard sending a byte)?
	call	CheckForINT		; Did an interrupt occur ?
	jc	.FAIL			; --> if not
	test byte [es:IntIsrRecord],2	; Was it IRQ1 ?
	jz	.FAIL			; --> if not 

	; IRQ1 occurred.
	in	al,PPI8255_A		; Read byte sent by keyboard.
	cmp	al,0AAh			; Correct code in response to a reset ?
	je	.PASS			; --> if yes

.FAIL:	
	__CHECKPOINT__ 0xCE ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	; Flag to the following test that this test failed.
	mov	byte [es:KybTestResult],1	; 0000:0401 (i.e. in low RAM, which has been tested good)

	; Display FAILED, update the test's error counter, and remove the arrow.
	mov	si,TxtChkKeybReset
	mov	bx,ErrKeybReset
	call	DisplayFailedA

	jmp	.EXIT			; -->

.PASS:	;------------------------
	; Test successful.
	; -----------------------

	; Flag to the following test that this test passed.
	mov	byte [es:KybTestResult],0	; 0000:0401 (i.e. in low RAM, which has been tested good)

	; Display PASSED and remove the arrow.
	mov	si,TxtChkKeybReset
	call	DisplayPassedA

.EXIT:	; 8259 - Disable all IRQ's.
	mov	al,11111111b
	out	PIC8259_imr,al
	cli

	; Reset the keyboard interface circuitry.
	call	ResetKybInterface	; ( Destroys: AL )

	__CHECKPOINT__ 0x50 ;++++++++++++++++++++++++++++++++++++++++



CheckKybStuck:
; ****************************************************************************
; ON-SCREEN TEST: Displayed is "Keyboard stuck key".
;
; If the previous test failed:
;   Do not do this test. Display 'N/A' where PASED or PASSED would go.
;
; If the previous test passed:
;   See if the keyboard is reporting a stuck key.
;   If not, display PASS.
;   If so, display FAIL, and display the code for the key next to 'Stuck key found:' 

	; Display "Keyboard stuck key" in inverse, with an arrow to the left of it.
	mov	si,TxtChkKeybStuck
	call	TextToScreenInv
	call	ShowArrow

	; Do the delay that we put between on-screen tests.
	call	InterTestDelay

	; If the 'Keyboard responds to reset' test failed, then:
	;   - Put N/A in place where Passed/FAILED normally goes; then
	;   - Remove the arrow; then
	;   - Abort this test.
	xor	ax,ax
	mov	es,ax
	cmp	byte [es:KybTestResult],0
	je	.CONT			; --> it passed
	mov	si,TxtChkKeybStuck
	call	TextToScreen		; Undo the inverse text on the original message.
	mov	dx,TxtNA
	call	DispSecondMsg
	mov	si,TxtChkKeybStuck
	call	RemoveArrow
	jmp	.EXIT			; -->

.CONT:	; Reset the keyboard interface circuitry.
	call	ResetKybInterface	; ( Destroys: AL )

	; Clear our interrupt ISR recorder.
	xor	ax,ax
	mov	es,ax
	mov	byte [es:IntIsrRecord],0

	; 8259 - Enable IRQ1 (the keyboard interrupt) and disable all other IRQ's.
	mov	al,11111101b
	out	PIC8259_imr,al

	; Now wait for an interrupt.
	call	CheckForINT		; Did an interrupt occur ?
	jc	.PASS			; --> if no

	; An interrupt occurred.
	; Assume IRQ1, because that it the only IRQ that we have presenty enabled.
	; Read the keyboard byte into AL.
	in	al,PPI8255_A
	push	ax			; Save AL for later

	; Display "Stuck key found:  ".
	mov	si,TxtStuckKey
	call	TextToScreen

	; To the right of that, display the stuck key (in hex) that the keyboard reported.
	pop ax				; Restore byte of stuck key.
	call DisplayALinHex

.FAIL:	
	__CHECKPOINT__ 0xD0 ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	; Display FAILED, update the test's error counter, and remove the arrow.
	mov	si,TxtChkKeybStuck
	mov	bx,ErrKeybStuck
	call	DisplayFailedA

	jmp	.EXIT			; -->

.PASS:	;------------------------
	; Test successful.
	; -----------------------

	; Display PASSED and remove the arrow.
	mov	si,TxtChkKeybStuck
	call	DisplayPassedA


.EXIT:	; 8259 - Disable all IRQ's.
	mov	al,11111111b
	out	PIC8259_imr,al

	; CPU - Disable maskable interrupts.
	cli

	; Reset the keyboard interface circuitry.
	call	ResetKybInterface	; ( Destroys: AL )

	__CHECKPOINT__ 0x52 ;++++++++++++++++++++++++++++++++++++++++

