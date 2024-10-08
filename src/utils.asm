section .data
	global argv1
	global argv1_length
	global argv0_length
	global argv0
	global line_str_num
	global collum_str_num

	;       modes
	O_RDONLY db 0           ; read-only
	O_WRONLY db 1           ; write-only
	O_RDWR   db 2           ; read and write

	; flags
	O_CREAT  db 64,0,0,0         ; create file if it doesn't exist
	O_TRUNC  db 0,0x02,0,0; truncate file
	AT_FDCWD dq -100          ; read and write

	SEEK_END db 2,0,0,0

	input_char db 100 dup(0)
	int_specifier db 'int: %i', 10, 0
	str_specifier db 'int: %s', 10, 0
	argv0 db 8 dup(0)
	argv0_length db 4 dup(0)
	argv1 db 8 dup(0)
	argv1_length db 4 dup(0)
	heap_buffer_start_addr db 8 dup(0)
	break_addr db 8 dup(0)
	heap_buffer_size db 8 dup(0)
	line_break db 10, 0
	collum_str_num db 100 dup(0)
	line_str_num db 100 dup(0)
	temp_str_num_store db 100 dup(0)


section .text
	global write_char_to_stdout
	global input_char
	global read_args
	global get_file_path_size
	global print_str
	global print_int
	global exit_program
	global get_file_size
	global heap_buffer_start_addr
	global break_addr
	global heap_buffer_size
	global read_syscall
	global alloc_heap_block
	global break_line
	global convert_num_to_ascii
	global write_to_stdout
	global expand_heap_block
	global reset_file_pointer_to_start
	global open_file_for_read
	global open_file_for_write
	extern _start


exit_program:
	mov     rax, 60; syscall number for exit (60)
	mov     rdi, 0
	syscall ; call kernel

print_str: ;receive str addr on rdi
	mov r12, rdi
	call get_str_length
	mov rsi, r12
	mov rdx, rax
	call write_to_stdout
	ret

print_int: ;receive int on rdi and print with printf
	sub rsp, 8
	mov rsi, rdi
	mov rdi, int_specifier
	ret

write_to_stdout: ;length rdx, addr on rsi
	mov rax, 1
	mov rdi, 1
	syscall ; result at rax
	ret

break_line: 
	mov rdx, 2
	mov rsi, line_break
	mov rax, 1
	mov rdi, 1
	syscall ; result at rax
	ret

convert_num_to_ascii: ; receive num on rdi, num_str_addr on rsi returns num_str addr on rax
	xor rax, rax
	xor rdx, rdx ; clean registers

	mov r12d, edi
	mov byte al, 1 ;only for eax not be zero
	mov r14, 0 ;digit count
	mov r8, temp_str_num_store ;temp array for storing the digits

	mov eax, edi ;32 bit integer
	.loop:
	xor edx, edx ;zero on top of compound register
	mov ecx, 10
	div ecx ;result: eax, remainder: edx

	push rax ;store only because convert uses rax
	push rdx
	call convert_digit_to_ascii

	add r8, r14
	mov [r8], eax

	pop rax ; restore eax value
	cmp eax, 0
	mov r8, temp_str_num_store
	je move_from_temp_array_in_reverse_order
	add r14, 1 ;increment digit count
	jmp .loop


move_from_temp_array_in_reverse_order: ;receiving_array on rsi, temp_array on r8, higher index on r14
	mov rax, 0 ;counter
	mov rdi, 0 ;break_loop condition
	mov r9, rsi ;original_addr from receiving
	mov r10, r8 ;original_addr from temp

	.loop:
	cmp r14, 0
	je .set_break_condition

	.loop_body:
	mov rsi, r9 ;restore addresses that were added on previous iteration
	mov r8, r10

	add rsi, rax
	add r8, r14

	mov byte r11b, [r8] ;store r8 byte on r11
	mov byte [rsi], r11b
	
	add rax, 1 ;increse receiving array addr
	sub r14, 1 ;decrese higher address
	
	cmp rdi, 1
	je .ret
	jmp .loop

	.set_break_condition:
	mov rdi, 1
	jmp .loop_body

	.ret:
	mov rsi, r9
	add rsi, rax
	mov byte [rsi], 0 ;add null char
	mov rax, r9 ;put string addr on rax for return
	ret
	
convert_digit_to_ascii: ; receive num on stack
	pop r12 ;save_address on r12
	pop rdi
	push r12 ;push it back to the stack for the ret
	cmp rdi, 0
	je .0
	cmp rdi, 1
	je .1
	cmp rdi, 2
	je .2
	cmp rdi, 3
	je .3
	cmp rdi, 4
	je .4
	cmp rdi, 5
	je .5
	cmp rdi, 6
	je .6
	cmp rdi, 7
	je .7
	cmp rdi, 8
	je .8
	cmp rdi, 9
	je .9

	ret ; should never occur
	.0:
	mov rax, 48
	jmp .ret
	.1:
	mov rax, 49
	jmp .ret
	.2:
	mov rax, 50
	jmp .ret
	.3:
	mov rax, 51
	jmp .ret
	.4:
	mov rax, 52
	jmp .ret
	.5:
	mov rax, 53
	jmp .ret
	.6:
	mov rax, 54
	jmp .ret
	.7:
	mov rax, 55
	jmp .ret
	.8:
	mov rax, 56
	jmp .ret
	.9:
	mov rax, 57
	.ret:
	ret

get_argc: ;working
	mov  rdi, int_specifier
	mov  rax, [rsp + 8]; argc
	ret

read_args: ; for some reason argc has 8 bytes
	mov rax, [rsp + 16]
	mov [argv0], rax 
	mov rax, [rsp + 24]
	mov [argv1], rax
	ret

get_file_path_size:
	mov  rdi, [argv0]; argv[0]
	call get_str_length
	mov  [argv0_length], eax ; store size
	mov  rdi, [argv1]; argv[1]
	call get_str_length
	mov  [argv1_length], eax ; store size
	ret

get_str_length: ;receive string addr on rdi
	mov rax, 0
.loop_start:
	cmp byte [rdi], 0
	je  .break
	add rdi, 1
	add rax, 1
	jmp .loop_start
.break:
	ret

get_file_size: ; receive file descriptor on rdi, returns file_size
	mov rax, 8 ;fseek syscall
	mov rsi, 0
	mov rdx, 2 ; seek_end macro value
	syscall 
	cmp rax, 0xfffffffffffffff7
	je .return_zero_if_file_doesnt_exist
	ret
	.return_zero_if_file_doesnt_exist:
	mov rax, 0
	ret

open_file_for_read:; receives file name on rdi and return fd
	mov rax, 257; syscall number for open (2)
	mov rsi, rdi
	xor rdi, rdi
	mov dword edi, [AT_FDCWD]
	mov r10, 0o644; file perms bits
	xor rdx, rdx
	or dword edx, 2 ; RDWR flag
	syscall ; call kernel
	ret

open_file_for_write: ; receives file name on rdi and return fd on rax
	mov rax, 257; syscall number for open (2)
	mov rsi, rdi
	xor rdi, rdi
	mov dword edi, [AT_FDCWD]
	mov r10, 0o644; file perms bits
	xor rdx, rdx
	mov dword edx, [O_CREAT] ; check_correct_flags
	or dword edx, [O_TRUNC] ; check_correct_flags
	or dword edx, 2
	syscall ; call kernel
	ret

lseek_syscall: ;look at the linux ABI
	mov rax, 8
	syscall

expand_heap_block: ; receive amount of bytes on rdi
	mov r12, rdi
	add rdi, [break_addr] ; new_address
	call brk_syscall
	mov [break_addr], rax
	sub rax, [heap_buffer_start_addr] 
	add rax, 1
	mov [heap_buffer_size], rax
	mov rax, [break_addr]
	ret

alloc_heap_block: ;  receive amount of bytes on rdi and expand program break
	mov r12, rdi
	call get_current_break
	mov [heap_buffer_start_addr], rax
	add rax, r12; current_break + amount_of_bytes = new_desired_break_addr
	mov rdi, rax
	call brk_syscall
	mov [break_addr], rax
	sub rax, [heap_buffer_start_addr] ; new_break - buffer_start = buffer_size - 1
	add rax, 1 ; (buffer_size - 1) + 1 = actual_buffer_size
	mov [heap_buffer_size], rax
	mov rax, [break_addr]
	ret

reset_file_pointer_to_start: ; receive file descriptor on rdi
	mov rax, 8 ;fseek syscall
	mov rsi, 0
	mov rdx, 0 ; seek_set macro value
	syscall 
	ret

read_syscall: ; fd on rdi, buf_addr on rsi and num of bytes on rdx
	mov rax, 0
	syscall
	ret

brk_syscall: ; receive addrss to ask on rdi
	mov rax, 12
	syscall
	ret

get_current_break:
	mov rdi, 0
	call brk_syscall
	ret
