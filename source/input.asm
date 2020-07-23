section .rodata
  clear_input_value db 0x1B, 0x5B, 0x44 ;this is 7 bytes
					db 0x20
		left_arrow	db 0x1B, 0x5B, 0x44
		right_arrow db 0x1B, 0x5B, 0x43
section .data
		input_c dd 0
section .text
;----------------------------------------------------------------
input:
		xor		r12,	r12			;always 0 in this func

		xor		rdi,	rdi
		mov		rsi,	login_input_str
		mov		rdx,	LOGIN_INPUT_STRLEN
		call	write

		mov		rcx,	128
		mov		rdi,	read_buffer_data
		xor		rax,	rax
		rep		stosq

		mov		rbx,	read_buffer_data ;buf iterator
		xor		r8,		r8			;input size now
.input_start:
		mov		rdi,	1
		mov		rsi,	input_c
		mov		rdx,	4
		xor		rax,	rax		;read
		mov		dword[input_c], eax
		syscall

		mov		r9d,	dword[input_c]
		cmp		rax,	3
		jne		.if_not_arrow
		cmp		r9d,	0x00415B1B	;arrow up
		je		.if_arrow_up
		cmp		r9d,	0x00425B1B	;arrow down
		je		.if_arrow_down
		cmp		r9d,	0x00435B1B	;arrow right
		je		.if_arrow_right
		cmp		r9d,	0x00445B1B	;arrow left
		jne		.input_start
.if_arrow_left:
		cmp		rbx,	read_buffer_data
		je		.input_start
		test	r8,		r8
		je		.input_start
		call	to_left_once
		dec		rbx		;it
		jmp		.input_start
.if_arrow_up:
		jmp		.input_start
.if_arrow_down:
		jmp		.input_start
.if_arrow_right:
		lea		rax,	[read_buffer_data + r8]	;iterator to end
		cmp		rbx,	rax
		je		.input_start
		call	to_right_once
		inc		rbx		;it
		jmp		.input_start
.if_not_arrow:
		cmp		r9b,	0x7F	;backspace
		je		.if_backspace
		cmp		r9b,	0x0A	;enter
		je		.if_enter
.if_default:
		lea		rax,	[read_buffer_data + r8]	;iterator to end
		cmp		rbx,	rax
		je		.if_default_if_end
		mov		rsi,	rbx
		sub		rsi,	read_buffer_data
		mov		rcx,	r8
		sub		rcx,	rsi
		mov		rdx,	rcx

		sub		rsp,	rdx

		mov		rdi,	rsp
		mov		rsi,	rbx		 ;pre_it
		rep		movsb

		mov		rcx,	rdx
		lea		rdi,	[rbx + 1];it
		mov		rsi,	rsp		 ;pre_it
		rep		movsb
		
		add		rsp,	rdx

		mov		byte[rbx],	r9b
		inc		r8		;inc input size now

		xor		rdi,	rdi
		mov		rsi,	rbx
		inc		rdx
		mov		rax,	1	;write
		syscall
		
		inc		rbx		;inc it
		
		dec		rdx
		call	to_left
		jmp		.input_start
.if_default_if_end:
		mov		byte[rbx],	r9b
		inc		rbx		;inc it
		inc		r8  	;inc input size now
		
		xor		rdi,	rdi
		mov		rsi,	input_c
		mov		rdx,	1
		mov		rax,	1	;write
		syscall
		jmp		.input_start
.if_backspace:
		cmp		rbx,	read_buffer_data
		je		.input_start
		test	r8,		r8
		je		.input_start
		lea		rax,	[read_buffer_data + r8]	;iterator to end
		cmp		rbx,	rax
		je		.if_backspace_if_end
		mov		rsi,	rbx
		sub		rsi,	read_buffer_data
		mov		rcx,	r8
		sub		rcx,	rsi
		mov		rdx,	rcx

		sub		rsp,	rdx

		mov		rdi,	rsp
		mov		rsi,	rbx		 ;pre_it
		rep		movsb

		mov		rcx,	rdx
		lea		rdi,	[rbx - 1];it
		mov		rsi,	rsp		 ;pre_it
		rep		movsb
		
		add		rsp,	rdx

		call	clear_input_once

		dec		rbx
		dec		r8
		mov		sil,	0x20
		mov		byte[read_buffer_data + r8], sil
		xor		rdi,	rdi
		mov		rsi,	rbx
		add		rdx,	3
		mov		rax,	1
		syscall
		mov		byte[read_buffer_data + r8], r12b

		sub		rdx,	2
		call	to_left
		jmp		.input_start
.if_backspace_if_end:
		dec		rbx
		dec		r8
		mov		byte[rbx],	r12b ;0
		call	clear_input_once
		jmp		.input_start
.if_enter:
		xor		rdi,	rdi
		mov		rsi,	input_c
		mov		rdx,	1
		mov		rax,	1	;write
		syscall
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
to_left_once:
		push	rdi
		push	rsi
		push	rdx

		xor		rdi,	rdi
		mov		rsi,	left_arrow
		mov		rdx,	3
		call	write

		pop		rdx
		pop		rsi
		pop		rdi
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args: rdx - num of left move
to_left:
		push	rdx
		push	rdi
		push	rsi
		push	rax
		sub		rsp,	4096

		mov		rax,	rdx
		shl		rdx,	1
		add		rdx,	rax
		mov		rax,	rdx

		mov		rsi,	rsp
		mov		edi,	0x00445b1b ;left arrow
		add		rax,	rsp
.tl_lp:
		mov		dword[rsi],	edi
		add		rsi,	3
		cmp		rax,	rsi
		jne		.tl_lp

		xor		rdi,	rdi
		mov		rsi,	rsp
		call	write

		add		rsp,	4096
		pop		rax
		pop		rsi
		pop		rdi
		pop		rdx
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
to_right_once:
		push	rdi
		push	rsi
		push	rdx

		xor		rdi,	rdi
		mov		rsi,	right_arrow
		mov		rdx,	3
		call	write

		pop		rdx
		pop		rsi
		pop		rdi
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args: rdx - num of right move
to_right:
		push	rdi
		push	rsi
		push	rax
		sub		rsp,	4096

		mov		rsi,	rsp
		mov		edi,	0x00435b1b ;right arrow
		xor		rax,	rax
.tl_lp:
		mov		dword[rsi],	edi
		add		rsi,	3
		cmp		rax,	rdx
		jne		.tl_lp

		xor		rdi,	rdi
		mov		rsi,	rsp
		shl		rdx,	1
		add		rdx,	rax
		call	write

		add		rsp,	4096
		pop		rax
		pop		rsi
		pop		rdi
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args: rdx - num of clear
clear_input:
		push	rdi
		push	rsi
		push	rax
		sub		rsp,	4096

		mov		rsi,	rsp
		mov		rdi,	0x00445B1B20445B1B;left, space, left
		xor		rax,	rax
.ci_lp:
		mov		qword[rsi],	rdi
		add		rsi,	7
		cmp		rax,	rdx
		jne		.ci_lp

		xor		rdi,	rdi
		mov		rsi,	rsp
		shl		rdx,	3
		sub		rdx,	rax
		call	write

		add		rsp,	4096
		pop		rax
		pop		rsi
		pop		rdi
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
clear_input_once:
		push	rdx
		push	rdi
		push	rsi
		push	rax

		xor		rdi,	rdi
		mov		rsi,	clear_input_value
		mov		rdx,	7
		call	write

		pop		rax
		pop		rsi
		pop		rdi
		pop		rdx
		ret
;----------------------------------------------------------------
