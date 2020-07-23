%define USER_PROCESS  6
%define LOGIN_PROCESS 7
section .rodata
		utmp_path  db "/var/run/utmp", 0

section .bss
		login	resb 32

;struc stat
;		st_dev			 resq 1 ;0..7,	   device
;		st_ino			 resq 1 ;8..15,    file serial number
;		st_nlink		 resq 1 ;16..23,   link count
;		st_mode			 resd 1 ;24..27,   file mode
;		st_uid			 resd 1 ;28..31,   user id of the file's owner
;		st_gid			 resd 1 ;32..35,   group id of the file's group
;		__pad0			 resd 1 ;36..39
;		st_rdev			 resq 1 ;40..47,   device number, if device
;		st_size			 resq 1 ;48..55,   size of file, in bytes
;		st_blksize		 resq 1 ;56..63,   optimal block size for I/O
;		st_blocks		 resq 1 ;64..71,   Nr. 512-byte blocks allocated
;		st_atim			 resq 2 ;72..87,   timespec, time of last access
;		st_mtim			 resq 2 ;88..103,  timespec, time of last modification
;		st_ctim			 resq 2 ;104..119, timespec, time of last status change
;		__glibc_reserved resq 3 ;120..143, __syscall_slong_t
;endstruc ;144

;struc exit_status
;		e_termination	resw 1
;		e_exit			resw 1

;struc utmp
;		ut_type			 resd 1   ;0..3, type of login
;		ut_pid			 resd 1   ;4..7, process ID of login process
;		ut_line			 resb 32  ;8..39, devicename
;		ut_id			 resb 4   ;40..43, inittab ID
;		ut_user			 resb 32  ;44..75, username
;		ut_host			 resb 256 ;76..331, hostname for remote login
;		ut_exit			 resw 2   ;332..335, exit_status of process marked as DEAD_PROCESS
;		ut_session		 resd 1   ;336..339, session ID, used for windowing
;		ut_tv			 resd 2   ;340..347, sec and microsec, time entry was made
;		ut_addr_v6		 resd 4   ;348..363, internet address of remote host
;		__glibc_reserved resb 20  ;364..383, reserved for future use
;		align			 resb 1
;endstruc ;384

section .text
setlogin:
		%define	ALLOC_SETLOGIN 144 ;sizeof(stat)
		sub		rsp,	ALLOC_SETLOGIN
		
		mov		rdi,	utmp_path
		xor		rdx,	rdx			;O_RDONLY	 |
		xor		rsi,	rsi
		mov		rax,	0x02		;open
		syscall

		mov		r15,	rax			;save fd
		
		mov		rdi,	r15			;fd
		lea		rsi,	[rsp]		;struct stat
		mov		rax,	0x05		;fstat
		syscall

		mov		r14,	[rsp + 48]  ;st_size
		sub		rsp,	r14

		mov		rdi,	r15			;fd
		mov		rsi,	rsp			;buf
		mov		rdx,	r14			;num_of_read
		xor		rax,	rax			;read
		syscall

		mov		r13,	rax			;size_buf

		mov		edi,	r15d
		mov		rax,	0x03		;close
		syscall

		mov		rdx,	rsp ;begin iterator for utmp
		lea		rbx,	[rdx + r13] ;end   iterator for utmp
		jmp		.sl_lp_begin
.sl_lp:
		add		rdx,	384			;sizeof(utmp)
.sl_lp_begin:
		cmp		dword[rdx], USER_PROCESS
		je		.sl_lp_end
		cmp		dword[rdx], LOGIN_PROCESS
		je		.sl_lp_end
		cmp		rdx,	rbx
		jl		.sl_lp
.sl_lp_end:
		
		mov		rdi,	login
		lea		rsi,	[rdx + 44]
		mov		rcx,	4		;32/8
		rep		movsq

		add		rsp,	r14
		add		rsp,	ALLOC_SETLOGIN

		ret
