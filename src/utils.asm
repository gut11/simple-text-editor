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

	input_char db 100 dup(0)
	int_specifier db 'int: %i', 10, 0
	str_specifier db 'int: %s', 10, 0
	argv0 db 8 dup(0)
	argv0_length db 4 dup(0)
	argv1 db 8 dup(0)
	argv1_length db 4 dup(0)


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

expand_heap_block:
	

alloc_heap_block: ;Receive number of bytes on rdi, allocate with mmap, returns address
	mov rsi, rdi ;insert param num bytes on rsi	
	mov rax, 9 ;mmap syscall number
	mov rdi, 0 ;null for address so kernel can choose address
	mov rdx, 0x0000000000000111 ; flags of read write and execute permission
	mov r10, 0x0000000000000020 ; Anonymous flag for not linking memory to any file
	syscall
	ret

open_file_syscall: ; receives file name on rdi and return fd
	mov     rax, 2; syscall number for open (2)
	mov     rsi, 0; flags: O_RDONLY (0)
	syscall ; call kernel
	ret

	; get_str_len:
	; xor rax, rax; Clear rax (set length to 0)
	; xor r10, r10; Clear r10 (index)
	
	; loop_start:
	; cmp byte [rdi + r10], 0; Compare byte at (rdi + r10) with 0
	; je break; Jump to break if it is 0
	; inc rax; Increment rax (length)
	; inc r10; Increment index
	; jmp loop_start; Jump back to the start of the loop
	
	; break:
	; ret; Return with length in rax

	; paddd xmm0, [rsp]
	; MOVAPS xmm1, xmm2
	; movaps xmm1, [rsp - 1]
