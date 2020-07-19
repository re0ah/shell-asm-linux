section .rodata
		PATH			 db "/bin/", 0
		%define PATH_LEN 5

		PATH_BSHELL		 db "/bin/sh", 0

section .text
;----------------------------------------------------------------
;args:
;	1. r11, argv
execvp:
		push	rdi
		push	rsi
		push	rcx
		push	rdx

		sub		rsp,	1024	;allocate stack for modificated argv[0]
		cld
		xor		rdx,	rdx
		xor		rcx,	rcx		;size of argv[0]
		mov		rdi,	[r11]
	;check if pathname contain '/'
.e_check_slash: 
		mov		sil,	byte[rdi + rcx]
		inc		rcx
		cmp		sil,	'/'
		je		.e_if_slash
		test	sil,	sil
		jne		.e_check_slash

		mov		rsi,	qword[PATH]
		mov		qword[rsp],	rsi

		mov		rsi,	rdi
		lea		rdi,	[rsp + PATH_LEN]
		rep		movsb

		mov		rdi,	rsp
.e_if_slash:
		mov		rsi,	r11
		call	execve
;		jmp		execve_as_script
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. r11,	argv
execve_as_script:
		mov		rsi,	PATH_BSHELL
		mov		qword[rsp],	rsi

		lea		rdi,	[rsp + 8]
		mov		rsi,	r11
.e_copy_argv:
		movsq
		cmp		[rsi], 	rdx	;rdx is 0
		jne		.e_copy_argv

		mov		rdi,	[rsp]
		mov		rsi,	rsp
		call	execve

		add		rsp,	1024	;free stack

		pop		rdx
		pop		rcx
		pop		rdi
		pop		rsi
		ret
;----------------------------------------------------------------
