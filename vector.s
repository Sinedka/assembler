SYS_WRITE   equ 1
SYS_READ    equ 0
SYS_EXIT    equ 60
STDOUT      equ 1
STDIN       equ 0
; | input: size
; | output: 
; rax = pointer to allocated memory
%macro mmap_alloc 1
    push rdi
    push rsi
    push rdx
    push r10
    push r8
    push r9

    ; === mmap ===
    xor rdi, rdi                 ; addr = NULL
    mov rsi, %1
    shl rsi, 3                   ; размер в байтах
    mov rdx, 0x3                 ; PROT_READ | PROT_WRITE
    mov r10, 0x22                ; MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1                   ; fd = -1
    xor r9, r9                   ; offset = 0
    mov rax, 9                   ; syscall mmap
    syscall
    
    pop r9
    pop r8
    pop r10
    pop rdx
    pop rsi
    pop rdi
%endmacro

; | input:
; rdi = pointer to Vector,
; rsi = old size,
; rdx = new size
; | output:
; rax = pointer to allocated memory
%macro mremap_alloc 0
    push r10
    push r8
    push r9

    ; mov rdi, rdi               ; pointer to Vector
    ; mov rsi, %3                ; old_size
    shl rsi, 8                   ; old_size в байтах
    ; mov rdx, rdx                  ; new_size
    shl rdx, 8                   ; new_size в байтах
    mov r10, 1                   ; MREMAP_MAYMOVE
    mov rax, 25                  ; syscall mremap
    syscall

    pop r9
    pop r8
    pop r10
%endmacro

section .data
    format: db "%d", 0xa, 0
    number: dq 1234

section .bss
    align 8
    vector: resq 3

section .text
    global _start
_start:
    mov rdi, vector
    call vector_create

    mov rdi, vector
    mov rsi, 1234
    call vector_push_back

    ; mov rdi, vector
    ; mov rsi, 5678
    ; call vector_push_back

    mov rax, format
    mov rbx, [vector]
    push qword [rbx]
    call printf

    ; mov rsi, 2
    ; call vector_push_back


exit:
    mov rax,60
    mov rdi, 0
    syscall 

; void vector_create(struct Vector* vec);
vector_create:
    ; rdi = pointer to Vector
    mov qword [rdi], 0          ; data = NULL
    mov qword [rdi + 8], 0       ; size = 0
    mov qword [rdi + 16], 0      ; capacity = 0
    ret

; void vector_push_back(struct Vector* vec, uint64_t value);
vector_push_back:
    ; rdi = pointer to Vector
    ; rsi = значение для вставки

    push rbx               ; Сохраняем указатель на Vector

    mov rax, [rdi + 8]          ; rax = size
    mov rcx, [rdi + 16]         ; rcx = capacity

    cmp rax, rcx
    jne .no_expand               ; если size < capacity, не расширяем

    cmp rcx, 0
    jne .double_capacity

    ; capacity == 0 -> выделяем 1 элемент
    mov rdx, 1
    jmp .allocate_new

.double_capacity:
    lea rdx, [rcx * 2]           ; capacity *= 2

.allocate_new:
    cmp rcx, 0
    jne .use_mremap

.use_mmap:
    push rax
    mmap_alloc rdx
    mov [rdi], rax               ; Сохраняем новый указатель
    pop rax

    jmp .insert_element

.use_mremap:
    push rax
    push rsi
    mov rsi, rcx
    ; mremap_alloc rdi, rcx, rdx
    mremap_alloc
    mov [rdi], rax               ; Сохраняем новый указатель
    pop rsi
    pop rax

.insert_element:
    mov [rdi + 16], rdx          ; Сохраняем новую capacity
    
    ; вставляем элемент
    mov rdx, [rdi]               ; указатель на первый элемент вектора
    mov rax, [rdi + 8]           ; размер вектора

    mov rcx, rsi                 ; значение для вставки

    mov [rdx + rax*8], rcx       ; data[size] = value
    inc rax
    mov [rdi + 8], rax           ; size++

    pop rbx
    ret

.alloc_failed:
    pop rbx
    ret

; void vector_free(struct Vector* vec);
vector_free:
    ; rdi = pointer to Vector
    mov rax, [rdi]
    test rax, rax
    je .no_free

    ; вызываем munmap
    ; rdi = addr
    ; rsi = length (capacity * 8)

    mov rsi, [rdi + 16]
    shl rsi, 3
    mov rdi, rax                ; addr
    mov rax, 11                 ; syscall number: munmap
    syscall

.no_free:
    ret


; | input:
; rax = format
; stack = values
; | output:
; rax = count(-1 if error)
printf:
    push rbx
    push rcx
    mov rbx, 32
    xor rcx, rcx

printf_next_iter:
    cmp [rax], byte 0
    je printf_close

    cmp [rax], byte '%'
    je printf_special_char
    
    jmp printf_default_char

    printf_special_char:
        inc rax

        cmp [rax], byte 's'
        je printf_print_string

        cmp [rax], byte 'd'
        je printf_print_decimal

        cmp [rax], byte 'c'
        je printf_print_char

        cmp [rax], byte '%'
        je printf_default_char

        jmp printf_is_error

    printf_print_string:
        push rax
        mov rax, [rsp+rbx]
        call print_string
        pop rax
        jmp printf_shift_stack
    printf_print_decimal:
        push rax
        mov rax, [rsp+rbx]
        call print_decimal
        pop rax
        jmp printf_shift_stack
    printf_print_char:
        push rax
        mov rax, [rsp+rbx]
        call print_char
        pop rax
        jmp printf_shift_stack

    printf_default_char:
        push rax
        mov rax, [rax]
        call print_char
        pop rax

        jmp printf_next_step

printf_shift_stack:
    inc rcx
    add rbx, 8

printf_next_step:
    inc rax
    jmp printf_next_iter

printf_is_error:
    mov rcx, -1
printf_close:
    mov rax, rcx
    pop rcx
    pop rbx
    ret


; | input:
; rax = number
print_decimal:
    push rax
    push rbx
    push rcx
    push rdx

    xor rcx, rcx ;длина числа

    cmp rax, 0
    jne not_zero

    ; Если rax == 0, сразу вывести '0'
    mov rax, '0'
    call print_char
    jmp close_decimal

not_zero:
    cmp rax, 0
    jg next_iter_decimal
    
    ;если число отрицательное
    neg rax
    push rax
    mov rax, '-'
    call print_char
    pop rax

next_iter_decimal:
    mov rbx, 10   ;base
    
    xor rdx, rdx 
    
    div rbx
    push rdx
    inc rcx ;длина числа

    
    cmp rax, 0 ;число кончилось
    je print_iter_decimal
    jmp next_iter_decimal

print_iter_decimal:

    cmp rcx, 0
    jle close_decimal
    dec rcx ;длина числа
    
    pop rax
    add rax, '0'
    call print_char

    jmp print_iter_decimal

close_decimal:
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; | input
; rax = string
print_string:
    push rbx
    xor rbx, rbx

next_iter_string:
    cmp [rax+rbx], byte 0
    je close_string

    push rax
    mov rax, [rax+rbx]
    call print_char
    pop rax

    inc rbx
    jmp next_iter_string

close_string:
    pop rbx
    ret

; | input
; rax = char
print_char:
    push rdx
    push rsi
    push rdi
    push rcx
    push r11
    push rax

    mov rax, SYS_WRITE       ; номер системного вызова write
    mov rdi, STDOUT       ; дескриптор stdout
    mov rsi, rsp
    mov rdx, 1
    syscall

    pop rax
    pop r11
    pop rcx
    pop rdi
    pop rsi
    pop rdx
    ret
