; B1.ASM, written by PasTinyAsm.  The routines are in LIB.ASM.
        org     100h
        jmp     near start
        times 26 dw 0           ; the variables A to Z
start:
                                ; TIMES 2
        mov     ax,2
        mov     cx,ax
L1:
        or      cx,cx
        jnz     short $+5
        jmp     near L2
        push    cx
                                ; PRINT hello
        mov     dx,text1
        call    L_PRINT
                                ; FOR X=1 TO 3
        mov     ax,1
        mov     [00131h],ax        ; X
        mov     ax,3
        push    ax              ; the last value
L3:
        mov     ax,[00131h]        ; X
        pop     bx
        push    bx
        cmp     ax,bx
        jbe     short $+5
        jmp     near L4
                                ; OUT X
        mov     ax,[00131h]        ; X
        call    L_NUMBER
        call    L_NEWLINE
                                ; NEXT
        mov     ax,[00131h]        ; X
        pop     bx
        push    bx
        cmp     ax,bx
        jne     short $+5
        jmp     near L4
        inc     word [00131h]
        jmp     near L3
L4:
        pop     bx              ; drop the last value
                                ; BEEP 440 300
        mov     ax,440
        push    ax
        mov     ax,300
        mov     bx,ax
        pop     ax
        call    L_BEEP
                                ; END
        pop     cx
        dec     cx
        jmp     near L1
L2:
        mov     dx,text2
        call    L_PRINT
        mov     ax,4C00h
        int     21h
; routine BEEP from LIB.ASM goes here
; routine PRINT from LIB.ASM goes here
; routine NEWLINE from LIB.ASM goes here
; routine NUMBER from LIB.ASM goes here
text1:  db      "hello$"
text2:  db      "done$"
