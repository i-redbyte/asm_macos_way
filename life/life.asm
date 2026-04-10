default rel

%define SDL_INIT_VIDEO      0x00000020
%define SDL_QUIT_EVENT      0x00000100

%define SC_A                4
%define SC_D                7
%define SC_S                22
%define SC_W                26
%define SC_ESCAPE           41
%define SC_SPACE            44
%define SC_MINUS            45
%define SC_EQUALS           46
%define SC_RIGHT            79
%define SC_LEFT             80
%define SC_DOWN             81
%define SC_UP               82

%define WINDOW_WIDTH        1280
%define WINDOW_HEIGHT       720
%define WINDOW_HALF_WIDTH   640
%define WINDOW_HALF_HEIGHT  360
%define STEP_DELAY_MS       100
%define INITIAL_CELL_SIZE   12
%define MIN_CELL_SIZE       2
%define MAX_CELL_SIZE       48

%macro STORE_NEIGHBOR 2
    mov eax, %1
    shl rax, 32
    mov edx, %2
    or rax, rdx
    mov [r15], rax
    add r15, 8
%endmacro

extern _printf
extern _scanf
extern _snprintf
extern _fflush
extern _srand
extern _rand
extern _time
extern _qsort
extern _realloc
extern _free

extern _SDL_Init
extern _SDL_Quit
extern _SDL_GetError
extern _SDL_CreateWindow
extern _SDL_DestroyWindow
extern _SDL_SetWindowTitle
extern _SDL_CreateRenderer
extern _SDL_DestroyRenderer
extern _SDL_PollEvent
extern _SDL_PumpEvents
extern _SDL_GetKeyboardState
extern _SDL_SetRenderDrawColor
extern _SDL_RenderClear
extern _SDL_RenderDrawLine
extern _SDL_RenderFillRect
extern _SDL_RenderPresent
extern _SDL_GetTicks64
extern _SDL_Delay

global _main

section .data
window_title        db "ASM Conway Life", 0
prompt_msg          db "Initial live cells: ", 0
input_fmt           db "%lld", 0
invalid_msg         db "Please enter a positive integer.", 10, 0
alloc_msg           db "Out of memory.", 10, 0
sdl_init_fmt        db "SDL init failed: %s", 10, 0
window_fail_fmt     db "Window creation failed: %s", 10, 0
renderer_fail_fmt   db "Renderer creation failed: %s", 10, 0
title_fmt           db "ASM Conway Life | gen %llu | live %llu | %s", 0
status_paused       db "PAUSED", 0
status_running      db "RUN", 0

section .bss
initial_cells       resq 1
spawn_span          resd 1

live_ptr            resq 1
live_len            resq 1
live_cap            resq 1

next_ptr            resq 1
next_len            resq 1
next_cap            resq 1

candidates_ptr      resq 1
candidates_cap      resq 1

window_ptr          resq 1
renderer_ptr        resq 1

camera_x            resq 1
camera_y            resq 1
generation          resq 1
last_step_ticks     resq 1

cell_size           resd 1
app_running         resb 1
sim_running         resb 1
space_prev          resb 1
plus_prev           resb 1
minus_prev          resb 1

event_buffer        resb 64
cell_rect           resd 4
title_buffer        resb 128

section .text
_main:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    call read_initial_count
    test eax, eax
    jz .failure

    xor edi, edi
    call _time
    mov edi, eax
    call _srand

    call populate_initial_cells
    test eax, eax
    jz .failure

    mov edi, SDL_INIT_VIDEO
    call _SDL_Init
    test eax, eax
    jnz .sdl_init_failed

    lea rdi, [rel window_title]
    mov esi, 100
    mov edx, 100
    mov ecx, WINDOW_WIDTH
    mov r8d, WINDOW_HEIGHT
    xor r9d, r9d
    call _SDL_CreateWindow
    test rax, rax
    jz .window_failed
    mov [rel window_ptr], rax

    mov rdi, rax
    mov esi, -1
    xor edx, edx
    call _SDL_CreateRenderer
    test rax, rax
    jz .renderer_failed
    mov [rel renderer_ptr], rax

    mov byte [rel app_running], 1
    mov byte [rel sim_running], 1
    call _SDL_GetTicks64
    mov [rel last_step_ticks], rax
    call update_window_title

.main_loop:
    cmp byte [rel app_running], 0
    je .shutdown

    call process_events
    call handle_keyboard

    cmp byte [rel app_running], 0
    je .shutdown

    call maybe_step_simulation
    call render_world

    mov edi, 16
    call _SDL_Delay
    jmp .main_loop

.sdl_init_failed:
    lea rdi, [rel sdl_init_fmt]
    call print_sdl_error
    jmp .failure

.window_failed:
    lea rdi, [rel window_fail_fmt]
    call print_sdl_error
    jmp .failure

.renderer_failed:
    lea rdi, [rel renderer_fail_fmt]
    call print_sdl_error
    jmp .failure

.shutdown:
    call cleanup
    xor eax, eax
    leave
    ret

.failure:
    call cleanup
    mov eax, 1
    leave
    ret

read_initial_count:
    push rbp
    mov rbp, rsp
    sub rsp, 16

    lea rdi, [rel prompt_msg]
    xor eax, eax
    call _printf

    xor edi, edi
    call _fflush

    lea rdi, [rel input_fmt]
    lea rsi, [rel initial_cells]
    xor eax, eax
    call _scanf
    cmp eax, 1
    jne .invalid

    mov rax, [rel initial_cells]
    cmp rax, 1
    jl .invalid

    call compute_spawn_span

.store_span:
    mov [rel spawn_span], eax
    mov eax, 1
    leave
    ret

.invalid:
    lea rdi, [rel invalid_msg]
    xor eax, eax
    call _printf
    xor eax, eax
    leave
    ret

compute_spawn_span:
    push rbp
    mov rbp, rsp

    mov rcx, [rel initial_cells]
    mov eax, 1

.root_loop:
    mov edx, eax
    imul rdx, rdx
    cmp rdx, rcx
    jae .apply_minimum
    inc eax
    jmp .root_loop

.apply_minimum:
    cmp eax, 16
    jge .done
    mov eax, 16

.done:
    pop rbp
    ret

populate_initial_cells:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    lea rdi, [rel live_ptr]
    lea rsi, [rel live_cap]
    mov rdx, [rel initial_cells]
    call ensure_capacity
    test eax, eax
    jz .fail

    xor rbx, rbx
    mov r12, [rel initial_cells]

.generate_loop:
    cmp rbx, r12
    jae .done_generating

    call random_key
    mov r8, [rel live_ptr]
    xor r9, r9

.scan_duplicates:
    cmp r9, rbx
    jae .store_key
    cmp rax, [r8 + r9 * 8]
    je .generate_loop
    inc r9
    jmp .scan_duplicates

.store_key:
    mov [r8 + rbx * 8], rax
    inc rbx
    jmp .generate_loop

.done_generating:
    mov [rel live_len], rbx

    mov rdi, [rel live_ptr]
    mov rsi, rbx
    mov edx, 8
    lea rcx, [rel compare_u64]
    call _qsort

    mov qword [rel camera_x], 0
    mov qword [rel camera_y], 0
    mov qword [rel generation], 0
    mov dword [rel cell_size], INITIAL_CELL_SIZE
    mov byte [rel space_prev], 0
    mov byte [rel plus_prev], 0
    mov byte [rel minus_prev], 0

    mov eax, 1
    pop r12
    pop rbx
    pop rbp
    ret

.fail:
    lea rdi, [rel alloc_msg]
    xor eax, eax
    call _printf
    xor eax, eax
    pop r12
    pop rbx
    pop rbp
    ret

random_key:
    push rbp
    mov rbp, rsp
    sub rsp, 16

    mov eax, [rel spawn_span]
    mov [rbp - 8], eax
    lea eax, [rax + rax + 1]
    mov [rbp - 12], eax

    call _rand
    mov ecx, [rbp - 12]
    xor edx, edx
    div ecx
    mov eax, edx
    sub eax, [rbp - 8]
    mov [rbp - 4], eax

    call _rand
    mov ecx, [rbp - 12]
    xor edx, edx
    div ecx
    mov eax, edx
    sub eax, [rbp - 8]
    mov edx, eax

    mov eax, [rbp - 4]
    shl rax, 32
    or rax, rdx

    leave
    ret

ensure_capacity:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14

    mov rbx, rdi
    mov r12, rsi
    mov r13, [r12]
    cmp r13, rdx
    jae .ok

    cmp r13, 64
    jae .grow_loop
    mov r13, 64

.grow_loop:
    cmp r13, rdx
    jae .allocate
    add r13, r13
    jmp .grow_loop

.allocate:
    mov rdi, [rbx]
    mov rsi, r13
    shl rsi, 3
    call _realloc
    test rax, rax
    jz .fail

    mov [rbx], rax
    mov [r12], r13

.ok:
    mov eax, 1
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.fail:
    xor eax, eax
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

process_events:
    push rbp
    mov rbp, rsp

.event_loop:
    lea rdi, [rel event_buffer]
    call _SDL_PollEvent
    test eax, eax
    jz .done

    cmp dword [rel event_buffer], SDL_QUIT_EVENT
    jne .event_loop
    mov byte [rel app_running], 0
    jmp .event_loop

.done:
    pop rbp
    ret

handle_keyboard:
    push rbp
    mov rbp, rsp

    call _SDL_PumpEvents
    xor edi, edi
    call _SDL_GetKeyboardState
    mov r8, rax

    cmp byte [r8 + SC_ESCAPE], 0
    je .space_toggle
    mov byte [rel app_running], 0

.space_toggle:
    movzx eax, byte [r8 + SC_SPACE]
    cmp byte [rel space_prev], 0
    jne .update_space
    test eax, eax
    jz .update_space
    mov dl, [rel sim_running]
    xor dl, 1
    mov [rel sim_running], dl
    call update_window_title

.update_space:
    mov [rel space_prev], al

    movzx eax, byte [r8 + SC_EQUALS]
    cmp byte [rel plus_prev], 0
    jne .store_plus
    test eax, eax
    jz .store_plus
    mov ecx, [rel cell_size]
    cmp ecx, MAX_CELL_SIZE
    jge .store_plus
    add ecx, 2
    mov [rel cell_size], ecx

.store_plus:
    mov [rel plus_prev], al

    movzx eax, byte [r8 + SC_MINUS]
    cmp byte [rel minus_prev], 0
    jne .store_minus
    test eax, eax
    jz .store_minus
    mov ecx, [rel cell_size]
    cmp ecx, MIN_CELL_SIZE
    jle .store_minus
    sub ecx, 2
    cmp ecx, MIN_CELL_SIZE
    jge .minus_ok
    mov ecx, MIN_CELL_SIZE
.minus_ok:
    mov [rel cell_size], ecx

.store_minus:
    mov [rel minus_prev], al

    cmp byte [r8 + SC_A], 0
    jne .move_left
    cmp byte [r8 + SC_LEFT], 0
    je .move_right_check
.move_left:
    mov rax, [rel camera_x]
    dec rax
    mov [rel camera_x], rax

.move_right_check:
    cmp byte [r8 + SC_D], 0
    jne .move_right
    cmp byte [r8 + SC_RIGHT], 0
    je .move_up_check
.move_right:
    mov rax, [rel camera_x]
    inc rax
    mov [rel camera_x], rax

.move_up_check:
    cmp byte [r8 + SC_W], 0
    jne .move_up
    cmp byte [r8 + SC_UP], 0
    je .move_down_check
.move_up:
    mov rax, [rel camera_y]
    dec rax
    mov [rel camera_y], rax

.move_down_check:
    cmp byte [r8 + SC_S], 0
    jne .move_down
    cmp byte [r8 + SC_DOWN], 0
    je .done
.move_down:
    mov rax, [rel camera_y]
    inc rax
    mov [rel camera_y], rax

.done:
    pop rbp
    ret

maybe_step_simulation:
    push rbp
    mov rbp, rsp
    sub rsp, 16

    cmp byte [rel sim_running], 0
    je .done

    call _SDL_GetTicks64
    mov [rbp - 8], rax
    mov rdx, rax
    sub rdx, [rel last_step_ticks]
    cmp rdx, STEP_DELAY_MS
    jb .done

    mov rax, [rbp - 8]
    mov [rel last_step_ticks], rax
    call simulate_generation
    test eax, eax
    jnz .advance_generation

    lea rdi, [rel alloc_msg]
    xor eax, eax
    call _printf
    mov byte [rel app_running], 0
    jmp .done

.advance_generation:
    inc qword [rel generation]
    call update_window_title

.done:
    leave
    ret

simulate_generation:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8

    mov r12, [rel live_len]
    test r12, r12
    jnz .prepare_buffers
    mov qword [rel next_len], 0
    mov eax, 1
    jmp .finish

.prepare_buffers:
    mov rdx, r12
    shl rdx, 3

    lea rdi, [rel candidates_ptr]
    lea rsi, [rel candidates_cap]
    call ensure_capacity
    test eax, eax
    jz .fail

    mov rdx, r12
    shl rdx, 3
    lea rdi, [rel next_ptr]
    lea rsi, [rel next_cap]
    call ensure_capacity
    test eax, eax
    jz .fail

    mov rbx, [rel live_ptr]
    mov r13, [rel candidates_ptr]
    mov r15, r13
    xor r14, r14

.candidate_loop:
    cmp r14, r12
    jae .sort_candidates

    mov r8d, dword [rbx + r14 * 8 + 4]
    mov r9d, dword [rbx + r14 * 8]

    mov r10d, r8d
    dec r10d
    mov r11d, r9d
    dec r11d
    STORE_NEIGHBOR r10d, r11d
    STORE_NEIGHBOR r8d, r11d
    mov r10d, r8d
    inc r10d
    STORE_NEIGHBOR r10d, r11d

    mov r10d, r8d
    dec r10d
    STORE_NEIGHBOR r10d, r9d
    mov r10d, r8d
    inc r10d
    STORE_NEIGHBOR r10d, r9d

    mov r11d, r9d
    inc r11d
    mov r10d, r8d
    dec r10d
    STORE_NEIGHBOR r10d, r11d
    STORE_NEIGHBOR r8d, r11d
    mov r10d, r8d
    inc r10d
    STORE_NEIGHBOR r10d, r11d

    inc r14
    jmp .candidate_loop

.sort_candidates:
    mov rdi, [rel candidates_ptr]
    mov rsi, r12
    shl rsi, 3
    mov edx, 8
    lea rcx, [rel compare_u64]
    call _qsort

    mov rbx, [rel candidates_ptr]
    mov r13, [rel live_ptr]
    mov r14, [rel live_len]
    mov r15, [rel next_ptr]
    xor r8, r8
    xor r9, r9
    mov r12, [rel live_len]
    shl r12, 3

.scan_candidates:
    cmp r8, r12
    jae .store_next_len

    mov r10, [rbx + r8 * 8]
    mov ecx, 1
    inc r8

.count_duplicates:
    cmp r8, r12
    jae .evaluate
    cmp r10, [rbx + r8 * 8]
    jne .evaluate
    inc ecx
    inc r8
    jmp .count_duplicates

.evaluate:
    cmp r9, r14
    jae .check_rules

.advance_live:
    cmp r9, r14
    jae .check_rules
    mov rax, [r13 + r9 * 8]
    cmp rax, r10
    jb .live_next
    jmp .check_rules

.live_next:
    inc r9
    jmp .advance_live

.check_rules:
    xor edx, edx
    cmp r9, r14
    jae .apply_rules
    cmp r10, [r13 + r9 * 8]
    jne .apply_rules
    mov edx, 1

.apply_rules:
    cmp ecx, 3
    je .keep_cell
    cmp ecx, 2
    jne .scan_candidates
    test edx, edx
    jz .scan_candidates

.keep_cell:
    mov [r15], r10
    add r15, 8
    jmp .scan_candidates

.store_next_len:
    mov rax, r15
    sub rax, [rel next_ptr]
    shr rax, 3
    mov [rel next_len], rax

    mov rcx, [rel next_len]

    mov rax, [rel live_ptr]
    mov rdx, [rel next_ptr]
    mov [rel live_ptr], rdx
    mov [rel next_ptr], rax

    mov rax, [rel live_cap]
    mov rdx, [rel next_cap]
    mov [rel live_cap], rdx
    mov [rel next_cap], rax

    mov rax, [rel live_len]
    mov [rel next_len], rax
    mov [rel live_len], rcx

    mov eax, 1
    jmp .finish

.fail:
    xor eax, eax

.finish:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

render_world:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14

    mov rdi, [rel renderer_ptr]
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    mov r8d, 255
    call _SDL_SetRenderDrawColor

    mov rdi, [rel renderer_ptr]
    call _SDL_RenderClear

    call render_grid

    mov rdi, [rel renderer_ptr]
    xor esi, esi
    mov edx, 220
    xor ecx, ecx
    mov r8d, 255
    call _SDL_SetRenderDrawColor

    mov r12, [rel live_ptr]
    mov r13, [rel live_len]
    mov ebx, [rel cell_size]
    xor r14, r14

.render_loop:
    cmp r14, r13
    jae .present

    mov eax, dword [r12 + r14 * 8 + 4]
    movsxd r9, eax
    mov eax, dword [r12 + r14 * 8]
    movsxd r10, eax

    mov rax, r9
    sub rax, [rel camera_x]
    imul rax, rbx
    add rax, WINDOW_HALF_WIDTH

    mov rcx, rax
    add rcx, rbx
    cmp rcx, 0
    jle .next_cell
    cmp rax, WINDOW_WIDTH
    jge .next_cell

    mov rcx, r10
    sub rcx, [rel camera_y]
    imul rcx, rbx
    add rcx, WINDOW_HALF_HEIGHT

    mov rdx, rcx
    add rdx, rbx
    cmp rdx, 0
    jle .next_cell
    cmp rcx, WINDOW_HEIGHT
    jge .next_cell

    mov dword [rel cell_rect], eax
    mov dword [rel cell_rect + 4], ecx
    mov dword [rel cell_rect + 8], ebx
    mov dword [rel cell_rect + 12], ebx

    mov rdi, [rel renderer_ptr]
    lea rsi, [rel cell_rect]
    call _SDL_RenderFillRect

.next_cell:
    inc r14
    jmp .render_loop

.present:
    mov rdi, [rel renderer_ptr]
    call _SDL_RenderPresent

    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

render_grid:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    mov ebx, [rel cell_size]
    cmp ebx, 4
    jl .done

    mov rdi, [rel renderer_ptr]
    mov esi, 18
    mov edx, 38
    mov ecx, 44
    mov r8d, 255
    call _SDL_SetRenderDrawColor

    mov r12d, WINDOW_HALF_WIDTH
.vertical_right:
    cmp r12d, WINDOW_WIDTH
    jge .vertical_left_setup
    mov rdi, [rel renderer_ptr]
    mov esi, r12d
    xor edx, edx
    mov ecx, r12d
    mov r8d, WINDOW_HEIGHT - 1
    call _SDL_RenderDrawLine
    add r12d, ebx
    jmp .vertical_right

.vertical_left_setup:
    mov r12d, WINDOW_HALF_WIDTH
    sub r12d, ebx

.vertical_left:
    cmp r12d, 0
    jl .horizontal_down_setup
    mov rdi, [rel renderer_ptr]
    mov esi, r12d
    xor edx, edx
    mov ecx, r12d
    mov r8d, WINDOW_HEIGHT - 1
    call _SDL_RenderDrawLine
    sub r12d, ebx
    jmp .vertical_left

.horizontal_down_setup:
    mov r12d, WINDOW_HALF_HEIGHT

.horizontal_down:
    cmp r12d, WINDOW_HEIGHT
    jge .horizontal_up_setup
    mov rdi, [rel renderer_ptr]
    xor esi, esi
    mov edx, r12d
    mov ecx, WINDOW_WIDTH - 1
    mov r8d, r12d
    call _SDL_RenderDrawLine
    add r12d, ebx
    jmp .horizontal_down

.horizontal_up_setup:
    mov r12d, WINDOW_HALF_HEIGHT
    sub r12d, ebx

.horizontal_up:
    cmp r12d, 0
    jl .axis_color
    mov rdi, [rel renderer_ptr]
    xor esi, esi
    mov edx, r12d
    mov ecx, WINDOW_WIDTH - 1
    mov r8d, r12d
    call _SDL_RenderDrawLine
    sub r12d, ebx
    jmp .horizontal_up

.axis_color:
    mov rdi, [rel renderer_ptr]
    mov esi, 42
    mov edx, 110
    mov ecx, 120
    mov r8d, 255
    call _SDL_SetRenderDrawColor

    mov rdi, [rel renderer_ptr]
    mov esi, WINDOW_HALF_WIDTH
    xor edx, edx
    mov ecx, WINDOW_HALF_WIDTH
    mov r8d, WINDOW_HEIGHT - 1
    call _SDL_RenderDrawLine

    mov rdi, [rel renderer_ptr]
    xor esi, esi
    mov edx, WINDOW_HALF_HEIGHT
    mov ecx, WINDOW_WIDTH - 1
    mov r8d, WINDOW_HALF_HEIGHT
    call _SDL_RenderDrawLine

.done:
    pop r12
    pop rbx
    pop rbp
    ret

update_window_title:
    push rbp
    mov rbp, rsp

    cmp byte [rel sim_running], 0
    jne .running
    lea r8, [rel status_paused]
    jmp .format

.running:
    lea r8, [rel status_running]

.format:
    mov r9, r8
    lea rdi, [rel title_buffer]
    mov esi, 128
    lea rdx, [rel title_fmt]
    mov rcx, [rel generation]
    mov r8, [rel live_len]
    xor eax, eax
    call _snprintf

    mov rdi, [rel window_ptr]
    lea rsi, [rel title_buffer]
    call _SDL_SetWindowTitle

    leave
    ret

compare_u64:
    push rbp
    mov rbp, rsp

    mov rax, [rdi]
    mov rcx, [rsi]
    cmp rax, rcx
    jb .less
    ja .greater
    xor eax, eax
    pop rbp
    ret

.less:
    mov eax, -1
    pop rbp
    ret

.greater:
    mov eax, 1
    pop rbp
    ret

print_sdl_error:
    push rbp
    mov rbp, rsp
    sub rsp, 16

    mov [rbp - 8], rdi
    call _SDL_GetError
    mov rsi, rax
    mov rdi, [rbp - 8]
    xor eax, eax
    call _printf

    leave
    ret

cleanup:
    push rbp
    mov rbp, rsp

    mov rdi, [rel renderer_ptr]
    test rdi, rdi
    jz .skip_renderer
    call _SDL_DestroyRenderer
    mov qword [rel renderer_ptr], 0

.skip_renderer:
    mov rdi, [rel window_ptr]
    test rdi, rdi
    jz .skip_window
    call _SDL_DestroyWindow
    mov qword [rel window_ptr], 0

.skip_window:
    mov rdi, [rel live_ptr]
    test rdi, rdi
    jz .skip_live
    call _free
    mov qword [rel live_ptr], 0
    mov qword [rel live_len], 0
    mov qword [rel live_cap], 0

.skip_live:
    mov rdi, [rel next_ptr]
    test rdi, rdi
    jz .skip_next
    call _free
    mov qword [rel next_ptr], 0
    mov qword [rel next_len], 0
    mov qword [rel next_cap], 0

.skip_next:
    mov rdi, [rel candidates_ptr]
    test rdi, rdi
    jz .done
    call _free
    mov qword [rel candidates_ptr], 0
    mov qword [rel candidates_cap], 0

.done:
    call _SDL_Quit
    pop rbp
    ret
