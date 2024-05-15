bits 16
org 0x7c00

	; Set video mode to 640x480 16 color
	mov ax, 0x0012
	int 0x10

	; Set DAC registers to interesting colors
	xor bx, bx
	xor cx, cx
	xor dx, dx
	mov ax, 0x1010
	set_dac_loop:
		int 0x10
		add cx, 0x0404
		add dh, 0x04
		inc bx
		cmp bx, 16
		jb set_dac_loop

	; Set palette
	mov ax, 0x1000
	xor bx, bx
	set_palette:
		int 0x10
		add bx, 0x0101
		cmp bx, 0x1010
		jb set_palette

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

			fild word [constant_15]
			fmulp
			fistp word [float_xchg]

			mov al, byte [float_xchg]

			; TODO: for testing
			mov al, dl
			shr al, 4

			mov ah, 0x0C
			mov bh, 0
			int 0x10

			inc cx
			cmp cx, WIDTH
			jb x_loop

		inc dx
		cmp dx, HEIGHT
		jb y_loop

	jmp $

rand_01:
	fldln2
	ret

	WIDTH equ 640
	HEIGHT equ 480

	constant_15: dw 15
	float_xchg: dw 0

times 510-($-$$) db 0
dw 0xAA55
