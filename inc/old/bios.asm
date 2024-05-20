; code: language=nasm tabSize=8
%include "defines.inc"


	; jmp ChecksumROM


; ---------------------------------------------------------------------------
section_save
section .romdata
; ---------------------------------------------------------------------------

TxtChecksumROM:		db  3,  2, 'Diagnostic ROM checksum', 0

; ---------------------------------------------------------------------------
section .lib
; ---------------------------------------------------------------------------

; ****************************************************************************
; Check out an 8 KB sized ROM and then display the result.
;
;   INPUTS: - DI = start of 8 KB range.
;           - SI = original text.
;
;  OUTPUTS: - {nothing}
;
; DESTROYS: AX, BX, CX, DI, DX, ES, SI
;
; ****************************************************************************
DoCheck8kbRom:

	call	Check8kbRom		; ( Destroys: AX, CX, DX)
	jnc	.PASS			; --> if good
	jmp	DisplayFailedA		; Trail ends in a RET   ( Destroys: AX, BX, CX, DI, DX, ES, SI )
.PASS:	jmp	DisplayPassedA		; Trail ends in a RET   ( Destroys: AX, BX, CX, DI, DX, ES, SI )



; ****************************************************************************
; Check the passed 8 KB sized ROM.
; 
; Primarily, we are looking for the 8-bit checksum being 00. 
;
; However, if that is the only thing we did, empty ROM sockets could pass.
; E.g. Motherboard #1 returns FF reading an empty ROM socket. 8 KB of FF has an 8-bit checksum of 00.
; E.g. Motherboard #1 returns FE reading an empty ROM socket. 8 KB of FE has an 8-bit checksum of 00.
; E.g. Motherboard #1 returns FC reading an empty ROM socket. 8 KB of FC has an 8-bit checksum of 00.
;
; BTW. I have IBM 51xx motherboards that read FC, FE, and FF. Who knows what other variations there are.
;
; Ideally, we want empty ROM sockets to show as FAILED.
;
; Note that identifying an empty ROM socket cannot always be determined by seeing if ALL bytes of the ROM are the same.
; An example is the IBM 62X0819 motherboard ROM (32 KB) for the IBM 5160.
; The second and third 8 KB blocks of that 32 KB ROM contain nothing but CC (also having an 8-bit checksum of 00).
;
; SUMMARY: There is no foolproof way of determining an empty ROM socket.
;
; But a compromise is possible.
;
; Fail the test if either of the following are true:
; Failure criterion #1: The 8-bit checksum is not 00; or
; Failure criterion #2: All bytes are identical, AND, the byte is in [FC to FF].
;
;   INPUTS: - DI = start of 8 KB range (e.g. for F400:0000, passed is F400).
;
;  OUTPUTS: Carry flag, clear (NC) = SUCCESS, set (C) = ERROR
;
; DESTROYS: AX, CX, DX
;
; ****************************************************************************
Check8kbRom:

	push	ds
	push	si

	mov	ds,di		; DS = segment to be tested.
	mov	cx,2000h	; 8 KB of ROM.
	xor	dx,dx		; Zero our byte recorder.
	xor	si,si		; Zero our offset counter.
	xor	ah,ah		; Zero the running checksum.

.L10:	; Read the content of every byte in this ROM.
	lodsb			; Copy contents of [SI] into AL, then increment SI.
	add	ah,al		; Add to the running 8-bit checksum.
	; If first byte, store it.
	cmp	cx,2000h
	jne	.S20
	mov	dl,al		; DL := record of first byte.
.S20:	; Compare the byte read to the first byte read.
	; If different, flag that in DH.
	cmp	al,dl
	je	.S30
	mov	dh,1		; Flag non-identical bytes in content.
.S30:	loop	.L10

	; All 8KB is processed.
	;
	; ------------------------------
	; Failure criterion #1 - 8-bit checksum is not 00.
	cmp	ah,0
	jne	.FAIL		; --> if not 00
	;
	; ------------------------------
	; 8-bit checksum is 00.
	; That is good, but the test can still fail.
	; Failure criterion #2 - All bytes are identical, AND, the byte is in [FC to FF].
	cmp	dh,1
	je	.PASS		; --> if bytes non-identical
	; All bytes are identical.
	; The test fails if the byte is in [FC to FF].
	mov	al,dl
	cmp	dl,0FFh
	je	.FAIL		; --> FF
	cmp	al,0FEh
	je	.FAIL		; --> FE
	cmp	al,0FDh
	je	.FAIL		; --> FD
	cmp	al,0FCh
	je	.FAIL		; --> FC

.PASS:	clc			; Clear carry flag to indicate success.
	jmp	.EXIT		; -->

.FAIL:	stc			; Set carry flag to indicate ERROR.

.EXIT:	pop	si
	pop	ds

	ret



; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------

ChecksumROM:
; ****************************************************************************
; ON-SCREEN TEST: Displayed is "Diagnostic ROM checksum".
;
; Verify that the 8-bit checksum of Ruud's Diagnostic ROM is 00.
; Ruud's Diagnostic ROM is 8 KB sized and starts at address FE000 (F000:E000).

	; Display "Diagnostic ROM checksum" in inverse, with an arrow to the left of it.
	mov	si,TxtChecksumROM
	call	TextToScreenInv
	call	ShowArrow

	; Do the delay that we put between on-screen tests.
	call	InterTestDelay

	; Preparation.
	mov	ax,0F000h	; Segment = F000
	mov	es,ax
	mov	bx,0E000h	; Starting offset.
	mov	cx,2000h	; 8 KB sized.
	xor	al,al		; Zero our running sum.

.L10:	; Add (sum) the content of every byte in this ROM.
	add	al,[es:bx]
	inc	bx		; Point to next address.
	loop	.L10

	; Result is zero ?
	or	al,al
	jz	.PASS		; --> if yes

.FAIL:	
; ----------------------------------------------------------------------------
; Checksum is bad.
; ----------------------------------------------------------------------------
	__CHECKPOINT__ 0x96 ;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	; Display FAILED, but do NOT remove the arrow.
	mov	si,TxtChecksumROM
	call	DisplayFailed

	; Display ">> Critical error, diagnostics have been stopped! <<"
	mov	si,TxtChecksumROM
	call	DispCritical

	; Halt the CPU
%ifdef USE_SERIAL
	call	SendCrlfHashToCom1	; Send a CR/LF/hash sequence to COM1, indicating CPU halt.
%endif
	cli
	hlt


.PASS:	;------------------------
	; Checksum is good.
	; -----------------------
	; Display PASSED and remove the arrow.
	mov	si,TxtChecksumROM
	call	DisplayPassedA

	__CHECKPOINT__ 0x18 ;++++++++++++++++++++++++++++++++++++++++
