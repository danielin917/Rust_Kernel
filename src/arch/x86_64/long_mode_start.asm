global long_mode_start

section .text
bits 64 ;the pc expects 64 bit instructions now so we use bits 64	
;we can still use 32 bit registers (eax, ebx etc... but now we have 64 bit registers rax rbx etc..)
; we write these 64 bit registers into memory using  mov qword
long_mode_start:
	mov rax, 0x2f592f412f4b2f4f ;print green 'OKAY'
	mov qword [0xb8000], rax
	hlt
