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

;thanks https://chromium.googlesource.com/chromiumos/docs/+/master/constants/syscalls.md for comfortable table of syscalls

bits 64

%define PAGESIZE 4096
%define PIPESIZE 65536
%define READ_BUFFER_MAX_SIZE 1024
%define PATH_MAX_SIZE	 	 1024

section .rodata
		PATH_0			 db "/bin", 0
		PATH_0_LEN		 db 4
		PATH_1			 db "/usr/bin", 0
		PATH_1_LEN		 db 8
		PATH			 dq	PATH_0
						 dq	PATH_1
		PATH_LEN		 dq PATH_0_LEN
						 dq PATH_1_LEN
		PATH_SIZE		 db 2			;if put new path, then 
								;change this value

		PATH_BSHELL		 db "/bin/sh", 0

;		PATH_ARGV_NAME	 db "/bin/sh", 0
;		PATH_ARGV_0		 db "-c", 0
;		PATH_ARGV_1		 db "echo $PATH", 0
;		PATH_ARGV_2		 db 0
;		PATH_ARGV		 dq	PATH_ARGV_NAME
;						 dq	PATH_ARGV_0
;						 dq	PATH_ARGV_1
;						 dq	PATH_ARGV_2

section .bss
		read_buffer_data resb READ_BUFFER_MAX_SIZE
;		PATH			 resb 1024
;		PATH_SIZE		 resw 1

section .text

;----------------------------------------------------------------
;set PATH from system variable
;	create pipe, fork, and execv "/bin/sh -c "echo $PATH"", after
;which reading from pipe in parent process
;
;modify registers: rdi = value of fd[1], useless
				  ;rcx = something remaining from close syscall
				  ;rax = syscall close return value
				  ;rdx = PATH_MAX_SIZE
;init_path:
;		sub		rsp,	8
;	;int pipe(int pipefd[2]);
;		mov		rdi,	rsp
;		mov		rax,	0x16	;pipe
;		syscall
;   ;pid_t fork(void);
;		mov		rax,	0x39	;fork
;		syscall
;		test	rax,	rax
;		jne		.itit_path_parrent_code			;jump to parent code
;			;this is child code
;		;int dup2(int oldfd, int newfd);
;			mov		edi,	dword[rsp + 4] ;fd[1], WRITE_END
;			mov		rsi,	1			   ;STDOUT_FILENO
;			mov		rax,	0x21
;			syscall
;   	;int close(int fd);
;			mov		edi,	dword[rsp]	   ;fd[0], READ_END
;			mov		rax,	0x03		   ;close
;			syscall
;			mov		edi,	dword[rsp + 4] ;fd[1], WRITE_END
;			mov		rax,	0x03		   ;close
;			syscall
;      ;int execve(const char *pathname, char *const argv[],
;                  ;char *const envp[]);
;			mov		rdi,	PATH_ARGV_NAME
;			mov		rsi,	PATH_ARGV
;			xor		rdx,	rdx
;			mov		rax,	0x3b	;execve
;			syscall
;			
;	;pid_t wait4(pid_t pid, int *wstatus, int options,
;                ;struct rusage *rusage);
;.init_path_parrent_code:
;xor		rdi,	rdi
;		xor		rsi,	rsi
;		xor		rdx,	rdx
;		xor		r10,	r10
;		mov		rax,	0x3d	;wait4
;		syscall
;   ;ssize_t read(int fd, void *buf, size_t count);
;		mov		edi,	dword[rsp]	;fd[0], READ_END
;		mov		rsi,	PATH
;		mov		rdx,	PATH_MAX_SIZE
;		xor		rax,	rax		;read
;		syscall
;		mov		word[PATH_SIZE],	ax
;		add		rax,	PATH
;		xor		rcx,	rcx
;		mov		byte[rax], 	cl ;0
;		mov		cl,		':'
;		mov		byte[rax - 1], 	cl
;   ;int close(int fd);
;		mov		edi,	dword[rsp]	;fd[0],	READ_END
;		mov		rax,	0x03	;close
;		syscall
;		mov		edi,	dword[rsp + 4];fd[1], WRITE_END
;		mov		rax,	0x03	;close
;		syscall
;		add		rsp,	8
;		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. rcx, ptr to buffer
;Function skip all spaces and return pointer after spaces
;
;modify registers: rcx = rcx + n, n - num of spaces
;				   rax = 0x20, uncomment push/pop/sub for get num of spaces
skip_spaces:
;		push	rcx
		mov		rax,	0x20	;0x20 = ' '
		jmp 	.ss_loop_2
.ss_loop:
		inc		rcx
.ss_loop_2:
		cmp		byte [rcx], al	
		je	 	.ss_loop
;		pop		rax
;		sub		rax,	rcx
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. rcx, ptr to buffer
;
;	delete repeating ' ' and alls ' ' on end
;	don't deleting spacing enclosed in brackets
;	also on end replace \n to \0
;	example: "e   xam  pl "   "    e   " -> "e xam pl "   " e"*/
;
;modify registers: rdx = new size of rcx_buffer
				  ;rax = prev size of rcx_buffer
				  ;rbx = rcx_buffer[1]
				  ;rbp = 0
delete_space_holes:
		sub		rsp, 	READ_BUFFER_MAX_SIZE ;alloc stack memory
		
		xor		rdx,	rdx 	;bool for check whether we are in brackets

		xor		rax, 	rax 	;iterator for rcx_buffer
		xor		rbp,	rbp 	;iterator for stack buffer
	;copy on stack buffer from rcx according by the rules on the comment
;of this function
.dsh_loop:
		mov		bx,  	word[rcx + rax]
		cmp		rdx,	1
		je		.dsh_if_in_double_quote_now
		cmp		bl,		'"'
		jne		.dsh_if_in_not_double_quote
		mov		rdx,	1
		jmp		.dsh_loop_epilogue
.dsh_if_in_not_double_quote: 
		cmp		bx,		0x2020		;'  ', two spaces in a row
		jne		.dsh_loop_epilogue
		inc		rax
		jmp		.dsh_loop
.dsh_if_in_double_quote_now:
		cmp		bl,		'"'
		jne		.dsh_loop_epilogue
		xor		rdx,	rdx
.dsh_loop_epilogue:
		mov		byte [rsp + rbp], bl
		inc		rax
		inc 	rbp
		test	bl,		bl
		jne		.dsh_loop

		dec		rbp		;the cycle is written so that an extra 1 added to rbp
	;in rbp at the moment stores size of stack_buffer. Perhaps it will
;still be needed - save it in rdx
		mov		rdx,	rbp

	;copy on rcx_buffer from stack.
	;This cycle don't copy first element, but I don't need
.dsh_cp_buf:
		mov		bl,		byte[rsp + rbp]
		mov		byte[rcx + rbp], bl
		dec		rbp
		jnz		.dsh_cp_buf

		mov		byte[rcx + rdx - 1], bpl

		add		rsp,	READ_BUFFER_MAX_SIZE ;free stack memory
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. rcx, ptr to buffer
;
;replace some sequences to single char
	;'\ ' = 0x01
	;'\"' = 0x02
	;'&&' = 0x03
	;'||' = 0x04
	;'>>' = 0x05
;
;modify registers: rdx = new size of rcx_buffer
				  ;rax = prev size of rcx_buffer
				  ;rbx = rcx_buffer[1]
				  ;rbp = 0
replace_special_symbols:
		sub		rsp, 	READ_BUFFER_MAX_SIZE ;alloc stack memory
		
		xor		rax, 	rax 	;iterator for rcx_buffer
		xor		rbp,	rbp 	;iterator for stack buffer
	;copy on stack buffer from rcx according by the rules on the comment
;of this function
.rsp_loop:
		mov		bx,  	word[rcx + rax]
		cmp		bx,		0x5C20		;'\ '
		je		.l0
		cmp		bx,		0x5C22		;'\"'
		je		.l1
		cmp		bx,		0x2626		;'&&'
		je		.l2
		cmp		bx,		0x7C7C		;'||'
		je		.l3
		cmp		bx,		0x3E3E		;'>>'
		je		.l4
		jmp		.rsp_l
.l0:	
		mov		bl,		0x01
		jmp		.rsp_l
.l1:	
		mov		bl,		0x02
		jmp		.rsp_l
.l2:	
		mov		bl,		0x03
		jmp		.rsp_l
.l3:	
		mov		bl,		0x04
		jmp		.rsp_l
.l4:	
		mov		bl,		0x05
		jmp		.rsp_l
.rsp_l:
.rsp_l:
		mov		byte [rsp + rbp], bl
		inc		rax
		inc 	rbp
		test	bl,		bl
		jne		.rsp_loop

		dec		rbp		;the cycle is written so that an extra 1 added to rbp
	;in rbp at the moment stores size of stack_buffer. Perhaps it will
;still be needed - save it in rdx
		mov		rdx,	rbp

	;copy on rcx_buffer from stack.
	;This cycle don't copy first element, but I don't need
.rsp_cp_buf:
		mov		bl,		byte[rsp + rbp]
		mov		byte[rcx + rbp], bl
		dec		rbp
		jnz		.rsp_cp_buf

		add		rsp,	READ_BUFFER_MAX_SIZE ;free stack memory
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. rcx, ptr to buffer
;Function skip all spaces and return pointer after spaces
;
;modify registers: rcx = rcx + n, n - num of spaces
;				   rax = 0x20, uncomment push/pop/sub for get num of spaces
sep_str_to_cmd:
		
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1.	rsi,	argv
;modify registers: rax = 0
;				   r12 = argc
calc_argc:
		xor		rax,	rax
.e_count_argc_loop:
		cmp		[rsi + r12 * 8], rax
		je		.e_count_argc_loop_end
		inc		r12
		jmp		.e_count_argc_loop
.e_count_argc_loop_end:
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. r12, argc
;	2. rsi,	argv
;
;modify registers: r15 = r12 * 16
				  ;r9  = 0
				  ;rcx = ??? change in syscall
				  ;r11 = ??? change in syscall
				  ;rdx = ??? change in syscall
				  ;rsi = ??? change in syscall
				  ;rdi = ??? change in syscall
				  ;rax = return of syscall
execve_as_script:
		mov		r15,	r12
		shl		r15,	4	;alloc with a margin
		sub		rsp,	r15	;alloc rsp_argv so call pathname through /bin/sh
		
		mov		rax,	PATH_BSHELL
		mov		qword[rsp],	rax
		xor		rax,	rax

		;copy rsi_argv to rsp_argv
.eas_cpy_argv:	
		mov		r9,		qword[rsi + rax * 8]
		inc		rax
		mov		qword[rsp + rax * 8],	r9
		test	r9,		r9
		jne		.eas_cpy_argv

	;int execve(const char *filename, char *const argv[],
		;char *const envp[]); 
		mov		rdi,	[rsp]
		mov		rsi,	rsp
		xor		rdx,	rdx
		mov		rax,	0x3b	;execve
		syscall

		add		rsp,	r15	;free rsp_argv
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. rsi, argv
;
;modify registers: r12 = argc
				  ;rcx = ??? change in syscall
				  ;r11 = ??? change in syscall
				  ;rdx = ??? change in syscall
				  ;rsi = ??? change in syscall
				  ;rdi = ??? change in syscall
				  ;if is_slash
				  	  ;rax = return of syscall
					  ;if execve_as_script was called:
					  	  ;r15 = r12 * 16
				  ;if not_is_slash
				  	  ;rax = [PATH_SIZE]
					  ;if execve_as_script was called:
					  	  ;r15 = r12 * 16
execvp:
	;counting argc
		xor		r12,	r12
		call	calc_argc
	;check if pathname contain '/'
		mov		rbp,	[rsi]
.e_check_slash: 
		mov		cl,	byte[rbp]
		cmp		cl,	'/'
		je		.e_if_slash
		inc		rbp
		test	cl,	cl
		jne		.e_check_slash
		sub		rsp,	1024	;allocate stack for modificated argv[0]

;		xor		rax,	rax		;path index iterator
.e_not_slash_loop:
		xor		rbp,	rbp		;stack iterator
		xor		rdi,	rdi		;path copy iterator
		mov		r9,		[PATH + rax * 8] ;PATH[i] string, PATH is char**
.e_cpy_path_to_argv_0:	
		mov		cl,	byte[r9 + rdi]
		mov		byte [rsp + rbp], cl
		inc		rbp
		inc		rdi
		test	cl,	cl
		jne		.e_cpy_path_to_argv_0
		mov		byte [rsp + rbp - 1], '/'
		xor		rdi,	rdi
		mov		r9,		[rsi]	;pathname
.e_cpy_pathname_to_argv_0:
		mov		cl,	byte[r9 + rdi]
		mov		byte [rsp + rbp], cl
		inc		rbp
		inc		rdi
		test	cl,	cl
		jne		.e_cpy_pathname_to_argv_0

	;int execve(const char *filename, char *const argv[],
		;char *const envp[]); 
		push	rax
		push	rsi
		lea		rdi,	[rsp + 16]
		mov		rsi,	rsi
		xor		rdx,	rdx
		mov		rax,	0x3b	;execve
		syscall
		pop		rsi
		call	execve_as_script
		pop		rax

		inc		rax
		cmp		ax,	[PATH_SIZE]
		jne		.e_not_slash_loop
		add		rsp,	1024	;free stack
		ret
.e_if_slash:
	;int execve(const char *filename, char *const argv[],
		;char *const envp[]); 
		mov		rdi,	[rsi]
		mov		rsi,	rsi
		xor		rdx,	rdx
		mov		rax,	0x3b	;execve
		syscall
		call	execve_as_script
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. rcx, ptr to buffer
;	2. rsi,	ptr to argv
;	3. rdx, size of buffer
;Function skip all spaces and return pointer after spaces
;
;modify registers: rbx = 0
				  ;rsi = argc
				  ;rcx = rcx + n, n - num of spaces
				  ;rax = 0x20, uncomment push/pop/sub for get num of spaces
parse_cmd:
		sub		rsp,	32
		xor		bl,	bl
		mov		dil,	0x20
		xor		rax,	rax
		mov		rsi,	1
		mov		qword[rsp],	rcx

.lp:	cmp		byte[rcx + rax],	dil
		jne		.ne2
		mov		byte[rcx + rax],	bl
		lea		r9,		[rcx + rax + 1]
		mov		qword[rsp + 8 * rsi],	r9
		inc		rsi
.ne2:	inc		rax
		cmp		rax,	rdx
		jne		.lp
		mov		qword[rsp + 8 * rsi],	rbx

		mov		rsi,	rsp
		mov		rbx,	2
		call 	execvp

		add		rsp,	32
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1.	bl,	char
;list of seps:
	;'|'
	;'&'
	;'>'
	;';'
	;'&&' = 0x03
	;'||' = 0x04
	;'>>' = 0x05
;modify registers: rbx - 1 or 0
if_sep:
		cmp		bl,	'|'
		je		.is_true
		cmp		bl,	'&'
		je		.is_true
		cmp		bl,	'>'
		je		.is_true
		cmp		bl,	';'
		je		.is_true
		cmp		bl,	0x03	;'&&'
		je		.is_true
		cmp		bl,	0x04	;'||'
		je		.is_true
		cmp		bl,	0x05	;'>>'
		je		.is_true
		xor		rbx,	rbx
		ret
.is_true:
		mov		rbx,	1
		ret
;----------------------------------------------------------------
;args:
;	1.	rcx,	buf
;modify registers: rax = size of buffer + 1
				  ;r14 = num of sep
				  ;bl = 0
				  ;r11 = 0 or 1

calc_sep:
		xor		rax,	rax
		xor		r14,	r14
.cs_loop:
		call	if_sep
		test	rbx,	rbx
		je		.cs_1
		inc		r14
.cs_1	inc		rax
		mov		bl,	byte[rcx + rax]
		test	bl,	bl
		jne		.cs_loop

		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;get argc* and calc argc for each cmd
;fill sep*
;
;args:
;	1.	rcx,	buf
;	2.	rsi,	argc*
;	3.	rdi,	sep*
;modify registers: rax = size of buffer + 1
				  ;r14 = num of sep

fill_argc:
	;in this function we made almost the same in delete_space_holes.
;maybe I should combine them? Later. Maybe.
	;this code is bad, but is correct. Rewrite this later.
		xor		rdx,	rdx 	;bool for check whether we are in brackets

		xor		rax, 	rax 	;iterator for rcx_buffer
		xor		rbp,	rbp		;iterator for argc
.fa_loop2:
		mov		r10,	2		;counter of single argc
.fa_loop:
		mov		bl,  	byte[rcx + rax]
		cmp		rdx,	1
		je		.fa_if_in_double_quote_now
		cmp		bl,		'"'
		jne		.fa_if_in_not_double_quote
		mov		rdx,	1
		jmp		.fa_loop_epilogue
.fa_if_in_not_double_quote: 
		cmp		bl,		0x20 ;' '
		jne		.fa_check_sep
		inc		rax
		inc		r10
		jmp		.fa_loop
.fa_check_sep:
		call	if_sep
		test	rbx,	rbx
		je		.fa_loop_pre
		mov		dword[rsi + (rbp * 4)], r10d
		mov		bl,  	byte[rcx + rax]
		mov		byte[rdi + rbp], bl
		inc		rax
		inc		rbp
		jmp		.fa_loop2
.fa_loop_pre:
		inc		rax
		mov		bl,  	byte[rcx + rax - 1]
		test	bl,		bl
		jne		.fa_loop
.fa_if_in_double_quote_now:
		cmp		bl,		'"'
		jne		.fa_loop_epilogue
		xor		rdx,	rdx
.fa_loop_epilogue:
		inc		rax
		test	bl,		bl
		jne		.fa_loop
		mov		dword[rsi + (rbp * 4)], r10d

		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
global _start
_start:
;		call 	init_path
	;ssize_t read(int fd, void *buf, size_t count);
		mov		rdi,	1		;stdin
		mov		rsi,	read_buffer_data
		mov		rdx,	READ_BUFFER_MAX_SIZE
		xor		rax,	rax		;read
		syscall

		mov		rdx,	rax		;in rax size of input bytes
		mov		rcx,	read_buffer_data
		call 	skip_spaces
		call	replace_special_symbols
		call 	delete_space_holes
		call	calc_sep
		;num of sep = r14, num of cmd = r14 + 1.
		;what is cmd? Argv & argc. We can know argc for each cmd with
	;help simple func, and after alloc the right amount of memory
	;argc = 4 byte. Need alloc (r14 + 1) * 4 bytes for argc*
	;sep  = 1 byte. Need alloc r14 bytes for sep*
		lea		r15,	[(r14 + 1) * 4]
		add		r15,	r14
		sub		rsp,	r15
;		push	r15
		;register states on this step:
			;rcx = ptr to buf
			;rdx = size of buf
			;rax = size of buf
			;r14 = num of separators
			;r15 = size of allocate to argc*
			;[rsp..rsp+r14] = memory of sep
			;[rsp+r14..rsp+r15] = memory of argc
			;bl = 0
			;rbp = 0
			;rdi = 1
		mov		rdi,	rsp
		lea		rsi,	[rsp + r14]
		call	fill_argc
		;call	sep_str_to_cmd
		;call	parse_cmd
;		pop		r15
		add		rsp,	r15

		xor		rdi,	rdi		;stdout
		mov		rsi,	rcx
		mov		rdx,	24
		mov		rax,	1		;write
		syscall
	;Terminate program
		xor		rdi, 	rdi		; result, return 0
		mov		rax, 	60		; exit
		syscall
