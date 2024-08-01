section .bss
align 16
output:     resb 189        ; Резервирование 189 байтов для буфера вывода

section .text
align 16
global _start

_start:
    push    rbx
    mov     rdx, output
    mov     r8, 18
    xor     r9, r9

line:
    mov     byte [rdx], '/'
    inc     rdx
    inc     r9
    cmp     r9, r8
    jne     line

lineDone:
    mov     byte [rdx], 10
    inc     rdx
    dec     r8
    xor     r9, r9
    cmp     r8, 0
    jg      line

done:
    pop     rbx                     ; Восстановление значения rbx
    mov     rax, 0x02000004         ; Системный вызов для write
    mov     rdi, 1                  ; Файловый дескриптор (stdout)
    mov     rsi, output             ; Адрес буфера
    mov     rdx, 189                ; Длина буфера
    syscall                         ; Вызов системного вызова
    mov     rax, 0x02000001         ; Системный вызов для exit
    xor     rdi, rdi                ; Код возврата 0
    syscall                         ; Вызов системного вызова
