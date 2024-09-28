section .data
	extern input_char
	extern argv1
	extern argv1_length
	extern argv0_length
	extern argv0

	backspace db 8,0

	esc_move_home db 0x1b, '[H', 0
	esc_clear_screen db 0x1b, 'c', 0
	esc_move_up db 0x1b, '[#A', 0 ;# is number of lines
	esc_move_down db 0x1b, '[#B', 0
	esc_move_right db 0x1b, '[#C', 0
	esc_move_left db 0x1b, '[#D', 0
	esc_erase_line db 0x1b, '[2K', 0

	fd db 8 dup(0)             ; Storage for the file descriptor
	file_size db 8 dup(0)
	file_buffer_addr db 8 dup(0)
	current_key db 0
	cursor_collum db 8 dup(0)
	cursor_line db 8 dub(0)

section .text
	extern write_char_to_stdout
	extern read_args
	extern get_file_path_size
	extern print_str
	extern print_int
	extern exit_program
	extern open_file_syscall
	extern get_file_size ; receive file descriptor on rdi, returns file_size
	extern read_syscall
	extern alloc_heap_block
	extern break_line
	extern convert_num_to_ascii
	extern write_to_stdout

	global  _start

_start:
	call clear_screen
	call read_args
	call get_file_path_size
	mov rdi, [argv1]
	call print_str
	call break_line
	AND  rsp, 0xFFFFFFFFFFFFFFF0
	mov edi, [argv1_length]
	call print_int
	mov rdi, backspace
	call print_str
	mov rdi, 1
	mov rsi, 0
	call write_to_stdout
	.loop:
	jmp .loop
	jmp  exit_program


key_press_handler:
	call wait_for_input
	cmp rax, 8

handle_backspace:

handle_up:

handle_down:

handle_right:

handle_left:

	
wait_for_input:
	mov rdi, 0
	mov rsi, 1
	call read_syscall
	ret

insert_number_of_moves: ; receive str_addr on rdi, number on rsi
	mov r12, rdi
	mov rdi, rsi
	call convert_num_to_ascii
	add r12, 2 ; walk until # index
	mov byte [r12], al
	ret

erase_line:
	mov rdi, esc_erase_line
	call print_str

move_up: ; amount on rdi
	mov rsi, rdi
	mov rdi, esc_move_up
	call insert_number_of_moves
	mov rdi, esc_move_up
	call print_str
	ret
	
	
move_down:
	mov rsi, rdi
	mov rdi, esc_move_down
	call insert_number_of_moves
	mov rdi, esc_move_down
	call print_str
	ret

move_right:
	mov rsi, rdi
	mov rdi, esc_move_right
	call insert_number_of_moves
	mov rdi, esc_move_right
	call print_str
	ret

move_left:
	mov rsi, rdi
	mov rdi, esc_move_left
	call insert_number_of_moves
	mov rdi, esc_move_left
	call print_str
	ret

move_home:
	mov rdi, esc_move_home
	call print_str
	ret

clear_screen:
	mov rdi, esc_clear_screen
	call print_str
	ret

render_screen:
	call clear_screen
	
	
open_file_in_editor: ; file name on rdi
	call open_file_syscall
	mov [fd], rax
	call get_file_size	
	mov [file_size], rax
	call allocate_file_size_times_two
	call insert_file_content_on_buffer
	ret

insert_file_content_on_buffer: 
	mov rdi, [fd]
	mov rsi, [file_buffer_addr]
	mov rdx, [file_size]
	call read_syscall


allocate_file_size_times_two: ; file_size should be on file_size data var
	mov rdi, [file_size]
	add rdi, rdi;x2
	call alloc_heap_block
	mov [file_buffer_addr], rax
	ret

