section .data
		login_input_str db "["
						dq 0, 0, 0, 0, 0 ;40 bytes
						dq 0, 0, 0, 0, 0 ;40 bytes
						dq 0, 0, 0, 0, 0 ;40 bytes
						db 0, 0, 0, 0, 0, 0, 0 ;7 bytes, 128 all
		%define LOGIN_INPUT_STRLEN 128

section .text
setlogin_input_str:
		lea		rdi,	[login_input_str + 1]
		mov		rsi,	login
		xor		rax,	rax		;counter
.slis_lp:
		mov		cl,		byte[rsi + rax]
		mov		byte[rdi + rax], cl
		inc		rax
		test	cl,		cl
		jne		.slis_lp
		dec		rax
		mov		ecx,	0x0020245D
		mov		dword[rdi + rax],	ecx
		ret
