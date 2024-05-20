; code: language=nasm tabSize=8
%include "defines.inc"


ColdStart:	
; ****************************************************************************
; Entry point after a hard reset.

	cli			; Disable maskable interrupts.

	; Disable NMI interrupts from reaching the CPU.
	; (FYI. The hardware on a good motherboard will automatically do that at power-on time.)
	xor	al,al
	out	PORT_NMI_MASK,al


	cld			; Set the direction flag to increment.

	mov	ax,cs		; set the data segment to the code segment
	mov	ds,ax



	; ----------------------------------------------------------------------------
	; Send 33h to the three standard LPT ports and to the debug port used by the IBM AT.
	; 33h chosen because it is very distinctive.
	; For those without an MDA/CGA card, the 33h indicates that the code has started to execute.
	mov	al,33h
	mov	dx,LPT1		; I/O port 378h
	out	dx,al
	dec	dh		; I/O port 278h
	out	dx,al
	mov	dx,LPT3		; I/O port 3BCh. The parallel/LPT port on most MDA cards.
	out	dx,al
	mov	dx,80h		; IBM AT's debug port. Rarely works for PC's and XT's.
	out	dx,al

