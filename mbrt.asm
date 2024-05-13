bits 16
org 0x7c00
	mov ax, 0xFFFF
	mov es, ax ; Temporarily set to top of stack for use in 4F01 to get mode information

	; Set video mode to 800x600 24-bit
	mov ax, 0x4F02
	mov bx, 0x4115
	int 0x10

	; Store mode info in 0xFFFF:0
	mov ax, 0x4F03
	int 0x10
	mov cx, bx
	mov ax, 0x4F01
	xor di, di
	int 0x10

	; TODO: Transition to protected mode

	jmp $

times 510-($-$$) db 0
dw 0xAA55
