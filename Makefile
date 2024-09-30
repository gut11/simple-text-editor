compile: 
	./assemble.sh

link: 
	ld -o ./build/editor.out ./build/*.o 

run: compile link
	./build/editor.out $(args)

clean:
	rm ./*.o
	rm ./*.out

all: compile link run clean
