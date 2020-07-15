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

%define PAGE_SIZE 4096
%define PIPE_SIZE 65536
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
;	1. rsi, ptr to buffer
;Function skip all spaces and return pointer after spaces
;
;modify registers: rsi = rsi + n, n - num of spaces
;				   rax = 0x20, uncomment push/pop/sub for get num of spaces
skip_spaces:
		push	rax
;		push	rsi
		mov		rax,	0x20	;0x20 = ' '
		jmp 	.ss_loop_2
.ss_loop:
		inc		rsi
.ss_loop_2:
		cmp		byte[rsi], al	
		je	 	.ss_loop
;		pop		rax
;		sub		rax,	rsi
		pop		rax
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. rsi, ptr to buffer
;
;	delete repeating ' ' and alls ' ' on end
;	don't deleting spacing enclosed in brackets
;	also on end replace \n to \0
;	deleting all "
;	example: "e   xam  pl "   "    e   " -> "e xam pl     e"*/
;
;modify registers: rcx = new size of rsi_buffer
;
delete_space_holes:
		push	rdx
		push	rax
		push	rbx
		push	rbp

		sub		rsp, 	READ_BUFFER_MAX_SIZE ;alloc stack memory
		
		xor		rdx,	rdx 	;bool for check whether we are in brackets

		xor		rax, 	rax 	;iterator for rsi_buffer
		xor		rbp,	rbp 	;iterator for stack buffer
	;copy on stack buffer from rsi according by the rules on the comment
;of this function
.dsh_loop:
		mov		bx,  	word[rsi + rax]
		cmp		rdx,	1
		je		.dsh_if_in_double_quote_now
		cmp		bl,		'"'
		jne		.dsh_if_in_not_double_quote
		mov		rdx,	1
		inc		rax
		jmp		.dsh_loop
.dsh_if_in_not_double_quote: 
		cmp		bx,		0x2020		;'  ', two spaces in a row
		jne		.dsh_loop_epilogue
		inc		rax
		jmp		.dsh_loop
.dsh_if_in_double_quote_now:
		cmp		bl,		'"'
		jne		.dsh_loop_epilogue
		xor		rdx,	rdx
		inc		rax
		jmp		.dsh_loop
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

	;copy on rsi_buffer from stack.
	;This cycle don't copy first element, but I don't need
.dsh_cp_buf:
		mov		bl,		byte[rsp + rbp]
		mov		byte[rsi + rbp], bl
		dec		rbp
		jnz		.dsh_cp_buf

		mov		byte[rsi + rdx - 1], bpl

		add		rsp,	READ_BUFFER_MAX_SIZE ;free stack memory

		pop	rax
		pop	rbx
		pop	rbp
		pop	rdx
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;replace special symbols (list below) on numbers
;deleting spaces around |, ||, >, >>, &, &&
;
;args:
;	1. rsi, ptr to buffer
;
;replace some sequences to single char
	%define	SEP_IF_AND  0x01
	%define	SEP_IF_PIPE	0x02
	%define SEP_OUT_END	0x03
	%define SEP_AND		0x04
	%define SEP_PIPE	0x05
	%define SEP_OUT		0x06
	%define SEP_SEMICLN 0x07
	%define	SPACE_BR	0x08
	%define	DQUOTE_BR	0x09
	;'&&' -> 0x01
	;'||' -> 0x02
	;'>>' -> 0x03
	;'&'  -> 0x04
	;'|'  -> 0x05
	;'>'  -> 0x06
	;';'  -> 0x07
	;'\ ' -> 0x08
	;'\"' -> 0x09
;
;modify registers: rcx = new size of rsi_buffer
;
replace_special_symbols:
		push	rdx
		push	rax
		push	rbx
		push	rbp

		sub		rsp, 	READ_BUFFER_MAX_SIZE ;alloc stack memory
		
		xor		rax, 	rax 	;iterator for rsi_buffer
		xor		rbp,	rbp 	;iterator for stack buffer
	;copy on stack buffer from rsi according by the rules on the comment
;of this function
.rsp_loop:
		mov		bx,  	word[rsi + rax]

		cmp		bx,		0x2620		;' &'
		je		.l_skip
		cmp		bx,		0x7C20		;' |'
		je		.l_skip
		cmp		bx,		0x3E20		;' >'
		je		.l_skip
		cmp		bx,		0x3B20		;' ;'
		je		.l_skip

		cmp		bx,		0x2626		;'&&'
		je		.l1

		cmp		bx,		0x7C7C		;'||'
		je		.l2

		cmp		bx,		0x3E3E		;'>>'
		je		.l3

		cmp		bl,		0x26		;'&'
		je		.l4

		cmp		bl,		0x7C		;'|'
		je		.l5

		cmp		bl,		0x3E		;'>'
		je		.l6

		cmp		bl,		0x3B		;';'
		je		.l7

		cmp		bx,		0x205C		;'\ '
		je		.l8

		cmp		bx,		0x225C		;'\"'
		je		.l9
		jmp		.rsp_l

.l_skip:
		inc		rax
		jmp		.rsp_loop
.l_double_sign:
		add		rax,	2
.l_one_sign:
		mov		byte [rsp + rbp], bl
		inc		rbp
		mov		bl,  	byte[rsi + rax]
		cmp		bl,		0x20
		jne		.rsp_loop
		inc		rax
		jmp		.rsp_loop
.l1:	
		mov		bl,		SEP_IF_AND
		jmp 	.l_double_sign
.l2:	
		mov		bl,		SEP_IF_PIPE
		jmp 	.l_double_sign
.l3:	
		mov		bl,		SEP_OUT_END
		jmp 	.l_double_sign
.l4:	
		mov		bl,		SEP_AND
		inc		rax
		jmp		.l_one_sign
.l5:	
		mov		bl,		SEP_PIPE
		inc		rax
		jmp		.l_one_sign
.l6:	
		mov		bl,		SEP_OUT
		inc		rax
		jmp		.l_one_sign
.l7:	
		mov		bl,		SEP_SEMICLN
		inc		rax
		jmp		.l_one_sign
.l8:	
		mov		bl,		SPACE_BR
		inc		rax
		jmp		.rsp_l
.l9:	
		mov		bl,		DQUOTE_BR
		inc		rax
.rsp_l:
		mov		byte [rsp + rbp], bl
		inc 	rbp
		inc		rax
		test	bl,		bl
		jne		.rsp_loop

		dec		rbp		;the cycle is written so that an extra 1 added to rbp
	;in rbp at the moment stores size of stack_buffer. Perhaps it will
;still be needed - save it in rdx
		mov		rcx,	rbp

	;copy on rsi_buffer from stack.
	;This cycle don't copy first element, but I don't need
.rsp_cp_buf:
		mov		bl,		byte[rsp + rbp]
		mov		byte[rsi + rbp], bl
		dec		rbp
		jnz		.rsp_cp_buf

		add		rsp,	READ_BUFFER_MAX_SIZE ;free stack memory

		pop		rbx
		pop		rax
		pop		rdx
		pop		rbp
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1.	r11,	argv
;modify registers: r12 = argc
calc_argc:
		push	rax
		xor		rax,	rax
		xor		r12,	r12
.e_count_argc_loop:
		cmp		[r11 + r12 * 8], rax
		je		.e_count_argc_loop_end
		inc		r12
		jmp		.e_count_argc_loop
.e_count_argc_loop_end:
		pop		rax
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. r12, argc
;	2. r11,	argv
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
		push	r15
		push	rax
		push	r9
		push	r11
		push	rdi
		push	rdx

		mov		r15,	r12
		shl		r15,	4	;alloc with a margin
		sub		rsp,	r15	;alloc rsp_argv so call pathname through /bin/sh
		
		mov		rax,	PATH_BSHELL
		mov		qword[rsp],	rax
		xor		rax,	rax

		;copy r11_argv to rsp_argv
.eas_cpy_argv:	
		mov		r9,		qword[r11 + rax * 8]
		inc		rax
		mov		qword[rsp + rax * 8],	r9
		test	r9,		r9
		jne		.eas_cpy_argv

	;int execve(const char *filename, char *const argv[],
		;char *const envp[]); 
		mov		rdi,	[rsp]
		mov		r11,	rsp
		xor		rdx,	rdx
		call	execve

		add		rsp,	r15	;free rsp_argv

		pop		rdx
		pop		rdi
		pop		r11
		pop		r9
		pop		rax
		pop		r15
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. rdi, fname
;	2. rsi,	argv
;	3. rdx,	envp
	;int execve(const char *filename, char *const argv[],
		;char *const envp[]); 
;
;modify registers: rax - ret of syscall
execve:
		push	rdx
		push	rsi
		push	rdi
		push	rcx
		push	r11

		mov		rax,	0x3b	;execve
		syscall

		pop		r11
		pop		rcx
		pop		rdi
		pop		rsi
		pop		rdx
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. r11, argv
;
;modify registers: rax - result
execvp:
		push	r11
		push	rbp
		push	rcx
		push	rdi
		push	r9
		push	rax
	;counting argc
		call	calc_argc
	;check if pathname contain '/'
		mov		rbp,	[r11]
.e_check_slash: 
		mov		cl,	byte[rbp]
		cmp		cl,	'/'
		je		.e_if_slash
		inc		rbp
		test	cl,	cl
		jne		.e_check_slash
		sub		rsp,	1024	;allocate stack for modificated argv[0]

		xor		rax,	rax		;path index iterator
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
		mov		r9,		[r11]	;pathname
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
		push	r11
		lea		rdi,	[rsp + 16]
		mov		rsi,	r11
		xor		rdx,	rdx
		call	execve
		pop		r11
		;call	execve_as_script
		pop		rax

		inc		rax
		cmp		ax,	[PATH_SIZE]
		jne		.e_not_slash_loop
		add		rsp,	1024	;free stack

		pop		rax
		pop		r9
		pop		rdi
		pop		rcx
		pop		rbp
		pop		r11
		ret
.e_if_slash:
	;int execve(const char *filename, char *const argv[],
		;char *const envp[]); 
		mov		rdi,	[r11]
		mov		rsi,	r11
		xor		rdx,	rdx
		call	execve
		call	execve_as_script

		pop		rax
		pop		r9
		pop		rdi
		pop		rcx
		pop		rbp
		pop		r11
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1.	r15b,	char
;list of seps:
	;'&&' = 0x01
	;'||' = 0x02
	;'>>' = 0x03
	;'&'  = 0x04
	;'|'  = 0x05
	;'>'  = 0x06
	;';'  = 0x07
;modify registers: rbx - 1 or 0
if_sep:
		cmp		r15b,	SEP_SEMICLN
		jbe		.is_true
.ret_null:
		xor		r15,	r15
		ret
.is_true:
		test	r15b,	r15b
		je		.ret_null
		mov		r15,	1
		ret
;----------------------------------------------------------------
;args:
;	1.	rsi,	buf
;modify registers: rcx = size of buffer
				  ;r13 = num of sep
calc_sep:
		push	rbx
		push	r15
		xor		rcx,	rcx
		xor		r13,	r13
.cs_loop:
		mov		r15b,	bl
		call	if_sep
		test	r15,	r15
		je		.cs_1
		inc		r13
.cs_1	inc		rcx
		mov		bl,	byte[rsi + rcx]
		test	bl,	bl
		jne		.cs_loop

		pop		r15
		pop		rbx
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
;	2. r11, ptr to argv
;Function skip all spaces and return pointer after spaces
;
parse_cmd:
		push	rax
		push	r15
		push	r13
		push	r12
		push	r8
		push	rbx
		mov		[r11],	rsi		;argv[0] = buf

		xor		r13,	r13
		mov		r12,	0x20
		mov		r8,		1		;argv iterator
.pc_loop:
		mov		bl,		byte[rsi]
		cmp		bl,		r12b	;0x20, ' '
		jne		.pc_loop2
		mov		byte[rsi],	r13b ;0
		inc		rsi
		mov		qword[r11 + (r8 * 8)], rsi
		inc		r8
.pc_loop2:
		cmp		bl,		DQUOTE_BR
		jne		.if_not_dquote_br
		mov		al,		'"'
		mov		byte[rsi],	al
		jmp		.if_not_space_br
.if_not_dquote_br:
		cmp		bl,		SPACE_BR
		jne		.if_not_space_br
		mov		al,		' '
		mov		byte[rsi],	al
.if_not_space_br:
		test	bl,		bl
		je		.pc_loop_end
		mov		r15b,	bl
		call	if_sep
		test	r15,	r15
		jne		.pc_loop_end
		inc		rsi
		jmp		.pc_loop
.pc_loop_end:
		mov		[r11 + (r8 * 8)],	r13 ;0
		mov		byte[rsi],	r13b ;0
		inc		rsi

		pop		rbx
		pop		r8
		pop		r12
		pop		r13
		pop		r15
		pop		rax
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. rdi,	int32 fd
;	2. rsi,	void* buf
;	3. rdx,	size_t count
;
open:
		push	rdx
		push	rsi
		push	rdi
		push	rcx
		push	r11
    ;int open(const char *pathname, int flags, mode_t mode);
		mov		rax,	0x02	;open
		syscall
		pop		r11
		pop		rcx
		pop		rdi
		pop		rsi
		pop		rdx
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. rdi,	int32 fd
;	2. rsi,	void* buf
;	3. rdx,	size_t count
;
read:
		push	rdx
		push	rsi
		push	rdi
		push	rcx
		push	r11
	;ssize_t read(int fd, void *buf, size_t count);
		xor		rax,	rax		;read
		syscall
		pop		r11
		pop		rcx
		pop		rdi
		pop		rsi
		pop		rdx
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. rdi,	int32 fd
;	2. rsi,	void* buf
;	3. rdx,	size_t count
;
write:
		push	rdx
		push	rsi
		push	rdi
		push	rcx
		push	r11
	;ssize_t write(int fd, const void *buf, size_t count);
		mov		rax,	1		;write
		syscall
		pop		r11
		pop		rcx
		pop		rdi
		pop		rsi
		pop		rdx
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. rdi, return status
;
;modify registers: rax = ret of syscall
exit:
		mov		rax, 	60		; exit
		syscall
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. rdi, fd[2]
;
;modify registers: rax = ret of syscall
pipe:
		push	rcx
		push	rax
		push	r11
;	;int pipe(int pipefd[2]);
		mov		rax,	0x16	;pipe
		syscall
		pop		r11
		pop		rax
		pop		rcx
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. edi, fd
;
;modify registers: rax = ret of syscall
close:
		push	rcx
		push	rdi
		push	r11
		mov		rax,	0x03		   ;close
		syscall
		pop		r11
		pop		rdi
		pop		rcx
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;modify registers: rax = ret of syscall
fork:
		push	rcx
		push	rdi
		push	r11
		mov		rax,	0x39		   ;fork
		syscall
		pop		r11
		pop		rdi
		pop		rcx
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. edi, oldfd
;	2. rsi, newfd
;
;modify registers: rax = ret of syscall
dup2:
;		;int dup2(int oldfd, int newfd);
		push	rcx
		push	r11
		mov		rax,	0x21		   ;dup2
		syscall
		pop		r11
		pop		rcx
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. edi, oldfd
;	2. rsi, newfd
;
wait4:
;	;pid_t wait4(pid_t pid, int *wstatus, int options,
;                ;struct rusage *rusage);
;.init_path_parrent_code:
		push	rcx
		push	r11
		mov		rax,	0x3d	;wait4
		syscall
		pop		r11
		pop		rcx
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. edi, oldfd
;	2. rsi, newfd
wait_null:
		push	rdi
		push	rsi
		push	rdx
		push	r10
		push	rcx
		push	r11

		xor		rdi,	rdi
		xor		rsi,	rsi
		xor		rdx,	rdx
		xor		r10,	r10
		mov		rax,	0x3d	;wait4
		syscall

		pop		r11
		pop		rcx
		pop		r10
		pop		rdx
		pop		rsi
		pop		rdi
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
.eac_body_sep_if_pipe:
.eac_body_sep_out_end:
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

		mov		edi,	[r11]
		mov		rsi,	0x0441	;O_WRONLY | O_CREAT | O_APPEND
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
.eac_body_sep_and:
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
		jmp		.eac_body_end

.eac_body_sep_out:
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

		mov		edi,	[r11]
		mov		rsi,	0x0241	;O_WRONLY | O_CREAT | O_TRUNC
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
;		call 	init_path

		mov		rdi,	1		;stdin
		mov		rsi,	read_buffer_data
		mov		rdx,	READ_BUFFER_MAX_SIZE
		call	read

		call 	skip_spaces
		mov		rcx,	rax		;in rax size of input bytes
		call	replace_special_symbols
		call 	delete_space_holes
		call	calc_sep
		;num of sep = r13, num of cmd = r13 + 1.
		;what is cmd? Argv & argc. We can know argc for each cmd with
	;help simple func, and after alloc the right amount of memory
	;argc = 4 byte. Need alloc (r13 + 1) * 4 bytes for argc*
	;sep  = 1 byte. Need alloc r13 bytes for sep*
		lea		r15,	[(r13 + 1) * 4]
		add		r15,	r13
		sub		rsp,	r13
		;register states on this step:
			;rsi = buf
			;rcx = size of buf
			;r13 = num  of sep
			;r15 = size of allocate to argc* & sep*
			;[rsp..rsp+r13] = memory of sep
			;[rsp+r13..rsp+r15-rax] = memory of argc
		mov		rdx,	rsp			;ptr to sep*
		lea		rbx,	[rsp + r13] ;ptr to argc*
		call	fill_argc
		call	exec_all_cmd
		add		rsp,	r15

		mov		rdi,	1		;stdin
		mov		rdx,	32
		call	write

		xor		rdi, 	rdi		; result, return 0
		call	exit
