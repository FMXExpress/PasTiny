; save the text screen (80 x 25 characters and colours) to SNAP.SCR and
; the BIOS 8 x 16 font to SNAP.FNT, so the screen can be drawn as a picture
bits 16
org 100h
        mov     ah,3Ch
        xor     cx,cx
        mov     dx,name1
        int     21h
        mov     bx,ax
        push    ds
        mov     ax,0B800h
        mov     ds,ax
        xor     dx,dx
        mov     cx,4000
        mov     ah,40h
        int     21h
        pop     ds
        mov     ah,3Eh
        int     21h
        mov     ah,3Ch
        xor     cx,cx
        mov     dx,name2
        int     21h
        mov     si,ax
        mov     ax,1130h
        mov     bh,6
        int     10h                     ; ES:BP = the 8 x 16 font
        mov     bx,si
        push    ds
        push    es
        pop     ds
        mov     dx,bp
        mov     cx,4096
        mov     ah,40h
        int     21h
        pop     ds
        mov     ah,3Eh
        int     21h
        ret
name1:  db      'SNAP.SCR',0
name2:  db      'SNAP.FNT',0
