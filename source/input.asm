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

		mov		di,		word[history_file_lenght]
		mov		word[history_line_pos], di

		xor		rdi,	rdi
		mov		rsi,	login_input_str
		mov		rdx,	LOGIN_INPUT_STRLEN
		call	write

		mov		rdi,	read_buffer_data
		mov		rcx,	128
		xor		rax,	rax
		rep		stosq
		
		mov		rdi,	read_buffer_data2
		mov		rcx,	128
		xor		rax,	rax
		rep		stosq

		mov		rbx,	read_buffer_data  ;buf iterator now
		mov		rbp,	read_buffer_data  ;buf now
		xor		r8,		r8				  ;input size now
		push	qword r8				  ;qword[rsp + 24], input size now
										  ;for read_buffer_data2
		push	qword read_buffer_data2	  ;qword[rsp + 16], iterator
		push	qword r8				  ;qword[rsp + 8], input size now
										  ;for read_buffer_data
		push	qword read_buffer_data	  ;qword[rsp], iterator
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
		cmp		rbx,	rbp
		je		.input_start
		test	r8,		r8
		je		.input_start
		call	to_left_once
		dec		rbx		;it
		jmp		.input_start
.if_arrow_up:
		mov		rdx,	r8
		call	clear_input
		cmp		rbp,	read_buffer_data2
		je		.if_read_buffer_data2_now
		mov		rbp,	read_buffer_data2
		mov		qword[rsp],	rbx			;save it rbuf
		mov		rbx,	qword[rsp + 16]	;load it rbuf2
		mov		qword[rsp + 8],	r8		;save input size now rb
		mov		r8,		qword[rsp + 24]	;load input size now rb2
		jmp		.if_read_buffer_data_now
.if_read_buffer_data2_now:
		mov		rbx,	read_buffer_data2
		xor		r8,		r8
.if_read_buffer_data_now:
		movzx	r9,		word[history_line_pos]
		movzx	r10,	word[history_data_line_pos + r9]

		mov		rsi,	qword[history_data]
		add		rsi,	r10
		movzx	rdx,	word[history_data_line_lenght + r9]

		mov		rcx,	rdx
		mov		rdi,	rbx
		rep		movsb
		xor		rax,	rax
		stosb

		xor		rdi,	rdi
		sub		rsi,	rdx
		add		rbx,	rdx	;add to it
		add		r8,		rdx	;add to input size now

		mov		rax,	1	;write
		syscall

		test	r9,		r9
		je		.input_start
		sub		r9,		2
		mov		word[history_line_pos],	r9w
		jmp		.input_start
.if_arrow_down:
		cmp		rbp,	read_buffer_data
		je		.input_start
		mov		r13w,	word[history_file_lenght]
		movzx	r9,		word[history_line_pos]
		add		r9,		2
		cmp		r13w,	r9w
		jne		.l
		mov		word[history_line_pos], r9w
		mov		rdx,	r8
		call	clear_input
		mov		rbp,	read_buffer_data
		mov		rbx,	qword[rsp]
		mov		r8,		qword[rsp + 8]

		xor		rdi,	rdi
		mov		rsi,	rbp
		mov		rdx,	r8
		mov		rax,	1	;write
		syscall
		jmp		.input_start
.l:
		mov		word[history_line_pos],	r9w
		jmp		.input_start
.if_arrow_right:
		lea		rax,	[rbp + r8]	;iterator to end
		cmp		rbx,	rax
		je		.input_start
		call	to_right_once
		inc		rbx		;it
		jmp		.input_start
.if_not_arrow:
		cmp		r9b,	0x7F	;backspace
		je		.if_backspace
		cmp		r9b,	0x09	;tab
		je		.if_tab
		cmp		r9b,	0x0A	;enter
		je		.if_enter
.if_default:
		lea		rax,	[rbp + r8]	;iterator to end
		cmp		rbx,	rax
		je		.if_default_if_end
		mov		rsi,	rbx
		sub		rsi,	rbp
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
		cmp		rbx,	rbp
		je		.input_start
		test	r8,		r8
		je		.input_start
		lea		rax,	[rbp + r8]	;iterator to end
		cmp		rbx,	rax
		je		.if_backspace_if_end
		mov		rsi,	rbx
		sub		rsi,	rbp
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
		mov		byte[rbp + r8], sil
		xor		rdi,	rdi
		mov		rsi,	rbx
		add		rdx,	3
		mov		rax,	1
		syscall
		mov		byte[rbp + r8], r12b

		sub		rdx,	2
		call	to_left
		jmp		.input_start
.if_backspace_if_end:
		dec		rbx
		dec		r8
		mov		byte[rbx],	r12b ;0
		call	clear_input_once
		jmp		.input_start
.if_tab:
		jmp		.input_start
.if_enter:
		xor		rdi,	rdi
		mov		rsi,	input_c
		mov		rdx,	1
		mov		rax,	1	;write
		syscall
		
		add		rsp,	32	;above was push 4 qword values
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
		test	rdx,	rdx
		je		.end
		push	rdx
		push	rdi
		push	rsi
		push	rax
		sub		rsp,	4096

		mov		rdi,	rsp
		lea		rsi,	[rsp + (rdx * 8)]
		mov		rax,	0x00445B1B20445B1B;left, space, left
.ci_lp:
		stosq
		cmp		rdi,	rsi
		jne		.ci_lp

		xor		rdi,	rdi
		mov		rsi,	rsp
		shl		rdx,	3
		call	write

		add		rsp,	4096
		pop		rax
		pop		rsi
		pop		rdi
		pop		rdx
.end:
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
