; bootloader stage 2

org 0x7E00
bits 16

; set DS to match ORG (0x7E00 >> 4 = 0x07E0)
mov ax, 0x07E0
mov ds, ax

mov ax, 0xb800
mov es, ax
mov word [es:0], 0x0F41 ; set vga adress

; clear the VGA text screen (80x25 = 2000 chars)
mov ax, 0xB800
mov es, ax
xor di, di
mov ax, 0x0F20    ; word = attribute<<8 | ' ' (white on black, space)
mov cx, 2000
rep stosw

%if 0
; print "Booting into 32 bit mode...\r\n" because it looks cool
; \r \n is 0x0D 0x0A in case u forgor
mov ax, 0xB800
mov es, ax
xor di, di        ; start at top-left (offset 0)
mov si, str

print:
    lodsb
    cmp al, 0b
    je end
    mov [es:di], al        ; character
    mov byte [es:di+1], 0x0F ; attribute (white on black)
    add di, 2
    jmp print
end:

str:
db "Booting into 32 bit mode...", 0b
%endif ; no printing beacuse it makes it flicker :(

; ----define code and data segments----
GDT:
    ; null descriptor
    null_descriptor:
    dq 0x0000000000000000

    ; 64-bit code descriptor (limit=0xFFFFF, base=0, access=0x9A, flags=0xA)
    code_descriptor:
    dw 0xFFFF        ; limit_low
    dw 0x0000        ; base_low
    db 0x00          ; base_mid
    db 0x9A          ; access
    db 0xAF          ; granularity (flags<<4 | limit_high)
    db 0x00          ; base_high

    ; data descriptor (limit=0xFFFFF, access=0x92, flags=0xA)
    data_descriptor:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0x92
    db 0xAF
    db 0x00

GDT_end:

GDT_descriptor:
    dw GDT_end - GDT - 1 ; size
    dd GDT ; start

CODE_SEG equ code_descriptor - GDT
DATA_SEG equ data_descriptor - GDT

; page table
align 4096
PML4:
    dq PDPT + 0x03

align 4096
PDPT:
    dq PD + 0x03

align 4096
PD:
    dq 0x00000000 + 0x83  ; map first 2MiB (covers 0xB8000), present|rw|ps

; ----load table----
cli
lgdt [GDT_descriptor]

; actually change to 32 bit mode (for now)
mov eax, cr0
or eax, 1        ; set PE (was "1b" — wrong)
mov cr0, eax

; long jump to protected-mode entry
jmp CODE_SEG:start_protected_mode

; ...existing code...
    ; enable paging: set CR0.PG (bit 31) and write back
    mov eax, cr0
    or  eax, 1 << 31
    mov cr0, eax

    ; far jump into 64-bit code selector (loads CS with L-bit descriptor)
    jmp CODE_SEG:start_64bit


bits 32
start_protected_mode:
    ; reload segments (data selector base must be 0 in your GDT)
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov ss, ax

    cli                     ; ensure interrupts disabled while changing paging state

    ; enable PAE (CR4.PAE = bit 5)
    mov eax, cr4
    or  eax, 1 << 5
    mov cr4, eax

    ; load CR3 with physical (page-aligned) address of PML4
    lea eax, [PML4]         ; get address of PML4
    and eax, 0xFFFFF000     ; ensure page-aligned
    mov cr3, eax

    ; enable Long Mode (EFER.LME = bit 8)
    mov ecx, 0xC0000080
    rdmsr                   ; EDX:EAX = MSR
    or  eax, 1 << 8
    wrmsr

    ; enable paging (CR0.PG = bit 31)
    mov eax, cr0
    or  eax, 1 << 31
    mov cr0, eax

    ; far jump into 64-bit code segment (loads CS with L-bit descriptor)
    jmp CODE_SEG:start_64bit


    bits 64
    start_64bit:


    ; set up segment registers (flat, safe)
    mov ax, DATA_SEG ; data segment selector (GDT)
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, 0x90000 ; stack

    ; clear VGA (80x25) using linear address 0xB8000
    cld
    mov rcx, 2000
    mov rdi, 0xB8000
    mov ax, 0x0F20
    rep stosw

    ; write 'A' at column 1 
    mov ax, 0x0F41        ; 'A' + attribute
    mov rdi, 0xB8000 + 2  ; column 1
    mov [rdi], ax

    ; disable blinking cursor (set cursor start register bit 5)
    mov dx, 0x3D4
    mov al, 0x0A
    out dx, al
    mov dx, 0x3D5
    in al, dx
    or al, 0x20
    out dx, al

    ; set hardware cursor position to 0 (optional)
    mov dx, 0x3D4
    mov al, 0x0E
    out dx, al
    mov dx, 0x3D5
    xor al, al
    out dx, al
    mov dx, 0x3D4
    mov al, 0x0F
    out dx, al
    mov dx, 0x3D5
    xor al, al
    out dx, al

jmp $ ; halt

times 16384-($-$$) db 0 ; pad
