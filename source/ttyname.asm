%define BUFSIZ 8192
%define AT_FDCWD -100

section .rodata
		devpts_path  db "/dev/pts/", 0

section .data
		ttyname db "pts/", 0, 0, 0, 0, 0, 0, 0, 0, 0,
				db		   0, 0, 0, 0, 0, 0, 0, 0, 0,
				db		   0, 0, 0, 0, 0, 0, 0, 0, 0 
										 ;32 bytes, where 27 zeros - reserve
										 ;and last null-term

;struc __dirstream
;		fd 		   resd 1 ;0..3,   file descriptor
;		allocation resq 1 ;4..11,  space allocated for the block
;		size 	   resq 1 ;12..19, total valid data in the block
;		offset 	   resq 1 ;20..27, current offset into the block
;		filepos    resq 1 ;28..35, position of next entry to read
;		errcode    resd 1 ;36..39, delayed error code
;		_data	   resb 8 ;40..47, not using, for align
;endstruc ;48 bytes

;struc timespec
;		tv_sec	   resq 1 ;0..7
;		tv_nsec	   resq 1 ;8..15
;endstruc ;16 bytes

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

;struc dirent
;		d_ino	   resq 1 ;0..7
;		d_off	   resq 1 ;8..15
;		d_reclen   resw 1 ;16..17
;		d_type	   resb 1 ;18..18
;		d_name	   resb 261 ;19..279
;endstruc ;280 bytes

section .text

ttyname_init:
		%define	BUFSIZ4 32768
		%define	ALLOC_TTYNAME_INIT 33240 ;sizeof(__dirstream) + 
										 ;bufsiz * 4 +
										 ;sizeof(stat) +
										 ;sizeof(dirent)
		sub		rsp,	ALLOC_TTYNAME_INIT
		
		mov		rdi,	rsp;struct __distream
		xor		rax,	rax
		mov		rcx,	6	;8 * 6 = 48 bytes, sizeof(__dirstream)
		rep		stosq

		mov		rdi,	AT_FDCWD
		mov		rsi,	devpts_path
		mov		edx,	0x98800		;O_RDONLY	 |
									;O_NDELAY	 |
									;O_DIRECTORY |
									;O_LARGEFILE |
									;O_CLOEXEC
		mov		rax,	0x101		;openat
		syscall
		
		mov		dword[rsp],	eax ;dirstream->fd
		mov		edi,	eax			;fd
		lea		rsi,	[rsp + 40]  ;data ptr
		mov		rdx,	32768		;allocation
		mov		rax,	0xd9		;getdents64
		syscall

		xor		rdi,	rdi			;fd
		lea		rsi,	[rsp + 32808];struct stat
		mov		rax,	0x05		;fstat
		syscall

		mov		rax,	[rsp + 32816]
		lea		rdx,	[rsp + 40]	;dirstream data ptr
		jmp		.readdir_start
.readdir:
		add		rdx,	rcx
.readdir_start:
		movzx	rcx,	word[rdx + 16];stat, d_reclen
		cmp		qword[rdx], rax ;dirent, d_ino
		jne		.readdir

		mov		eax,	dword[rdx + 19]
		mov		dword[ttyname + 4], eax

		mov		edi,	dword[rsp] ;dirstream->fd
		mov		rax,	0x03		;close
		syscall

		add		rsp,	ALLOC_TTYNAME_INIT
		ret
