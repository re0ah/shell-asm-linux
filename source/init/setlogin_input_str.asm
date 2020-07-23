%define PATH_MAX 4096
section .bss
		login_input_str resb 4096
		%define LOGIN_INPUT_STRLEN 4096
section .text
setlogin_input_str:
		mov		rdi,	login_input_str
		mov		al,		'['
		stosb

		mov		rsi,	login
.slis_lp:
		mov		al,		byte[rsi]
		stosb
		inc		rsi
		test	al,		al
		jne		.slis_lp

		dec		rdi
		mov		al,	0x20 ;" "
		stosb

		mov		rsi,	LOGIN_INPUT_STRLEN
		mov		rax,	0x4f	;getcwd
		syscall
		add		rdi,	rax

		mov		ecx,	0x0020245D ;"]$ \0"
		mov		dword[rdi],	ecx
		ret
