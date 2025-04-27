SYS_WRITE   equ 1
SYS_READ    equ 0
SYS_EXIT    equ 60
STDOUT      equ 1
STDIN       equ 0


section .data
    input   db "{ %s, %d, %c, %%}", 0xA, 0
    string  db "hello", 0
    decimal dq 571
    symbol  dq '!'

section .text
    global _start

_start:
    mov rax, input
    push qword [symbol]
    push qword [decimal]
    push string
    call printf

exit:
    mov rax, SYS_EXIT
    xor rdi, rdi
    syscall


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
