" Comprehensive tests for cleave#join_buffers functionality
" Run with: vim -c "source test/test_join_buffers_comprehensive.vim" -c "call RunJoinBuffersTests()" -c "qa!"

function! AssertEqual(expected, actual, message)
    if a:expected != a:actual
        echomsg "FAIL: " . a:message
        echomsg "  Expected: '" . a:expected . "'"
        echomsg "  Actual: '" . a:actual . "'"
        return 0
    else
        echomsg "PASS: " . a:message
        return 1
    endif
endfunction

function! TestJoinSpacingLogic()
    echomsg "Testing join spacing logic..."
    let passed = 0
    let total = 0
    
    " Test case 1: Line exactly at cleave column
    let left_line = "Hello "
    let right_line = "World"
    let cleave_col = 7
    
    if empty(right_line)
        let result = left_line
    else
        let left_len = strdisplaywidth(left_line)
        let padding_needed = cleave_col - 1 - left_len
        let padding = padding_needed > 0 ? repeat(' ', padding_needed) : ''
        let result = left_line . padding . right_line
    endif
    
    let total += 1
    let passed += AssertEqual("Hello World", result, "Line exactly at cleave column")
    
    " Test case 2: Line shorter than cleave column with empty right
    let left_line2 = "Hi"
    let right_line2 = ""
    let cleave_col2 = 7
    
    if empty(right_line2)
        let result2 = left_line2
    else
        let left_len2 = strdisplaywidth(left_line2)
        let padding_needed2 = cleave_col2 - 1 - left_len2
        let padding2 = padding_needed2 > 0 ? repeat(' ', padding_needed2) : ''
        let result2 = left_line2 . padding2 . right_line2
    endif
    
    let total += 1
    let passed += AssertEqual("Hi", result2, "Short line with empty right part")
    
    " Test case 3: Line shorter than cleave column with non-empty right
    let left_line3 = "Hi"
    let right_line3 = "there"
    let cleave_col3 = 7
    
    if empty(right_line3)
        let result3 = left_line3
    else
        let left_len3 = strdisplaywidth(left_line3)
        let padding_needed3 = cleave_col3 - 1 - left_len3
        let padding3 = padding_needed3 > 0 ? repeat(' ', padding_needed3) : ''
        let result3 = left_line3 . padding3 . right_line3
    endif
    
    let total += 1
    let passed += AssertEqual("Hi    there", result3, "Short line with non-empty right part")
    
    " Test case 4: CJK characters
    let left_line4 = "你好"
    let right_line4 = "世界"
    let cleave_col4 = 6
    
    if empty(right_line4)
        let result4 = left_line4
    else
        let left_len4 = strdisplaywidth(left_line4)  " Should be 4
        let padding_needed4 = cleave_col4 - 1 - left_len4  " 6 - 1 - 4 = 1
        let padding4 = padding_needed4 > 0 ? repeat(' ', padding_needed4) : ''
        let result4 = left_line4 . padding4 . right_line4
    endif
    
    let total += 1
    let passed += AssertEqual("你好 世界", result4, "CJK characters with padding")
    
    " Test case 5: Left line longer than cleave column (should not add padding)
    let left_line5 = "Very long line"
    let right_line5 = "short"
    let cleave_col5 = 7
    
    if empty(right_line5)
        let result5 = left_line5
    else
        let left_len5 = strdisplaywidth(left_line5)  " Should be 14
        let padding_needed5 = cleave_col5 - 1 - left_len5  " 7 - 1 - 14 = -8
        let padding5 = padding_needed5 > 0 ? repeat(' ', padding_needed5) : ''
        let result5 = left_line5 . padding5 . right_line5
    endif
    
    let total += 1
    let passed += AssertEqual("Very long lineshort", result5, "Left line longer than cleave column")
    
    echomsg "TestJoinSpacingLogic: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction

function! TestSplitAndJoinRoundTrip()
    echomsg "Testing split and join round-trip consistency..."
    let passed = 0
    let total = 0
    
    " Test various content types
    let test_cases = [
        \ ["Simple ASCII line", 10],
        \ ["Line with    multiple    spaces", 15],
        \ ["你好世界测试", 8],
        \ ["Mixed 你好 content", 12],
        \ ["Code example: function()", 18],
        \ ["", 5],
        \ ["Single", 3],
        \ ["Exact length", 12]
    \ ]
    
    for [original_content, cleave_col] in test_cases
        " Split the content
        let left_part = cleave#virtual_strpart(original_content, 1, cleave_col)
        let right_part = cleave#virtual_strpart(original_content, cleave_col)
        
        " Join using the new logic
        if empty(right_part)
            let rejoined = left_part
        else
            let left_len = strdisplaywidth(left_part)
            let padding_needed = cleave_col - 1 - left_len
            let padding = padding_needed > 0 ? repeat(' ', padding_needed) : ''
            let rejoined = left_part . padding . right_part
        endif
        
        let total += 1
        let passed += AssertEqual(original_content, rejoined, "Round-trip: '" . original_content . "' at col " . cleave_col)
    endfor
    
    echomsg "TestSplitAndJoinRoundTrip: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction

function! TestEdgeCases()
    echomsg "Testing edge cases..."
    let passed = 0
    let total = 0
    
    " Edge case 1: Empty left, non-empty right
    let left_line = ""
    let right_line = "content"
    let cleave_col = 5
    
    if empty(right_line)
        let result = left_line
    else
        let left_len = strdisplaywidth(left_line)
        let padding_needed = cleave_col - 1 - left_len
        let padding = padding_needed > 0 ? repeat(' ', padding_needed) : ''
        let result = left_line . padding . right_line
    endif
    
    let total += 1
    let passed += AssertEqual("    content", result, "Empty left, non-empty right")
    
    " Edge case 2: Both empty
    let left_line2 = ""
    let right_line2 = ""
    let cleave_col2 = 5
    
    if empty(right_line2)
        let result2 = left_line2
    else
        let left_len2 = strdisplaywidth(left_line2)
        let padding_needed2 = cleave_col2 - 1 - left_len2
        let padding2 = padding_needed2 > 0 ? repeat(' ', padding_needed2) : ''
        let result2 = left_line2 . padding2 . right_line2
    endif
    
    let total += 1
    let passed += AssertEqual("", result2, "Both parts empty")
    
    " Edge case 3: Cleave column 1 (should not happen in practice, but test anyway)
    let left_line3 = ""
    let right_line3 = "fullcontent"
    let cleave_col3 = 1
    
    if empty(right_line3)
        let result3 = left_line3
    else
        let left_len3 = strdisplaywidth(left_line3)
        let padding_needed3 = cleave_col3 - 1 - left_len3
        let padding3 = padding_needed3 > 0 ? repeat(' ', padding_needed3) : ''
        let result3 = left_line3 . padding3 . right_line3
    endif
    
    let total += 1
    let passed += AssertEqual("fullcontent", result3, "Cleave at column 1")
    
    echomsg "TestEdgeCases: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction

function! RunJoinBuffersTests()
    echomsg "Running comprehensive join buffers tests..."
    echomsg "============================================="
    
    let total_passed = 0
    let total_tests = 0
    
    let [p1, t1] = TestJoinSpacingLogic()
    let total_passed += p1 | let total_tests += t1
    
    let [p2, t2] = TestSplitAndJoinRoundTrip()
    let total_passed += p2 | let total_tests += t2
    
    let [p3, t3] = TestEdgeCases()
    let total_passed += p3 | let total_tests += t3
    
    echomsg "============================================="
    echomsg "JOIN BUFFERS TEST RESULTS:"
    echomsg "Total: " . total_passed . "/" . total_tests . " tests passed"
    
    if total_passed == total_tests
        echomsg "🎉 ALL JOIN TESTS PASSED!"
    else
        echomsg "❌ " . (total_tests - total_passed) . " TESTS FAILED!"
    endif
    
    return total_passed == total_tests ? 0 : 1
endfunction