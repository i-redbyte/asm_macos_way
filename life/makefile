SDL_LIBS := $(shell pkg-config --libs sdl2)

all: life

life: life.o
	clang -o life life.o $(SDL_LIBS)

life.o: life.asm
	nasm -f macho64 life.asm -o life.o

clean:
	rm -f life life.o
