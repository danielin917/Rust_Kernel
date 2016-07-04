global start
extern long_mode_start
;;REFERENCE:0xb8000 is the start of the VGA text buffer


section .text
bits 32
start:
	mov esp, stack_top
	
	call check_multiboot
	call check_cpuid
	call check_long_mode
	
	call set_up_page_tables
	call enable_paging
	
	lgdt [gdt64.pointer];Load global destriptor pointer
	
	mov ax, gdt64.data;load selector registers
	mov ss, ax;stack selector
	mov ds, ax;data selector
	mov es, ax;extra selector
	
	jmp gdt64.code:long_mode_start; only way to reload the code selector is a far jump or far return
	;print ok to screen
	mov dword [0xb8000], 0x2f4b2f4f
	hlt
;;Prints ERR and code to screen, then hangs
error:
	mov dword [0xb8000], 0x4f524f45
	mov dword [0xb8004], 0x4f3a4f52
	mov dword [0xb8008], 0x4f204f20
	mov byte  [0xb800a], al
	hlt

check_multiboot:
    cmp eax, 0x36d76289
    jne .no_multiboot
    ret

.no_multiboot:
    mov al, "0"
    jmp error


check_long_mode:
    ; test if extended processor info in available
    mov eax, 0x80000000    ; implicit argument for cpuid
    cpuid                  ; get highest supported argument
    cmp eax, 0x80000001    ; it needs to be at least 0x80000001
    jb .no_long_mode       ; if it's less, the CPU is too old for long mode

    ; use extended info to test if long mode is available
    mov eax, 0x80000001    ; argument for extended processor info
    cpuid                  ; returns various feature bits in ecx and edx
    test edx, 1 << 29      ; test if the LM-bit is set in the D-register
    jz .no_long_mode       ; If it's not set, there is no long mode
    ret
.no_long_mode:
    mov al, "2"
    jmp error

check_cpuid:
    ; Check if CPUID is supported by attempting to flip the ID bit (bit 21)
    ; in the FLAGS register. If we can flip it, CPUID is available.

    ; Copy FLAGS in to EAX via stack
    pushfd
    pop eax

    ; Copy to ECX as well for comparing later on
    mov ecx, eax

    ; Flip the ID bit
    xor eax, 1 << 21

    ; Copy EAX to FLAGS via the stack
    push eax
    popfd

    ; Copy FLAGS back to EAX (with the flipped bit if CPUID is supported)
    pushfd
    pop eax

    ; Restore FLAGS from the old version stored in ECX (i.e. flipping the
    ; ID bit back if it was ever flipped).
    push ecx
    popfd

    ; Compare EAX and ECX. If they are equal then that means the bit
    ; wasn't flipped, and CPUID isn't supported.
    cmp eax, ecx
    je .no_cpuid
    ret
.no_cpuid:
    mov al, "1"
    jmp error

set_up_page_tables:
	;map first p4 entry to to p3 table
	mov eax, p3_table
	or eax, 0b11 ;exists and is writable
	mov [p4_table], eax
	
	;map first p3 table entry to p2 table
	mov eax, p2_table
	or eax, 0b11;exists and is writeable
	mov [p3_table], eax

	mov ecx, 0 ;set the counter variable to 0
.map_p2_table:
	;map ecx-th P2 entry to a huge a huge page that starts at address 2MiB*ecx
	mov eax, 0x200000; <---- page size
	mul ecx	;start address of ecx-th page
	or eax, 0b10000011 ;present + writable and is a huge page	
	mov [p2_table + ecx * 8], eax ; map the entry	
	
	inc ecx		;increment counter
	cmp ecx, 512	;if counter ==512, the whole P2 table is mapped
	jne .map_p2_table	;else map the next entry
	
	ret
enable_paging:
	;load P4 to cr3 (this is where the computer looks for the highest page table)
	mov eax, p4_table
	mov cr3, eax

	;enable PAE (physical address extension flag down in cr4
	mov eax, cr4
	or eax, 1 << 5
	mov cr4, eax

	; set long mode bit in EFER msr(model specific register)
	mov ecx, 0xC0000080
	rdmsr; read model specific register at address ecx
	or eax, 1 << 8
	wrmsr; write model specific register at address ecx

	;enable paging in the cr0 register
	mov eax, cr0
	or eax, 1 << 31
	mov cr0, eax

	ret
section .rodata;read only data section
gdt64: ;Global descriptor table, needed to to execute 64 bit code. We don't actually use segmentation though we use paging but GDT is still required.
	;GDT starts with zero entry and then arbitrary amount of  segments after
	dq 0 ;the zero entry (define quad outputs a 64 bit constant
.code: equ $ -gdt64
	dq (1<<44) | (1<<47) | (1<<41) | (1<<43) | (1<<53) ;code segment
.data: equ $ -gdt64
	dq (1<<44) | (1<<47) | (1<<41); data segment
.pointer:;labels that begin with a point (.pointer) are sub labels of the last label without a point (gdt64.pointer to access)
	dw $ - gdt64 - 1;$is replaced with current address. We are loading a special pointer to the load gdt instdtruction (lgdt)
	dq gdt64
section .bss;These are our page tables
align 4096
p4_table:
    resb 4096
p3_table:
    resb 4096
p2_table:
    resb 4096
stack_bottom:
    resb 64
stack_top:

