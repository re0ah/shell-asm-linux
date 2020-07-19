section .text
%define READ_BUFFER_MAX_SIZE 1024

%define	SEP_IF_AND  0x01 ;&&
%define	SEP_IF_PIPE	0x02 ;||
%define SEP_OUT_END	0x03 ;>>
%define SEP_AND		0x04 ;&
%define SEP_PIPE	0x05 ;|
%define SEP_OUT		0x06 ;>
%define SEP_SEMICLN 0x07 ;';'
%define	SPACE_BR	0x08 ;'\ '
%define	DQUOTE_BR	0x09 ;'\"'
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

;----------------------------------------------------------------
prepare_for_parse:
		push	rdx
		push	rbx
		push	rbp
		push	rdi
		push	rsi
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. rsi, ptr to buffer
;Function skip all spaces and return pointer after spaces
;
;modify registers: rsi = rsi + n, n - num of spaces
skip_spaces:
		mov		rdi,	0x20	;0x20 = ' '
		jmp 	.ss_loop_2
.ss_loop:
		inc		rsi
.ss_loop_2:
		cmp		byte[rsi], dil
		je	 	.ss_loop
;----------------------------------------------------------------

;----------------------------------------------------------------
;replace special symbols (list below) on numbers
;deleting spaces around |, ||, >, >>, &, &&
;
;args:
;	1. rsi, ptr to buffer
;replace some sequences to single char
	;'&&' -> 0x01
	;'||' -> 0x02
	;'>>' -> 0x03
	;'&'  -> 0x04
	;'|'  -> 0x05
	;'>'  -> 0x06
	;';'  -> 0x07
	;'\ ' -> 0x08
	;'\"' -> 0x09
replace_special_symbols:
		sub		rsp, 	READ_BUFFER_MAX_SIZE ;alloc stack memory

		mov		rdi, 	rsi 	;iterator for rsi_buffer
		mov		rbp,	rsp 	;iterator for stack buffer
	;copy on stack buffer from rsi according by the rules on the comment
;of this function
.rsp_loop:
		mov		bx,  	word[rdi]

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
		inc		rdi
		jmp		.rsp_loop
.l_double_sign:
		add		rdi,	2
.l_one_sign:
		mov		byte [rbp], bl
		inc		rbp
		mov		bl,  	byte[rdi]
		cmp		bl,		0x20
		jne		.rsp_loop
		inc		rdi
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
		inc		rdi
		jmp		.l_one_sign
.l5:
		mov		bl,		SEP_PIPE
		inc		rdi
		jmp		.l_one_sign
.l6:
		mov		bl,		SEP_OUT
		inc		rdi
		jmp		.l_one_sign
.l7:
		mov		bl,		SEP_SEMICLN
		inc		rdi
		jmp		.l_one_sign
.l8:
		mov		bl,		SPACE_BR
		inc		rdi
		jmp		.rsp_l
.l9:
		mov		bl,		DQUOTE_BR
		inc		rdi
.rsp_l:
		mov		byte [rbp], bl
		inc 	rbp
		inc		rdi
		test	bl,		bl
		jne		.rsp_loop
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
		mov		r9,		rsi
		mov		rsi,	rsp
		sub		rsp, 	READ_BUFFER_MAX_SIZE ;alloc stack memory

		xor		rdx,	rdx 	;bool for check whether we are in brackets

		mov		rdi,	rsi		;iterator for rsi_buffer
		xor		rcx,	rcx 	;iterator for stack buffer
	;copy on stack buffer from rsi according by the rules on the comment
;of this function
.dsh_loop:
		mov		bx,  	word[rdi]
		cmp		rdx,	1
		je		.dsh_if_in_double_quote_now
		cmp		bl,		'"'
		jne		.dsh_if_in_not_double_quote
		mov		rdx,	1
		inc		rdi
		jmp		.dsh_loop
.dsh_if_in_not_double_quote:
		cmp		bx,		0x2020		;'  ', two spaces in a row
		jne		.dsh_loop_epilogue
		inc		rdi
		jmp		.dsh_loop
.dsh_if_in_double_quote_now:
		cmp		bl,		'"'
		jne		.dsh_loop_epilogue
		xor		rdx,	rdx
		inc		rdi
		jmp		.dsh_loop
.dsh_loop_epilogue:
		mov		byte [rsp + rcx], bl
		inc		rdi
		inc 	rcx
		test	bl,		bl
		jne		.dsh_loop

		mov		rdi,	r9
		mov		rsi,	rsp
		rep		movsb
;		mov		byte[rdi - 2], cl

		add		rsp,	2048;free stack memory

		pop		rsi
		pop		rdi
		pop		rbp
		pop		rbx
		pop		rdx
		ret
;----------------------------------------------------------------

;----------------------------------------------------------------
;args:
;	1. rsi, ptr to buffer
;	2. r11, ptr to argv
;Function skip all spaces and return pointer after spaces
;
parse_cmd:
		push	r15
		push	r13
		push	r8
		mov		[r11],	rsi		;argv[0] = buf

		xor		r13,	r13
		lea		r8,		[r11 + 8]	;argv iterator
.pc_loop:
		mov		r15b,	byte[rsi]
		test	r15b,	r15b
		je		.pc_loop_end
		cmp		r15b,	' '
		je		.pc_l1
		cmp		r15b,	DQUOTE_BR
		je		.pc_l2
		cmp		r15b,	SPACE_BR
		je		.pc_l3
		call	if_sep
		test	r15,	r15
		jne		.pc_loop_end
		inc		rsi
		jmp		.pc_loop
.pc_l1:
		mov		byte[rsi],	r13b ;0
		inc		rsi
		mov		qword[r8], rsi
		add		r8,		8
		jmp		.pc_loop
.pc_l2:
		mov		r15b,	'"'
		mov		byte[rsi],	r15b
		inc		rsi
		jmp		.pc_loop
.pc_l3:
		mov		r15b,	' '
		mov		byte[rsi],	r15b
		inc		rsi
		jmp		.pc_loop
.pc_loop_end:
		mov		[r8],	r13 ;0
		mov		byte[rsi],	r13b ;0
		inc		rsi

		pop		r8
		pop		r13
		pop		r15
		ret
;----------------------------------------------------------------
