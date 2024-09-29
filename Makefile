compile: 
	./assemble.sh

link: 
	ld -o ./build/editor.out -dynamic-linker /lib64/ld-linux-x86-64.so.2 -lc ./build/*.o 

run: compile link
	./build/editor.out $(args)

clean:
	rm ./*.o
	rm ./*.out

all: compile link run clean
