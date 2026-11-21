; C1.ASM, written by PasTinyAsm.  The routines are in LIB.ASM.
        org     100h
        jmp     near start
        times 26 dw 0           ; the variables A to Z
start:
                                ; FOR I=5 DOWNTO 1:OUT I:BEEP:NEXT:ECHO liftoff
        mov     ax,5
        mov     [00113h],ax        ; I
        mov     ax,1
        push    ax              ; the last value
L1:
        mov     ax,[00113h]        ; I
        pop     bx
        push    bx
        cmp     ax,bx
        jae     short $+5
        jmp     near L2
        mov     ax,[00113h]        ; I
        call    L_NUMBER
        call    L_NEWLINE
        mov     ax,440
        mov     bx,300
        call    L_BEEP
        mov     ax,[00113h]        ; I
        pop     bx
        push    bx
        cmp     ax,bx
        jne     short $+5
        jmp     near L2
        dec     word [00113h]
        jmp     near L1
L2:
        pop     bx              ; drop the last value
        mov     dx,text1
        call    L_PRINT
        call    L_NEWLINE
        mov     ax,4C00h
        int     21h
; routine BEEP from LIB.ASM goes here
; routine PRINT from LIB.ASM goes here
; routine NEWLINE from LIB.ASM goes here
; routine NUMBER from LIB.ASM goes here
text1:  db      "liftoff$"
