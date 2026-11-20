; print the colour attribute of the top left cell as two hex digits
bits 16
org 100h
        mov ax,0B800h
        mov es,ax
        mov bl,[es:1]
        mov cl,4
        mov al,bl
        shr al,cl
        call hex
        mov al,bl
        and al,15
        call hex
        mov ah,2
        mov dl,13
        int 21h
        mov dl,10
        int 21h
        ret
hex:    add al,'0'
        cmp al,'9'
        jbe .ok
        add al,7
.ok:    mov dl,al
        mov ah,2
        int 21h
        ret
