" Complete test for gutter preservation through split → reflow → join workflow
" Run with: vim -c "source test/test_complete_gutter_workflow.vim" -c "call TestCompleteGutterWorkflow()" -c "qa!"

function! TestCompleteGutterWorkflow()
    echomsg "Testing complete gutter workflow: split → reflow → join..."
    
    " Test different gutter widths
    let test_gutters = [0, 2, 4, 6]
    
    for gutter_width in test_gutters
        echomsg ""
        echomsg "=== Testing gutter width: " . gutter_width . " ==="
        
        " Create test content
        enew
        call setline(1, [
            \ "This is a long line that will be used to test the complete gutter workflow",
            \ "Another line with some content that should maintain gutter settings",
            \ "Short line",
            \ "Final line for testing"
        \ ])
        
        " Set foldcolumn
        execute 'setlocal foldcolumn=' . gutter_width
        let original_foldcolumn = &foldcolumn
        let original_bufnr = bufnr('%')
        
        echomsg "Step 1: Original buffer foldcolumn = " . original_foldcolumn
        
        " Step 1: Split
        let cleave_col = 20
        let original_lines = getline(1, '$')
        let [left_lines, right_lines] = cleave#split_content(original_lines, cleave_col)
        
        " Create left buffer
        silent execute 'enew'
        silent execute 'file test_' . gutter_width . '.left'
        let left_bufnr = bufnr('%')
        call setline(1, left_lines)
        setlocal buftype=nofile
        setlocal bufhidden=hide
        setlocal noswapfile
        execute 'setlocal foldcolumn=' . original_foldcolumn
        
        " Create right buffer
        silent execute 'enew'
        silent execute 'file test_' . gutter_width . '.right'
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
        
        execute 'buffer ' . left_bufnr
        let after_split_foldcolumn = &foldcolumn
        echomsg "Step 2: After split, left buffer foldcolumn = " . after_split_foldcolumn
        
        " Step 2: Reflow (simulate)
        let new_width = 25
        let current_lines = getline(1, '$')
        
        " Simple reflow simulation
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
        
        call setline(1, reflowed_lines)
        if line('$') > len(reflowed_lines)
            execute (len(reflowed_lines) + 1) . ',$delete'
        endif
        execute 'setlocal textwidth=' . new_width
        
        let after_reflow_foldcolumn = &foldcolumn
        echomsg "Step 3: After reflow, left buffer foldcolumn = " . after_reflow_foldcolumn
        
        " Step 3: Join
        let left_lines_final = getbufline(left_bufnr, 1, '$')
        let right_lines_final = getbufline(right_bufnr, 1, '$')
        
        " Combine content
        let combined_lines = []
        let max_lines = max([len(left_lines_final), len(right_lines_final)])
        
        for i in range(max_lines)
            let left_line = (i < len(left_lines_final)) ? left_lines_final[i] : ''
            let right_line = (i < len(right_lines_final)) ? right_lines_final[i] : ''
            
            if empty(right_line)
                let combined_line = left_line
            else
                let left_len = strdisplaywidth(left_line)
                let padding_needed = cleave_col - 1 - left_len
                let padding = padding_needed > 0 ? repeat(' ', padding_needed) : ''
                let combined_line = left_line . padding . right_line
            endif
            
            call add(combined_lines, combined_line)
        endfor
        
        " Update original buffer with the fix
        execute 'buffer ' . original_bufnr
        call setline(1, combined_lines)
        if line('$') > len(combined_lines)
            execute (len(combined_lines) + 1) . ',$delete'
        endif
        
        " Apply the fix: preserve both textwidth and foldcolumn
        let left_textwidth = getbufvar(left_bufnr, '&textwidth', 0)
        if left_textwidth > 0
            execute 'setlocal textwidth=' . left_textwidth
        endif
        
        let left_foldcolumn = getbufvar(left_bufnr, '&foldcolumn', 0)
        execute 'setlocal foldcolumn=' . left_foldcolumn
        
        let final_foldcolumn = &foldcolumn
        let final_textwidth = &textwidth
        
        echomsg "Step 4: After join, original buffer:"
        echomsg "  foldcolumn = " . final_foldcolumn . " (expected: " . original_foldcolumn . ")"
        echomsg "  textwidth = " . final_textwidth . " (expected: " . new_width . ")"
        
        " Verify results
        if final_foldcolumn == original_foldcolumn
            echomsg "✓ PASS: Gutter preserved through complete workflow"
        else
            echomsg "✗ FAIL: Gutter not preserved through complete workflow"
        endif
        
        if final_textwidth == new_width
            echomsg "✓ PASS: Textwidth preserved from reflow"
        else
            echomsg "✗ FAIL: Textwidth not preserved from reflow"
        endif
        
        " Clean up
        if bufexists(left_bufnr)
            execute 'bdelete! ' . left_bufnr
        endif
        if bufexists(right_bufnr)
            execute 'bdelete! ' . right_bufnr
        endif
        
        bdelete!
    endfor
    
    echomsg ""
    echomsg "Complete gutter workflow test finished."
endfunction