;This is free and unencumbered software released into the public domain.
;
;Anyone is free to copy, modify, publish, use, compile, sell, or
;distribute this software, either in source code form or as a compiled
;binary, for any purpose, commercial or non-commercial, and by any
;means.
;
;In jurisdictions that recognize copyright laws, the author or authors
;of this software dedicate any and all copyright interest in the
;software to the public domain. We make this dedication for the benefit
;of the public at large and to the detriment of our heirs and
;successors. We intend this dedication to be an overt act of
;relinquishment in perpetuity of all present and future rights to this
;software under copyright law.
;
;THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
;IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
;OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
;ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
;OTHER DEALINGS IN THE SOFTWARE.
;
;For more information, please refer to <http://unlicense.org/>

;thanks
;https://chromium.googlesource.com/chromiumos/docs/+/master/constants/syscalls.md
;for comfortable table of syscalls
bits 64

%include "syscalls.asm"
%include "execvp.asm"
%include "parse.asm"
%include "term.asm"
%include "input.asm"

%define PAGE_SIZE 4096
%define PIPE_SIZE 65536
%define READ_BUFFER_MAX_SIZE 1024
%define PATH_MAX_SIZE	 	 1024

section .bss
		read_buffer_data resb READ_BUFFER_MAX_SIZE
section .text
;----------------------------------------------------------------
;args:
;	1.	rsi,	buf
;modify registers: r13 = num of sep
calc_sep:
		push	r15
		mov		rcx,	rsi
		xor		r13,	r13
		mov		r15b,	byte[rcx]
.cs_loop:
		call	if_sep
		test	r15,	r15
		je		.cs_1
		inc		r13
.cs_1	inc		rcx
		mov		r15b,	byte[rcx]
		test	r15b,	r15b
		jne		.cs_loop

		pop		r15
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;get argc* and calc argc for each cmd
;fill sep*
;
;args:
;	1.	rsi,	buf*,	char
;	2.	rdx,	sep*,	char
;	3.	rbx,	argc*,	int32
;modify registers: rax = size of buffer

fill_argc:
		push	rcx
		push	rax
		push	rbp
		push	r9
		push	r10
		push	r15
		xor		r9,		r9 	;bool for check whether we are in brackets

		mov		rax,	rsi		;iterator for rsi_buffer
		xor		rbp,	rbp		;iterator for argc & sep
.fa_loop2:
		mov		r10,	2		;counter of single argc
.fa_loop:
		mov		cl,  	byte[rax]
		cmp		r9,		1
		je		.fa_if_in_double_quote_now
		cmp		cl,		'"'
		jne		.fa_if_in_not_double_quote
		mov		r9,		1
		jmp		.fa_loop_epilogue
.fa_if_in_not_double_quote: 
		cmp		cl,		0x20 ;' '
		jne		.fa_check_sep
		inc		rax
		inc		r10
		jmp		.fa_loop
.fa_check_sep:
		mov		r15b,	cl
		call	if_sep
		test	r15,	r15
		je		.fa_loop_epilogue
		mov		dword[rbx + (rbp * 4)], r10d
		mov		byte[rdx + rbp], cl
		inc		rax
		inc		rbp
		jmp		.fa_loop2
.fa_if_in_double_quote_now:
		cmp		cl,		'"'
		jne		.fa_loop_epilogue
		xor		r9,		r9
.fa_loop_epilogue:
		inc		rax
		test	cl,		cl
		jne		.fa_loop
		mov		dword[rbx + (rbp * 4)], r10d

		pop		r15
		pop		r10
		pop		r9
		pop		rbp
		pop		rax
		pop		rcx
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. rsi, ptr to buffer
;	2. rbx,	ptr to argc*
;	3. rdx, ptr to sep*
;	4. r13, num of sep
;Function skip all spaces and return pointer after spaces
;
exec_all_cmd:
		lea		r9,		[(r13 + 1) * 8]	;size of alloc fd (8 it is 2 int32)
		sub		rsp,	r9		;alloc stack memory

		mov		rdi,	rsp
		lea		r10,	[r9 + rsp]
.eac_open_pipes:
		call	pipe
		add		rdi,	8
		cmp		rdi,	r10
		jne		.eac_open_pipes

		xor		rcx,	rcx		;iterator for argc*
.eac_again:
		mov		r8d,	dword[rbx + (rcx * 4)] ;argc[rcx]
		lea		r10,	[r8d * 8]	;size of alloc for argv_pre
		sub		rsp,	r10		;alloc stack memory

		mov		r11,	rsp
		call 	parse_cmd

		call	fork
		test	rax,	rax
		jne		.eac_parrent_code			;jump to parent code
				;this is child code
				mov		r15,	r11
				lea		r12,	[r10 + (rcx * 8)] ;fd[rcx]
				cmp		r13,	rcx
				je		.eac_if_last_0
				mov		dil,	byte[rdx + r13]
				cmp		dil,	SEP_SEMICLN
				jne		.eac_if_not_last_0
		.eac_if_last_0:
				mov		edi,	dword[rsp + r12] ;fd[rcx][0], READ_END
				xor		rsi,	rsi			   	 ;STDIN_FILENO
				jmp		.eac_jmp_dup_last_0
		.eac_if_not_last_0:
				mov		edi,	dword[rsp + r12 + 4] ;fd[rcx][1], WRITE_END
				mov		rsi,	1			    	 ;STDOUT_FILENO
		.eac_jmp_dup_last_0:
				call	dup2

				mov		edi,	dword[rsp + r12]	 ;fd[rcx][0], READ_END
				call	close

				mov		edi,	dword[rsp + r12 + 4] ;fd[rcx][1], WRITE_END
				call	close
				
				mov		r11,	r15
				call	execvp

				mov		rdi,	1
				call	exit
.eac_parrent_code:
		cmp		r13,	rcx
		je		.eac_if_last
		mov		dil,	byte[rdx + r13]
		cmp		dil,	SEP_SEMICLN
		jne		.eac_if_not_last
.eac_if_last:
		call	wait_null
		add		rsp,	r10		;free stack memory (argv_pre)
		jmp 	.eac_pre_close_pipes
.eac_if_not_last:
		lea		r12,	[r10 + (rcx * 8)];	fd[rcx]
		mov		edi,	dword[rsp + r12 + 4] ;fd[rcx][1], READ_END
		call	close
		call	wait_null
		inc		rcx

.eac_main_body:
		mov		r8d,	dword[rbx + (rcx * 4)] ;argc[rcx]
		lea		r14,	[r8d * 8]	;size of alloc for argv
		sub		rsp,	r14		;alloc stack memory

		mov		r11,	rsp
		call 	parse_cmd
		
		mov		r8b,	byte[rdx + rcx - 1]	;sep[rcx - 1]

		cmp		r8b,	SEP_IF_AND	; '&&'
		je		.eac_body_sep_if_and
		cmp		r8b,	SEP_IF_PIPE ; '||'
		je		.eac_body_sep_if_pipe
		cmp		r8b,	SEP_OUT_END	; '>>'
		je		.eac_body_sep_out_end
		cmp		r8b,	SEP_AND		; '&'
		je		.eac_body_sep_and
		cmp		r8b,	SEP_PIPE	; '|'
		je		.eac_body_sep_pipe
		cmp		r8b,	SEP_OUT		; '>'
		je		.eac_body_sep_out
		jmp		.eac_body_end
.eac_body_sep_if_and:
		int3
.eac_body_sep_if_pipe:
		int3
.eac_body_sep_out:
		mov		r8,	0x0241
		jmp		.eac_body_sep_out_1
.eac_body_sep_out_end:
		mov		r8,	0x0441
.eac_body_sep_out_1:
		dec		rcx
		lea		r12,	[r10 + (rcx * 8)];	fd[rcx - 1]
		add		r12,	r14
		inc		rcx
		mov		edi,	dword[rsp + r12] ;fd[rcx - 1][0], READ_END
		push	rsi
		push	rdx
		sub		rsp,	PIPE_SIZE

		mov		rsi,	rsp
		mov		rdx,	PIPE_SIZE
		call	read

		push	rax

		mov		edi,	dword[r11]
		mov		rsi,	r8
		mov		rdx,	0x01A4	;S_IRUSR  | S_IWUSR | S_IRGRP | S_IROTH
		call	open

		pop		rdx
		mov		rsi,	rsp
		push	rax

		mov		edi,	eax
		call	write

		pop		rdi
		call	close

		add		rsp,	PIPE_SIZE
		pop		rdx
		pop		rsi
		jmp		.eac_body_end
.eac_body_sep_and:
		int3
.eac_body_sep_pipe:
		call	fork
		test	rax,	rax
		jne		.eac_parrent_code_1			;jump to parent code
				;this is child code
				mov		r15,	r11

				add		r10,	r14

				lea		rbp,	[r10 + (rcx * 8)] ;fd[rcx]

				dec		rcx
				lea		r12,	[r10 + (rcx * 8)] ;fd[rcx - 1]
				inc		rcx

				mov		edi,	dword[rsp + r12]  ;fd[rcx - 1][0], READ_END
				xor		rsi,	rsi				  ;STDIN_FILENO
				call	dup2

				cmp		r13,	rcx
				je		.eac_jmp_dup_last_1
				mov		dil,	byte[rdx + r13]
				cmp		dil,	SEP_SEMICLN
				je		.eac_jmp_dup_last_1

				mov		edi,	dword[rsp + rbp + 4] ;fd[rcx][1], WRITE_END
				mov		rsi,	1					 ;STDOUT_FILENO
				call	dup2

		.eac_jmp_dup_last_1:
				mov		edi,	dword[rsp + r12]	 ;fd[rcx - 1][0], READ_END
				call	close

				mov		edi,	dword[rsp + rbp + 4] ;fd[rcx][1], WRITE_END
				call	close
				
				mov		r11,	r15
				call	execvp
.eac_parrent_code_1:
		push	r12
		push	rdi
		lea		r12,	[r10 + (rcx * 8)] ;fd[rcx]
		add		r12,	r14
		mov		edi,	dword[rsp + r12 + 16]  ;fd[rcx - 1][0], READ_END
		call	close
		pop		rdi
		pop		r12
		call	wait_null

.eac_body_end:
		inc		rcx
		add		rsp,	r14		;free stack memory (argv)

		mov		r8,		[rdx + rcx - 1]	;sep[rcx - 1]
		cmp		r8,		SEP_SEMICLN ; ';'
		jne		.eac_body_end_if_not_semicln
		add		rsp,	r10		;free stack memory (argv_pre)
		jmp		.eac_again
.eac_body_end_if_not_semicln:
		cmp		rcx,	r13
		jbe		.eac_main_body
		add		rsp,	r10		;free stack memory (argv_pre)

.eac_pre_close_pipes:
		mov		r10,	rsp
		mov		r11,	rsp
		add		r11,	r9
.eac_close_pipes:
		mov		edi,	dword[r10]
		call	close
		mov		edi,	dword[r10 + 4]
		call	close
		add		r10,	8
		cmp		r10,	r11
		jne		.eac_close_pipes

		add		rsp,	r9		;free stack memory (fd)
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
global _start
_start:
		call	term_init

		call	input

		mov		rsi,	read_buffer_data
		call	prepare_for_parse

		call	calc_sep
		;num of sep = r13, num of cmd = r13 + 1.
		;what is cmd? Argv & argc. We can know argc for each cmd with
	;help simple func, and after alloc the right amount of memory
	;argc = 4 byte. Need alloc (r13 + 1) * 4 bytes for argc*
	;sep  = 1 byte. Need alloc r13 bytes for sep*
		lea		r15,	[(r13 + 1) * 4]
		add		r15,	r13

		sub		rsp,	r15

		mov		rdx,	rsp			;ptr to sep*
		lea		rbx,	[rsp + r13] ;ptr to argc*
		call	fill_argc
		call	exec_all_cmd

		cld
.clear_read:
		xor		rax,	rax
		mov		rdi,	read_buffer_data
		mov		rcx,	128
		rep		stosq
		add		rsp,	r15

		jmp		_start

		xor		rdi,	rdi		;stdin
		mov		rsi,	read_buffer_data
		mov		rdx,	32
		call	write

		xor		rdi, 	rdi		; result, return 0
		call	exit
