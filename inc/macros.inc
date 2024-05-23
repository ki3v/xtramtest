; code: language=nasm tabSize=8
%ifndef MACROS_INC
%define MACROS_INC


;=========================================================================
%macro ss_call 1
	mov	sp, %%addr
	jmp	%1
	%%addr: dw %%continue
	%%continue:
%endmacro

;=========================================================================
%macro use 1
	%deftok USENAME %1
	%ifndef %[USENAME]
		%deftok %[USENAME] %1
		; %warning using %1
		%push INCLUDE
		section_save
		%include %str(%[USENAME])
		section_restore
		%pop INCLUDE
	%else
		; %warning %1 already included
	%endif
	%undef USENAME
%endmacro


;=========================================================================
%imacro section_save 0.nolist
	%push SECTION
	%xdefine %$SECTION_OLD __?SECT?__
%endmacro
%imacro section_restore 0.nolist
	%xdefine __?SECT?__ %$SECTION_OLD
	%$SECTION_OLD
	%pop SECTION
%endmacro


; ****************************************************************************
; MACRO:
; Output the passed byte/code to:
;     - the three standard LPT ports; and
;     - IBM's debug port; and
;     - if the byte is less than 10h, the serial port of 3F8h ('COM1').
;
; REQUIREMENT: For XLATB, DS is set to the CS (where Tbl_ASCII is). This is normally the case in this program.
;
; REMARK: Intended for when:
;         - MDA/CGA/A0000 RAM available, but the stack has yet to be set to use that RAM; or
;         - Such RAM does not exist.
; ****************************************************************************
%macro __CHECKPOINT__NOSTACK__ 1
..@CKPT%1:
	mov	al,%1

	;------------------------
	; IBM's debug port
	; -----------------------
	out	80h,al		; IBM AT's debug port. Rarely works for PC's and XT's.

%ifdef USE_LPT
	;------------------------
	; Three standard LPT ports
	; -----------------------
	mov	dx,LPT1		; I/O port 378h
	out	dx,al
	dec	dh		; I/O port 278h
	out	dx,al
	mov	dx,LPT3		; I/O port 3BCh. The parallel/LPT port on most MDA cards.
	out	dx,al
%endif

%ifdef USE_SERIAL
%if %1 < 10h
	;------------------------
	; If the byte is less than 10h, covert the least significant (LS) nibble to ASCII, then output that to the serial port of 3F8h ('COM1').
	; Why only the lower nibble?
	; We are in a macro that cannot call subroutines (because no stack yet).
	; This macro is only used for checkpoints less than 10h.
	; Therefore, to shorten the code (important for this 8 KB sized ROM), only the LS nibble is processed.
	; -----------------------

	; cmp	al,10h
	; jge	%%EXIT		; --> if 10h or greater.
	mov	ah,al		; Save the byte for later.

	; Wait for the COM1 UART to indicate that it is ready for a TX byte.
	mov	dx,COM1_lsr	; Line status register (LSR).
%%L10:	in	al,dx
	and	al,00100000b
	jz	%%L10		; --> if UART is not ready.

	; Output an ASCII space.
	mov	dx,COM1_tx_rx_dll
	mov	al,' '
	out	dx,al

	; Wait for the COM1 UART to indicate that it is ready for a TX byte.
	mov	dx,COM1_lsr	; Line status register (LSR).
%%L20:	in	al,dx
	and	al,00100000b
	jz	%%L20		; --> if UART is not ready.

	; Ouput the LS nibble.
	mov	dx,COM1_tx_rx_dll
	mov	al,ah		; Get the byte to send, back into AL.
	mov	bx,Tbl_ASCII
	xlatb			; Convert AL into ASCII.
	out	dx,al		; Output it.
%endif
%endif

%%EXIT:
%endmacro



; ****************************************************************************
; MACRO:
; Output a debug code to the three standard LPT ports and to COM1 and to IBM's debug port.
;
; REMARK: Only for use when the stack is available !!!
; ****************************************************************************
%macro __CHECKPOINT__ 1
	mov	al,%1
	call	CheckpointStack
%endmacro

%macro asciiz 1+
	db %1, 0
%endmacro

%endif


