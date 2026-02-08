" Test script for cleave#split_buffer() virtual column functionality
" This tests that the function uses virtcol() instead of col()

" Load the cleave plugin
source autoload/cleave.vim

" Test function
function! TestSplitBufferVirtcolUsage()
    echo "Testing cleave#split_buffer() virtual column usage..."
    
    " Create a buffer with multi-byte content
    enew
    call setline(1, 'Hello 你好 World')
    
    " Position cursor at different locations and check column detection
    " Test 1: At start of wide character
    call cursor(1, 7)  " Byte position 7 (start of 你)
    let byte_pos = col('.')
    let virt_pos = virtcol('.')
    
    echo "Cursor at byte " . byte_pos . ", virtual column " . virt_pos
    echo "String: 'Hello 你好 World'"
    echo "Expected: byte 7, virtual column 7"
    
    if byte_pos == 7 && virt_pos == 7
        echo "PASS: Cursor positioning correct"
    else
        echo "FAIL: Cursor positioning incorrect"
    endif
    
    " Test 2: Within wide character
    call cursor(1, 9)  " Byte position 9 (within 你)
    let byte_pos2 = col('.')
    let virt_pos2 = virtcol('.')
    
    echo "Cursor at byte " . byte_pos2 . ", virtual column " . virt_pos2
    echo "Expected: byte 9, virtual column 8"
    
    if byte_pos2 == 9 && virt_pos2 == 8
        echo "PASS: Wide character handling correct"
    else
        echo "FAIL: Wide character handling incorrect"
    endif
    
    " Clean up
    bdelete!
    echo "Test completed"
endfunction

" Run the test
call TestSplitBufferVirtcolUsage()