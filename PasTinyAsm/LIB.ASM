; PasTinyAsm call library: the routines a generated .COM program is made of.
;
; Every routine is assembled on its own by tools/buildlib.py (NASM, 16-bit,
; 8086 instructions only) and stored as bytes in LIB.INC.  A routine must
; not refer to anything outside itself, so it can be placed at any address.
; Arguments arrive in AX and BX, or DX for text.  Any register may be changed.
;
; A line ";; NAME kind lo1 hi1 lo2 hi2" starts a routine:
;   kind 0 = no argument, 1 = one number in AX, 2 = numbers in AX and BX,
;   3 = text, address in DX (ends with "$"), 4 = no argument, result in AX
;   lo/hi = the smallest and largest value allowed for each number
;
; The screen routines write to the colour text screen at B800:0000 (80 x 25).
; Delays use BIOS interrupt 15h function 86h, present on every AT-class PC.

;; CLS 0 0 0 0 0
; Clear the screen (set 80 x 25 colour text mode).
        mov     ax,3
        int     10h
        ret

;; FLASH 1 1 50 0 0
; Flash the screen AX times, keeping what is on it.
        mov     cx,ax
        jcxz    .out                    ; a count of 0 does nothing
.again: push    cx
        call    .flip
        call    .wait
        call    .flip
        call    .wait
        pop     cx
        loop    .again
.out:   ret
.flip:  push    es                      ; swap light and dark in every cell
        mov     ax,0B800h
        mov     es,ax
        mov     di,1
        mov     cx,2000
.cell:  xor     byte [es:di],7Fh
        add     di,2
        loop    .cell
        pop     es
        ret
.wait:  mov     cx,1                    ; 120 ms = 1D4C0h microseconds
        mov     dx,0D4C0h
        mov     ah,86h
        int     15h
        ret

;; COLOR 1 0 7 0 0
; Paint the whole screen background in colour AX, with bright white text.
        mov     cl,4
        shl     al,cl
        or      al,0Fh
        mov     bl,al
        push    es
        mov     ax,0B800h
        mov     es,ax
        mov     di,1
        mov     cx,2000
.cell:  mov     [es:di],bl
        add     di,2
        loop    .cell
        pop     es
        ret

;; INK 1 0 15 0 0
; Change the colour of all text on the screen to AX, keeping the background.
        mov     bl,al
        push    es
        mov     ax,0B800h
        mov     es,ax
        mov     di,1
        mov     cx,2000
.cell:  mov     al,[es:di]
        and     al,0F0h
        or      al,bl
        mov     [es:di],al
        add     di,2
        loop    .cell
        pop     es
        ret

;; BORDER 1 0 15 0 0
; Set the border colour to AX.
        mov     bl,al
        mov     bh,0
        mov     ah,0Bh
        int     10h
        ret

;; GOTO 2 1 25 1 80
; Move the cursor to row AX, column BX (counted from 1).
        dec     ax
        dec     bx
        mov     dh,al
        mov     dl,bl
        mov     bh,0
        mov     ah,2
        int     10h
        ret

;; HIDE 0 0 0 0 0
; Hide the cursor.
        mov     ah,1
        mov     cx,2000h
        int     10h
        ret

;; SHOW 0 0 0 0 0
; Show the cursor.
        mov     ah,1
        mov     cx,0607h
        int     10h
        ret

;; BEEP 2 40 9999 10 9999
; Sound the speaker at AX hertz for BX milliseconds.
        cmp     ax,19                   ; too low for the timer: do nothing
        jb      .out
        mov     cx,ax
        mov     dx,12h                  ; 1193180 / hertz = timer count
        mov     ax,34DCh
        div     cx
        mov     cx,ax
        mov     al,0B6h
        out     43h,al
        mov     al,cl
        out     42h,al
        mov     al,ch
        out     42h,al
        in      al,61h
        or      al,3
        out     61h,al
        mov     ax,1000                 ; BX milliseconds -> CX:DX microseconds
        mul     bx
        mov     cx,dx
        mov     dx,ax
        mov     ah,86h
        int     15h
        in      al,61h
        and     al,0FCh
        out     61h,al
.out:   ret

;; SIREN 1 1 20 0 0
; Sweep the speaker up and down AX times.
        mov     si,ax
        test    si,si                   ; a count of 0 does nothing
        jz      .out
        in      al,61h
        or      al,3
        out     61h,al
.round: mov     bx,2983                 ; timer count for 400 hertz
.up:    call    .tone
        sub     bx,40
        cmp     bx,994                  ; 1200 hertz
        ja      .up
.down:  call    .tone
        add     bx,40
        cmp     bx,2983
        jb      .down
        dec     si
        jnz     .round
        in      al,61h
        and     al,0FCh
        out     61h,al
.out:   ret
.tone:  mov     al,0B6h
        out     43h,al
        mov     al,bl
        out     42h,al
        mov     al,bh
        out     42h,al
        xor     cx,cx                   ; 8 ms
        mov     dx,8000
        mov     ah,86h
        int     15h
        ret

;; SCALE 0 0 0 0 0
; Play eight notes going up, from middle C.
        in      al,61h
        or      al,3
        out     61h,al
        call    .here
.notes: dw      4561,4063,3620,3417,3044,2712,2416,2280
.here:  pop     si                      ; SI = address of the note table
        mov     di,8
.next:  mov     al,0B6h
        out     43h,al
        mov     ax,[cs:si]
        out     42h,al
        mov     al,ah
        out     42h,al
        mov     cx,3                    ; 200 ms = 30D40h microseconds
        mov     dx,0D40h
        mov     ah,86h
        int     15h
        add     si,2
        dec     di
        jnz     .next
        in      al,61h
        and     al,0FCh
        out     61h,al
        ret

;; WAIT 1 1 60000 0 0
; Wait AX milliseconds.
        mov     bx,1000
        mul     bx
        mov     cx,dx
        mov     dx,ax
        mov     ah,86h
        int     15h
        ret

;; KEY 0 0 0 0 0
; Wait for a key (read one character from standard input, without echo).
        mov     ah,8
        int     21h
        ret

;; PRINT 3 0 0 0 0
; Print the text at DX.
        mov     ah,9
        int     21h
        ret

;; NEWLINE 0 0 0 0 0
; Start a new line.
        mov     ah,2
        mov     dl,13
        int     21h
        mov     dl,10
        int     21h
        ret

;; NUMBER 1 0 65535 0 0
; Print AX as a decimal number.
        mov     bx,10
        xor     cx,cx
.split: xor     dx,dx
        div     bx
        push    dx
        inc     cx
        test    ax,ax
        jnz     .split
.digit: pop     dx
        add     dl,'0'
        mov     ah,2
        int     21h
        loop    .digit
        ret

;; INPUT 4 0 0 0 0
; Read a whole number typed at the keyboard, up to Enter, into AX.
        xor     bx,bx
.next:  mov     ah,1                    ; read one character, with echo
        int     21h
        cmp     al,13
        je      .done
        cmp     al,26                   ; end of a redirected input file
        je      .done
        sub     al,'0'
        cmp     al,9
        ja      .next                   ; not a digit: ignore it
        mov     cl,al
        xor     ch,ch
        mov     ax,10
        mul     bx
        add     ax,cx
        mov     bx,ax
        jmp     .next
.done:  mov     ah,2
        mov     dl,10
        int     21h
        mov     ax,bx
        ret
