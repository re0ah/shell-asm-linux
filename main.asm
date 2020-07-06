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

bits 64

%define PAGESIZE 4096
%define PIPESIZE 65536
%define READ_BUFFER_MAX_SIZE 1024
%define PATH_MAX_SIZE	 	 1024

section .rodata
		PATH_ARGV_NAME	 db "/bin/sh", 0
		PATH_ARGV_0		 db "-c", 0
		PATH_ARGV_1		 db "echo $PATH", 0
		PATH_ARGV_2		 db 0
		PATH_ARGV		 dq	PATH_ARGV_NAME
						 dq	PATH_ARGV_0
						 dq	PATH_ARGV_1
						 dq	PATH_ARGV_2

section .bss
		read_buffer_data resb READ_BUFFER_MAX_SIZE
		PATH			 resb 1024
		PATH_SIZE		 resw 1

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
init_path:
		sub		rsp,	8
	;int pipe(int pipefd[2]);
		mov		rdi,	rsp
		mov		rax,	0x16	;pipe
		syscall
    ;pid_t fork(void);
		mov		rax,	0x39	;fork
		syscall
		cmp		rax,	0
		jne		.itp_pt			;jump to parent code
			;this is child code
		;int dup2(int oldfd, int newfd);
			mov		edi,	dword[rsp + 4] ;fd[1], WRITE_END
			mov		rsi,	1			   ;STDOUT_FILENO
			mov		rax,	0x21
			syscall
    	;int close(int fd);
			mov		edi,	dword[rsp]	   ;fd[0], READ_END
			mov		rax,	0x03		   ;close
			syscall
			mov		edi,	dword[rsp + 4] ;fd[1], WRITE_END
			mov		rax,	0x03		   ;close
			syscall
       ;int execve(const char *pathname, char *const argv[],
                  ;char *const envp[]);
			mov		rdi,	PATH_ARGV_NAME
			mov		rsi,	PATH_ARGV
			xor		rdx,	rdx
			mov		rax,	0x3b	;execve
			syscall
			
	;pid_t wait4(pid_t pid, int *wstatus, int options,
                ;struct rusage *rusage);
.itp_pt:xor		rdi,	rdi
		xor		rsi,	rsi
		xor		rdx,	rdx
		xor		r10,	r10
		mov		rax,	0x3d	;wait4
		syscall
    ;ssize_t read(int fd, void *buf, size_t count);
		mov		edi,	dword[rsp]	;fd[0], READ_END
		mov		rsi,	PATH
		mov		rdx,	PATH_MAX_SIZE
		xor		rax,	rax		;read
		syscall
		mov		word[PATH_SIZE],	ax
		add		rax,	PATH
		xor		rcx,	rcx
		mov		byte[rax], 	cl ;0
		mov		cl,		':'
		mov		byte[rax - 1], 	cl
    ;int close(int fd);
		mov		edi,	dword[rsp]	;fd[0],	READ_END
		mov		rax,	0x03	;close
		syscall
		mov		edi,	dword[rsp + 4];fd[1], WRITE_END
		mov		rax,	0x03	;close
		syscall
		add		rsp,	8
		ret
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
		jmp 	.sk_sc2
.sk_sc: inc		rcx
.sk_sc2:cmp		byte [rcx], al	
		je	 	.sk_sc
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
		
;		xor		rdx,	rdx 	;bool for check whether we are in brackets
								;in general, zeroing it makes no sense,
						    ;so I commented this

		xor		rax, 	rax 	;iterator for rcx_buffer
		xor		rbp,	rbp 	;iterator for stack buffer
	;copy on stack buffer from rcx according by the rules on the comment
;of this function
.dsh_lp:mov		bx,  	word[rcx + rax]
		cmp		rdx,	1
		je		.dsh_2
		cmp		bl,		'"'
		jne		.dsh_3
		mov		rdx,	1
		jmp		.dsh_0
.dsh_3: cmp		bx,		0x2020		;'  ', two spaces in a row
		jne		.dsh_0
		inc		rax
		jmp		.dsh_lp
.dsh_2:	cmp		bl,		'"'
		jne		.dsh_0
		xor		rdx,	rdx
.dsh_0:	mov		byte [rsp + rbp], bl
.dsh_1:	inc		rax
		inc 	rbp
		cmp		bl,		0x00
		jne		.dsh_lp

		dec		rbp		;the cycle is written so that an extra 1 added to rbp
	;in rbp at the moment stores size of stack_buffer. Perhaps it will
;still be needed - save it in rdx
		mov		rdx,	rbp

	;copy on rcx_buffer from stack.
	;This cycle don't copy first element, but I don't need
.cp_buf:mov		bl,		byte[rsp + rbp]
		mov		byte[rcx + rbp], bl
		dec		rbp
		jnz		.cp_buf

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
replace_special_symbols:
		sub		rsp,	READ_BUFFER_MAX_SIZE ;allocate stack memory

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
;	1. rcx, ptr to buffer
;	2. rsi,	ptr to argv
;Function skip all spaces and return pointer after spaces
;
;modify registers: rcx = rcx + n, n - num of spaces
;				   rax = 0x20, uncomment push/pop/sub for get num of spaces
parse_cmd:
		sub		rsp,	32
;int execve(const char *filename, char *const argv[],
;char *const envp[]); 
;		mov		rdi,	
;		mov		rsi,
;		mov		rdx,	
;		mov		rax,	0x3b	;execve
;		syscall
		add		rsp,	32
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
global _start
_start:
		call 	init_path
	;ssize_t read(int fd, void *buf, size_t count);
		mov		rdi,	1		;stdin
		mov		rsi,	read_buffer_data
		mov		rdx,	READ_BUFFER_MAX_SIZE
		xor		rax,	rax		;read
		syscall

		mov		rdx,	rax		;in rax size of input bytes
		mov		rcx,	read_buffer_data
		call 	skip_spaces
		call 	delete_space_holes
;		call	replace_special_symbols
;		call	sep_str_to_cmd
		call	parse_cmd

		xor		rdi,	rdi		;stdout
		mov		rsi,	rcx
		mov		rax,	1		;write
		syscall
	;Terminate program
		xor		rdi, 	rdi		; result, return 0
		mov		rax, 	60		; exit
		syscall
