

; ---------------------------------------------------------------------------
section_save
section .romdata
; ---------------------------------------------------------------------------

TxtSwitchPC1:		db 9, 45, '    '
			db 201, 205, 'PC SW1', 205, 187,
			db ' '
			db 201, 205, 'PC SW2', 205, 187, 0

TxtSwitchPC2:		db 10, 45, '    ', 186, '12345678', 186
			db ' ', 186, '12345---', 186, 0
TxtSwitchPC3:		db 11, 45, ' ON ', 186, '        ', 186
			db ' ', 186, '        ', 186, '', 0
TxtSwitchPC4:		db 12, 45, '    ', 186, '        ', 186
			db ' ', 186, '        ', 186, '', 0
TxtSwitchPC5:		db 13, 45, '    '
			db 200, 205, 205, 205, 205, 205, 205, 205, 205, 188,
			db ' '
			db 200, 205, 205, 205, 205, 205, 205, 205, 205, 188, 0

TxtSwitchXT1:		db 14, 44, '           '
			db 201, 205, 'XT SW1', 205, 187, 0
TxtSwitchXT2:		db 15, 44, '           ', 186, '12345678', 186, '       ', 0
TxtSwitchXT3:		db 16, 44, '        ON ', 186, '        ', 186, '       ', 0
TxtSwitchXT4:		db 17, 44, '           ', 186, '        ', 186, '       ', 0

TxtSwitchXT5:		db 18, 44, '           '
			db 200, 205, 205, 205, 205, 205, 205, 205, 205, 188, 0

; ---------------------------------------------------------------------------
section .lib
; ---------------------------------------------------------------------------

; ****************************************************************************
; Subroutine to display a row of switch block settings.
;
;   INPUTS: AL = Contains the switch block settings
;           DI = Place on screen
;           CX = Number of switches in AL to display
; ****************************************************************************
SubSwitches:

	; Set DI to the offset in MDA/CGA video RAM where the switch state is displayed.
	call	CalcScreenOffset

	; Display the switch states.
.L10:	shr	al,1			; Shift right 1 bit. Bit 0 goes into carry flag.
	jc	.OFF			; If carry set, --> bottom row

	; Switch is ON.
	; Place 'X' on top row.
	mov	byte [ss:di],'X'
	jmp	.S20

.OFF:	; Switch is OFF.
	; Place 'X' on bottom row.
	mov	byte [ss:di+160],'X'

.S20:	add	di,2			; Point to next screen position.
	loop	.L10

	ret




; ---------------------------------------------------------------------------
section_restore
; ---------------------------------------------------------------------------


DispSwitches:
; ****************************************************************************
; Display the switch settings.

	; ------------------------------------------------
	; PC switch blocks SW1 and SW2
	; ------------------------------------------------

	; Draw the empty 'PC SW1' box and 'PC SW2' box.
	mov	si,TxtSwitchPC1
	call	TextToScreen
	mov	si,TxtSwitchPC2
	call	TextToScreen
	mov	si,TxtSwitchPC3
	call	TextToScreen
	mov	si,TxtSwitchPC4
	call	TextToScreen
	mov	si,TxtSwitchPC5
	call	TextToScreen

	; Read SW1 into AL.
	; For a PC, done by setting bit 7 on 8255 port B, then reading port A.
	in	al,PPI8255_B
	or	al,10000000b
	out	PPI8255_B,al
	nop				; Delay for I/O.
	nop				; Delay for I/O.
	in	al,PPI8255_A

	; In the 'PC SW1' box, display the SW1 switch settings.
	mov	si,TxtSwitchPC3
	mov	di,5			; On screen, start at offset 5.
	mov	cx,8			; Show all 8 switches.
	call	SubSwitches

	; Read SW2 into AL.
	;
	; A two-stage process.	
	; For a PC, done by:
	;          Switches 1 to 4:   Set bit 2 on 8255 port B, then read low nibble of port C.
	;                 Switch 5: Clear bit 2 on 8255 port B, then read LSB of port C.
	in	al,PPI8255_B
	or	al,00000100b
	out	PPI8255_B,al		; Set bit 2 on 8255 port B
	nop				; Delay for I/O.
	nop				; Delay for I/O.
	in	al,PPI8255_C
	and	al,00001111b		; Because of later OR'ing.
	mov	bl,al			; BL := {0-0-0-0}{switches 4-3-2-1}
	in	al,PPI8255_B
	and	al,11111011b
	out	PPI8255_B,al		; Clear bit 2 of port B
	nop				; Delay for I/O.
	nop				; Delay for I/O.
	in	al,PPI8255_C		; AL := {?-?-?-?}{?-?-?-switch 5}
	mov	cl,4
	shl	al,cl			; AL := {?-?-?-switch 5}{0-0-0-0}
	or	al,bl			; AL := {?-?-?-switch 5}{switches 4-3-2-1}

	; In the 'PC SW2' box, display the SW2 switch settings.
	mov	si,TxtSwitchPC3
	mov	di,16			; On screen, start at offset 16.
	mov	cx,5			; Show first 5 switches only.
	call	SubSwitches

	; ------------------------------------------------
	; XT switch blocks SW1
	; ------------------------------------------------

	; Draw the empty 'XT SW1' box.
	mov	si,TxtSwitchXT1
	call	TextToScreen
	mov	si,TxtSwitchXT2
	call	TextToScreen
	mov	si,TxtSwitchXT3
	call	TextToScreen
	mov	si,TxtSwitchXT4
	call	TextToScreen
	mov	si,TxtSwitchXT5
	call	TextToScreen

	; Read SW1 into AL.
	;
	; A two-stage process.	
	; For an XT, done by:
	;          Switches 1 to 4: Clear bit 3 on 8255 port B, then read low nibble of port C.
	;          Switches 5 to 8:   Set bit 3 on 8255 port B, then read low nibble of port C.
	in	al,PPI8255_B
	and	al,11110111b
	out	PPI8255_B,al		; Clear bit 3 on port B.
	nop				; Delay for I/O.
	nop				; Delay for I/O.
	in	al,PPI8255_C
	and	al,00001111b		; Because of later OR'ing.
	mov	bl,al			; BL := {0-0-0-0}{switches 4-3-2-1}
	in	al,PPI8255_B
	or	al,00001000b
	out	PPI8255_B,al		; Set bit 3 of port B
	nop				; Delay for I/O.
	nop				; Delay for I/O.
	in	al,PPI8255_C		; AL := {?-?-?-?}{switches 8-7-6-5}
	mov	cl,4
	shl	al,cl			; AL := {switches 8-7-6-5}{0-0-0-0}
	or	al,bl			; AL := {switches 8-7-6-5){switches 4-3-2-1}

	; In the 'XT SW1' box, display the SW1 switch settings.
	mov	si,TxtSwitchXT3
	mov	di,12			; On screen, start at offset 12.
	mov	cx,8			; Show all 8 switches.
	call	SubSwitches

	__CHECKPOINT__ 0x72 ;++++++++++++++++++++++++++++++++++++++++
