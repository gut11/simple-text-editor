compile:
	nasm -f elf64 *.asm -o editor.o

link:
	ld editor.o -o editor.out

run:
	./editor.out

clean:
	rm ./*.o
	rm ./*.out

all: compile link run clean
