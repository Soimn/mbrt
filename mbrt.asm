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

	fninit

	xor dx, dx
	fld dword [ray_y_origin]
	y_loop:
		xor cx, cx
		fld1
		fchs
		x_loop:
			fnsave [0x7F00]

			; Setup fpu stack
			; v_x, v_y, v_z, q_x, q_y, q_z
			frstor [0x7F00]
			fxch
			fld1
			fchs ; v_z = -1

			call trace_ray
			
			fild word [constant_15]
			fmulp
			fistp word [0x7E00]

			mov ah, 0x0C
			mov al, byte [0x7E00]
			mov bh, 0
			int 0x10

			frstor [0x7F00]

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

trace_ray:
	; Normalize v
	; fpu stack
	; v_x, v_y, v_z
	fld st0
	fmul st0, st0
	fld st2
	fmul st0, st0
	faddp
	fld st3
	fmul st0, st0
	faddp
	fsqrt
	fdiv st3, st0
	fdiv st2, st0
	fdivp

	; Setup sphere
	; fpu stack
	; v_x, v_y, v_z
	fldpi
	fldpi
	fchs
	; fpu stack
	; v_x, v_y, v_z, r_sq, q_z

	; Compute <v, q>
	; fpu stack
	; v_x, v_y, v_z, r_sq, q_z
	fld st0
	fmul st0, st3
	fxch st2
	; fpu stack
	; v_x, v_y, v_z, <v, q>, q_z, r_sq

	; Compute <q, q> - r^2
	; fpu stack
	; v_x, v_y, v_z, <v, q>, q_z, r_sq
	fxch
	fmul st0, st0
	fsubrp
	; fpu stack
	; v_x, v_y, v_z, r_sq, <v, q>, <q, q> - r^2
	
	; Compute sqrt((<v, q>)^2 - (<q, q> - r^2))
	; fpu stack
	; v_x, v_y, v_z, <v, q>, <q, q> - r^2
	fld st1
	fmul st0, st0
	fsubrp
	fsqrt ; causes an Invalid Op exception when the arg is negative, used to determine hit later
	; fpu stack
	; v_x, v_y, v_z, <v, q>/<v, v>, sqrt((<v, q>)^2 - (<q, q> - r^2))

	; Compute t
	; fpu stack
	; v_x, v_y, v_z, <v, q>/<v, v>, sqrt((<v, q>)^2 - (<q, q> - r^2))
	fsubp
	ftst
	fstsw ax
	fnclex
	or al, ah
	and al, 1
	; fpu stack
	; v_x, v_y, v_z, t

	cmp al, 0
	jne hit_sky
		; Compute intersection p
		; fpu stack
		; v_x, v_y, v_z, t
		fmul st3, st0
		fmul st2, st0
		fmulp
		; fpu stack
		; p_x, p_y, p_z

		; Compute normal
		; fpu stack
		; p_x, p_y, p_z
		fld st2
		fld st2
		fld st2
		fldpi
		faddp
		; fpu stack
		; p_x, p_y, p_z, n_x, n_y, n_z

		; Normalize normal
		; fpu stack
		; p_x, p_y, p_z, n_x, n_y, n_z
		fld st2
		fmul st0, st0
		fld st2
		fmul st0, st0
		faddp
		fld st1
		fmul st0, st0
		faddp
		fsqrt
		fdiv st3, st0
		fdiv st2, st0
		fdivp
		; fpu stack
		; p_x, p_y, p_z, n_x, n_y, n_z

		; Compute <n, l>
		; l is [-1, 1, lg2(e) + lg10(2)]
		; fpu stack
		; p_x, p_y, p_z, n_x, n_y, n_z
		fldl2e
		fldlg2
		faddp
		fmulp
		fxch st2
		fsubp
		faddp

		fldl2e
		fldlg2
		faddp
		fmul st0, st0
		fld1
		fadd st1, st0
		faddp
		fsqrt
		fdivp
		; fpu stack
		; p_x, p_y, p_z, <n, l>

		; Multiply with albedo
		; fpu stack
		; p_x, p_y, p_z, <n, l>
		fldln2
		fmulp
		; fpu stack
		; p_x, p_y, p_z, L

		jmp hit_end
	hit_sky:
		fld1
		fldlg2
		fld1
		fadd st0, st0
		fdivp
		fsubp
	hit_end:

	ret

	ray_y_origin: dd 0.75
	ray_step: dd 0.003125

	constant_15: dw 15


times 510-($-$$) db 0
dw 0xAA55
