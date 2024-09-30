create_build:
	mkdir -p ./build/

assemble: create_build
	./assemble.sh

link: 
	ld -o ./build/editor.out ./build/*.o 

run: assemble link
	./build/editor.out $(args)

clean:
	rm ./*.o
	rm ./*.out

all: assemble link run clean
