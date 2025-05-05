nasm -f elf64 printf.s -o printf.o
ld printf.o -o printf
./printf
