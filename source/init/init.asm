%include "init/term.asm"
%include "init/ttyname.asm"
%include "init/setlogin.asm"
%include "init/setlogin_input_str.asm"
%include "init/history.asm"

section .text
init:
	call term_init
	call ttyname_init
	call setlogin
	call setlogin_input_str
	call history_init
	ret
