; code: language=nasm tabSize=8
%include "defines.inc"


; ****************************************************************************
; THIS SUBROUTINE PERFORMS A READ/WRITE STORAGE TEST ON A BLOCK
;      OF STORAGE.
; ENTRY REQUIREMENTS:
;       ES = ADDRESS OF STORAGE SEGMENT BEING TESTED
;       DS = ADDRESS OF STORAGE SEGMENT BEING TESTED
;       CX = WORD COUNT OF STORAGE BLOCK TO BE TESTED
; EXIT PARAMETERS:
;       ZERO FLAG = 0 IF STORAGE ERROR (DATA COMPARE OR PARITY
;       CHECK. AL=O DENOTES A PARITY CHECK. ELSE AL=XOR'ED
;       BIT PATTERN OF THE EXPECTED DATA PATTERN VS THE ACTUAL
;       DATA READ.
; AX,BX,CX,DX,DI, AND SI ARE ALL DESTROYED.
; ****************************************************************************
PORT_B	EQU 061H	; PORT B READ/WRITE DIAGNOSTIC REGISTER
PORT_C	EQU 062H	; 8255 PORT C ADDR
STGTST_CNT:
	MOV BX,CX	; SAVE WORD COUNT OF BLOCK TO TEST
	CLD		; SET DIR FLAG TO INCREMENT
	SUB DI,DI	; SET DI=OFFSET 0 REL TO ES REG
	SUB AX,AX	; SETUP FOR O->FF PATTERN TEST
.C2_1:
	MOV [DI],AL	; ON FIRST BYTE
	MOV AL,[DI] 
	XOR AL,AH	; O.K.?
	JNZ .COMPERR
	; GO ERROR IF NOT <--- changed
	INC AH
	MOV AL,AH
	JNZ .C2_1	; LOOP TILL WRAP THROUGH FF
	MOV AX,055AAH 	; GET INITIAL DATA PATTERN TO WRITE
	MOV DX,AX 	; SET INITIAL COMPARE PATTERN.
	REP STOSW 	; FILL STORAGE LOCATIONS IN BLOCK
	IN AL,PORT_B
	OR AL,030H	; TOGGLE PARITY CHECK LATCHES
	OUT PORT_B,AL
	NOP
	AND AL,0CFH
	OUT PORT_B,AL
;
	DEC DI		; POINT TO LAST WORD JUST WRITTEN
	DEC DI
	STD		; SET DIR FLAG TO GO BACKWARDS
	MOV SI,DI	; INITIALIZE DESTINATION POINTER
	MOV CX,BX	; SETUP WORD COUNT FOR LOOP
.C3:			;       INNER TEST LOOP
	LODSW	 	; READ OLD TEST WORD FROM STORAGE	; { LODSW: [DS:SI]-->AX, then SI=SI+2 }
	XOR AX,DX	; DATA READ AS EXPECTED ?
	JNE .COMPERR	; NO - GO TO ERROR ROUTINE
	MOV AX,0AA55H	; GET NEXT DATA PATTERN TO WRITE
	STOSW		; WRITE INTO LOCATION JUST READ		; { STOSW: AX-->[ES:DI], then DI=DI+2 }
	LOOP .C3	; DECREMENT WORD COUNT AND LOOP
;
	CLD		; SET DIR FLAG TO GO FORWARD
	INC DI		; SET POINTER TO BEG LOCATION
	INC DI
	MOV SI,DI	; INITIALIZE DESTINATION POINTER
	MOV CX,BX	; SETUP WORD COUNT FOR LOOP
	MOV DX,AX	; SETUP COMPARE PATTERN OF "0AA55H"
.C4:			;       INNER TEST LOOP
	LODSW		; READ OLD TEST WORD FROM STORAGE	; { LODSW: [DS:SI]-->AX, then SI=SI+2 }
	XOR AX,DX	; DATA READ AS EXPECTED?
	JNE .COMPERR	; NO - GO TO ERROR ROUTINE
	MOV AX,0FFFFH	; GET NEXT DATA PATTERN TO WRITE
	STOSW		; WRITE INTO LOCATION JUST READ		; { STOSW: AX-->[ES:DI], then DI=DI+2 }
	LOOP .C4	; DECREMENT WORD COUNT AND LOOP
;
	DEC DI		; POINT TO LAST WORD JUST WRITTEN
	DEC DI
	STD		; SET DIR FLAG TO GO BACKWARDS
	MOV SI,DI	; INITIALIZE DESTINATION POINTER
	MOV CX,BX	; SETUP WORD COUNT FOR LOOP
	MOV DX,AX	; SETUP COMPARE PATTERN "0FFFFH"
.C5:			;       INNER TEST LOOP
	LODSW		; READ OLD TEST WORD FROM STORAGE	; { LODSW: [DS:SI]-->AX, then SI=SI+2 }
	XOR AX,DX	; DATA READ AS EXPECTED?
	JNE .COMPERR	; NO - GO TO ERROR ROUTINE
	MOV AX,00101H	; GET NEXT DATA PATTERN TO WRITE
	STOSW		; WRITE INTO LOCATION JUST READ		; { STOSW: AX-->[ES:DI], then DI=DI+2 }
	LOOP .C5	; DECREMENT WORD COUNT AND LOOP
;
	CLD		; SET DIR FLAG TO GO FORWARD
	INC DI		; SET POINTER TO BEG LOCATION
	INC DI
	MOV SI,DI	; INITIALIZE DESTINATION POINTER
	MOV CX,BX	; SETUP WORD COUNT FOR LOOP
	MOV DX,AX	; SETUP COMPARE PATTERN "00101H"
.C6:			;       INNER TEST LOOP
	LODSW		; READ OLD TEST WORD FROM STORAGE	; { LODSW: [DS:SI]-->AX, then SI=SI+2 }
	XOR AX,DX	; DATA READ AS EXPECTED ?
	JNE .COMPERR	; NO - GO TO ERROR ROUTINE
	STOSW		; WRITE ZERO INTO LOCATION READ		; { STOSW: AX-->[ES:DI], then DI=DI+2 }
	LOOP .C6	; DECREMENT WORD COUNT AND LOOP
	DEC DI		; POINT TO LAST WORD JUST WRITTEN
	DEC DI
	STD		; SET DIR FLAG TO GO BACKWARDS
	MOV SI,DI	; INITIALIZE DESTINATION POINTER
	MOV CX,BX	; SETUP WORD COUNT FOR LOOP
	MOV DX,AX	; SETUP COMPARE PATTERN "00000H"
.C6X:
	LODSW		; VERIFY MEMORY IS ZERO.		; { LODSW: [DS:SI]-->AX, then SI=SI+2 }
	XOR AX,DX	; DATA READ AS EXPECTED ?
	JNE .COMPERR	; NO - GO TO ERROR ROUTINE
	LOOP .C6X	; DECREMENT WORD COUNT AND LOOP
;
	IN AL,PORT_C	; DID A PARITY ERROR OCCUR ?
	AND AL,0C0H	; ZERO FLAG WILL BE OFF, IF PARITY ERROR
	jnz .PARERR	; --> if parity error

	; RAM tested okay.
	; Zero flag is set.
	MOV AL,0	; AL=O DATA COMPARE OK
	CLD		; SET DIRECTION FLAG TO INC
	RET

.PARERR:
	; Data comparison good, but a parity error is indicated.
	;
	mov	word [ss:BadAddrSegment],ds	; Save segment of address in error (LODSW uses DS:SI)
	mov	word [ss:BadAddrOffset],si	; Save  offset of address in error (LODSW uses DS:SI)
	mov	word [ss:BadDataParity],1	; Save: high_byte:{bit error pattern = 00}, low_byte={parity bit error}
	jmp	.FAILEXIT

.COMPERR:
	; A data comparison failed.
	;
	mov	word [ss:BadAddrSegment],ds	; Save segment of address in error (LODSW uses DS:SI)
	mov	word [ss:BadAddrOffset],si	; Save  offset of address in error (LODSW uses DS:SI)
	;
	; AX is the bit error pattern (a word).
	; If both AH and AL are non-zero, that means that both test bytes (written/read as a word) are in error - choose either.
	; Otherwise, the non-zero register is the bit error pattern.
	cmp	ah,0
	jne	.S10				; --> if AH has a one somewhere in its bit error pattern, use AH
	mov	ah,al				; AL has bit error pattern, move into AH
.S10:	mov	al,0				; Indicate no parity error.
	mov	word [ss:BadDataParity],ax	; High_byte:{bit error pattern}, low_byte={no parity bit error}
	;
	; Get bit error pattern into AL for caller.
	; Because AL is what this IBM subroutine returns the bit error pattern in.
	mov	al,ah
	;
.FAILEXIT:
	cld					; Set direction flag to increment (because STD was used earlier).
	;
	; Clear ZF to indicate error to caller, but do not change AL in doing so.
	mov	bx,1
	or	bx,bx

	ret
