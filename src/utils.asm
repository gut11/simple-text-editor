extern printf

section .data
	global argv1
	global argv1_length
	global argv0_length
	global argv0
	;       modes
	O_RDONLY db 0           ; read-only
	O_WRONLY db 1           ; write-only
	O_RDWR   db 2           ; read and write

	; flags
	O_CREAT  dw 100         ; create file if it doesn't exist
	O_TRUNC  dw 1000        ; truncate file
	O_APPEND dw 2000        ; append to file

	SEEK_END db 2

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


section .text
	global write_char_to_stdout
	global input_char
	global read_args
	global get_file_path_size
	global print_str
	global print_int
	global exit_program
	global open_file_syscall
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
	call printf
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

convert_num_to_ascii: ; receive num on rdi
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
	jmp .ret
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
	ret

open_file_syscall: ; receives file name on rdi and return fd
	mov     rax, 2; syscall number for open (2)
	mov     rsi, 2; flags: O_RDWR (2)
	mov rdx, [O_CREAT] ; check_correct_flags
	syscall ; call kernel
	ret

lseek_syscall: ;look at the linux ABI
	mov rax, 8
	syscall

reset_file_ptr: ;fd on rdi
	mov rsi, 0
	mov rdx, [SEEK_END]
	call lseek_syscall
	ret
	
; insert_char_on_position: ;fd on rdi, receives position on rsi,  
; 	mov r12, rsi
; 	call reset_file_ptr

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
