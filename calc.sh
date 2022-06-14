#!/bin/bash

nasm -f elf64 calc.asm
ld calc.o -o calc

echo 'done'
echo 'try:'

./calc