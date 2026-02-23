; bootloader stage 2

org 0x7E00
bits 16

; set DS to match ORG (0x7E00 >> 4 = 0x07E0)
mov ax, 0x07E0
mov ds, ax

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
    or eax, 1 << 5
    mov cr4, eax

    ; load CR3 with physical (page-aligned) address of PML4
    lea eax, [PML4]         ; get address of PML4
    and eax, 0xFFFFF000     ; ensure page-aligned
    mov cr3, eax

    ; enable Long Mode (EFER.LME = bit 8)
    mov ecx, 0xC0000080
    rdmsr                   ; EDX:EAX = MSR
    or eax, 1 << 8
    wrmsr

    ; enable paging (CR0.PG = bit 31)
    mov eax, cr0
    or eax, 1 << 31
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

    mov rax, 0x1122334455667788
    
jmp $ ; halt

times 16384-($-$$) db 0 ; pad
