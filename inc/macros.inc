; code: language=nasm tabSize=8
%ifndef MACROS_INC
%define MACROS_INC


;=========================================================================
%macro romcall 1
	mov	sp, %%addr
	jmp	%1
	%%addr: dw %%continue
	%%continue:
%endmacro


;=========================================================================
%macro bpcall 1
	mov	bp, %%continue
	jmp	%1
	%%continue:
%endmacro

%macro bpret 0
	jmp	bp
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



%macro asciiz 1+
	db %1, 0
%endmacro

%endif


