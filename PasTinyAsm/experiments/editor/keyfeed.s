.intel_syntax noprefix
.code16
.global _start
_start:
    mov dx, offset filename
    mov ax, 0x3d00
    int 0x21
    jc failed
    mov bx, ax
    mov dx, offset keys
    mov cx, 12000
    mov ah, 0x3f
    int 0x21
    jc failed
    mov [count], ax
    mov ah, 0x3e
    int 0x21
    mov ax, 0x3516
    int 0x21
    mov [oldvec], bx
    mov [oldvec+2], es
    mov dx, offset hook
    mov ax, 0x2516
    int 0x21
    mov dx, offset endresident
    add dx, 15
    mov cl, 4
    shr dx, cl
    mov ax, 0x3100
    int 0x21
failed:
    mov ax, 0x4c01
    int 0x21
hook:
    cmp ah, 0
    jne chain
    push bx
    mov bx, cs:[cursor]
    cmp bx, cs:[count]
    jae finished
    xor ax, ax
    mov al, cs:[keys+bx]
    inc bx
    test al, al
    jnz save
    mov ah, cs:[keys+bx]
    inc bx
save:
    mov cs:[cursor], bx
    pop bx
    iret
finished:
    mov ax, 0x2d00
    pop bx
    iret
chain:
    jmp far ptr cs:[oldvec]
oldvec: .long 0
cursor: .word 0
count: .word 0
filename: .asciz "KEYS.IN"
keys: .space 12000
endresident:
