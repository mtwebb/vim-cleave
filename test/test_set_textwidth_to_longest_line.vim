" Test cleave#set_textwidth_to_longest_line() function with multi-byte characters and tabs

" Test 1: ASCII-only content
function! Test_set_textwidth_ascii()
    " Create a new buffer with ASCII content
    enew
    call setline(1, ['short', 'medium line', 'this is a very long line'])
    
    let result = cleave#set_textwidth_to_longest_line()
    let expected = 25  " Length of "this is a very long line"
    
    if result == expected && &textwidth == expected
        echo "PASS: ASCII textwidth calculation"
    else
        echo "FAIL: ASCII textwidth calculation. Expected: " . expected . ", Got: " . result . ", textwidth: " . &textwidth
    endif
    
    bdelete!
endfunction

" Test 2: Wide characters (CJK)
function! Test_set_textwidth_wide_chars()
    " Create a new buffer with wide characters
    enew
    call setline(1, ['short', '中文测试', 'ASCII and 中文 mixed'])
    
    let result = cleave#set_textwidth_to_longest_line()
    " "ASCII and 中文 mixed" = 10 ASCII chars + 2 wide chars (4 display width) = 14 display width
    let expected = 14
    
    if result == expected && &textwidth == expected
        echo "PASS: Wide character textwidth calculation"
    else
        echo "FAIL: Wide character textwidth calculation. Expected: " . expected . ", Got: " . result . ", textwidth: " . &textwidth
    endif
    
    bdelete!
endfunction

" Test 3: Tabs
function! Test_set_textwidth_tabs()
    " Save original tabstop
    let original_tabstop = &tabstop
    set tabstop=4
    
    " Create a new buffer with tabs
    enew
    call setline(1, ['short', "tab\there", "multiple\ttabs\there"])
    
    let result = cleave#set_textwidth_to_longest_line()
    " "multiple\ttabs\there" = 8 chars + 4 spaces (tab) + 4 chars + 4 spaces (tab) + 4 chars = 24 display width
    let expected = 24
    
    if result == expected && &textwidth == expected
        echo "PASS: Tab textwidth calculation"
    else
        echo "FAIL: Tab textwidth calculation. Expected: " . expected . ", Got: " . result . ", textwidth: " . &textwidth
    endif
    
    " Restore original tabstop
    execute 'set tabstop=' . original_tabstop
    bdelete!
endfunction

" Test 4: Trailing whitespace removal
function! Test_set_textwidth_trailing_whitespace()
    " Create a new buffer with trailing whitespace
    enew
    call setline(1, ['short', 'medium line   ', 'long line with trailing spaces    '])
    
    let result = cleave#set_textwidth_to_longest_line()
    let expected = 30  " Length of "long line with trailing spaces" without trailing spaces
    
    if result == expected && &textwidth == expected
        echo "PASS: Trailing whitespace removal"
    else
        echo "FAIL: Trailing whitespace removal. Expected: " . expected . ", Got: " . result . ", textwidth: " . &textwidth
    endif
    
    bdelete!
endfunction

" Test 5: Mixed content (emoji, wide chars, tabs)
function! Test_set_textwidth_mixed()
    " Save original tabstop
    let original_tabstop = &tabstop
    set tabstop=8
    
    " Create a new buffer with mixed content
    enew
    call setline(1, ['ASCII', '中文', "tab\there", 'emoji 😀 test', "mixed\t中文\t😀"])
    
    let result = cleave#set_textwidth_to_longest_line()
    " "mixed\t中文\t😀" = 5 chars + 3 spaces (tab to column 8) + 2 wide chars (4 display) + 8 spaces (tab to column 16) + 1 emoji (2 display) = 22 display width
    let expected = 22
    
    if result == expected && &textwidth == expected
        echo "PASS: Mixed content textwidth calculation"
    else
        echo "FAIL: Mixed content textwidth calculation. Expected: " . expected . ", Got: " . result . ", textwidth: " . &textwidth
    endif
    
    " Restore original tabstop
    execute 'set tabstop=' . original_tabstop
    bdelete!
endfunction

" Run all tests
call Test_set_textwidth_ascii()
call Test_set_textwidth_wide_chars()
call Test_set_textwidth_tabs()
call Test_set_textwidth_trailing_whitespace()
call Test_set_textwidth_mixed()

echo "Test suite completed for cleave#set_textwidth_to_longest_line()"