DEFAULT REL

section .bss
termios:        resb 36

stdin_fd:       equ 0           ; STDIN_FILENO
ICANON:         equ 1<<1
ECHO:           equ 1<<3

section .text
global canonical_off
global echo_off

canonical_off:
        call read_stdin_termios

        ; clear canonical bit in local mode flags
        and dword [termios+12], ~ICANON

        call write_stdin_termios
        ret

echo_off:
        call read_stdin_termios

        ; clear echo bit in local mode flags
        and dword [termios+12], ~ECHO

        call write_stdin_termios
        ret

canonical_on:
        call read_stdin_termios

        ; set canonical bit in local mode flags
        or dword [termios+12], ICANON

        call write_stdin_termios
        ret

echo_on:
        call read_stdin_termios

        ; set echo bit in local mode flags
        or dword [termios+12], ECHO

        call write_stdin_termios
        ret

; clobbers RAX, RCX, RDX, R8..11 (by int 0x80 in 64-bit mode)
; allowed by x86-64 System V calling convention    
read_stdin_termios:
        push rbx

        mov rax, 36h
        mov ebx, stdin_fd
        mov ecx, 5401h
        mov edx, termios
        int 80h            ; ioctl(0, 0x5401, termios)

        pop rbx
        ret

write_stdin_termios:
        push rbx

        mov rax, 36h
        mov ebx, stdin_fd
        mov ecx, 5402h
        mov edx, termios
        int 80h            ; ioctl(0, 0x5402, termios)

        pop rbx
        ret
