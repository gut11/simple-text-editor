#!/usr/bin/env bash

for file in ./src/*.asm; do
	base_name="$(basename "$file" .asm)"
	nasm -f elf64 $file -o "./build/${base_name}.o"
done
