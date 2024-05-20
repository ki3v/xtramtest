; ---------------------------------------------------------------------------
section_save
section .romdata
; ---------------------------------------------------------------------------
TxtFoundRAM:		db 11,  2, 'Found RAM:     KB', 0
; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------

SizeRAM:
; ****************************************************************************
; ON-SCREEN: Displayed is "Found RAM:".
; 
; Find the total amount of conventional RAM.
; 
; Done by checking one address within each 16 KB sized block.
; Start with the 16 KB block directly under the 640K (A0000) address.
; If no RAM found there, check the next lower block.
; The 'check the next lower block' step is continued until RAM is found.
; 
; Note: RAM is looked for by writing then reading back five test values to the test address.
;       From that, a 'combined' bit error pattern is returned.
;       In that bit error pattern, only if more than 4 bits are in error, will it be considered that no RAM exists at the test address.
; 
;       I can test this by removing some RAM chips from bank 3 on my IBM 5160 64-256KB motherboard.
;       With four RAM chips removed from bank 3, the RAM size is still indicated as 256 KB. 
;       But when I remove a fifth chip, the RAM size is then indicated as 192 KB (i.e. the fourth RAM bank is considered as unpopulated.)

	; Display "Found RAM:" with an arrow to the left of it.
	mov	si,TxtFoundRAM
	call	TextToScreen
	call	ShowArrow

	; Do the delay that we put between on-screen tests.
	call	InterTestDelay

	mov	ax,9FFFh		; Segment - top of highest possible 16K block of RAM (A0000 = 640K)
	mov	es,ax
.NEWBLK:
	mov	cx,1			; Test only one byte.
	call	TESTRAMBLOCK		; Test first address at ES.   ( Destroys: SI, AX, CX, DX )
	jnc	.EXISTS			; --> if TESTRAMBLOCK reported no bits in error
	; Either TESTRAMBLOCK reported bad data bits, or it reported parity bit error.
	; If it was the parity bit, RAM exists. (TESTRAMBLOCK will only ever indicate a parity error if RAM exists.)
	mov	word ax,[ss:BadDataParity]	; Get the bad data bits (byte) and parity bit indicator (byte).
	cmp	ah,0
	je	.EXISTS			; --> if no bad data bits (i.e. must be a parity chip problem; RAM exists)
	; Bad data bits were found.
	; Count them.
	mov	bl,ah			; BL contains bad bits
	mov	bh,0
	mov	cx,8			; Check 8 bits 
.L10:	rol	bl,1			; Rotate BL through Carry, set?
	jnc	.S20			; --> if no, on to next bit
	inc	bh			; Increase bad bit counter
.S20:	loop	.L10
	; More than 4 bad bits ?
	cmp	bh,4
	jbe	.EXISTS			; --> if not, consider RAM to be present

	; At the test block, there is no RAM, or found was RAM that is too bad (5 or more bad data bits).

	; If we are presently in the first 16 KB block, it is not possible to go lower, so assume that the lower 16K exists.
	; We can assume that because the 'First 2KB RAM' test passed.
	mov	ax,es
	cmp	ax,3FFh			; Are we presently in the first 16 KB block ?
	je	.EXISTS			; --> yes, assume RAM exists

	; Try the next lower 16 KB block.
	sub	ax,0400h		; Subtract 16 KB from segment address.
	mov	es,ax

	jmp	.NEWBLK			; -->

.EXISTS:
	; Either:
	; - No bad data bits (RAM definately present), or 
	; - Less than 5 bad bits (RAM definately present but with some bad RAM chips)
	;
	; At this time, ES points to the highest segment (minus 1) where RAM was found.
	; "RAM was found" = five test values revealed a bad bit count between 0 and 3

	; Save the top-of-RAM segment address for later routines.
	mov	ax,es
	inc	ax			; Round the number up (e.g. 9FFFh --> A000h)(e.g. 03FFh --> 0400h)
	mov	word [ss:SegTopOfRam],ax

	; Set DI to the offset in MDA/CGA video RAM where to display the amount of found RAM.
	; Will be used by our call below to 'DispDecimal_2'.
	mov	si,TxtFoundRAM
	mov	di,11			; 11 chars from the start of "Found RAM:"
	call	CalcScreenOffset	; ( Destroys: nothing )

	; AX presently contains the top-of-RAM segment address (e.g. A000h).
	; Convert that to KB.
	mov	cl,6
	shr	ax,cl			; AX = AX div 64 = number of KB  (e.g. A000h --> 640 dec)

	; Display the amount of found RAM.
	call	AX2DEC			; out: BL = ones, DL = tens, DH = hundreds  in:	AX = number < 1000
	call	DispDecimal_2		;  in: BL = ones, DL = tens, DH = hundreds, DI = offset in MDA/CGA video RAM

	; Remove the arrow.
	mov	si,TxtFoundRAM
	call	RemoveArrow

	__CHECKPOINT__ 0x35 ;++++++++++++++++++++++++++++++++++++++++


