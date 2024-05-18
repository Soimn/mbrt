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

	; TODO: Possibly remove
	mov ax, 0xFFFF
	mov ss, ax
	mov sp, ax

	fninit
	sub sp, 108
	mov bp, sp

	xor dx, dx
	fld dword [ray_y_origin]
	y_loop:
		xor cx, cx
		fld1
		fchs
		x_loop:
			fnsave [ss:bp]

			; Setup fpu stack
			; v_x, v_y, v_z, q_x, q_y, q_z
			frstor [ss:bp]
			fxch
			fld1
			fchs ; v_z = -1

			fldz ; q_x = 0
			fldz ; q_y = 0

			fld1
			fadd st0, st0
			fadd st0, st0
			fchs ; q_z = -4

			fld1 ; r_sq = 1
			fstp dword [ray_sphere_args_r_sq]

			call ray_sphere
			
			cmp al, 1
			je color_set_black
				fld1
				jmp color_set_end
			color_set_black:
				fldz
			color_set_end:
			
			fild word [constant_15]
			fmulp
			fistp word [light_to_color_float_xchg]

			mov ah, 0x0C
			mov al, byte [light_to_color_float_xchg]
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

; xorshift would be better but x' = (x*pi + golden_ratio) mod 1 looks random enough, and requires much less code
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
; v_x, v_y, v_z, q_x, q_y, q_z
; ->
; v_x, v_y, v_z, t
ray_sphere:

	; Compute <v, q>
	; fpu stack
	; v_x, v_y, v_z, q_x, q_y, q_z
	fld st5
	fmul st0, st3
	fld st5
	fmul st0, st3
	faddp
	fld st4
	fmul st2
	faddp
	fxch st3
	; fpu stack
	; v_x, v_y, v_z, <v, q>, q_y, q_z, q_x

	; Compute <q, q> - r^2
	; fpu stack
	; v_x, v_y, v_z, <v, q>, q_y, q_z, q_x
	fmul st0, st0
	fxch
	fmul st0, st0
	faddp
	fxch
	fmul st0, st0
	faddp
	fsub dword [ray_sphere_args_r_sq]
	; fpu stack
	; v_x, v_y, v_z, <v, q>, <q, q> - r^2
	
	; Compute <v, q>/<v, v> and (<q, q> - r^2)/<v, v>
	; fpu stack
	; v_x, v_y, v_z, <v, q>, <q, q> - r^2
	fld st4
	fmul st0, st0
	fld st4
	fmul st0, st0
	fld st4
	fmul st0, st0
	faddp
	faddp
	fdiv st2, st0
	fdivp
	; fpu stack
	; v_x, v_y, v_z, <v, q>/<v, v>, (<q, q> - r^2)/<v, v>
	
	; Compute sqrt((<v, q>/<v, v>)^2 - (<q, q> - r^2)/<v, v>)
	; fpu stack
	; v_x, v_y, v_z, <v, q>/<v, v>, (<q, q> - r^2)/<v, v>
	fld st1
	fmul st0, st0
	fsubrp
	fsqrt ; causes an Invalid Op exception when the arg is negative, used to determine hit later
	; fpu stack
	; v_x, v_y, v_z, <v, q>/<v, v>, sqrt((<v, q>/<v, v>)^2 - (<q, q> - r^2)/<v, v>)

	; Compute t
	; fpu stack
	; v_x, v_y, v_z, <v, q>/<v, v>, sqrt((<v, q>/<v, v>)^2 - (<q, q> - r^2)/<v, v>)
	fsubp
	ftst
	fstsw ax
	or ah, al
	and al, 1
	; fpu stack
	; v_x, v_y, v_z, t

	ret

	ray_y_origin: dd 0.75
	ray_step: dd 0.003125

	constant_15: dw 15
	light_to_color_float_xchg: dd 0xFFFFFFFF

	rand_01_seed: dd 2.718281828459045
	rand_01_phi: dd 1.618033988749894848204586834365638117

	ray_sphere_args_r_sq: dd 0

times 510-($-$$) db 0
dw 0xAA55
