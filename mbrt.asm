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

	fninit
	sub sp, 108

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
			fmul st0, st0
			fld st2
			fmul st0, st0
			faddp
			fld1
			faddp
			fsqrt
			fdiv st2, st0
			fdivp

			mov di, center_sphere
			call ray_sphere

			cmp al, 0
			je no_color
				fld1
				jmp color_end
			no_color:
				fldz
			color_end:

			fincstp
			call rand_01
			
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
		fsub dword [ray_step]
		inc dx
		cmp dx, 480
		jb y_loop

	jmp $

rand_01:
	fld1
	fld dword [rand_01_seed]
	fldpi
	fmulp
	fadd dword [rand_01_phi]
	fprem1
	fst dword [rand_01_seed]
	ret

	; fpu stack
	; v_y, v_x
	; ->
	; v_y, v_x, t
	; registers
	; di: address of c_x, c_y, c_z, r_sq
	; ->
	; di: address of c_x, c_y, c_z, r_sq
	; ax: did_hit
	ray_sphere:
		; fpu stack
		; v_y, v_x

		; Compute <v, c>
		fld st0
		fmul dword [di]
		fld st2
		fmul dword [di+4]
		faddp
		fld dword [di+8]
		fsubp

		; fpu stack
		; v_y, v_x, <v, c>

		; Compute <c, c>
		fld dword [di]
		fmul st0, st0
		fld dword [di+4]
		fmul st0, st0
		faddp
		fld dword [di+8]
		fmul st0, st0
		faddp

		; fpu stack
		; v_y, v_x, <v, c>, <c, c>

		; Compute <c, c> - r_sq
		fsub dword [di+12]

		; fpu stack
		; v_y, v_x, <v, c>, <c, c> - r_sq

		; Compute <v, c>^2
		fld st1
		fmul st0, st0

		; fpu stack
		; v_y, v_x, <v, c>, <c, c> - r_sq, <v, c>^2

		; Compute <v, c>^2 - <c, c> + r_sq
		fsubrp

		; fpu stack
		; v_y, v_x, <v, c>, <v, c>^2 - <c, c> + r_sq
		
		; Compute t
		fsqrt ; NOTE: produces Invalid Op exception when st0 is negative, which is used later
		fsubp
		
		; fpu stack
		; v_y, v_x, t

		; Determine is discriminant is negative and if t is negative
		ftst
		fstsw word [ray_sphere_sw]
		fnclex

		mov ax, word [ray_sphere_sw]
		and ah, al
		and al, 1

		ret

	ray_y_origin: dd 0.75
	ray_step: dd 0.003125

	constant_15: dw 15
	light_to_color_float_xchg: dd 0xFFFFFFFF

	rand_01_seed: dd 3.1415926535
	rand_01_phi: dd 1.618033988749894848204586834365638117

	ray_sphere_sw: dw 0

	center_sphere: dd 0.0, -6.0, -20.0, 0.1


times 510-($-$$) db 0
dw 0xAA55
