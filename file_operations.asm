section .data
	; modes
	O_RDONLY db 0           ; read-only
	O_WRONLY db 1           ; write-only
	O_RDWR   db 2           ; read and write

	; flags
	O_CREAT  dw 100         ; create file if it doesn't exist
	O_TRUNC  dw 1000        ; truncate file
	O_APPEND dw 2000        ; append to file

    filename db 'myfile.txt', 0      ; Null-terminated string for the filename
	input_char db 0
    file_descriptor dq 0              ; Storage for the file descriptor

section .text
    global _start

_start:
	jmp read_char_input
	jmp write_char_to_stdout
	jmp exit_program



exit_program:
    mov rax, 60                 ; syscall number for exit (60)
    xor rdi, rdi                ; exit code 0
    syscall                     ; call kernel

read_char_input:
	mov rax, 0
	mov rdi, 0
	mov rsi, input_char
	mov rdx, 1
	syscall ; result at rax
	mov [input_char] rax

write_char_to_stdout:
	mov rax, 1
	mov rdi, 1
	mov rsi, input_char
	mov rdx, 1
	syscall ; result at rax

read_file_path_arg:
	

open_file:
    mov rax, 2                  ; syscall number for open (2)
    lea rdi, [filename]         ; pointer to the filename
    mov rsi, 0                  ; flags: O_RDONLY (0)
    syscall                     ; call kernel


; get_str_len:
;     xor rax, rax            ; Clear rax (set length to 0)
;     xor r10, r10            ; Clear r10 (index)
;
; loop_start:
;     cmp byte [rdi + r10], 0 ; Compare byte at (rdi + r10) with 0
;     je break                ; Jump to break if it is 0
;     inc rax                 ; Increment rax (length)
;     inc r10                 ; Increment index
;     jmp loop_start          ; Jump back to the start of the loop
;
; break:
;     ret                     ; Return with length in rax
