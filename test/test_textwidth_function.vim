" Test for cleave#set_textwidth_to_longest_line() function
" Run with: vim -c "source autoload/cleave.vim" -c "source test/test_textwidth_function.vim" -c "call RunTextwidthTests()" -c "qa!"

function! AssertEqual(expected, actual, message)
    if a:expected != a:actual
        echomsg "FAIL: " . a:message
        echomsg "  Expected: " . string(a:expected)
        echomsg "  Actual: " . string(a:actual)
        return 0
    else
        echomsg "PASS: " . a:message
        return 1
    endif
endfunction

function! TestTextwidthASCII()
    echomsg "Testing ASCII content..."
    let passed = 0
    let total = 0
    
    enew
    call setline(1, ['short', 'medium line', 'this is a very long line'])
    
    let result = cleave#set_textwidth_to_longest_line()
    let expected = 25  " Length of "this is a very long line"
    
    let total += 1
    let passed += AssertEqual(expected, result, "ASCII: function return value")
    let total += 1
    let passed += AssertEqual(expected, &textwidth, "ASCII: textwidth option set")
    
    bdelete!
    return [passed, total]
endfunction

function! TestTextwidthWideChars()
    echomsg "Testing wide characters..."
    let passed = 0
    let total = 0
    
    enew
    call setline(1, ['short', '中文测试', 'ASCII and 中文 mixed'])
    
    let result = cleave#set_textwidth_to_longest_line()
    " "ASCII and 中文 mixed" = 10 ASCII chars + 2 wide chars (4 display width) = 14 display width
    let expected = 14
    
    let total += 1
    let passed += AssertEqual(expected, result, "Wide chars: function return value")
    let total += 1
    let passed += AssertEqual(expected, &textwidth, "Wide chars: textwidth option set")
    
    bdelete!
    return [passed, total]
endfunction

function! TestTextwidthTabs()
    echomsg "Testing tabs..."
    let passed = 0
    let total = 0
    
    " Save original tabstop
    let original_tabstop = &tabstop
    set tabstop=4
    
    enew
    call setline(1, ['short', "tab\there", "multiple\ttabs\there"])
    
    let result = cleave#set_textwidth_to_longest_line()
    " "multiple\ttabs\there" = 8 chars + 4 spaces (tab) + 4 chars + 4 spaces (tab) + 4 chars = 24 display width
    let expected = 24
    
    let total += 1
    let passed += AssertEqual(expected, result, "Tabs: function return value")
    let total += 1
    let passed += AssertEqual(expected, &textwidth, "Tabs: textwidth option set")
    
    " Restore original tabstop
    execute 'set tabstop=' . original_tabstop
    bdelete!
    return [passed, total]
endfunction

function! TestTextwidthTrailingWhitespace()
    echomsg "Testing trailing whitespace removal..."
    let passed = 0
    let total = 0
    
    enew
    call setline(1, ['short', 'medium line   ', 'long line with trailing spaces    '])
    
    let result = cleave#set_textwidth_to_longest_line()
    let expected = 30  " Length of "long line with trailing spaces" without trailing spaces
    
    let total += 1
    let passed += AssertEqual(expected, result, "Trailing whitespace: function return value")
    let total += 1
    let passed += AssertEqual(expected, &textwidth, "Trailing whitespace: textwidth option set")
    
    bdelete!
    return [passed, total]
endfunction

function! RunTextwidthTests()
    echomsg "Running textwidth function tests..."
    echomsg "=================================="
    
    let total_passed = 0
    let total_tests = 0
    
    let [p1, t1] = TestTextwidthASCII()
    let total_passed += p1
    let total_tests += t1
    
    let [p2, t2] = TestTextwidthWideChars()
    let total_passed += p2
    let total_tests += t2
    
    let [p3, t3] = TestTextwidthTabs()
    let total_passed += p3
    let total_tests += t3
    
    let [p4, t4] = TestTextwidthTrailingWhitespace()
    let total_passed += p4
    let total_tests += t4
    
    echomsg "=================================="
    echomsg "TOTAL: " . total_passed . "/" . total_tests . " tests passed"
    
    if total_passed == total_tests
        echomsg "ALL TESTS PASSED!"
        return 0
    else
        echomsg "SOME TESTS FAILED!"
        return 1
    endif
endfunction