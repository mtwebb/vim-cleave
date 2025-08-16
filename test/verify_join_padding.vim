" Verification script for join_buffers padding calculations
" This script tests that strdisplaywidth() is used correctly

function! VerifyPaddingCalculation()
    echo "=== Verifying padding calculation logic ==="
    
    " Test cases with known display widths
    let test_cases = [
        \ {'line': 'Hello', 'expected_width': 5},
        \ {'line': 'Hello 世界', 'expected_width': 11},
        \ {'line': '测试', 'expected_width': 4},
        \ {'line': 'αβγ', 'expected_width': 3},
        \ {'line': 'Tab	here', 'expected_width': 12},
        \ {'line': '', 'expected_width': 0}
    \ ]
    
    echo "Testing strdisplaywidth() calculations:"
    for test_case in test_cases
        let actual_width = strdisplaywidth(test_case.line)
        let status = (actual_width == test_case.expected_width) ? 'PASS' : 'FAIL'
        echo printf("  '%s' -> width %d (expected %d) [%s]", 
                    \ test_case.line, actual_width, test_case.expected_width, status)
    endfor
    
    echo ""
    echo "Testing padding calculation for cleave_column = 15:"
    let cleave_column = 15
    
    for test_case in test_cases
        let left_line = test_case.line
        let left_len = strdisplaywidth(left_line)
        let padding_needed = cleave_column - 1 - left_len
        let padding = padding_needed > 0 ? repeat(' ', padding_needed) : ''
        let right_content = 'RIGHT'
        let combined = left_line . padding . right_content
        
        echo printf("  Left: '%s' (width %d)", left_line, left_len)
        echo printf("  Padding needed: %d spaces", padding_needed)
        echo printf("  Combined: '%s'", combined)
        
        " Verify right content starts at correct virtual column
        let right_start_vcol = cleave#find_right_content_vcol(combined)
        let expected_vcol = cleave_column
        let status = (right_start_vcol == expected_vcol) ? 'PASS' : 'FAIL'
        echo printf("  Right starts at vcol %d (expected %d) [%s]", 
                    \ right_start_vcol, expected_vcol, status)
        echo ""
    endfor
endfunction

" Helper function to find virtual column where right content starts
function! cleave#find_right_content_vcol(line)
    let vcol = 1
    let char_pos = 0
    let found_space = 0
    
    while char_pos < len(a:line)
        let char = strpart(a:line, char_pos, 1)
        
        " Look for transition from spaces to non-spaces (right content)
        if char == ' '
            let found_space = 1
        elseif found_space && char != ' '
            " Found start of right content
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
    
    return -1  " Right content not found
endfunction

call VerifyPaddingCalculation()