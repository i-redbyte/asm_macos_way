## Displays a symbolic triangle pointing down  ##

**Build and run:**

```shell
 nasm -f macho64 triangle.asm && gcc -nostartfiles -o triangle triangle.o -e _start -Wl,-no_pie && ./triangle
```

Output:

```
//////////////////
/////////////////
////////////////
///////////////
//////////////
/////////////
////////////
///////////
//////////
/////////
////////
///////
//////
/////
////
///
//
/
```