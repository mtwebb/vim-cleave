

Vim cleave is vim plugin that splits a buffer vertically into a left buffer and
right buffer and replaces the window with two windows showing the left and
right buffers.  contents of the buffers should be in same position but now in two files and two windows

start by splitting the buffer based on cursor position. Later will add other ways to split the file. 
the content of each line up to the split position go into the left buffer and contents from the cursor after go into the right buffer 
name the buffers the same as the file that was split but with a .left and a .right suffix



