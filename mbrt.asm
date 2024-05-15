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
	; xorshift32 ported from https://en.wikipedia.org/wiki/Xorshift
	pusha
	mov cx, word [rand_01_seed]
	mov dx, word [rand_01_seed+2]

	; x ^= x << 13
	mov ax, cx
	mov si, cx
	mov di, dx

	shl ax, 13
	xor cx, ax

	shr si, 3
	shl di, 13
	or di, si
	xor dx, di

	; x ^= x >> 17
	mov di, dx
	shr di, 1
	xor cx, di

	; x ^= x << 5
	mov ax, cx
	mov si, cx
	mov di, dx

	shl ax, 5
	xor cx, ax

	shr si, 11
	shl di, 5
	or di, si
	xor dx, di

	mov word [rand_01_seed], cx
	mov word [rand_01_seed+2], dx

	; generate float
	mov word [rand_01_float_xchg], cx
	shr dx, 9
	or dx, 0x3F80
	mov word [rand_01_float_xchg+2], dx

	fld dword [rand_01_float_xchg]
	fld1
	fsubp st1, st0

	popa
	ret

	WIDTH equ 640
	HEIGHT equ 480

	rand_01_seed: dd 0x3BADF00D
	rand_01_float_xchg: dd 0
	constant_15: dw 15
	float_xchg: dd 0

times 510-($-$$) db 0
dw 0xAA55
