;info about struct of file, where stores history about user input
;filename: "history"
;stores info in lines, which ends on '\n'
%define MAX_HISTORY_SIZE 512 ;in lines
section .rodata
		history_fname db "history", 0

%define HISTORY_DATA_SESSION_SIZE 1024
%define MAX_LINE_SIZE 128 ;in bytes
				;2^(sizeof(history_data_line_pos) * 8) / 2^lg(MAX_HISTORY_SIZE)
				;2^16 / 2^9 = 2^7 = 128
section .data
		history_data dq 1 ;bytes ptr, allocate with malloc
						  ;also there allocated data in this session
section .bss
		history_data_line_pos resw 1536
					;1536 = MAX_HISTORY_SIZE + HISTORY_DATA_SESSION_SIZE
					;first - fname_history, after - session_history
		history_data_line_lenght resw 1536
					;1536 = MAX_HISTORY_SIZE + HISTORY_DATA_SESSION_SIZE
					;first - fname_history, after - session_history
		history_file_lenght 	  resw 1 ;num of lines in history_fname
		history_data_session_size resw 1 ;it-counter for session data
		
		history_line_pos resw 1 ;dec/inc and use as history_data_line_pos[i]
section .text
history_init:
		mov		rdi,	history_fname
		xor		rdx,	rdx		;O_RDONLY
		xor		rsi,	rsi		;mode
		mov		rax,	0x02	;open syscall
		syscall
		test	eax,	eax
		jl		if_history_empty;history_fname doesn't exist
		mov		r15d,	eax		;save fd

		sub		rsp,	144		;sizeof(struct stat)
		mov		edi,	eax		;fd
		mov		rsi,	rsp		;struct stat
		mov		rax,	0x05	;fstat syscall
		syscall
		mov		rsi,	qword[rsp + 48]	;stat.st_size (size of file)
		add		rsp,	144
		test	rsi,	rsi
		je		if_history_empty;history_fname file is empty
		mov		r14,	rsi

		shr		rsi,	12		;div on PAGESIZE(4096)
		call	if_history_empty;(p.s. history is not empty)

		mov		edi,	r15d	;fd
		mov		rsi,	rax		;destination
		mov		rdx,	r14		;num of read
		xor		rax,	rax		;read syscall
		syscall

		mov		edi,	r15d	;fd
		mov		rax,	0x03	;close syscall
		syscall

;		jmp history_parse
history_parse:
;count num of lines and save where they are starts in history_data_line_pos
		xor		rdi,	rdi	;counter history_data_line_pos
		xor		rax,	rax	;counter source
		xor		r8,		r8	;counter lenght
		mov		word[history_data_line_pos],	ax
.main_lp:
		mov		cl,		byte[rsi + rax]
		cmp		cl,		0x0A	;'\n'
		jne		.if_not_new_line
		inc		rax
		mov		word[history_data_line_lenght + rdi],	r8w
		add		rdi,	2
		mov		word[history_data_line_pos + rdi],	ax
		xor		r8,		r8
		cmp		rax,	r14
		je		.end
		jmp		.main_lp
.if_not_new_line:
		inc		r8
		inc		rax
		cmp		rax,	r14
		jne		.main_lp
.end:
		sub		rdi,	2
		mov		word[history_file_lenght], di
		ret

if_history_empty:
		add		rsi,	2		;num of pages
								;2 is minimum, also always need 1 page for
								;session_data

		xor		rdi,	rdi		;addr
		mov		rdx,	0x03	;PROT_READ   | PROT_WRITE
		mov		r10,	0x22	;MAP_PRIVATE | MAP_ANONYMOUS
		mov		r8,		-1		;fd
		xor		r9,		r9		;offset
		mov		rax,	0x09	;mmap syscall
		syscall
		mov		qword[history_data], rax

		ret
