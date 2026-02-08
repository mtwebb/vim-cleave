" Test for CleaveJoin spacing issues
" Run with: vim -c "source test/test_join_spacing.vim" -c "call TestJoinSpacing()" -c "qa!"

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

function! TestJoinSpacing()
    echomsg "Testing CleaveJoin spacing calculation..."
    let passed = 0
    let total = 0
    
    " Test case 1: Simple ASCII content
    " Original: "Hello World"
    " Split at column 7: "Hello " | "World"
    " When joined should be: "Hello World" (no extra spaces)
    
    let left_line = "Hello "
    let right_line = "World"
    let cleave_col = 7
    
    " Current (incorrect) calculation
    let left_len = strdisplaywidth(left_line)  " = 6
    let padding_needed_wrong = cleave_col - 1 - left_len  " = 7 - 1 - 6 = 0
    let padding_wrong = padding_needed_wrong > 0 ? repeat(' ', padding_needed_wrong) : ''
    let result_wrong = left_line . padding_wrong . right_line
    
    " Correct calculation should be
    let padding_needed_correct = cleave_col - 1 - left_len  " Actually this is correct for this case
    
    let total += 1
    let passed += AssertEqual("Hello World", result_wrong, "Simple ASCII join")
    
    " Test case 2: Left line shorter than cleave column
    " Original: "Hi there"  
    " Split at column 7: "Hi " | "there"
    " When joined should be: "Hi    there" (3 spaces to reach column 7)
    
    let left_line2 = "Hi "
    let right_line2 = "there"
    let cleave_col2 = 7
    
    let left_len2 = strdisplaywidth(left_line2)  " = 3
    let padding_needed2 = cleave_col2 - 1 - left_len2  " = 7 - 1 - 3 = 3
    let padding2 = padding_needed2 > 0 ? repeat(' ', padding_needed2) : ''
    let result2 = left_line2 . padding2 . right_line2
    
    let total += 1
    let passed += AssertEqual("Hi    there", result2, "Short left line join")
    
    " Test case 3: CJK characters
    " Original: "你好 World"
    " Split at column 6: "你好" | " World"  
    " When joined should be: "你好  World" (2 spaces to reach column 6)
    
    let left_line3 = "你好"
    let right_line3 = " World"
    let cleave_col3 = 6
    
    let left_len3 = strdisplaywidth(left_line3)  " = 4 (CJK chars are 2 columns each)
    let padding_needed3 = cleave_col3 - 1 - left_len3  " = 6 - 1 - 4 = 1
    let padding3 = padding_needed3 > 0 ? repeat(' ', padding_needed3) : ''
    let result3 = left_line3 . padding3 . right_line3
    
    let total += 1
    let passed += AssertEqual("你好  World", result3, "CJK character join")
    
    " Test case 4: Debug the actual issue - what happens when we split and rejoin
    echomsg ""
    echomsg "=== Debugging actual split/join behavior ==="
    
    " Create a test buffer with content
    enew
    call setline(1, "Hello World")
    
    " Simulate split at column 7
    let original_line = getline(1)
    let left_part = cleave#virtual_strpart(original_line, 1, 7)
    let right_part = cleave#virtual_strpart(original_line, 7)
    
    echomsg "Original: '" . original_line . "'"
    echomsg "Split at column 7:"
    echomsg "  Left: '" . left_part . "' (length: " . strdisplaywidth(left_part) . ")"
    echomsg "  Right: '" . right_part . "' (length: " . strdisplaywidth(right_part) . ")"
    
    " Now simulate join
    let left_len_debug = strdisplaywidth(left_part)
    let padding_needed_debug = 7 - 1 - left_len_debug
    let padding_debug = padding_needed_debug > 0 ? repeat(' ', padding_needed_debug) : ''
    let rejoined = left_part . padding_debug . right_part
    
    echomsg "Join calculation:"
    echomsg "  Left length: " . left_len_debug
    echomsg "  Padding needed: " . padding_needed_debug
    echomsg "  Padding: '" . padding_debug . "'"
    echomsg "  Rejoined: '" . rejoined . "'"
    
    let total += 1
    let passed += AssertEqual(original_line, rejoined, "Split/rejoin consistency")
    
    bdelete!
    
    echomsg ""
    echomsg "TestJoinSpacing: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction