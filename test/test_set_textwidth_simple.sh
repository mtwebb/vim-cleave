#!/bin/bash

# Simple test for cleave#set_textwidth_to_longest_line() function
vim -u NONE -c "
source autoload/cleave.vim
enew
call setline(1, ['short', 'medium line', 'this is a very long line'])
let result = cleave#set_textwidth_to_longest_line()
echo 'ASCII test - Result: ' . result . ', textwidth: ' . &textwidth
bdelete!

enew
call setline(1, ['short', '中文测试', 'ASCII and 中文 mixed'])
let result = cleave#set_textwidth_to_longest_line()
echo 'Wide char test - Result: ' . result . ', textwidth: ' . &textwidth
bdelete!

qa!
"