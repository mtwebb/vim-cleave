" Integration test for join_buffers with various character types
" This test actually splits and joins buffers to verify the logic works end-to-end

function! TestJoinIntegration()
    echo "=== Integration Test: Split and Join with Various Character Types ==="
    
    " Test case 1: Mixed ASCII and wide characters
    echo "Test 1: Mixed ASCII and wide characters"
    enew
    call setline(1, [
        \ 'Hello 世界 test line',
        \ 'Another 测试 content',
        \ 'Pure ASCII content',
        \ '完全中文内容测试',
        \ 'Mixed: αβγ and 123'
    \ ])
    
    echo "Original lines:"
    for i in range(1, line('$'))
        let line = getline(i)
        echo printf("  %d: '%s' (width: %d)", i, line, strdisplaywidth(line))
    endfor
    
    " Split at virtual column 12
    let split_vcol = 12
    echo printf("Splitting at virtual column %d", split_vcol)
    call cleave#split_buffer(bufnr('%'), split_vcol)
    
    " Capture split results
    let left_lines = getbufline(bufnr('%'), 1, '$')
    wincmd l
    let right_lines = getbufline(bufnr('%'), 1, '$')
    wincmd h
    
    echo "After split:"
    echo "  Left buffer:"
    for i in range(len(left_lines))
        echo printf("    %d: '%s' (width: %d)", i+1, left_lines[i], strdisplaywidth(left_lines[i]))
    endfor
    echo "  Right buffer:"
    for i in range(len(right_lines))
        echo printf("    %d: '%s' (width: %d)", i+1, right_lines[i], strdisplaywidth(right_lines[i]))
    endfor
    
    " Join back
    echo "Joining buffers..."
    call cleave#join_buffers()
    
    " Verify joined result
    echo "After join:"
    for i in range(1, line('$'))
        let line = getline(i)
        echo printf("  %d: '%s' (width: %d)", i, line, strdisplaywidth(line))
        
        " Find where right content starts
        let right_vcol = cleave#find_right_content_position(line)
        if right_vcol > 0
            echo printf("     Right content starts at virtual column %d", right_vcol)
            if right_vcol != split_vcol
                echo printf("     ERROR: Expected %d, got %d", split_vcol, right_vcol)
            endif
        endif
    endfor
    echo ""
    
    " Test case 2: Edge cases with empty lines and tabs
    echo "Test 2: Edge cases with empty lines and tabs"
    enew
    call setline(1, [
        \ '',
        \ 'Line with	tab',
        \ 'Short',
        \ 'Very long line that exceeds split point',
        \ '	Leading tab'
    \ ])
    
    echo "Original lines:"
    for i in range(1, line('$'))
        let line = getline(i)
        echo printf("  %d: '%s' (width: %d)", i, line, strdisplaywidth(line))
    endfor
    
    let split_vcol = 10
    echo printf("Splitting at virtual column %d", split_vcol)
    call cleave#split_buffer(bufnr('%'), split_vcol)
    call cleave#join_buffers()
    
    echo "After split and join:"
    for i in range(1, line('$'))
        let line = getline(i)
        echo printf("  %d: '%s' (width: %d)", i, line, strdisplaywidth(line))
        
        let right_vcol = cleave#find_right_content_position(line)
        if right_vcol > 0
            echo printf("     Right content starts at virtual column %d", right_vcol)
        endif
    endfor
    echo ""
endfunction

" Helper function to find right content position in a joined line
function! cleave#find_right_content_position(line)
    if empty(a:line)
        return 0
    endif
    
    let vcol = 1
    let char_pos = 0
    let found_non_space = 0
    let in_padding = 0
    
    while char_pos < len(a:line)
        let char = strpart(a:line, char_pos, 1)
        
        if !found_non_space && char != ' '
            let found_non_space = 1
        elseif found_non_space && char == ' ' && !in_padding
            " Start of padding area
            let in_padding = 1
        elseif in_padding && char != ' '
            " End of padding - start of right content
            return vcol
        endif
        
        " Update virtual column
        if char == "\t"
            let tab_width = &tabstop - ((vcol - 1) % &tabstop)
            let vcol += tab_width
        else
            let vcol += strdisplaywidth(char)
        endif
        
        let char_pos += len(char)
    endwhile
    
    return 0
endfunction

call TestJoinIntegration()