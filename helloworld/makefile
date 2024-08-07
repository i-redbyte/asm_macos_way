hello: hello.o
		clang -nostartfiles -o hello hello.o -e _start -Wl,-no_pie
hello.o: hello.asm
		nasm -f macho64 hello.asm -o hello.o