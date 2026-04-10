## Conway's Life ##

Graphical Conway's Game of Life for macOS in NASM with `SDL2`.

The field is logically unbounded: the program stores only live cells, and the window shows the current viewport controlled by the camera.

At startup the program asks in the terminal how many live cells to create, then places them randomly near the origin and opens a window with green cells.
The window includes a grid, and the title bar shows the current generation, live cell count, and run / pause state.

**Build**

```shell
make
```

**Run**

```shell
./life
```

**Controls**

```text
Space        pause / resume
W A S D      move camera
Arrow keys   move camera
=            zoom in
-            zoom out
Esc          quit
```
