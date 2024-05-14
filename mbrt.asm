bits 16
org 0x7c00

	; Set video mode to 640x480 16 color
	mov ax, 0x0012
	int 0x10

	mov ax, 0xA000
	mov es, ax

	mov ax, 0xFFFF
	mov ss, ax
	mov sp, ax
	
	; TODO:
	finit

	xor dx, dx
	y_loop:
		xor cx, cx
		x_loop:
			; TODO: produce color in the range [0, 1] and store it at the top of the float stack
			
			call rand_01

			fild word [constant_3]
			fmulp
			fistp word [float_xchg]

			mov bx, [float_xchg]
			and bx, 0x3
			mov ax, [palette+bx]

			mov ah, 0x0C
			mov bh, 0
			int 0x10

			inc cx
			cmp cx, 640
			jb x_loop

		inc dx
		cmp dx, 480
		jb y_loop

	jmp $

rand_01:
	fldln2
	ret

	constant_3: dw 3
	float_xchg: dw 0
	palette: db 0x0, 0x8, 0x7, 0xF

times 510-($-$$) db 0
dw 0xAA55
