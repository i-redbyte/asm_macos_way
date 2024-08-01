## Mean number ##

This program that treats all its command line arguments as integers and displays their average as a floating point number.

**Compile and build**

```
 nasm -fmacho64 mean.asm && gcc -o mean mean.o
``` 

**Run**

Example1:

```shell
./mean 4 4 8 8 
```

**Output**

```shell
6
```

Example2:

```shell
./mean 5 5 5 100 
```

**Output**

```shell
28.75
```