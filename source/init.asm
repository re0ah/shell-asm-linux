%include "term.asm"
%include "ttyname.asm"
%include "setlogin.asm"
%include "setlogin_input_str.asm"

section .text
init:
	call term_init
	call ttyname_init
	call setlogin
	call setlogin_input_str
	ret
