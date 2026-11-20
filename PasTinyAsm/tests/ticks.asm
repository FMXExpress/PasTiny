; print the BIOS tick counter (18.2 per second), low word, as decimal
bits 16
org 100h
        xor ax,ax
        mov es,ax
        mov ax,[es:46Ch]
        mov bx,10
        xor cx,cx
.s:     xor dx,dx
        div bx
        push dx
        inc cx
        test ax,ax
        jnz .s
.d:     pop dx
        add dl,'0'
        mov ah,2
        int 21h
        loop .d
        mov ah,2
        mov dl,13
        int 21h
        mov dl,10
        int 21h
        ret
