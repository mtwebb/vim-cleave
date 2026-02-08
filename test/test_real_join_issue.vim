" Test to reproduce the actual CleaveJoin spacing issue
" Run with: vim -c "source test/test_real_join_issue.vim" -c "call TestRealJoinIssue()" -c "qa!"

function! TestRealJoinIssue()
    echomsg "Testing real CleaveJoin spacing issue..."
    
    " Test with various scenarios that might cause spacing issues
    
    " Scenario 1: Text with trailing spaces
    echomsg "=== Scenario 1: Text with trailing spaces ==="
    enew
    call setline(1, ["Line with trailing spaces   ", "Another line", "Third line"])
    
    " Split at column 15
    let cleave_col = 15
    echomsg "Original content:"
    for i in range(1, 3)
        let line = getline(i)
        echomsg "  Line " . i . ": '" . line . "' (display width: " . strdisplaywidth(line) . ")"
    endfor
    
    " Simulate the split
    let original_lines = getline(1, '$')
    let left_lines = []
    let right_lines = []
    
    for line in original_lines
        let left_part = cleave#virtual_strpart(line, 1, cleave_col)
        let right_part = cleave#virtual_strpart(line, cleave_col)
        call add(left_lines, left_part)
        call add(right_lines, right_part)
    endfor
    
    echomsg "After split at column " . cleave_col . ":"
    echomsg "Left parts:"
    for i in range(len(left_lines))
        echomsg "  '" . left_lines[i] . "' (width: " . strdisplaywidth(left_lines[i]) . ")"
    endfor
    echomsg "Right parts:"
    for i in range(len(right_lines))
        echomsg "  '" . right_lines[i] . "' (width: " . strdisplaywidth(right_lines[i]) . ")"
    endfor
    
    " Simulate the join with the new logic
    let combined_lines = []
    let max_lines = max([len(left_lines), len(right_lines)])
    
    echomsg "Join calculation (with fix):"
    for i in range(max_lines)
        let left_line = (i < len(left_lines)) ? left_lines[i] : ''
        let right_line = (i < len(right_lines)) ? right_lines[i] : ''
        
        " Apply the new logic: only add padding if there's content in the right part
        if empty(right_line)
            let combined_line = left_line
            echomsg "  Line " . (i+1) . ": No right content, using left as-is: '" . combined_line . "'"
        else
            let left_len = strdisplaywidth(left_line)
            let padding_needed = cleave_col - 1 - left_len
            let padding = padding_needed > 0 ? repeat(' ', padding_needed) : ''
            let combined_line = left_line . padding . right_line
            echomsg "  Line " . (i+1) . ": left_len=" . left_len . ", padding_needed=" . padding_needed . ", padding='" . padding . "', result='" . combined_line . "'"
        endif
        
        call add(combined_lines, combined_line)
        
        echomsg "  Line " . (i+1) . ":"
        echomsg "    Left: '" . left_line . "' (width: " . left_len . ")"
        echomsg "    Right: '" . right_line . "'"
        echomsg "    Padding needed: " . padding_needed
        echomsg "    Padding: '" . padding . "'"
        echomsg "    Combined: '" . combined_line . "'"
        echomsg "    Combined width: " . strdisplaywidth(combined_line)
    endfor
    
    echomsg "Final rejoined content:"
    for i in range(len(combined_lines))
        echomsg "  '" . combined_lines[i] . "'"
    endfor
    
    " Compare with original
    echomsg "Comparison with original:"
    for i in range(len(original_lines))
        let original = original_lines[i]
        let rejoined = i < len(combined_lines) ? combined_lines[i] : ''
        let match = (original == rejoined) ? "MATCH" : "DIFFER"
        echomsg "  " . match . ": '" . original . "' vs '" . rejoined . "'"
    endfor
    
    bdelete!
    
    " Scenario 2: Mixed content with CJK
    echomsg ""
    echomsg "=== Scenario 2: Mixed content with CJK ==="
    enew
    call setline(1, ["Hello 你好 World", "Test 测试 line", "Simple line"])
    
    let cleave_col2 = 10
    echomsg "Original content:"
    for i in range(1, 3)
        let line = getline(i)
        echomsg "  Line " . i . ": '" . line . "' (display width: " . strdisplaywidth(line) . ")"
    endfor
    
    " Test the split and join for CJK content
    let original_lines2 = getline(1, '$')
    let left_lines2 = []
    let right_lines2 = []
    
    for line in original_lines2
        let left_part = cleave#virtual_strpart(line, 1, cleave_col2)
        let right_part = cleave#virtual_strpart(line, cleave_col2)
        call add(left_lines2, left_part)
        call add(right_lines2, right_part)
    endfor
    
    echomsg "After split at column " . cleave_col2 . ":"
    for i in range(len(left_lines2))
        echomsg "  Left: '" . left_lines2[i] . "' | Right: '" . right_lines2[i] . "'"
    endfor
    
    " Join with new algorithm
    let combined_lines2 = []
    for i in range(len(left_lines2))
        let left_line = left_lines2[i]
        let right_line = right_lines2[i]
        
        if empty(right_line)
            let combined_line = left_line
            echomsg "  Join line " . (i+1) . ": No right content, using left as-is: '" . combined_line . "'"
        else
            let left_len = strdisplaywidth(left_line)
            let padding_needed = cleave_col2 - 1 - left_len
            let padding = padding_needed > 0 ? repeat(' ', padding_needed) : ''
            let combined_line = left_line . padding . right_line
            echomsg "  Join line " . (i+1) . ": left_len=" . left_len . ", padding_needed=" . padding_needed . ", result='" . combined_line . "'"
        endif
        
        call add(combined_lines2, combined_line)
    endfor
    
    bdelete!
    
    echomsg "Test completed."
endfunction