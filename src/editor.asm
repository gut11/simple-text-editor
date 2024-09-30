section .data
	extern input_char
	extern argv1
	extern argv1_length
	extern argv0_length
	extern argv0
	extern line_str_num
	extern collum_str_num

	backspace db 8,0
	open_bracket db 0x5b, 0

	test_str db 500 dup(0), 10, 0

	esc_move_home db 0x1b, '[H', 0
	esc_cursor_absolute_position db 0x1b, '[', 250 dup(0)  ;'[#;#H' string format
	esc_clear_screen db 0x1b, 'c', 0
	esc_move_up db 0x1b, '[1A', 0 ;# is number of lines
	esc_move_down db 0x1b, '[1B', 0
	esc_move_right db 0x1b, '[1C', 0
	esc_move_left db 0x1b, '[1D', 0
	esc_erase_line db 0x1b, '[2K', 0
	esc_background_green db 0x1b, '[42m', 0
	esc_reset_styles db 0x1b, '[0m', 0

	fd db 8 dup(0)             ; Storage for the file descriptor
	file_size db 8 dup(0)
	file_buffer_addr db 8 dup(0)
	file_buffer_used_bytes db 8 dup(0)
	buffer_resize_threshold db 8 dup(0)
	min_initial_allocation dq 4096
	current_key db 8 dup(0)
	cursor_collum db 1 ,7 dup(0)
	cursor_line db 1, 7 dup(0)
	cursor_position_on_file db 8 dup(0)

	timeval:
	tv_sec  dq 1
    tv_nsec dq 200000000

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
	extern heap_buffer_size
	extern expand_heap_block
	extern canonical_off
	extern echo_off
	extern heap_buffer_start_addr
	extern reset_file_pointer_to_start

	global  _start

_start:
	; call clear_screen
	; call read_args
	; call get_file_path_size
	; mov rdi, [argv1]
	; call print_str
	; call break_line
	; AND  rsp, 0xFFFFFFFFFFFFFFF0
	; mov edi, [argv1_length]
	; call print_int
	; mov rdi, backspace
	; call print_str
	; mov rdi, 1
	; mov rsi, 0
	; call write_to_stdout
		; mov rdi, 77652
		; mov rsi, test_str
		; call convert_num_to_ascii test
		; mov rdi, rax
		; call print_str
		; jmp exit_program

	call canonical_off
	call echo_off
	call clear_screen
	call read_args
	mov rdi, [argv1]
	call open_file_in_editor
	call render_screen
	; call move_home
	.loop:
	call wait_for_input
	call key_press_handler
	jmp .loop
	jmp  exit_program

move_chars_one_position_right: ;*buffer on rdi, buffer_content_size on rsi, start_index on rdx
	cmp rdx, rsi
	jg .break
	mov r15, 0 ; previous_char, starts null
	mov r14, 0 ;loop_counter
	mov r12, rsi
	sub r12, rdx ; buffer_content_size - start_index = remaining_index
	mov r13, rdx
	add r13, rdi ;r13 = *current_char

	.loop:
	cmp r14, r12
	jg .break

	mov byte dl, [r13] ;temp_var for current_char
	mov byte [r13], r15b ; substitute_current_char by old
	mov byte r15b, dl ; change old previous_char for new one

	add r13, 1
	add r14, 1
	jmp .loop

	.break:
	ret

move_chars_one_position_left: ;*buffer on rdi, buffer_content_size on rsi, start_index on rdx
	cmp rdx, rsi
	jg .break

	mov r15, 0 ; previous_char, starts null
	mov r14, 0 ;loop_counter
	mov r12, rsi

	sub r12, rdx ; buffer_content_size - start_index = remaining_index

	mov r13, rdx
	add r13, rdi ;r13 = *current_char

	.loop:
	cmp r14, r12
	jg .break

	mov byte r15b, [r13 + 1]; next_char
	mov byte [r13], r15b ; substitute_current_char by next

	add r13, 1
	add r14, 1
	jmp .loop

	.break:
	ret


write_to_file:
	mov rdi, [fd]
	call reset_file_pointer_to_start
	mov rax, 1
	mov rdi, [fd]
	mov rsi, [file_buffer_addr]
	mov rdx, [file_buffer_used_bytes]
	mov [file_size], rdx
	syscall
	call blink_screen_green
	ret

paint_green:
	mov rdi, esc_background_green
	call print_str
	ret

reset_styles:
	mov rdi, esc_reset_styles 
	call print_str
	ret
	
blink_screen_green:
	call clear_screen
	call paint_green
	call render_without_clean
	mov qword rax, 0
	mov qword r12, 220000000
	call sleep
	call reset_styles
	call render_screen
	ret
	

sleep: ; seconds on rax, ns on r12
	mov qword [tv_sec], rax
	mov qword [tv_nsec], r12
	mov qword rax, 35
	mov rdi, timeval
	xor rsi, rsi
	syscall
	ret



insert_new_char_on_buffer: ;receive char to insert on rdi
	push rdi
	mov rdi, [file_buffer_addr]
	mov rsi, [file_buffer_used_bytes]
	mov rdx, [cursor_position_on_file]
	call move_chars_one_position_right
	mov r12, [file_buffer_addr]
	add r12, [cursor_position_on_file]
	pop r13
	mov byte [r12], r13b ;insert char on buffer
	ret

remove_char_from_buffer:
	mov rdi, [file_buffer_addr]
	mov rsi, [file_buffer_used_bytes]
	mov rdx, [cursor_position_on_file]
	call move_chars_one_position_left

	cmp qword [cursor_position_on_file], 0
	jg .sub_position
	sub byte [file_buffer_used_bytes], 1
	ret

	.sub_position:
	sub qword [cursor_position_on_file], 1
	ret
	

key_press_handler: ;receive_input on rax
	mov rax, current_key
	cmp byte [rax], 0x13 ;ctrl bytes
	je write_to_file
	cmp byte [rax], 0x1b ;ESC byte
	je handle_arrows 
	cmp byte [rax], 0x7f ;backspace that for some reason is del byte
	je handle_backspace
	jmp handle_writable_char
	
handle_backspace:
	mov r12, rdi
	cmp qword [file_buffer_used_bytes], 1
	jl .ret
	call remove_char_from_buffer
	call decrement_cursor
	call render_screen
	.ret:
	ret
	; .sub_used_size:
	; jmp .render

decrement_cursor: ;char on rax
	cmp qword [cursor_line], 1
	je .line_one
	.continue:

	cmp qword [cursor_collum], 1
	je .collum_zero

	sub qword [cursor_collum], 1

	.ret:
	ret

	.collum_zero:
	call get_previous_line_size
	add rax, 1 ;\n removed but cannot be rendered
	sub qword [cursor_line], 1
	mov qword [cursor_collum], rax
	ret

	.line_one:
	cmp qword [cursor_collum], 1
	je .ret
	jmp .continue


get_previous_line_size: ; return size on rax
	mov rax, [cursor_position_on_file]
	mov rdi, [file_buffer_addr]
	mov rsi, 0 ;length counter

	add rax, rdi
	sub rax, 1 ;current \n doesnt count
	
	.loop:
	cmp byte [rax], 10
	je .ret
	cmp qword rax, rdi
	je .ret_first_line

	sub rax, 1
	add rsi, 1

	jmp .loop

	.ret_first_line:
	mov rax, rsi
	add rax, 1 ;for the \n from previous line that is missing in the first line
	ret

	.ret:
	mov rax, rsi
	ret

get_current_file_buffer_position:
	mov rax, [cursor_position_on_file]
	mov rdi, [file_buffer_addr]
	add rax, rdi
	ret

handle_arrows: ;;receive arrow on open bracket byte on rdi
	add rax, 2 ; move to letter
	cmp byte [rax], 'A'
	je .up
	cmp byte [rax], 'B'
	je .down
	cmp byte [rax], 'C'
	je .right
	cmp byte [rax], 'D'
	je .left
	.up:
	call handle_up
	jmp .ret
	.down:
	call handle_down
	jmp .ret
	.right:
	call handle_right
	jmp .ret
	.left:
	call handle_left

	.ret:
	call render_screen
	ret


handle_up:
	mov rdi, 1
	call move_up
	ret

handle_down:
	mov rdi, 1
	call move_down
	ret

handle_right:
	mov r12, [file_buffer_used_bytes]
	cmp [cursor_position_on_file], r12
	je .ret

	add qword [cursor_position_on_file], 1

	call get_current_file_buffer_position ;returns on rax addr on file buffer
	cmp byte [rax], 10
	je .move_to_next_line

	add qword [cursor_collum], 1
	jmp .ret

	.move_to_next_line:
	mov qword [cursor_collum], 1
	add qword [cursor_line], 1
	.ret:
	ret

handle_left:
	cmp byte [cursor_position_on_file], 0
	je .ret

	; call get_current_file_buffer_position ;returns on rax addr on file buffer
	cmp byte [cursor_collum], 1
	je .move_to_previous_line

	sub qword [cursor_collum], 1
	jmp .ret_subtract

	.move_to_previous_line:
	call get_previous_line_size
	add rax, 1 ;move to \n not last char
	mov qword [cursor_collum], rax
	sub qword [cursor_line], 1
	.ret_subtract:
	sub qword [cursor_position_on_file], 1
	.ret:
	ret

handle_writable_char: ; current_key variable on memory
	add qword [file_buffer_used_bytes], 1
	call resize_buffer_if_necessary
	mov rdi, [current_key]
	call insert_new_char_on_buffer
	mov rax, [current_key]
	call increment_cursor
	add qword [cursor_position_on_file], 1
	call render_screen
	ret

increment_cursor: ;char on rax
	cmp rax, 10
	jne .increment_collum
	add qword [cursor_line], 1
	mov qword [cursor_collum], 1
	jmp .ret
	.increment_collum:
	add qword [cursor_collum], 1
	.ret:
	ret


move_terminal_cursor_to_position:
	call insert_numbers_on_esc_string
	mov rdi, esc_cursor_absolute_position
	call print_str
	ret

insert_numbers_on_esc_string:
	mov rdi, [cursor_line]
	mov rsi, line_str_num
	call convert_num_to_ascii
	mov r12, esc_cursor_absolute_position
	add r12, 2 ; move to first num place
	call insert_nums_on_esc_string
	mov byte [r12], 0x3b ;insert ';' on esc_string
	add r12, 1
	mov rdi, [cursor_collum]
	mov rsi, collum_str_num
	push r12 ;save r12
	call convert_num_to_ascii
	pop r12
	call insert_nums_on_esc_string
	mov byte [r12], 0x48 ; insert H on esc_str
	add r12, 1
	mov byte [r12], 0 ;null terminate
	ret

insert_nums_on_esc_string: ;esc_str on r12 and number_str on rax
	.loop:
	cmp byte [rax], 0
	je .ret

	mov byte r11b, [rax]
	mov byte [r12], r11b

	add rax, 1
	add r12, 1

	jmp .loop
	.ret:
	ret


resize_buffer_if_necessary: 
	mov rdi, [buffer_resize_threshold]
	cmp [file_buffer_used_bytes], rdi
	jge .resize
	ret
	.resize:
	mov rdi, [heap_buffer_size]
	add rdi, rdi
	call expand_heap_block
	mov rdi, [heap_buffer_size]
	call set_buffer_threshold
	ret

add_char_on_file_buffer: ; receive_char on rdi, index on rsi
	mov r13, [file_buffer_addr]
	add r13, rsi ; add offset

set_buffer_threshold: ;receive buffer_size on rdi, and set threshold on var TODO set on buffer creation
	sub rdi, 100
	mov [buffer_resize_threshold], rdi
	ret

wait_for_input: ;fill current_key buffer
	mov rdi, 0
	mov rsi, current_key
	mov rdx, 20 ;read everything, shouldnt be more than 20 bytes in an input
	call read_syscall
	ret

insert_number_of_moves_on_esc: ; receive str_addr on rdi, number on rsi
	mov rsi, rdi
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
	call insert_number_of_moves_on_esc
	mov rdi, esc_move_up
	call print_str
	ret
	
	
move_down:
	mov rsi, rdi
	mov rdi, esc_move_down
	call insert_number_of_moves_on_esc
	mov rdi, esc_move_down
	call print_str
	ret

move_right:
	mov rsi, rdi
	mov rdi, esc_move_right
	call insert_number_of_moves_on_esc
	mov rdi, esc_move_right
	call print_str
	ret

move_left:
	mov rsi, rdi
	mov rdi, esc_move_left
	call insert_number_of_moves_on_esc
	mov rdi, esc_move_left
	call print_str
	ret

move_home:
	mov rdi, esc_move_home
	call print_str
	mov qword [cursor_position_on_file], 0
	mov qword [cursor_line], 0
	mov qword [cursor_collum], 0
	ret

clear_screen:
	mov rdi, esc_clear_screen
	call print_str
	ret

render_screen:
	call clear_screen
	mov rsi, [file_buffer_addr]
	mov rdx,[file_buffer_used_bytes]
	call write_to_stdout
	call move_terminal_cursor_to_position
	ret

render_without_clean:
	mov rsi, [file_buffer_addr]
	mov rdx,[file_buffer_used_bytes]
	call write_to_stdout
	call move_terminal_cursor_to_position
	ret
	
open_file_in_editor: ; file name on rdi
	call open_file_syscall
	mov [fd], rax
	mov rdi, rax
	call get_file_size	
	mov [file_size], rax
	call allocate_file_size_times_two
	mov rdi, [heap_buffer_size]
	call set_buffer_threshold
	call insert_file_content_on_buffer
	ret

insert_file_content_on_buffer: 
	mov rdi, [fd]
	call reset_file_pointer_to_start
	mov rsi, [file_buffer_addr]
	mov rdx, [file_size]
	call read_syscall
	mov [file_buffer_used_bytes], rax
	ret


allocate_file_size_times_two: ; file_size should be on file_size data var
	call find_first_time_allocation_size
	call alloc_heap_block
	mov rax, [heap_buffer_start_addr]
	mov [file_buffer_addr], rax
	ret


find_first_time_allocation_size: ; file_size on file_size var, returns on rdi
	mov rdi, [file_size]
	mov r12, [min_initial_allocation]
	cmp r12, rdi
	jge .return_min_allocation
	add rdi, rdi
	ret
	.return_min_allocation:
	mov rdi, r12
	ret
	
	
