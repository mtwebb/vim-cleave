" Test file for combined line construction logic in cleave#join_buffers()
" This tests various character widths and padding calculations

function! TestCombinedLineConstruction()
    echo "=== Testing Combined Line Construction Logic ==="
    
    " Test the core logic that combines left and right lines
    let test_cases = [
        \ {
        \   'name': 'ASCII only',
        \   'left': 'Hello',
        \   'right': 'World',
        \   'cleave_col': 10
        \ },
        \ {
        \   'name': 'Left with wide chars',
        \   'left': 'Hello 世界',
        \   'right': 'Test',
        \   'cleave_col': 15
        \ },
        \ {
        \   'name': 'Empty left',
        \   'left': '',
        \   'right': 'Content',
        \   'cleave_col': 8
        \ },
        \ {
        \   'name': 'Empty right',
        \   'left': 'Content',
        \   'right': '',
        \   'cleave_col': 12
        \ },
        \ {
        \   'name': 'Both empty',
        \   'left': '',
        \   'right': '',
        \   'cleave_col': 10
        \ },
        \ {
        \   'name': 'Left with tab',
        \   'left': "Hello\tTab",
        \   'right': 'Right',
        \   'cleave_col': 20
        \ },
        \ {
        \   'name': 'CJK characters',
        \   'left': '测试内容',
        \   'right': '右侧',
        \   'cleave_col': 12
        \ },
        \ {
        \   'name': 'Greek letters',
        \   'left': 'αβγδε',
        \   'right': 'ζηθ',
        \   'cleave_col': 10
        \ },
        \ {
        \   'name': 'Mixed content',
        \   'left': 'Mix 中文 αβ',
        \   'right': 'Right 测试',
        \   'cleave_col': 18
        \ }
    \ ]
    
    for test_case in test_cases
        echo printf("Test: %s", test_case.name)
        
        let left_line = test_case.left
        let right_line = test_case.right
        let cleave_column = test_case.cleave_col
        
        " Apply the same logic as in cleave#join_buffers()
        let left_len = strdisplaywidth(left_line)
        let padding_needed = cleave_column - 1 - left_len
        let padding = padding_needed > 0 ? repeat(' ', padding_needed) : ''
        let combined_line = left_line . padding . right_line
        
        echo printf("  Left: '%s' (display width: %d)", left_line, left_len)
        echo printf("  Right: '%s'", right_line)
        echo printf("  Cleave column: %d", cleave_column)
        echo printf("  Padding needed: %d", padding_needed)
        echo printf("  Combined: '%s'", combined_line)
        
        " Verify the right content starts at the correct virtual column
        let actual_right_vcol = cleave#find_right_start_vcol(combined_line)
        if actual_right_vcol > 0
            let expected_vcol = cleave_column
            let status = (actual_right_vcol == expected_vcol) ? 'PASS' : 'FAIL'
            echo printf("  Right content starts at vcol %d (expected %d) [%s]", 
                        \ actual_right_vcol, expected_vcol, status)
        else
            echo "  No right content found"
        endif
        
        " Test edge case: what if left content is longer than cleave column?
        if left_len >= cleave_column
            echo printf("  WARNING: Left content (%d) >= cleave column (%d)", left_len, cleave_column)
            echo printf("  In this case, no padding is added and right content immediately follows")
        endif
        
        echo ""
    endfor
endfunction

function! TestPaddingEdgeCases()
    echo "=== Testing Padding Edge Cases ==="
    
    " Test cases where padding calculation might be tricky
    let edge_cases = [
        \ {
        \   'name': 'Left exactly at cleave column',
        \   'left': 'Exactly12',  " 8 chars
        \   'cleave_col': 9  " Left ends at position 8, cleave at 9
        \ },
        \ {
        \   'name': 'Left exceeds cleave column',
        \   'left': 'TooLongContent',
        \   'cleave_col': 8
        \ },
        \ {
        \   'name': 'Wide char at boundary',
        \   'left': 'Test 世',  " 'Test ' = 5, '世' = 2, total = 7
        \   'cleave_col': 8   " Should need 0 padding
        \ },
        \ {
        \   'name': 'Tab near boundary',
        \   'left': "Tab\there",  " Tab expands to align to tabstop
        \   'cleave_col': 12
        \ }
    \ ]
    
    for test_case in edge_cases
        echo printf("Edge case: %s", test_case.name)
        
        let left_line = test_case.left
        let cleave_column = test_case.cleave_col
        let right_line = 'RIGHT'
        
        let left_len = strdisplaywidth(left_line)
        let padding_needed = cleave_column - 1 - left_len
        let padding = padding_needed > 0 ? repeat(' ', padding_needed) : ''
        let combined_line = left_line . padding . right_line
        
        echo printf("  Left: '%s' (display width: %d)", left_line, left_len)
        echo printf("  Cleave column: %d", cleave_column)
        echo printf("  Padding needed: %d", padding_needed)
        echo printf("  Combined: '%s'", combined_line)
        
        if padding_needed <= 0
            echo "  Note: No padding added - right content immediately follows left"
        endif
        
        echo ""
    endfor
endfunction

" Helper function to find where right content starts (virtual column)
function! cleave#find_right_start_vcol(line)
    if empty(a:line)
        return -1
    endif
    
    let vcol = 1
    let char_pos = 0
    let in_left_content = 1
    let in_padding = 0
    
    while char_pos < len(a:line)
        let char = strpart(a:line, char_pos, 1)
        
        if in_left_content && char == ' '
            " Transition from left content to padding
            let in_left_content = 0
            let in_padding = 1
        elseif in_padding && char != ' '
            " Found start of right content
            return vcol
        elseif in_left_content && char != ' '
            " Still in left content
        elseif !in_left_content && !in_padding && char != ' '
            " Right content immediately follows left (no padding)
            return vcol
        endif
        
        " Update virtual column position
        if char == "\t"
            let tab_width = &tabstop - ((vcol - 1) % &tabstop)
            let vcol += tab_width
        else
            let vcol += strdisplaywidth(char)
        endif
        
        let char_pos += len(char)
    endwhile
    
    return -1  " No right content found
endfunction

" Run the tests
call TestCombinedLineConstruction()
call TestPaddingEdgeCases()