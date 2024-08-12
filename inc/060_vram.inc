; code: language=nasm tabSize=8
%include "defines.inc"

; ---------------------------------------------------------------------------
section_save
section .romdata
; ---------------------------------------------------------------------------
TxtVrtf: 		db 'Test of video RAM failed. Aborting.  <-----', 0
; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------

CheckVideoRAM:
	__CHECKPOINT__NOSTACK__ 0x0F
; ****************************************************************************
; From here on, we need RAM for variables and for the stack.
;
; Look for RAM in the following locations:
;    - Address B0000 - MDA video RAM.
;    - Address B8000 - CGA video RAM.
;    - Address A0000 - A RAM card configured to put RAM there.
;
; If any of those found, set ES to it.
; If none found, send checkpoint 8A then halt the CPU.

	; ---------------------------------------
	; First, see if MDA video RAM is present.
	; ---------------------------------------
	mov	ax,SegMdaRam		; Start with MDA
	mov	es,ax
	mov	word [es:0],0720h	; Try one address for the moment.
	nop				; Delay for I/O.
	nop				; Delay for I/O.
	cmp	word [es:0],0720h	; Read it, the same value?
	jne	TRYCGA			; --> if no, try CGA
	
	__CHECKPOINT__NOSTACK__ 0x0B ;++++++++++++++++++++++++++++++++++++++++

	jmp	CVREXIT			; -->

	; ---------------------------------------
	; No MDA - See if CGA video RAM present.
	; ---------------------------------------
TRYCGA:	mov	ax,SegCgaRam		; Try CGA.
	mov	es,ax
	mov	word [es:0],0720h	; Try one address for the moment.
	nop				; Delay for I/O.
	nop				; Delay for I/O.
	cmp	word [es:0],0720h	; Read it, the same value?
	jne	TRYA0000		; --> if no, try RAM at A0000.

	__CHECKPOINT__NOSTACK__ 0x0C ;++++++++++++++++++++++++++++++++++++++++

	jmp	CVREXIT			; -->

	; ---------------------------------------
	; No CGA - See if RAM at address A0000 is present.
	; ---------------------------------------
TRYA0000:
	mov	ax,0A000h
	mov	es,ax
	mov	word [es:0],0720h	; Try one address for the moment.
	nop				; Delay for I/O.
	nop				; Delay for I/O.
	cmp	word [es:0],0720h	; Read it, the same value?
	jne	NOVID			; --> if no
	
	__CHECKPOINT__NOSTACK__ 0x0D ;++++++++++++++++++++++++++++++++++++++++

	jmp	CVREXIT			; -->


NOVID:	
; ----------------------------------------------------------------------------
; No MDA/CGA/A0000 video RAM found.
; ----------------------------------------------------------------------------

	__CHECKPOINT__NOSTACK__ 0x8A ;++++++++++++++++++++++++++++++++++++++++

%ifdef USE_SERIAL
	; Send '8A' to the COM1 port (i.e. I/O port 3F8h).
	mov	dx,COM1_lsr	; Line status register (LSR).
.L66:	in	al,dx
	and	al,00100000b
	jz	.L66		; --> if UART is not ready.
	mov	dx,COM1_tx_rx_dll
	mov	al,'8'
	out	dx,al
	mov	dx,COM1_lsr	; Line status register (LSR).
.L77:	in	al,dx
	and	al,00100000b
	jz	.L77		; --> if UART is not ready.
	mov	dx,COM1_tx_rx_dll
	mov	al,'A'
	out	dx,al
%endif
	; Halt the CPU.
	cli
	hlt

CVREXIT:


TVAR:
; ****************************************************************************
; MDA video RAM, or CGA video RAM, or RAM at address A0000, was found.
;
; On entry, ES is pointing to either:
; - Address B0000 if MDA video card RAM is present; or
; - Address B8000 if CGA video card RAM is present; or
; - Address A0000 if a RAM card is configured to put some RAM at A0000.
; 
; This diagnostic uses only 96 bytes of the RAM. We will now test those 96 bytes before we commit to using them.
; 
;   MDA: 4 KB of video RAM. The last 96 bytes are unused by the card - what this diagnostic will use.
;   CGA: The last 96 bytes of the first 4 KB are unused by the card - what this diagnostic will use.
; A0000: The 96 bytes starting at offset 4000h.
; 
; Test the 96 bytes. If that test fails, halt the CPU.

	mov	ax,0FFFFh		; First test data pattern

.L16:	; Fill 96 bytes with test data.
	mov	di,rwdata_base			; End of screen RAM.
	mov	cx,48			; 48 words = 96 bytes
	rep	stosw			; Fill 48 words with test data  { STOSW: AX-->[ES:DI], then DI=DI+2 }

	; A short delay.
	xor	cx,cx
	loop	$

	; See if the 96 bytes have the expected content.
	mov	di,rwdata_base			; End of screen RAM
	mov	cx,48
	repe	scasw			; Compare 48 words with test data, OK?
	jne	.FAIL			; --> if no

	; They do, so on to next test pattern.
	sub	ax,5555h		; Next pattern, overflow?
	jnc	.L16			; --> if no 

	jmp	.PASS			; -->

.FAIL:	
; ----------------------------------------------------------------------------
; MDA/CGA: Failure of the last 96 bytes of MDA/CGA video RAM.
;   A0000: Failure of the 96 bytes at offset 4000h within the RAM.
; ----------------------------------------------------------------------------

	__CHECKPOINT__NOSTACK__ 0x8D ;++++++++++++++++++++++++++++++++++++++++

	; Send '8D' to the COM1 port (i.e. I/O port 3F8h).
%ifdef USE_SERIAL
	mov	dx,COM1_lsr		; Line status register (LSR).
.L66:	in	al,dx
	and	al,00100000b
	jz	.L66			; --> if UART is not ready.
	mov	dx,COM1_tx_rx_dll
	mov	al,'8'
	out	dx,al
	mov	dx,COM1_lsr		; Line status register (LSR).
.L77:	in	al,dx
	and	al,00100000b
	jz	.L77			; --> if UART is not ready.
	mov	dx,COM1_tx_rx_dll
	mov	al,'D'
	out	dx,al
%endif

	; Display "Test of video RAM failed. Aborting.  <-----"
	mov	si,TxtVrtf
	mov	di,482			; DI := starting postion of text (offset into MDA/CGA video RAM)
	mov	ax,SegCgaRam
	mov	es,ax			; Point ES to segment address of MDA video RAM
	mov	ah,07h			; Char attribute = normal
.L40:	mov	al,[cs:si]		; Read character
	inc	si
	and	al,al			; End of the text?
	jz	.S40			; --> if yes 
	stosw				; Write character plus attribute { STOSW: AX-->[ES:DI], then DI=DI+2 }
	jmp	.L40			; -->

	; Halt the CPU
.S40:	cli
	hlt


.PASS:	;------------------------
	; Test successful.
	; -----------------------
	; MDA/CGA: Set the stack top to near the top of video RAM.
	;   A0000: Set the stack top at 4094 bytes into RAM.

	mov	ax,es
	mov	ss,ax			; SS = ES = segment address of video RAM (either MDA or CGA or A0000).
	; mov	sp,rwdata_init_sp-2	; 4094
	mov	sp,rwdata_init_sp		; 4096



; Info:	SS won't change anymore and will serve as a permanent pointer to the video RAM segment.

; Info:	We now have a stack. Therefore, we can now use '__CHECKPOINT__' (uses the stack) instead 
;	of '__CHECKPOINT__NOSTACK__' (does not use the stack). This will reduce the amount of code.

	__CHECKPOINT__ 0x0E ;++++++++++++++++++++++++++++++++++++++++


clear_rwdata:
; ****************************************************************************
; Clear the variables that are stored in the unused 96 bytes at the end of 4 KB sized video RAM.
; For CGA, that 4 KB is the first block of 4 KB.
	mov	ax, ss
	mov	es, ax			; Point ES to segment address of MDA/CGA video RAM.

	xor	al, al			; The bytes are to be zeroed.
	mov	di, rwdata_base		; Start at the first variable (Err8253Ch0).
	; mov	cx, 48			; 48 words = 96 bytes
	mov	cx, (rwdata_end-rwdata_start)	; erase the variable area
	rep	stosb			; STOSW: AX-->[ES:DI], then DI=DI+2

	mov	al, 55h			; fill the rest with 55h so we can see how much of the area is used
	mov	cx, (rwdata_init_sp-rwdata_base)-(rwdata_end-rwdata_start)
	rep	stosb

	; mov	ax, 0CCCCh
	; push	ax			; test the stack
	; pop	ax