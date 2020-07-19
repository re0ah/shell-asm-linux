section .text
;----------------------------------------------------------------
;args:
;	1. rdi,	int32 fd
;	2. rsi,	void* buf
;	3. rdx,	size_t count
;
open:
		push	rcx
		push	r11
    ;int open(const char *pathname, int flags, mode_t mode);
		mov		rax,	0x02	;open
		syscall
		pop		r11
		pop		rcx
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. rdi,	int32 fd
;	2. rsi,	void* buf
;	3. rdx,	size_t count
;
read:
		push	rcx
		push	r11
	;ssize_t read(int fd, void *buf, size_t count);
		xor		rax,	rax		;read
		syscall
		pop		r11
		pop		rcx
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. rdi,	int32 fd
;	2. rsi,	void* buf
;	3. rdx,	size_t count
;
write:
		push	rcx
		push	r11
	;ssize_t write(int fd, const void *buf, size_t count);
		mov		rax,	1		;write
		syscall
		pop		r11
		pop		rcx
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
		push	r11
;	;int pipe(int pipefd[2]);
		mov		rax,	0x16	;pipe
		syscall
		pop		r11
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
		push	r11
		mov		rax,	0x03		   ;close
		syscall
		pop		r11
		pop		rcx
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;modify registers: rax = ret of syscall
fork:
		push	rcx
		push	r11
		mov		rax,	0x39		   ;fork
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
;	1. rdi, fname
;	2. rsi,	argv
;	3. rdx,	envp
	;int execve(const char *filename, char *const argv[],
		;char *const envp[]);
;
;modify registers: rax - ret of syscall
execve:
		push	rcx
		push	r11

		mov		rax,	0x3b	;execve
		syscall

		pop		r11
		pop		rcx
		ret
;----------------------------------------------------------------
