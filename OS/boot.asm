; bootloader
org 0x7c00
bits 16

xor ax, ax
mov ds, ax
mov es, ax

mov ah, 2 ; read disk
mov al, 32 ; num of sectors to read
mov ch, 0 ; cylinder number
mov cl, 2 ; sector number
mov dh, 0 ; head number
mov dl, 0x00; floppy disk
mov bx, 0x7e00 ; address
int 0x13 ; call bios interupt to load next code segments

jc read_failed


jmp 0x0000:0x7e00

read_failed:
    mov ah, 0x0e
    mov bx, fail_msg

    print1:
        mov al, [bx]
        cmp al, 0b
        je end1
        int 0x10
        inc bx
        jmp print1
    end1:
    cli
    jmp $

    fail_msg:
    db "read failed", 0x0D, 0x0A, 0b

jmp $

end:

; magic number and padding
times 510-($-$$) db 0
dw 0xAA55