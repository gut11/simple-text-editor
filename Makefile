compile:
	nasm -f elf64 *.asm -o editor.o

link: 
	ld -dynamic-linker /lib64/ld-linux-x86-64.so.2 -lc *.o -o editor.out

run: compile link
	./editor.out $(args)

clean:
	rm ./*.o
	rm ./*.out

all: compile link run clean
