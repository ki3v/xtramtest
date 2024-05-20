; code: language=nasm tabSize=8
%include "defines.inc"


; ---------------------------------------------------------------------------
section_save
section .romdata
; ---------------------------------------------------------------------------
Tbl_ASCII:		db '0123456789ABCDEF'

TxtClearLine:		db '                                                                                ', 0
TxtFailed:		db 'FAILED', 0
TxtPassed:		db 'Passed', 0
TxtNA:			db 'N/A   ', 0		; Important: three spaces at end.

TxtCompletedPasses:	db 20, 42, 'Completed passes:', 0

TxtCritical:		db ' >> Critical error, diagnostics have been stopped! << ', 0
TxtFailAtAddress:	db '  Failure at address:     KB  (exactly xxxxx [hex])', 0
TxtBadBits:		db '  Bad bits:  7 6 5 4 3 2 1 0  P      ', 0
TxtRamChipWarning:	db '<----- May or may not be RAM chips.', 0

; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------

; ****************************************************************************
; Calculate the absolute address from a passed segment and offset address.
; Store the result in the 3-byte variable named 'AbsoluteAddress'.
;
; E.g. E81C:A67D gets converted to 0F283D.
;
;     INPUTS: - AX contains the segment of the address.
;             - DX contains the offset of the address.
;
;    OUTPUTS: Result placed in our 3-byte variable named 'AbsoluteAddress'
;
;   DESTROYS: BX, CL
;
; ****************************************************************************
CalcAbsFromSegOff:

	; Save AX and DX, because this subroutine must not destroy them.
	push	dx
	push	ax			; Note: Will be popped mid routine.

	; Get a preliminary first byte for the screen. We may need to increment it later.
	; Store in AL.
	mov	cl,12			; 
	shr	ax,cl			; AL: = first byte for screen, E.g. E81C --> E

	; Now calculate the next two bytes, and if required, increment the first byte.
	; Store in DX.
	pop	bx			; BX: = segment
	push	bx
	mov	cl,4			; 
	shl	bx,cl			; E.g. E81C --> 81C0
	add	dx,bx			; Add that to the offset, e.g. 81C0 + A67D = 283D with carry
	jnc	.S10			; --> if no carry
	inc	al			; Increment out first byte, e.g. E --> F

.S10:	; Store the bytes.
	mov	byte [ss:AbsoluteAddress+0],al
	mov	byte [ss:AbsoluteAddress+1],dh
	mov	byte [ss:AbsoluteAddress+2],dl

	; Restore AX and DX.
	pop	ax
	pop	dx

	ret



; ****************************************************************************
; A critical error occured.
; 1. Display the bad address and data, and also send it to COM1.
; 2. Halt the CPU.
; ****************************************************************************
CriticalErrorCond_1:

	; Display the failing address and data on-screen.
	call	DispBadAddressAndData

%ifdef USE_SERIAL
	; If COM1 is fitted, send the failing address and bit error pattern (BEP) to COM1.
	; Example: If sent earlier was B8, and the failing address is C000, and BEP is 02, then COM1 monitoring device will see 'B8 C000 02'.
	call	SendBadAddressToCom1
	call	SendBadDataToCom1

	; Now halt the CPU.
	call	SendCrlfHashToCom1	; Send a CR/LF/hash sequence to COM1, indicating CPU halt.
%endif
	cli
	hlt


; ****************************************************************************
; A critical error occured.
; 1. Display the bad address, and also send it to COM1.
; 2. Halt the CPU.
; ****************************************************************************
CriticalErrorCond_2:

	; Display the failing address on-screen.
	call	DispBadAddress

%ifdef USE_SERIAL
	; If COM1 is fitted, send the failing address to COM1.
	; Example: If sent earlier was B9, and the failing address is C000, then COM1 monitoring device will see 'B9 C000'.
	call	SendBadAddressToCom1

	; Now halt the CPU.
	call	SendCrlfHashToCom1	; Send a CR/LF/hash sequence to COM1, indicating CPU halt.
%endif
	cli
	hlt




; ****************************************************************************
; Increment, then fetch the pointed-to error count.
;
;   INPUTS: - BX points to the error count variable.
;           - SS points to the base of MDA or CGA video RAM, as applicable. (We also store some variables there.)
;
;  OUTPUTS: - BL = ones
;           - DL = tens
;           - DH = hundreds

; DESTROYS: AL
;
; ****************************************************************************
IncGetStoredCount:

	inc	byte [ss:bx]		; Increment the pointed-to count.
	mov	al,[ss:bx]		; Fetch the count.
	jmp	AL2DEC			; Convert it to decimal.   ( Trail ends in a RET )




; ****************************************************************************
; Display a critical error message on the screen.
;
;   INPUTS: - SI points to parameters of the on-screen test text (e.g. 'Testing CPU').
;             Parameters:
;                1st byte: row
;                2nd byte: column
;                The text starts at the 3rd byte
;
;  OUTPUTS: {nothing}
;
; DESTROYS: AX, BX, CX, DI, DX, ES, SI
;
; ****************************************************************************
DispCritical:

	;
	; First, clear the line where ">> Critical error ..." will be displayed, and the following line.
	mov	al,[cs:si]		; Get line of original message
	mov	bl,al			; Save for later
	add	al,1			; Next line
	call	ClearLineY		; Clear screen line in AL. ( Destroys: DI, ES )
	add	al,1			; Next line
	call	ClearLineY		; Clear screen line in AL. ( Destroys: DI, ES )
	;
	; Now display the ">> Critical error ..."
	mov	al,bl			; Get line of original message
	add	al,1			; Next line
	xor	ah,ah
	mov	ch,160
	mul	ch
	mov	di,ax			; DI = start of line on screen, as offfset in MDA/CGA video RAM
	add	di,4			; Start of critical message
	; Now display the text.
	mov	si,TxtCritical		; " >> Critical error, diagnostics have been stopped! << "
	mov	dh,70h			; Char attribute = inverted
	jmp	TextToScreen3		; Trail ends in a RET  ( Destroys: AX, BX, DI, DX, ES, {SI=SI-2} )


 
; ****************************************************************************
; 1. Display the text "FAILED" against the pointed-to message.
; 2. Remove the arrow against the pointed-to message.
; 3. Increment the associated error count.
; 4. Display the incremented error count to the left of "FAILED".
;
;   INPUTS: - BX points to the varible containing the error count.
;           - SI points to parameters of the on-screen test text (e.g. 'Testing CPU').
;             Parameters:
;                1st byte: row
;                2nd byte: column
;                The text starts at the 3rd byte
;
;  OUTPUTS: {nothing}
;
; DESTROYS: AX, BX, CX, DI, DX, ES, SI
;
; ****************************************************************************
DisplayFailedA:

	push	si
	push	bx

	; Undo the inverse text on the pointed-to test text.
	call	TextToScreen		

	; Set DI to to the offset in MDA/CGA video RAM where the error count is to be displayed.
	mov	di,26
	call	CalcScreenOffset	; ( Destroys: nothing )

	; BX points to the varible containing the error count.
	; Increment that error count variable,
	;      then return the count in decimal form within BL/DL/DH.
	pop	bx
	call	IncGetStoredCount

	; Get back our pointer to the test text parameters.
	pop	si
	push	si

	; On-screen, display the incremented error count.
	; In: BL = ones, DL = tens, DH = hundreds, DI = offset in MDA/CGA video RAM
	call	DispDecimal_2

	; Display "FAILED"
	mov	dx,TxtFailed
	mov	bl,70h			; Char attribute = inverted
	call	DispSecondMsg2

	; Remove the arrow.
	pop	si
	jmp	RemoveArrow		; Trail ends in a RET   ( Destroys: AX, BX, CX, DI, DX, ES, SI )



; ****************************************************************************
; Display the text "FAILED" against the pointed-to message.
;
;   INPUTS: - SI points to parameters of the on-screen test text (e.g. 'Testing CPU').
;             Parameters:
;                1st byte: row
;                2nd byte: column
;                The text starts at the 3rd byte
;
;  OUTPUTS: {nothing}
;
; DESTROYS: AX, BX, CH, DI, DX, ES, SI
;
; ****************************************************************************
DisplayFailed:

	; Undo the inverse text on the pointed-to message.
	call	TextToScreen

	; Display "FAILED"
	mov	dx,TxtFailed
	mov	bl,70h			; Char attribute = inverted
	jmp	DispSecondMsg2		; ( Destroys: AX, BX, CH, DI, DX, ES, SI )



; ****************************************************************************
; Display the text "PASSED" against message and remove the arrow.
;
;   INPUTS: - SI points to parameters of the on-screen test text (e.g. 'Testing CPU').
;             Parameters:
;                1st byte: row
;                2nd byte: column
;                The text starts at the 3rd byte
;
;  OUTPUTS: {nothing}
;
; DESTROYS: AX, BX, CX, DI, DX, ES, SI
;
; ****************************************************************************
DisplayPassedA:

	push	si

	; Undo the inverse text on the pointed-to message.
	call	TextToScreen		; ( Destroys: AX, BX, CH, DI, DX, ES )

	; Display "PASSED"
	mov	dx,TxtPassed
	call	DispSecondMsg		; ( Destroys: AX, BX, CH, DI, DX, ES, SI )

	; Remove the arrow.
	pop	si
	jmp	RemoveArrow		; Trail ends in a RET   ( Destroys: AX, BX, CX, DI, DX, ES, SI )



; ****************************************************************************
; Display the value in DX at the position specified by SI and DI.
;
;   INPUTS: - SI points to parameters of the on-screen test text (e.g. 'Testing CPU').
;             Parameters:
;                1st byte: row
;                2nd byte: column
;                The text starts at the 3rd byte
;           - AX = offset from start of the on-screen test text
;           - DX = word to display (in decimal)
;
;  OUTPUTS: {nothing}
;
; DESTROYS: {nothing}
;
; ****************************************************************************
DispDecimal_1:

	push	bx
	push	di
	push	si
	mov	di,ax
	call	CalcScreenOffset	; DI now at position where second count-down to be displayed.
	mov	ax,dx
	call	AX2DEC			; out: BL = ones, DL = tens, DH = hundreds  in:	AX = number < 1000
	call	DispDecimal_2		;  in: BL = ones, DL = tens, DH = hundreds, DI = offset in MDA/CGA video RAM
	pop	si
	pop	di
	pop	bx

	ret



; ****************************************************************************
; Display the decimal value in DH/DL/BL at the specified location in MDA/CGA video RAM.
;
;   INPUTS: - DI = Offset within MDA/CGA video RAM.
;           - BL = ones
;           - DL = tens
;           - DH = hundreds
;           
;  OUTPUTS: {nothing}
;
; DESTROYS: {nothing}
;
; ****************************************************************************
DispDecimal_2:

	push	ax
	push	dx

	cmp	dh,'0'			; Skip hundreds?
	ja	.L10			; --> if no display number

	mov	dh,' '			; Fill hundreds with a space

	cmp	dl,'0'			; Skip tens?
	jne	.L10			; --> if no

	mov	dl,' '			; Fill tens with a space
.L10:
	mov	ah,07h			; Char attribute = normal
	mov	al,dh
	mov	[ss:di],ax		; Hundreds -> screen

	mov	al,dl
	mov	[ss:di+2],ax		; Tens -> screen

	mov	al,bl
	mov	[ss:di+4],ax		; Ones -> screen

	pop	dx
	pop	ax

	ret


 
; ****************************************************************************
; Display a status message to the right of the pointed-to on-screen test text.
;
; On-screen test text example: 'Testing CPU'
;     Status message examples: 'Passed', 'FAILED', and 'N/A   '
;
;   INPUTS: - DX points to the status message to display.
;           - SI points to parameters of the on-screen test text.
;             Parameters:
;                1st byte: row
;                2nd byte: column
;                The text starts at the 3rd byte
;
;  OUTPUTS: {nothing}
;
; DESTROYS: DispSecondMsg : AX, BX, CH, DI, DX, ES, SI
;           DispSecondMsg2: AX, BX, CH, DI, DX, ES, SI
;
; ****************************************************************************
DispSecondMsg:

	mov	bl,07h			; Char attribute = normal

DispSecondMsg2:

	; Calculate position on the screen where the status message is to go.
	call	CalcScreenPos		; DI := starting postion of text (offset into MDA/CGA video RAM). ( Destroys: AX, CH, DI )
	add	di,30*2			; The status message starts 30 characters to the right of starting position.

	mov	si,dx			; SI := position on screen where the status message is to go.
	mov	dh,bl			; Char attribute

	jmp	TextToScreen3		; Trail ends in a RET  ( Destroys: AX, BX, DI, DX, ES, {SI=SI-2} )



; ****************************************************************************
; Convert AL to decimal.
;
;   INPUTS: - AL = number
;
;  OUTPUTS: - BL = ones
;           - DL = tens
;           - DH = hundreds
;
; DESTROYS: {nothing}
;
; ****************************************************************************
AL2DEC:

	xor	ah,ah
	; Fall through to AX2DEC



; ****************************************************************************
; Convert AX to decimal.
;
;   INPUTS: - AX = number < 1000
;
;  OUTPUTS: - BL = ones
;           - DL = tens
;           - DH = hundreds
;
; DESTROYS: {nothing}
;
; ****************************************************************************
AX2DEC:

	push	ax

	mov	dx,3030h		; Hundreds and tens
.L20:	cmp	ax,100			; Smaller than 99?
	jb	.L30			; --> if yes

	inc	dh
	sub	ax,100			; Subtract 100
	jmp	.L20			; Another check for hundreds

.L30:	cmp	al,10			; Smaller than 9?
	jb	.S40			; --> if yes

	inc	dl
	sub	al,10			; Subtract 10
	jmp	.L30			; Another check for tens

.S40:	or	al,30h			; Number -> ASCII
	mov	bl,al			; Save AL

	pop	ax

	ret



; ****************************************************************************
; Calculate the offset in MDA/CGA video memory where to place some text.
;
;   INPUTS: - DI is the number of chars to the right of the start of the text.
;           - SI points to parameters of the on-screen test text (e.g. 'Testing CPU').
;             Parameters:
;                1st byte: row
;                2nd byte: column
;                The text starts at the 3rd byte
;
;  OUTPUTS: - DI is the offset in MDA/CGA video memory.
;
; DESTROYS: {nothing}
;
; ****************************************************************************
CalcScreenOffset:
	push	ax			; Save AX
	push	cx			; Save CX
	push	si

	shl	di,1			; DI = DI * 2 because of attribute byte
	mov	al,[cs:si]		; Get row
	xor	ah,ah
	mov	ch,160			; = 2 * 80 (character + attribute)
	mul	ch			; AX = start of the line
	add	di,ax			; Save result
	inc	si
	mov	al,[cs:si]		; Get starting column
	xor	ah,ah
	shl	ax,1			; AX = AX * 2 because of attribute
	add	di,ax			; Save end result

	pop	si
	pop	cx			; Restore CX
	pop	ax			; Restore AX

	ret


; ****************************************************************************
; Remove the arrow placed at the start of the pointed-to test text.
;
;   INPUTS: - SI points to parameters of the on-screen test text (e.g. 'Testing CPU').
;             Parameters:
;                1st byte: row
;                2nd byte: column
;                The text starts at the 3rd byte
;
;  OUTPUTS: {nothing}
;
; DESTROYS: AX, BX, CX, DI, DX, ES, SI
;
; ****************************************************************************
RemoveArrow:

	mov	dl,1
	jmp	SubArrow



; ****************************************************************************
; Display an arrow against the pointed-to test text.
;
;   INPUTS: - SI points to parameters of the on-screen test text (e.g. 'Testing CPU').
;             Parameters:
;                1st byte: row
;                2nd byte: column
;                The text starts at the 3rd byte
;
;  OUTPUTS: {nothing}
;
; DESTROYS: AX, BX, CX, DI, DX, ES, SI
;
; ****************************************************************************
ShowArrow:
	xor	dl,dl			; Show arrow

SubArrow:
	call	CalcScreenPos		; DI := starting postion of text (offset into MDA/CGA video RAM). ( Destroys: AX, CH, DI )
	sub	di,4			; Starting position of '->'
	mov	dh,07h			; Char attribute = normal

	or	dl,dl			; Show arrow?
	jnz	.S10			; --> if no 

	mov	si,TxtShowArrow
	jmp	.S20			; -->

.S10:
	mov	si,TxtRemoveArrow
.S20:
	jmp	TextToScreen3		; ( Destroys: AX, BX, DI, DX, ES, SI )

TxtRemoveArrow:
	db '  ', 0

TxtShowArrow:
	db '->', 0



; ****************************************************************************
; Display pointed-to text, and display an arrow to the left of it.
;
;   INPUTS: - SI points to parameters of the on-screen text (e.g. 'Testing CPU') to be displayed.
;             Parameters:
;                 1st byte: row
;                 2nd byte: column
;                 The text starts at the 3rd byte
;
;  OUTPUTS: SI points to text starting at the 3rd byte.
;
; DESTROYS: AX, BX, CX, DI, DX, ES
;
; ****************************************************************************
TextToScreenA:

	push	si
	call	TextToScreen	; ( Destroys: AX, BX, CH, DI, DX, ES )
	call	ShowArrow	; ( Destroys: AX, BX, CX, DI, DX, ES, SI }
	pop	si
	ret



; ****************************************************************************
; Display pointed-to text, in inverse.
;
;   INPUTS: - SI points to parameters of the on-screen text (e.g. 'Testing CPU') to be displayed.
;             Parameters:
;                1st byte: row
;                2nd byte: column
;                The text starts at the 3rd byte
;
;  OUTPUTS: {nothing}
;
; TextToScreen  destroys:  AX, BX, CH, DI, DX, ES
; TextToScreen2 destroys:  AX, BX, CH, DI, DX, ES
; TextToScreen3 destroys:  AX  BX      DX  DI  ES, {SI=SI-2}
;
; ****************************************************************************
TextToScreenInv:

	mov	dh,70h			; Char attribute = inverse
	jmp	TextToScreen2



; ****************************************************************************
; Display pointed-to text, with preset or custom attribute.
;
;   INPUTS: - SI points to parameters of the on-screen text (e.g. 'Testing CPU') to be displayed.
;             Parameters:
;                1st byte: row
;                2nd byte: column
;                The text starts at the 3rd byte
;
;  OUTPUTS: {nothing}
;
; TextToScreen  destroys:  AX, BX, CH, DI, DX, ES
; TextToScreen2 destroys:  AX, BX, CH, DI, DX, ES
; TextToScreen3 destroys:  AX  BX      DX  DI  ES, {SI=SI-2}
;
; ****************************************************************************
TextToScreen:
	mov	dh,07h			; Char attribute = normal

TextToScreen2:
	call	CalcScreenPos		; DI := starting postion of text (offset into MDA/CGA video RAM). ( Destroys: AX, CH, DI )
					; SI now pointing to text starting at the 3rd byte.
					; ( Destroys: AX, CH, DI )
	
TextToScreen3:
	mov	ah,dh			; Set attribute for character
	; Copy the text to the screen.
	mov	dx,ss			; 
	mov	es,dx			; Point ES to segment address of MDA/CGA video RAM
	mov	bx,si			; Save SI
.L10:
	mov	al,[cs:si]		; Read character
	inc	si
	and	al,al			; End of the text?
	jz	.EXIT			; --> if yes 
	stosw				; Write character plus attribute { STOSW: AX-->[ES:DI], then DI=DI+2 }
	jmp	.L10			; -->
.EXIT:
	mov	si,bx
	sub	si,2			; Restore original SI (if TextToScreen or TextToScreen2 called)

	ret	



; ****************************************************************************
; Calculate the offset into MDA/CGA video RAM where the 
; pointed-to on-screen test text (e.g. 'Testing CPU') is to go.
;
;   INPUTS: - SI points to parameters of the on-screen test text (e.g. 'Testing CPU').
;             Parameters:
;                 1st byte: row
;                 2nd byte: column
;                 The text starts at the 3rd byte
;
;  OUTPUTS: DI is offset into MDA/CGA video RAM.
;
; DESTROYS: AX, CH, DI
;
; ****************************************************************************
CalcScreenPos:

	mov	al,[cs:si]		; Get row.
	inc	si

	xor	ah,ah
	mov	ch,160			; 160 bytes per line (80 chars per line @ 2 bytes each char).
	mul	ch			; AX = AL x 160
	mov	di,ax			; Save result.

	mov	al,[cs:si]		; Get column.
	inc	si

	xor	ah,ah
	shl	ax,1			; Muliply by 2 (because of attribute byte).
	add	di,ax			; DI := place where to copy the text to

	ret



; ****************************************************************************
; Display the word in AX on the screen in hex (e.g. if AX contains C35A hex, display "C35A").
;
;   INPUTS: - AX contains the word to display.
;           - SS points to the base of MDA or CGA video RAM, as applicable. (We also store some variables there.)
;           - DI is the offset into that video RAM to write to.
;
;  OUTPUTS: {nothing}
;
; DESTROYS: BX, CL
;
; ****************************************************************************
DisplayAXinHex:

	push	ss
	push	di
	push	ax

	; Do AH.
	xchg	al,ah			; AH into AL
	call	DisplayALinHex		; ( Destroys: BX, CL )

	; Point to next position on screen.
	add	di,4

	; Do AL.
	xchg	al,ah			; Get our original AL back
	call	DisplayALinHex		; ( Destroys: BX, CL )

	; Restore saved registers.
	pop	ax
	pop	di
	pop	ss

	ret



; ****************************************************************************
; Display the byte in AL on the screen in hex (e.g. if AL contains C3 hex, display "C3").
;
;   INPUTS: - AL contains the byte to display.
;           - SS points to the base of MDA or CGA video RAM, as applicable. (We also store some variables there.)
;           - DI is the offset into that video RAM to write to.
;
; REQUIREMENT: For XLATB, DS is set to the CS (where Tbl_ASCII is). This is normally the case in this program.
;
;  OUTPUTS: {nothing}
;
; DESTROYS: BX, CL
;
; ****************************************************************************
DisplayALinHex:

	push	ss
	push	di
	push	ax

	; Do high nibble.
	mov	cl,4
	shr	al,cl			; High nibble to low nibble.
	mov	bx,Tbl_ASCII
	xlatb				; Convert AL into ASCII.
	mov	ah,07h			; Char attribute = normal
	mov	[ss:di],ax		; Write to the screen.

	; Point to next position on screen.
	add	di,2

	; Do low nibble.
	pop	ax
	push	ax
	and	al,0fh			; AL only has low nibble of passed AL.
	mov	bx,Tbl_ASCII
	xlatb				; Convert AL into ASCII.
	mov	ah,07h			; Char attribute = normal
	mov	[ss:di],ax		; Write to the screen.

	; Restore saved registers.
	pop	ax
	pop	di
	pop	ss

	ret




; ****************************************************************************
; There was a failure of a RAM related test (address or data).
; Display details of the address.
;
;   INPUTS: - SI points to LINE,COLUMN,"Check first 2 KB of RAM", or or "Testing RAM ....."
;           - Variable 'BadAddrSegment' contains the segment of the failing address.
;           - Variable 'BadAddrOffset' contains the offset of the failing address.
;           - SS points to the base of MDA or CGA video RAM, as applicable. (We also store some variables there.)
;
;  OUTPUTS: {nothing}
;
; DESTROYS: AX, BX, CX, DI, DX, ES
;
; ****************************************************************************
DispBadAddress:

	push 	si			; Preserve SI.

	mov	al,[cs:si]		; Read line number byte of "Check first 2 KB of RAM" or "Testing RAM ....."
	mov	bl,al			; Save for later.

	; ---------------------------------------
	; Display  ">> Critical error ...".
	; ---------------------------------------
	push	bx
	call	DispCritical		; SI is to point to LINE,COLUMN,"Check first 2 KB of RAM" or "Testing RAM ....."  ( Destroys: AX, BX, CX, DI, DX, ES, SI )
	pop	bx

	; ---------------------------------------
	; Clear the 8 lines after "Critical error ...".
	; ---------------------------------------
	mov	al,bl			; Read line number byte of "Check first 2 KB of RAM" or "Testing RAM ....."
	add	al,1			; Next line.
	mov	cx,8			; 8 lines to clear.
.L10:	add	al,1			; Next line.
	call	ClearLineY		; Clear screen line in AL. ( Destroys: DI, ES )
	loop	.L10

	; ---------------------------------------
	; Display the address.
	; ---------------------------------------
	mov	al,bl			; Read line number byte of "Check first 2 KB of RAM"  or "Testing RAM ....."
	add	al,3			; Desired line.
	xor	ah,ah
	mov	ch,160
	mul	ch
	mov	di,ax			; DI (offset in MDA/CGA video RAM) is now at start of line on screen.
	mov	bp,di			; Save for later.

	; Display "  Failure at address:     KB  (exactly xxxxx)"
	mov	si,TxtFailAtAddress
	mov	dh,07h			; Char attribute = normal
	call	TextToScreen3		; ( Destroys: AX, BX, DI, DX, ES )

	; Display the failing address as a KB address.
	mov	di,bp			; Back at start of line.
	add	di,44			; Now at position to put KB value.
	mov	word ax,[ss:BadAddrSegment]
	mov	word dx,[ss:BadAddrOffset]
	call	DispSegOffAsKb		; AX:DX  ( Destroys: CL )

	; Display the absolute address figure.
	mov	di,bp			; Back at start of line.
	add	di,78			; Now at "xxxxx" on line.
	mov	word ax,[ss:BadAddrSegment]
	mov	word dx,[ss:BadAddrOffset]
	call	DispSegOffAsAbsolute	; AX:DX  ( Destroys: BX, CL )

	; Display the failing address in the bottom right corner of the screen.
	mov	es,ax
	call	DispEsDxInBrCorner	; ( Destroys: nothing )

	; ---------------------------------------
	; Exit
	; ---------------------------------------
	pop 	si			; Restore SI.
	ret				; Return to caller.



; ****************************************************************************
; There was a failure of a RAM related test (address or data).
; Display address and data details.
;
;   INPUTS: - SI points to LINE,COLUMN,"Check first 2 KB of RAM", or "Testing RAM ....."
;           - Variable 'BadAddrSegment' contains the segment of the failing address.
;           - Variable 'BadAddrOffset' contains the offset of the failing address.
;           - Variable 'BadDataParity' contains the bad data bits (upper byte) and parity bit indicator (lower byte).
;           - SS points to the base of MDA or CGA video RAM, as applicable. (We also store some variables there.)
;
;  OUTPUTS: {nothing}
;
; DESTROYS: AX, BX, CX, DI, DX, ES

; ****************************************************************************
DispBadAddressAndData:

	; ---------------------------------------
	; Display the address.
	; ---------------------------------------
	call	DispBadAddress		; ( Destroys: AX, BX, CX, DI, DX, ES )

	; ---------------------------------------
	; Display the data bits.
	; ---------------------------------------

	; Display the "Bad bits: ...' header.
	mov	al,[cs:si]		; Read line number byte of "Check first 2 KB of RAM" or "Testing RAM ....."
	mov	bl,al			; Save for later.
	add	al,5			; Target line for the header.
	xor	ah,ah
	mov	ch,160
	mul	ch
	mov	di,ax			; DI (offset in MDA/CGA video RAM) is now at start of line on screen.
	mov	si,TxtBadBits		; "  Bad bits:  7 6 5 4 3 2 1 0  P        "
	mov	dh,07h			; Char attribute = normal
	push	bx
	call	TextToScreen3		; ( Destroys: AX, BX, DI, DX, ES )
	pop	bx

	; Display the data bits.
	mov	al,bl			; Read line number byte of "Check first 2 KB of RAM" or "Testing RAM ....."
	add	al,6			; Target line for the data bits.
	xor	ah,ah
	mov	ch,160
	mul	ch
	mov	di,ax			; DI (offset in MDA/CGA video RAM) is now at start of line on screen.
	add	di,26			; 13th column.
	mov	word ax,[ss:BadDataParity]	; Get the bad data bits (byte) and parity bit indicator (byte).
	mov	bh,ah			; Put bad data bit pattern into BH.
.L20:	mov	cx,8
.L22:	shl	bh,1			; Bit is set?
	jnc	.L24			; --> if not
	mov	ax,7000h+'X'		; 'X' in inverse.
	jmp	.L26
.L24:	mov	ax,0700h+'O'		; 'O' in normal.
.L26:	mov	[ss:di],ax		; Write bit result.
	add	di,2			; Next screen position.
	mov	ax,0700h+' '		; Space
	mov	[ss:di],ax		; Display a space.
	add	di,2			; Next screen position.
	loop	.L22			; If CX <> zero, -> next data bit

	; ---------------------------------------
	; Display the parity bit, but only if there are no bad data bits.
	; ---------------------------------------
	add	di,2			; Next screen position.
	mov	word dx,[ss:BadDataParity]	; Get the bad data bits (byte) and parity bit indicator (byte).
	cmp	dh,0
	jne	.L32			; --> if bad data bits recorded.
	; No bad data bits. Display the parity bit.
	mov	ax,0700h+'O'		; 'O' in normal.
	cmp	dl,1			; Was an error in the parity bit recorded ?
	jne	.L30			; --> if no
.L28:	mov	ax,7000h+'X'		; 'X' in inverse.
.L30:	mov	[ss:di],ax		; Write parity bit result to screen.
	jmp	.L40			; -->
.L32:	; There are bad data bits.
	; Do not display the parity bit.
	; Overwrite the 'P' on the line above with a space.
	sub	di,160
	mov	ax,0700h+' '
	mov	[ss:di],ax
	add	di,160

.L40:	; ---------------------------------------
	; Display the warning.
	; ---------------------------------------
	add	di,12			; Advance 6 screen positions.
	mov	si,TxtRamChipWarning	; "<----- May or may not be RAM chips."
	mov	dh,07h			; Char attribute = normal
	call	TextToScreen3		; ( Destroys: AX, BX, DI, DX, ES )

	; ---------------------------------------
	; Return to caller.
	; ---------------------------------------
	ret


; ****************************************************************************
; Display the passed segment:offset address as an KB one.
;
; E.g. 0400:C000 gets displayed as "64 KB".
;
;     INPUTS: - AX contains the segment of the address.
;             - DX contains the offset of the address.
;             - SS points to the base of MDA or CGA video RAM, as applicable. (We also store some variables there.)
;             - DI is the offset into that video RAM to write to.
;
;
;    OUTPUTS: {nothing}
;
;   DESTROYS: CL
;
; ****************************************************************************
DispSegOffAsKb:

	; Save AX and DX, because this subroutine must not destroy them.
	push	ax
	push	dx

	; Display the KB amount.
	mov	cl,10
	shr	dx,cl			; DX = DX/1024  (e.g. C000 --> 0030)
	mov	cl,6
	shr	ax,cl			; AX = AX/64    (e.g. 0400 --> 0010)
	add	ax,dx
	call	AX2DEC			; out: BL = ones, DL = tens, DH = hundreds  in:	AX = number < 1000
	call	DispDecimal_2		;  in: BL = ones, DL = tens, DH = hundreds, DI = offset in MDA/CGA video RAM

	; Restore AX and DX.
	pop	dx
	pop	ax

	ret


; ****************************************************************************
; Display the passed segment:offset address as an absolute one.
;
; E.g. E81C:A67D gets displayed as "F283D".
;
;     INPUTS: - AX contains the segment of the address.
;             - DX contains the offset of the address.
;             - SS points to the base of MDA or CGA video RAM, as applicable. (We also store some variables there.)
;             - DI is the offset into that video RAM to write to.
;
; REQUIREMENT: For XLATB, DS is set to the CS (where Tbl_ASCII is). This is normally the case in this program.
;
;    OUTPUTS: {nothing}
;
;   DESTROYS: BX, CL
;
; ****************************************************************************
DispSegOffAsAbsolute:

	; Save AX and DX and DI, because this subroutine must not destroy them.
	push	ax
	push	dx
	push	di

	; Calculate the absolute address from the passed segment and offset address.
	; Store the result in the 3-byte variable named 'AbsoluteAddress'.
	call	CalcAbsFromSegOff	; From AX:DX  ( Destroys: BX, CL )

.S10:	; Display the absolute address.
	; Variable 'AbsoluteAddress' is 3 bytes, e.g. address 084A3F, 6 digits.
	; But this computer is a PC, and so the first digit will always be zero.
	; So in displaying the address, do not display the first digit.
	mov	bx,Tbl_ASCII
	mov	byte al,[ss:AbsoluteAddress+0]
	xlatb				; Convert AL into ASCII.
	mov	ah,07h			; Char attribute = normal
	mov	[ss:di],ax		; Write to the screen.
	;
	add	di,2			; Advance 1 character on-screen.
	;
	mov	byte al,[ss:AbsoluteAddress+1]
	call	DisplayALinHex		; ( Destroys: BX, CL )
	;
	add	di,4			; Advance 2 characters on-screen.
	;
	mov	byte al,[ss:AbsoluteAddress+2]
	call	DisplayALinHex		; ( Destroys: BX, CL )

	; Restore AX and DX and DI.
	pop	di
	pop	dx
	pop	ax

	ret


; ****************************************************************************
; Display the passed segment:offset address in the bottom right corner of the screen.
;
;   INPUTS: - ES contains the segment.
;           - DX contains the offset.
;           - SS points to the base of MDA or CGA video RAM, as applicable. (We also store some variables there.)
;
;  OUTPUTS: {nothing}
;
; DESTROYS: {nothing}
;
; ****************************************************************************
DispEsDxInBrCorner:

	; Save registers.
	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	ds

	; Display the segment.
	mov	di,BrCornerOffset
	mov	ax,es
	call	DisplayAXinHex		; At address SS:DI, which is in MDA/CGA video RAM.
					; ( Destroys: BX, CL )
	; Display a colon.
	add	di,8			; Advance four character positions to get past the segment.
	mov	ax,0700h+':'
	mov	[ss:di],ax
	add	di,2			; Advance one character position to get past the colon.

	; Display the offset.
	mov	ax,dx
	call	DisplayAXinHex		; At address SS:DI, which is in MDA/CGA video RAM.
	add	di,10			; Advance five character positions to get past the offset.
					; ( Destroys: BX, CL )
	; Display an equals.
	mov	ax,0700h+'='
	mov	[ss:di],ax
	add	di,4			; Advance two character positions to get past the equals.

	; Display the absolute address figure.
	mov	ax,es
	call	DispSegOffAsAbsolute	; AX:DX  ( Destroys: BX, CL )
	add	di,12			; Advance six character positions to get past the absolute address figure.

	; Display an equals.
	mov	ax,0700h+'='
	mov	[ss:di],ax
	add	di,4			; Advance two character positions to get past the equals.

	; Display a KB address (calculated from the segment:offset in AX:DX).
	; E.g. 0400:C000 = 10000 = 64 KB, so display '64 KB'.
	mov	ax,es
	call	DispSegOffAsKb		; AX:DX  ( Destroys: CL )
	add	di,8			; Advance four character positions to get past the KB figure.
	mov	ax,0700h+'K'
	mov	[ss:di],ax
	add	di,2			; Advance a character position.
	mov	ax,0700h+'B'
	mov	[ss:di],ax

	; Restore registers.
	pop	ds
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax

	ret


; ****************************************************************************
; Erase the address (shown in various formats) that is currently displayed in the bottom right corner of the screen.
;
;   INPUTS: - SS points to the base of MDA or CGA video RAM, as applicable. (We also store some variables there.)
;
;  OUTPUTS: {nothing}
;
; DESTROYS: DI
;
; ****************************************************************************
ClearBrCorner:

	push	ax
	push	cx

	mov	cx,26		; 26 words to erase.
	mov	di,BrCornerOffset
	mov	ax,0700h+' '
.L10:	mov	[ss:di],ax
	inc 	di
	inc 	di
	loop	.L10

	pop	cx
	pop	ax

	ret



; ****************************************************************************
; Display the passed byte, in hex, at the top right corner of the screen.
;
;   INPUTS: - AL contains the byte.
;           - SS points to the base of MDA or CGA video RAM, as applicable. (We also store some variables there.)
;
;  OUTPUTS: {nothing}
;
; DESTROYS: BX, CL, DI
;
; ****************************************************************************
DispAlTopCorner:

	mov	di,150
	call	DisplayALinHex		; At address SS:DI, which is in MDA/CGA video RAM.
					; ( Destroys: BX, CL )
	ret



; ****************************************************************************
; On-screen, clear the specified line number.
;
;   INPUTS: - AL is the line number (1 to 25).
;
;  OUTPUTS: {nothing}
;
; DESTROYS: DI, ES
;
; ****************************************************************************
ClearLineY:

	push	ax
	push	bx
	push	cx
	push	dx
	push	si

	xor	ah,ah
	mov	ch,160
	mul	ch
	mov	di,ax			; DI = start of line on screen
	mov	si,TxtClearLine+2
	mov	dh,07h			; Char attribute = normal
	call	TextToScreen3		; ( Destroys: AX, BX, DI, DX, ES )

	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret


