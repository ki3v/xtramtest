; ---------------------------------------------------------------------------
section_save
section .romdata
; ---------------------------------------------------------------------------
TxtChk2KbRAM:		db 10,  2, 'Check first 2 KB of RAM', 0
; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------

Check2KbRAM:
; ****************************************************************************
; ON-SCREEN TEST: Displayed is "Check first 2 KB of RAM".
; 
; Test each address in the first 2 KB of RAM.
; 
; -------------------------------------------------------------
; At each address:
; 
; - Use the five test values of: FFh,00h,55h,AAh,01h (in that order).
; 
; - Use ALL (repeat: all) test values.
;   Do not abort the test of an address if one of the test values results in an error.
;   For each test value, note the failing bit pattern.
;   Use the failing bit pattern (if any) from all five test values to create a 'combined' failing bit pattern.
;   
;   Note: If during a test, a parity error is indicated, the parity chip in the bank may or may not be faulty.
;         - If the test value read back differs to what was written, ignore the parity error.
;         - If the test value read back is the same to what was written, and a parity error indicated, 
;           that indicates a faulty parity chip (or parity circuitry).
;   
; -------------------------------------------------------------
;   
; As soon as a test (a five-values test) of an address fails, abort the "Check first 2 KB of RAM", then report details, then halt the CPU.

	; Display "Check first 2 KB of RAM" in inverse, with an arrow to the left of it.
	mov	si,TxtChk2KbRAM
	call	TextToScreenInv
	call	ShowArrow

	; Do the delay that we put between on-screen tests.
	call	InterTestDelay

	xor	dx,dx
	mov	es,dx			; ES := segment of first test RAM address, which is 0000
	mov	cx,0800h		; 2 KB sized block : a byte count required for TESTRAMBLOCK : 800H bytes = 2048 bytes = 2 KB
	call	TESTRAMBLOCK
	jnc	.PASS			; --> if TESTRAMBLOCK indicates no error

.FAIL:	
	__CHECKPOINT__ 0xAA ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	; Display FAILED, but do NOT remove the arrow.
	mov	si,TxtChk2KbRAM
	call	DisplayFailed

	; Display ">> Critical error ...", then display error (address + BEP) details, then halt the CPU.
	mov	si,TxtChk2KbRAM
	jmp	CriticalErrorCond_1

.PASS:	;------------------------
	; Test successful.
	; -----------------------

	; Display PASSED and remove the arrow.
	mov	si,TxtChk2KbRAM
	call	DisplayPassedA

	__CHECKPOINT__ 0x32 ;++++++++++++++++++++++++++++++++++++++++


