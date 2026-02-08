" Test file for cleave#join_buffers() with multi-byte characters
" This tests the padding calculations and virtual column alignment

function! TestJoinBuffersBasic()
    echo "=== Testing basic join_buffers functionality ==="
    
    " Test 1: Simple ASCII content
    enew
    call setline(1, [
        \ 'Hello world',
        \ 'Test line',
        \ 'Another test'
    \ ])
    
    echo "Original content:"
    let original_lines = getline(1, '$')
    for i in range(len(original_lines))
        echo printf("  Line %d: '%s'", i+1, original_lines[i])
    endfor
    
    " Split at virtual column 8
    call cleave#split_buffer(bufnr('%'), 8)
    
    " Get the cleave_col value to verify it's stored correctly
    let stored_cleave_col = getbufvar(bufnr('%'), 'cleave_col', -1)
    echo printf("Stored cleave_col: %d", stored_cleave_col)
    
    " Join back
    call cleave#join_buffers()
    
    let joined_lines = getline(1, '$')
    echo "Joined result:"
    for i in range(len(joined_lines))
        echo printf("  Line %d: '%s'", i+1, joined_lines[i])
        " Verify right content starts at virtual column 8
        let right_start_vcol = cleave#find_right_content_start(joined_lines[i])
        if right_start_vcol > 0
            echo printf("    Right content starts at vcol %d", right_start_vcol)
        endif
    endfor
    echo ""
endfunction

function! TestJoinBuffersWithMultiByte()
    echo "=== Testing join_buffers with multi-byte characters ==="
    
    " Create a test buffer with multi-byte content
    enew
    call setline(1, [
        \ 'Hello 世界',
        \ 'Test 测试',
        \ 'ASCII only',
        \ '日本語テスト',
        \ 'Mixed: αβγ and 123'
    \ ])
    
    echo "Original content with multi-byte characters:"
    let original_lines = getline(1, '$')
    for i in range(len(original_lines))
        echo printf("  Line %d: '%s' (display width: %d)", i+1, original_lines[i], strdisplaywidth(original_lines[i]))
    endfor
    
    " Split at virtual column 10
    call cleave#split_buffer(bufnr('%'), 10)
    
    " Get split results
    let left_lines = getbufline(bufnr('%'), 1, '$')
    wincmd l
    let right_lines = getbufline(bufnr('%'), 1, '$')
    wincmd h
    
    echo "After split:"
    echo "  Left lines:"
    for i in range(len(left_lines))
        echo printf("    Line %d: '%s' (display width: %d)", i+1, left_lines[i], strdisplaywidth(left_lines[i]))
    endfor
    echo "  Right lines:"
    for i in range(len(right_lines))
        echo printf("    Line %d: '%s' (display width: %d)", i+1, right_lines[i], strdisplaywidth(right_lines[i]))
    endfor
    
    " Now test joining
    call cleave#join_buffers()
    
    " Verify the joined result
    let joined_lines = getline(1, '$')
    echo "After join:"
    for i in range(len(joined_lines))
        echo printf("  Line %d: '%s' (display width: %d)", i+1, joined_lines[i], strdisplaywidth(joined_lines[i]))
        " Verify right content starts at virtual column 10
        let right_start_vcol = cleave#find_right_content_start(joined_lines[i])
        if right_start_vcol > 0
            echo printf("    Right content starts at vcol %d", right_start_vcol)
            if right_start_vcol != 10
                echo printf("    ERROR: Expected vcol 10, got %d", right_start_vcol)
            endif
        endif
    endfor
    echo ""
endfunction

function! TestJoinBuffersEdgeCases()
    echo "=== Testing join_buffers edge cases ==="
    
    " Test with empty lines and mixed content
    enew
    call setline(1, [
        \ '',
        \ 'Line with 中文',
        \ '',
        \ 'Another 行',
        \ 'Tab	test',
        \ 'Emoji 🌟 test'
    \ ])
    
    echo "Edge case content:"
    let original_lines = getline(1, '$')
    for i in range(len(original_lines))
        echo printf("  Line %d: '%s' (display width: %d)", i+1, original_lines[i], strdisplaywidth(original_lines[i]))
    endfor
    
    call cleave#split_buffer(bufnr('%'), 12)
    call cleave#join_buffers()
    
    let joined_lines = getline(1, '$')
    echo "Edge case joined result:"
    for i in range(len(joined_lines))
        echo printf("  Line %d: '%s' (display width: %d)", i+1, joined_lines[i], strdisplaywidth(joined_lines[i]))
        let right_start_vcol = cleave#find_right_content_start(joined_lines[i])
        if right_start_vcol > 0
            echo printf("    Right content starts at vcol %d", right_start_vcol)
        endif
    endfor
    echo ""
endfunction

" Helper function to find where right content starts in a joined line
function! cleave#find_right_content_start(line)
    let vcol = 1
    let char_pos = 0
    let in_padding = 0
    let left_content_ended = 0
    
    while char_pos < len(a:line)
        let char = strpart(a:line, char_pos, 1)
        
        if char == ' '
            if !left_content_ended
                " First space after content - start of padding
                let left_content_ended = 1
                let in_padding = 1
            endif
        elseif in_padding
            " Found non-space after padding - this is right content start
            return vcol
        elseif left_content_ended
            " Non-space after we thought content ended - this is right content
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
    
    return 0  " No right content found
endfunction

" Run the tests
call TestJoinBuffersBasic()
call TestJoinBuffersWithMultiByte()
call TestJoinBuffersEdgeCases()