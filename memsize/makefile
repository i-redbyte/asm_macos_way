all: memsize

memsize: memsize.o
	clang -nostartfiles -o memsize memsize.o -e _start -Wl,-no_pie

memsize.o: memsize.asm
	nasm -f macho64 memsize.asm -o memsize.o

clean:
	rm -f memsize memsize.o