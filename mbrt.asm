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

	sub sp, 108
	
	; TODO:
	finit

	xor dx, dx
	fld dword [ray_y_origin]
	y_loop:
		xor cx, cx
		fld1
		fchs
		x_loop:
			mov bp, sp ; TODO
			fnsave [ss:bp]
			frstor [ss:bp]

			; Normalize ray
			fld st0
			fmul st0, st1
			fld st2
			fmul st0, st3
			faddp
			fld1
			faddp
			fsqrt
			fdiv st2, st0
			fdivp
			
			fxch
			fabs
			fxch
			fabs ; TODO

			faddp
			fld1
			fld1
			faddp
			fdivp

			fild word [constant_15]
			fmulp
			fistp word [light_to_color_float_xchg]

			mov bp, sp ; TODO

			mov al, byte [light_to_color_float_xchg]

			mov ah, 0x0C
			mov bh, 0
			int 0x10

			frstor [ss:bp]
			fadd dword [ray_step]
			inc cx
			cmp cx, 640
			jb x_loop

		fincstp
		fadd dword [ray_step]
		inc dx
		cmp dx, 480
		jb y_loop

	jmp $

rand_01:
	; xorshift32 ported from https://en.wikipedia.org/wiki/Xorshift
	pusha
	mov si, word [rand_01_seed]
	mov di, word [rand_01_seed+2]

	; x ^= x << 13
	mov cx, 0x030D
	call rand_01_shl_xor

	; x ^= x >> 17
	mov dx, di
	shr dx, 1
	xor si, dx

	; x ^= x << 5
	mov cx, 0x0B05
	call rand_01_shl_xor

	mov word [rand_01_seed], si
	mov word [rand_01_seed+2], di

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

	rand_01_shl_xor:
		mov ax, si
		mov bx, si
		mov dx, di

		shl ax, cl
		xor si, ax

		shl dx, cl
		mov cl, ch
		shr bx, cl
		or dx, bx
		xor di, dx
		ret

	ray_y_origin: dd -0.75
	ray_step: dd 0.003125

	constant_15: dw 15
	light_to_color_float_xchg: dd 0xFFFFFFFF

	rand_01_seed: dd 0x3BADF00D
	rand_01_float_xchg: dd 0

	ray_sphere_r_sq_param: dd 0x12345678

times 510-($-$$) db 0
dw 0xAA55
