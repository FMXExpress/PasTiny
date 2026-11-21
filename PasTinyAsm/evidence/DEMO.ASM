; DEMO.ASM, written by PasTinyAsm.  The routines are in LIB.ASM.
        org     100h
        jmp     near start
        times 26 dw 0           ; the variables A to Z
start:
                                ; FLASH 3
        mov     ax,3
        call    L_FLASH
                                ; BEEP 440 300
        mov     ax,440
        push    ax
        mov     ax,300
        mov     bx,ax
        pop     ax
        call    L_BEEP
        mov     ax,4C00h
        int     21h
; routine FLASH from LIB.ASM goes here
; routine BEEP from LIB.ASM goes here
