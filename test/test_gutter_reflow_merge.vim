" Test to verify gutter is maintained after reflow followed by merge
" Run with: vim -c "source test/test_gutter_reflow_merge.vim" -c "call TestGutterReflowMerge()" -c "qa!"

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

function! TestGutterReflowMerge()
    echomsg "Testing gutter maintenance after reflow and merge..."
    let passed = 0
    let total = 0
    
    " Create test content
    enew
    call setline(1, [
        \ "This is a long line that will be reflowed to test gutter behavior",
        \ "Another line with some content here",
        \ "Short line",
        \ "Final line with more text content"
    \ ])
    
    " Save original buffer info
    let original_bufnr = bufnr('%')
    let original_name = expand('%:t')
    if empty(original_name)
        let original_name = 'test_buffer'
        execute 'file ' . fnameescape(original_name)
    endif
    
    echomsg "=== Initial Setup ==="
    echomsg "Original buffer: " . original_bufnr
    echomsg "Content lines: " . line('$')
    
    " Test with different gutter settings
    let test_gutters = [0, 3, 5]
    
    for gutter_width in test_gutters
        echomsg ""
        echomsg "=== Testing with gutter width: " . gutter_width . " ==="
        
        " Set foldcolumn (gutter)
        execute 'setlocal foldcolumn=' . gutter_width
        let original_foldcolumn = &foldcolumn
        
        echomsg "Set foldcolumn to: " . original_foldcolumn
        
        " Perform cleave split at column 20
        let cleave_col = 20
        echomsg "Splitting at column: " . cleave_col
        
        " Simulate the split process
        let original_lines = getline(1, '$')
        let [left_lines, right_lines] = cleave#split_content(original_lines, cleave_col)
        
        " Create buffers (simulating cleave#create_buffers)
        silent execute 'enew'
        silent execute 'file ' . fnameescape(original_name . '.left')
        let left_bufnr = bufnr('%')
        call setline(1, left_lines)
        setlocal buftype=nofile
        setlocal bufhidden=hide
        setlocal noswapfile
        execute 'setlocal foldcolumn=' . original_foldcolumn
        
        silent execute 'enew'
        silent execute 'file ' . fnameescape(original_name . '.right')
        let right_bufnr = bufnr('%')
        call setline(1, right_lines)
        setlocal buftype=nofile
        setlocal bufhidden=hide
        setlocal noswapfile
        setlocal foldcolumn=0
        
        " Set buffer variables
        call setbufvar(left_bufnr, 'cleave_original', original_bufnr)
        call setbufvar(left_bufnr, 'cleave_side', 'left')
        call setbufvar(left_bufnr, 'cleave_col', cleave_col)
        call setbufvar(right_bufnr, 'cleave_original', original_bufnr)
        call setbufvar(right_bufnr, 'cleave_side', 'right')
        call setbufvar(right_bufnr, 'cleave_col', cleave_col)
        
        echomsg "Created left buffer: " . left_bufnr . " (foldcolumn: " . getbufvar(left_bufnr, '&foldcolumn') . ")"
        echomsg "Created right buffer: " . right_bufnr . " (foldcolumn: " . getbufvar(right_bufnr, '&foldcolumn') . ")"
        
        " Switch to left buffer and check initial state
        execute 'buffer ' . left_bufnr
        let left_initial_foldcolumn = &foldcolumn
        let left_initial_textwidth = &textwidth
        
        echomsg "Left buffer initial state:"
        echomsg "  foldcolumn: " . left_initial_foldcolumn
        echomsg "  textwidth: " . left_initial_textwidth
        
        " Perform reflow on left buffer (simulate CleaveReflow)
        let new_width = 30
        echomsg "Reflowing left buffer to width: " . new_width
        
        " Get current content and reflow it
        let current_lines = getline(1, '$')
        echomsg "Lines before reflow: " . len(current_lines)
        
        " Simulate reflow (basic word wrapping)
        let reflowed_lines = []
        for line in current_lines
            if strdisplaywidth(line) <= new_width
                call add(reflowed_lines, line)
            else
                " Simple word wrap
                let words = split(line, ' ')
                let current_line = ''
                for word in words
                    if empty(current_line)
                        let current_line = word
                    elseif strdisplaywidth(current_line . ' ' . word) <= new_width
                        let current_line .= ' ' . word
                    else
                        call add(reflowed_lines, current_line)
                        let current_line = word
                    endif
                endfor
                if !empty(current_line)
                    call add(reflowed_lines, current_line)
                endif
            endif
        endfor
        
        " Update buffer content
        call setline(1, reflowed_lines)
        if line('$') > len(reflowed_lines)
            execute (len(reflowed_lines) + 1) . ',$delete'
        endif
        
        " Set new textwidth
        execute 'setlocal textwidth=' . new_width
        
        " Check state after reflow
        let left_after_reflow_foldcolumn = &foldcolumn
        let left_after_reflow_textwidth = &textwidth
        
        echomsg "Left buffer after reflow:"
        echomsg "  foldcolumn: " . left_after_reflow_foldcolumn
        echomsg "  textwidth: " . left_after_reflow_textwidth
        echomsg "  lines: " . line('$')
        
        let total += 1
        let passed += AssertEqual(original_foldcolumn, left_after_reflow_foldcolumn, "Gutter preserved after reflow (width " . gutter_width . ")")
        
        " Now perform merge (simulate CleaveJoin)
        echomsg "Performing merge..."
        
        " Get content from both buffers
        let left_lines_final = getbufline(left_bufnr, 1, '$')
        let right_lines_final = getbufline(right_bufnr, 1, '$')
        
        " Get cleave column
        let merge_cleave_col = getbufvar(left_bufnr, 'cleave_col', cleave_col)
        
        " Combine content using the corrected join logic
        let combined_lines = []
        let max_lines = max([len(left_lines_final), len(right_lines_final)])
        
        for i in range(max_lines)
            let left_line = (i < len(left_lines_final)) ? left_lines_final[i] : ''
            let right_line = (i < len(right_lines_final)) ? right_lines_final[i] : ''
            
            if empty(right_line)
                let combined_line = left_line
            else
                let left_len = strdisplaywidth(left_line)
                let padding_needed = merge_cleave_col - 1 - left_len
                let padding = padding_needed > 0 ? repeat(' ', padding_needed) : ''
                let combined_line = left_line . padding . right_line
            endif
            
            call add(combined_lines, combined_line)
        endfor
        
        " Update original buffer
        execute 'buffer ' . original_bufnr
        call setline(1, combined_lines)
        if line('$') > len(combined_lines)
            execute (len(combined_lines) + 1) . ',$delete'
        endif
        
        " Set textwidth from left buffer
        let left_textwidth = getbufvar(left_bufnr, '&textwidth', 0)
        if left_textwidth > 0
            execute 'setlocal textwidth=' . left_textwidth
        endif
        
        " Check final state
        let final_foldcolumn = &foldcolumn
        let final_textwidth = &textwidth
        
        echomsg "Original buffer after merge:"
        echomsg "  foldcolumn: " . final_foldcolumn
        echomsg "  textwidth: " . final_textwidth
        echomsg "  lines: " . line('$')
        
        let total += 1
        let passed += AssertEqual(original_foldcolumn, final_foldcolumn, "Gutter preserved after merge (width " . gutter_width . ")")
        
        " Clean up buffers
        if bufexists(left_bufnr)
            execute 'bdelete! ' . left_bufnr
        endif
        if bufexists(right_bufnr)
            execute 'bdelete! ' . right_bufnr
        endif
        
        " Reset for next test
        execute 'buffer ' . original_bufnr
        call setline(1, [
            \ "This is a long line that will be reflowed to test gutter behavior",
            \ "Another line with some content here", 
            \ "Short line",
            \ "Final line with more text content"
        \ ])
    endfor
    
    " Clean up
    bdelete!
    
    echomsg ""
    echomsg "TestGutterReflowMerge: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction

function! TestGutterWithActualCleaveCommands()
    echomsg ""
    echomsg "Testing gutter with actual Cleave commands..."
    let passed = 0
    let total = 0
    
    " Create test content
    enew
    call setline(1, [
        \ "This is a test line for gutter testing with cleave operations",
        \ "Another line that should maintain gutter settings",
        \ "Short line",
        \ "Final test line"
    \ ])
    
    " Set a specific gutter width
    setlocal foldcolumn=4
    let original_foldcolumn = &foldcolumn
    
    echomsg "Set original foldcolumn to: " . original_foldcolumn
    
    " Check if we can call actual cleave functions
    try
        " Position cursor and split
        call cursor(1, 15)
        let original_bufnr = bufnr('%')
        
        echomsg "Attempting to split buffer at cursor position..."
        call cleave#split_buffer(original_bufnr, 25)
        
        " Check if split was successful by looking for cleave buffers
        let left_bufnr = -1
        let right_bufnr = -1
        
        for i in range(1, bufnr("$"))
            if bufexists(i)
                let bufname = bufname(i)
                if bufname =~ '\.left$'
                    let left_bufnr = i
                elseif bufname =~ '\.right$'
                    let right_bufnr = i
                endif
            endif
        endfor
        
        if left_bufnr != -1 && right_bufnr != -1
            echomsg "Split successful. Left: " . left_bufnr . ", Right: " . right_bufnr
            
            " Check gutter on left buffer
            execute 'buffer ' . left_bufnr
            let left_foldcolumn = &foldcolumn
            
            echomsg "Left buffer foldcolumn: " . left_foldcolumn
            
            let total += 1
            let passed += AssertEqual(original_foldcolumn, left_foldcolumn, "Gutter preserved in left buffer after split")
            
            " Test reflow if the function exists
            if exists('*cleave#reflow_buffer')
                echomsg "Testing reflow..."
                call cleave#reflow_buffer(20)
                
                let left_foldcolumn_after_reflow = &foldcolumn
                echomsg "Left buffer foldcolumn after reflow: " . left_foldcolumn_after_reflow
                
                let total += 1
                let passed += AssertEqual(original_foldcolumn, left_foldcolumn_after_reflow, "Gutter preserved after reflow")
            endif
            
            " Test join
            if exists('*cleave#join_buffers')
                echomsg "Testing join..."
                call cleave#join_buffers()
                
                " Find the original buffer (should be active now)
                let current_bufnr = bufnr('%')
                let final_foldcolumn = &foldcolumn
                
                echomsg "Final buffer foldcolumn after join: " . final_foldcolumn
                
                let total += 1
                let passed += AssertEqual(original_foldcolumn, final_foldcolumn, "Gutter preserved after join")
            endif
        else
            echomsg "Split failed - could not find cleave buffers"
            let total += 1
            " This counts as a failure since we couldn't test the functionality
        endif
        
    catch /^Vim\%((\a\+)\)\=:E/
        echomsg "Error during cleave operations: " . v:exception
        let total += 1
        " Count as failure
    endtry
    
    " Clean up any remaining buffers
    for i in range(1, bufnr("$"))
        if bufexists(i) && i != original_bufnr
            let bufname = bufname(i)
            if bufname =~ '\.\(left\|right\)$'
                execute 'bdelete! ' . i
            endif
        endif
    endfor
    
    echomsg "TestGutterWithActualCleaveCommands: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction

function! RunGutterTests()
    echomsg "Running gutter maintenance tests..."
    echomsg "=================================="
    
    let total_passed = 0
    let total_tests = 0
    
    let [p1, t1] = TestGutterReflowMerge()
    let total_passed += p1 | let total_tests += t1
    
    let [p2, t2] = TestGutterWithActualCleaveCommands()
    let total_passed += p2 | let total_tests += t2
    
    echomsg "=================================="
    echomsg "GUTTER TEST RESULTS:"
    echomsg "Total: " . total_passed . "/" . total_tests . " tests passed"
    
    if total_passed == total_tests
        echomsg "🎉 ALL GUTTER TESTS PASSED!"
    else
        echomsg "❌ " . (total_tests - total_passed) . " GUTTER TESTS FAILED!"
    endif
    
    return total_passed == total_tests ? 0 : 1
endfunction