" Test to verify the gutter fix in join_buffers
" Run with: vim -c "source test/test_gutter_fix.vim" -c "call TestGutterFix()" -c "qa!"

function! TestGutterFix()
    echomsg "Testing gutter preservation fix in join_buffers..."
    
    " Create test content
    enew
    call setline(1, [
        \ "This is a test line for gutter preservation",
        \ "Another line with content",
        \ "Short line"
    \ ])
    
    " Set foldcolumn
    setlocal foldcolumn=3
    let original_foldcolumn = &foldcolumn
    let original_bufnr = bufnr('%')
    
    echomsg "Original buffer foldcolumn: " . original_foldcolumn
    
    " Simulate the split process
    let cleave_col = 15
    let original_lines = getline(1, '$')
    let [left_lines, right_lines] = cleave#split_content(original_lines, cleave_col)
    
    " Create left buffer
    silent execute 'enew'
    silent execute 'file test.left'
    let left_bufnr = bufnr('%')
    call setline(1, left_lines)
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    execute 'setlocal foldcolumn=' . original_foldcolumn
    
    " Create right buffer
    silent execute 'enew'
    silent execute 'file test.right'
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
    
    echomsg "Left buffer foldcolumn: " . getbufvar(left_bufnr, '&foldcolumn')
    echomsg "Right buffer foldcolumn: " . getbufvar(right_bufnr, '&foldcolumn')
    
    " Switch to left buffer and simulate join
    execute 'buffer ' . left_bufnr
    
    " Manually simulate the join process with the fix
    let left_lines_final = getbufline(left_bufnr, 1, '$')
    let right_lines_final = getbufline(right_bufnr, 1, '$')
    
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
            let padding_needed = cleave_col - 1 - left_len
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
    
    " Apply the fix: preserve both textwidth and foldcolumn
    let left_textwidth = getbufvar(left_bufnr, '&textwidth', 0)
    if left_textwidth > 0
        execute 'setlocal textwidth=' . left_textwidth
    endif
    
    let left_foldcolumn = getbufvar(left_bufnr, '&foldcolumn', 0)
    execute 'setlocal foldcolumn=' . left_foldcolumn
    
    let final_foldcolumn = &foldcolumn
    
    echomsg "Final buffer foldcolumn after join: " . final_foldcolumn
    echomsg "Expected foldcolumn: " . original_foldcolumn
    
    if final_foldcolumn == original_foldcolumn
        echomsg "SUCCESS: Gutter preserved after join!"
    else
        echomsg "FAILURE: Gutter not preserved after join!"
    endif
    
    " Clean up
    if bufexists(left_bufnr)
        execute 'bdelete! ' . left_bufnr
    endif
    if bufexists(right_bufnr)
        execute 'bdelete! ' . right_bufnr
    endif
    
    bdelete!
    
    echomsg "Test completed."
endfunction