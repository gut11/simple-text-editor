section .data
	extern input_char
	extern argv1
	extern argv1_length
	extern argv0_length
	extern argv0
	fd dq 8 dup(0)             ; Storage for the file descriptor
	esc_clear_screen db 0x1b, 'c', 0
	file_size db 8 dup(0)

section .text
	extern write_char_to_stdout
	extern read_args
	extern get_file_path_size
	extern print_str
	extern print_int
	extern exit_program
	extern open_file_syscall
	extern get_file_size ; receive file descriptor on rdi, returns file_size

	global  _start

_start:
	call read_args
	call get_file_path_size
	mov rdi, [argv1]
	call print_str
	AND  rsp, 0xFFFFFFFFFFFFFFF0
	mov edi, [argv1_length]
	call print_int
	; call clear_screen
	jmp  exit_program


open_file_in_editor: ; file name on rdi
	call open_file_syscall
	mov [fd], rax
	call get_file_size	
	mov [file_size], rax


allocate_file_size_times_two:
	
	

refresh_screen: ;receives new content on rdi
	call clear_screen
	ret

clear_screen:
	mov rdi, esc_clear_screen 
	call print_str
	ret
	
		
