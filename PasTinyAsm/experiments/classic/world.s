# GNU as, 8086 DOS .COM. Table entries: east room, west room, name address.
.intel_syntax noprefix
.code16
.global _start
_start:
    cld
look:
    mov bx, [room]
    shl bx, 1
    shl bx, 1
    mov dx, [rooms+bx+2]
    call puts
prompt:
    mov dx, offset input
    mov ah, 0x0a
    int 0x21
    xor bx, bx
    mov bl, [input+1]
    mov byte ptr [input+2+bx], 0
    mov si, offset verbs
next:
    lodsw
    or ax, ax
    jz unknown
    mov di, ax
    push si
    mov si, offset input+2
match:
    lodsb
    scasb
    jne mismatch
    or al, al
    jnz match
    pop si
    jmp word ptr [si]
mismatch:
    pop si
    add si, 2
    jmp next
unknown:
    mov dx, offset huh
message:
    call puts
    jmp prompt
puts:
    mov ah, 9
    int 0x21
    ret
east:
    xor di, di
    jmp move
west:
    mov di, 1
move:
    mov bx, [room]
    shl bx, 1
    shl bx, 1
    mov al, [rooms+bx+di]
    cmp al, 255
    je blocked
    xor ah, ah
    mov [room], ax
    jmp look
blocked:
    mov dx, offset wall
    jmp message
take:
    mov ax, [room]
    cmp ax, [lamp]
    jne absent
    mov word ptr [lamp], -1
    mov dx, offset taken
    jmp message
absent:
    mov dx, offset missing
    jmp message
inventory:
    mov dx, offset empty
    cmp word ptr [lamp], -1
    jne message
    mov dx, offset carrying
    jmp message
quit:
    mov ax, 0x4c00
    int 0x21
verbs: .word eastword,east, westword,west, takeword,take, invword,inventory, lookword,look, quitword,quit, 0
eastword: .asciz "east"
westword: .asciz "west"
takeword: .asciz "take lamp"
invword: .asciz "inventory"
lookword: .asciz "look"
quitword: .asciz "quit"
huh: .ascii "Unknown command.\r\n$"
wall: .ascii "No exit.\r\n$"
missing: .ascii "No lamp here.\r\n$"
taken: .ascii "Taken.\r\n$"
empty: .ascii "Empty inventory.\r\n$"
carrying: .ascii "Carrying lamp.\r\n$"
room: .word 0
lamp: .word 1
input: .byte 32,0
.space 34
.include "rooms.inc"
