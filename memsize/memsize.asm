section .data
    align 8
    name db "hw.memsize", 0   ; Имя параметра sysctl
    len dq 8                  ; Размер буфера для хранения значения
    msg_result db "Memory Size: ", 0
    msg_result_len equ $ - msg_result
    newline db 10             ; Новая строка для завершения вывода
    zero_msg db "Zero memory size detected", 0
    zero_msg_len equ $ - zero_msg
    error_msg db "Error in sysctlbyname call", 0
    error_msg_len equ $ - error_msg

section .bss
    align 8
    memsize resq 1            ; Буфер для хранения значения

section .text
    align 16
    global _start

_start:
    ; Загрузка указателя на имя параметра
    lea rdi, [rel name]       ; Указатель на имя параметра
    lea rsi, [rel memsize]    ; Указатель на буфер для результата
    mov rdx, [rel len]        ; Длина буфера (8 байт)
    xor r10, r10              ; Третий аргумент для sysctlbyname (не используется)
    xor r8, r8                ; Четвертый аргумент для sysctlbyname (не используется)

    ; Вызов sysctlbyname
    mov rax, 0x2000000 + 203  ; SYS_sysctlbyname (номер системного вызова для macOS)
    syscall                   ; Вызов системного вызова

    ; Проверка ошибки
    cmp rax, 0
    jl error_exit

    ; Вывод возвратного значения системного вызова
    mov rdi, 1                ; stdout
    mov rsi, rax              ; возвратное значение системного вызова
    mov rdx, 8                ; выводим 8 байт
    mov rax, 0x2000004        ; write(1, ...)
    syscall

    ; Проверка значения memsize
    mov rax, [rel memsize]
    cmp rax, 0
    je zero_memory_size

    ; Вывод сообщения "Memory Size: "
    mov rax, 0x2000004        ; write(1, ...)
    mov rdi, 1                ; stdout
    mov rsi, msg_result       ; указатель на сообщение
    mov rdx, msg_result_len   ; длина сообщения
    syscall

    ; Преобразование числа в строку для вывода
    mov rax, [rel memsize]
    call print_number

    ; Вывод новой строки
    mov rax, 0x2000004        ; write(1, ...)
    mov rdi, 1                ; stdout
    mov rsi, newline          ; указатель на символ новой строки
    mov rdx, 1                ; длина строки
    syscall

    ; Выход из программы
    mov rax, 0x2000001        ; exit(0)
    xor rdi, rdi
    syscall

zero_memory_size:
    ; Вывод сообщения о нулевом значении
    mov rax, 0x2000004        ; write(1, ...)
    mov rdi, 1                ; stdout
    mov rsi, zero_msg         ; указатель на сообщение
    mov rdx, zero_msg_len     ; длина сообщения
    syscall

    ; Выход из программы
    mov rax, 0x2000001        ; exit(1)
    mov rdi, 1
    syscall

error_exit:
    ; Вывод сообщения об ошибке
    mov rax, 0x2000004        ; write(1, ...)
    mov rdi, 1                ; stdout
    mov rsi, error_msg        ; указатель на сообщение
    mov rdx, error_msg_len    ; длина сообщения
    syscall

    ; Выход из программы
    mov rax, 0x2000001        ; exit(1)
    mov rdi, 1
    syscall

print_number:
    push rax
    mov rcx, 10
    xor rdx, rdx
    sub rsp, 64               ; Выделяем место на стеке для строки (максимальная длина строки)
    mov rbx, rsp              ; Сохраняем указатель на начало строки

.print_loop:
    div rcx
    add dl, '0'
    dec rbx
    mov [rbx], dl
    test rax, rax
    jnz .print_loop

    ; Вывод строки
    mov rax, 0x2000004        ; write(1, ...)
    mov rdi, 1                ; stdout
    mov rsi, rbx              ; указатель на начало строки
    mov rdx, rsp
    sub rdx, rbx              ; длина строки
    syscall

    ; Очистка стека
    add rsp, 64               ; Освобождаем место на стеке
    pop rax
    ret