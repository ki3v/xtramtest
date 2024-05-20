; code: language=nasm tabSize=8
%include "defines.inc"


; ****************************************************************************
; Inter-test delay.
;
;   INPUTS: {nothing}
;
;  OUTPUTS: {nothing}
;
; DESTROYS: CX, DL
;
; ****************************************************************************
InterTestDelay:

	mov	dl,2		; About half a second assuming 4.77 MHz.
	sub	cx,cx
.L10:	loop	.L10
	dec	dl
	jnz	.L10
	ret



; ****************************************************************************
; One second delay.
; Assumption: 8088 running at 4.77 MHz.
;
;   INPUTS: {nothing}
;
;  OUTPUTS: {nothing}
;
; DESTROYS: CX, DL
;
; ****************************************************************************
OneSecDelay:

	mov	dl,4
	sub	cx,cx
.L10:	loop	.L10
	dec	dl
	jnz	.L10
	ret

