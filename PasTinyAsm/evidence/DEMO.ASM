; DEMO.COM, written by PasTinyAsm.  The routines are in LIB.ASM.
        org     100h
        mov     ax,3
        call    L_FLASH
        mov     ax,440
        mov     bx,300
        call    L_BEEP
        mov     ax,4C00h
        int     21h
; routine FLASH from LIB.ASM goes here
; routine BEEP from LIB.ASM goes here
