section .data
    align 16
    msg db "Hello, world!", 10, 0
    msg_len equ $ - msg

    msg2 db "C the best language!", 10, 0
    msg_len2 equ $ - msg2
section .bss

section .text
    align 16
    global _start
_start:
    ; Write syscall
    mov rax, 0x02000004  ; syscall: write
    mov rdi, 1           ; file descriptor: stdout
    mov rsi, msg
    mov rdx, msg_len
    syscall

    ; Write syscall
    mov rax, 0x02000004  ; syscall: write
    mov rdi, 1           ; file descriptor: stdout
    mov rsi, msg2
    mov rdx, msg_len2
    syscall

    ; Exit syscall
    mov rax, 0x02000001  ; syscall: exit
    xor rdi, rdi         ; exit code: 0
    syscall
