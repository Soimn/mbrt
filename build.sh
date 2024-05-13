#!/bin/bash
nasm mbrt.asm -f bin -o mbrt.bin
dd if=./mbrt.bin of=./mbrt.img bs=512 count=1
