%define STDIN_FILENO  0
%define TCGETS		  0x5401
%define TCSETS		  0x5402
%define __KERNEL_NCCS 19

struc __kernel_termios
		c_iflag resd 1	;input   mode flags
		c_oflag resd 1	;output  mode flags
		c_cflag resd 1	;control mode flags
		c_lflag resd 1	;local   mode flags
		c_line	resb 1	;line discipline
		c_cc	resb __KERNEL_NCCS ;control characters
endstruc
%define __KERNEL_TERMIOS_SIZE 36 ;in bytes

section .bss
		default_kernel_termios resb 36
section .code
;----------------------------------------------------------------
term_init:
		sub		rsp,	__KERNEL_TERMIOS_SIZE

		mov		rdi,	STDIN_FILENO
		mov		rsi,	TCGETS
		mov		rdx,	rsp
		mov		rax,	0x10 ;ioctl
		syscall

		;save default kernel_termios value
		mov		rdi,	default_kernel_termios
		mov		rsi,	rsp
		mov		rcx,	9		;36/4
		rep		movsd
		
		mov		eax,	dword[rsp + 12]	;c_lflag 
		and		eax, 	0x0fffffff5		;&= ~(ICANON | ECHO)
		mov		dword[rsp + 12], eax

		mov		rdi,	STDIN_FILENO
		mov		rsi,	TCSETS
		mov		rdx,	rsp
		mov		rax,	0x10 ;ioctl
		syscall

		add		rsp,	__KERNEL_TERMIOS_SIZE
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
term_to_default:
		mov		rdi,	STDIN_FILENO
		mov		rsi,	TCSETS
		mov		rdx,	default_kernel_termios
		mov		rax,	0x10 ;ioctl
		syscall
		ret
;----------------------------------------------------------------
