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

	err_open_file db 'Error trying to open the file', 10, 0
	err_writing_to_file db 'Error writing to file', 10, 0
	err_press_any_key db 10, 10, 'Press enter to go back to file...',10, 0

	esc_move_home db 0x1b, '[H', 0
	esc_cursor_absolute_position db 0x1b, '[', 250 dup(0)  ;'[#;#H' string format
	esc_clear_screen db 0x1b, 'c', 0
	esc_move_up db 0x1b, '[1A', 0 ;# is number of lines
	esc_move_down db 0x1b, '[1B', 0
	esc_move_right db 0x1b, '[1C', 0
	esc_move_left db 0x1b, '[1D', 0
	esc_erase_line db 0x1b, '[2K', 0
	esc_background_green db 0x1b, '[42m', 0
	esc_background_red db 0x1b, '[41m', 0
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
	trash_buffer db 50 ; 50 bytes of nothing for throwing trash

	first_write db 0 ;boolean for first write

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
	extern open_file_for_read
	extern open_file_for_write

	global  _start

_start:
	call canonical_off
	call echo_off
	call clear_screen
	call read_args
	mov rdi, [argv1]
	call open_file_in_editor
	call render_screen
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

on_last_char: ;set cmp register for this comparison
	mov rax, [cursor_position_on_file]
	cmp rax, [file_buffer_addr]

; on_ghost_byte:
; 	cmp [ghost_byte], 1


fatal_error: ;receive msg on r8
	mov rdi, r8
	call print_str
	jmp exit_program

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
	cmp byte [first_write], 0
	je .open_in_truncate_mode
	.write:
	mov rdi, [fd]
	call reset_file_pointer_to_start
	cmp rax, 0
	jl .write_error
	mov rax, 1
	mov rdi, [fd]
	mov rsi, [file_buffer_addr]
	mov rdx, [file_buffer_used_bytes]
	mov [file_size], rdx
	syscall
	call blink_screen_green
	ret
	.open_in_truncate_mode:
	mov rdi, [argv1]
	call open_file_for_write
	cmp rax, 0
	jl .write_error
	mov [fd], rax
	mov byte [first_write], 1
	jmp .write
	.write_error:
	mov rdi, err_writing_to_file
	call render_error
	ret


paint_red:
	mov rdi, esc_background_red
	call print_str
	ret

paint_green:
	mov rdi, esc_background_green
	call print_str
	ret

reset_styles:
	mov rdi, esc_reset_styles 
	call print_str
	ret

blink_screen_red:
	call clear_screen
	call paint_red
	call render_without_clean
	mov qword rax, 0
	mov qword r12, 220000000
	call sleep
	call reset_styles
	call render_screen
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

	sub byte [file_buffer_used_bytes], 1
	ret

key_press_handler: ;receive_input on rax
	mov rax, current_key
	cmp byte [rax], 0x1b ;ESC byte
	je handle_arrows 
	cmp byte [rax], 0x7f ;backspace that for some reason is del byte
	je handle_backspace
	cmp byte [rax], 0x13 ;ctrl-s byte
	je write_to_file
	cmp byte [rax], 0x9 ; handle tab
	je handle_tab
	cmp byte [rax], 0x10 ;force refresh bytes
	je force_refresh
	cmp byte [rax], 0x0a ;line_break
	je handle_writable_char
	cmp byte [rax], 0x20
	jl .ret
	cmp byte [rax], 0x7e
	jg .ret
	jmp handle_writable_char
	.ret:
	ret

handle_tab:
	mov byte [current_key], 0x20
	call handle_writable_char
	call handle_writable_char
	ret

force_refresh:
	call render_screen
	call blink_screen_red
	ret
	
handle_backspace:
	mov r9, [file_buffer_used_bytes]
	mov r12, rdi
	cmp qword r9, 0
	je .ret
	cmp r9, [cursor_position_on_file]
	je .decrement_without_remove
	call remove_char_from_buffer
	; call decrement_cursor
	call render_screen
	.ret:
	ret
	.decrement_without_remove:
	; sub byte [cursor_position_on_file], 1
	; call decrement_cursor
	call render_screen
	ret

decrement_cursor: ;char on rax
	cmp qword [cursor_line], 1
	je .line_one
	.continue:

	cmp qword [cursor_collum], 1
	je .collum_zero

	; sub qword [cursor_collum], 1

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

ret_minus_one_if_last_line: ;starts from addr on rdi
	mov rsi, [file_buffer_addr]
	add rsi, [file_buffer_used_bytes]
	sub rsi, 1 ;because file_buffer_used_bytes is not an index
	mov r10, 0

	.loop:
	cmp rdi, rsi
	je .last_line
	cmp byte [rdi], 10
	je .not_last_line
	add rdi, 1
	add r10, 1
	jmp .loop

	.not_last_line:
	mov byte al, 0
	ret
	.last_line:
	mov byte al, -1
	ret


find_next_line_break: ;receive cursor_position_on_file on r9, return next line break addr on rax, distance from line_break in rsi,
	mov rax, r9

	mov rdi, [file_buffer_addr]
	add rax, rdi

	mov rsi, 0 ;length counter \n counts
	add rdi, [file_buffer_used_bytes] 
	sub rdi, 1 ;set rdi to last byte addr

	cmp byte [rax], 10
	je .treat_case_if_current_char_is_line_break
	
	.loop:
	cmp qword rax, rdi
	je .ret_last_line
	cmp byte [rax], 10
	je .ret

	add rax, 1
	add rsi, 1
	jmp .loop

	.ret_last_line:
	add rsi, 1 ;fix length for last line that has one iteration less
	ret

	.ret:
	ret

	.treat_case_if_current_char_is_line_break:
	cmp qword rax, rdi
	je .ret_last_line
	add rax, 1
	add rsi, 1
	jmp .loop


find_previous_line_break: ;receive cursor_position_on_file on r9, return previous line_break addr on rax, distance from line_break in rsi,
	mov rax, r9
	mov rdi, [file_buffer_addr]
	add rax, rdi
	mov rsi, 0 ;length counter \n counts

	cmp byte [rax], 10
	je .treat_case_if_current_char_is_line_break
	
	.loop:
	cmp qword rax, rdi
	je .ret_first_line
	cmp byte [rax], 10
	je .ret

	sub rax, 1
	add rsi, 1
	jmp .loop

	.ret_first_line:
	add rsi, 1 ;fix length for first line that has one iteration less
	ret

	.ret:
	ret

	.treat_case_if_current_char_is_line_break:
	sub rax, 1
	add rsi, 1
	jmp .loop


find_line_length: ; receive address of first char on line on rax, return length on rcx
	mov r15, [heap_buffer_start_addr]
	add r15, [file_buffer_used_bytes]
	
	mov rcx, 1

	.loop:
	cmp rax, r15
	je .ret

	cmp byte [rax], 10
	je .ret

	add rcx, 1
	add rax, 1
	jmp .loop

	.ret:
	ret

get_previous_line_size: ; return size on rax
	mov rax, [cursor_position_on_file]
	mov rdi, [file_buffer_addr]
	mov rsi, 0 ;length counter

	add rax, rdi
	sub rax, 2 ;current \n doesnt count
	
	.loop:
	cmp qword rax, rdi
	je .ret_first_line
	cmp byte [rax], 10
	je .ret

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
	jmp .ret
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
	cmp byte [cursor_line], 1
	je .ret

	mov qword r9, [cursor_position_on_file]
	call find_previous_line_break
	mov r10, rsi ;store length from current_char to line break on previous line

	sub r9, rsi ;subtract from cursor position the length to previous line break
	call find_previous_line_break ;returns on rsi with length from previous line

	mov rcx, [cursor_collum]

	.cmp:
	cmp rsi, rcx ;rsi=previous_line_length and rcx=cursor_position
	jge .move_to_line_same_or_bigger_length

	.move_to_line_less_length:
	sub [cursor_position_on_file], r10
	mov [cursor_collum], rsi
	sub byte [cursor_line], 1
	ret
	
	.move_to_line_same_or_bigger_length:
	sub [cursor_position_on_file], r10
	sub rsi, [cursor_collum]
	sub [cursor_position_on_file], rsi
	sub byte [cursor_line], 1
	ret

	.ret:
	ret

if_current_line_is_last:
	call get_current_file_buffer_position
	mov rdi, rax
	call ret_minus_one_if_last_line
	cmp byte al, -1
	ret

handle_down:
	mov qword r9, [cursor_position_on_file]
	cmp r9, [file_buffer_used_bytes]
	je .ret

	call if_current_line_is_last
	je .treat_last_line

	call find_next_line_break
	mov r10, rsi ;store length from current_char to line break

	mov rax, [file_buffer_addr]
	add rax, r9

	cmp byte [rax], 10
	je .handle_case_where_current_char_is_line_break ;if char is linebreak, next line break already is from the other line
	cmp byte [rax], 10

	add r9, rsi ;add from cursor position the length to next line break
	call find_next_line_break ;returns on rsi with length from next line

	mov rcx, [cursor_collum]

	.cmp:
	cmp rsi, rcx ;rsi=next_line_length and rcx=cursor_position
	jge .move_to_line_same_or_bigger_length

	.move_to_line_less_length:
	add [cursor_position_on_file], r10
	add [cursor_position_on_file], rsi
	mov [cursor_collum], rsi
	add byte [cursor_line], 1
	ret
	
	.move_to_line_same_or_bigger_length:
	add [cursor_position_on_file], r10
	mov rsi, [cursor_collum]
	add [cursor_position_on_file], rsi
	add byte [cursor_line], 1
	ret 

	.move_after_line_break:
	add [cursor_position_on_file], r10
	add byte [cursor_line], 1
	mov byte [cursor_collum], 1
	add byte [cursor_position_on_file], 1
	ret

	.treat_last_line:
	add r9, [file_buffer_addr]
	add r9, r10
	cmp byte [r9], 10
	je .move_after_line_break
	.ret:
	ret

	.handle_case_where_current_char_is_line_break:
	mov r10, 0 ;because we are in the line break for the next line
	mov rcx, [cursor_collum]
	jmp .cmp

handle_right:
	mov r12, [file_buffer_used_bytes]
	cmp [cursor_position_on_file], r12
	je .ret

	call get_current_file_buffer_position ;returns on rax addr on file buffer
	add qword [cursor_position_on_file], 1
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
	mov rax, [cursor_position_on_file]
	cmp byte al, 0
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
	cmp byte al, 10
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

render_error: ;receives msg on rdi
	mov r8, rdi
	call clear_screen
	mov rdi, r8
	call print_str
	mov rdi, err_press_any_key
	call print_str
	mov rsi, trash_buffer
	mov rdi, 1
	mov rdx, 10
	call read_syscall
	call render_screen
	ret

open_file_in_editor: ; file name on rdi
	call open_file_for_read
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
	cmp byte [file_size], 0
	je .ret
	mov rdi, [fd]
	call reset_file_pointer_to_start
	mov rsi, [file_buffer_addr]
	mov rdx, [file_size]
	call read_syscall
	mov [file_buffer_used_bytes], rax
	.ret
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
	
	
