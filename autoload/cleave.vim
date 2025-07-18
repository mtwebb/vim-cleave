" cleave.vim - autoload script for cleave plugin

" Global variable for gutter width
if !exists('g:cleave_gutter')
    let g:cleave_gutter = 3
endif

function! cleave#split_buffer(bufnr, ...)
    " 1. Determine Cleave Column
    let cleave_col = 0
    if a:0 > 0
        let cleave_col = a:1
    else
        let cleave_col = col('.')
    endif

    if cleave_col == 1
        echoerr "Cleave: Cannot split at the first column."
        return
    endif

    let original_bufnr = a:bufnr
    let original_winid = win_getid()
    let original_cursor = getcurpos()

    " 2. Content Extraction
    let original_lines = getbufline(original_bufnr, 1, '$')
    let [left_lines, right_lines] = cleave#split_content(original_lines, cleave_col)

    " 3. Buffer Creation
    let original_name = expand('%:t')
    if empty(original_name)
        let original_name = 'noname'
    endif
    let original_foldcolumn = &foldcolumn
    let [left_bufnr, right_bufnr] = cleave#create_buffers(left_lines, right_lines, original_name, original_foldcolumn)

    " 4. Window Management
    call cleave#setup_windows(cleave_col, left_bufnr, right_bufnr, original_winid, original_cursor, original_foldcolumn)

    " 5. Set buffer variables for potential undo
    call setbufvar(left_bufnr, 'cleave_original', original_bufnr)
    call setbufvar(left_bufnr, 'cleave_side', 'left')
    call setbufvar(left_bufnr, 'cleave_col', cleave_col)
    call setbufvar(right_bufnr, 'cleave_original', original_bufnr)
    call setbufvar(right_bufnr, 'cleave_side', 'right')
    call setbufvar(right_bufnr, 'cleave_col', cleave_col)

endfunction

function! cleave#split_content(lines, cleave_col)
    let left_lines = []
    let right_lines = []
    let split_col = a:cleave_col

    for line in a:lines
        let left_part = strpart(line, 0, split_col - 1)
        let right_part = strpart(line, split_col - 1)
        call add(left_lines, left_part)
        call add(right_lines, right_part)
    endfor
    return [left_lines, right_lines]
endfunction

function! cleave#create_buffers(left_lines, right_lines, original_name, original_foldcolumn)
    " Create left buffer
    silent execute 'enew'
    silent execute 'file ' . fnameescape(a:original_name . '.left')
    let left_bufnr = bufnr('%')
    call setline(1, a:left_lines)
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    execute 'setlocal foldcolumn=' . a:original_foldcolumn
    
    " Create right buffer
    silent execute 'enew'
    silent execute 'file ' . fnameescape(a:original_name . '.right')
    let right_bufnr = bufnr('%')
    call setline(1, a:right_lines)
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal foldcolumn=0
    setlocal filetype=right

    return [left_bufnr, right_bufnr]
endfunction

function! cleave#setup_windows(cleave_col, left_bufnr, right_bufnr, original_winid, original_cursor, original_foldcolumn)
    call win_gotoid(a:original_winid)
    vsplit
    
    execute 'buffer' a:left_bufnr
    execute 'vertical resize ' . (a:cleave_col - 2 + a:original_foldcolumn)
    call cursor(a:original_cursor[1], a:original_cursor[2])
    set scrollbind

    wincmd l
    execute 'buffer' a:right_bufnr
    call cursor(a:original_cursor[1], a:original_cursor[2])
    set scrollbind

    wincmd h
endfunction

function! cleave#undo_cleave()
    let current_bufnr = bufnr('%')
    let original_bufnr = getbufvar(current_bufnr, 'cleave_original', -1)

    if original_bufnr == -1
        echoerr "Cleave: Not a cleave buffer."
        return
    endif

    " Find the left and right buffers by iterating through all existing buffers
    let left_bufnr = -1
    let right_bufnr = -1
    for i in range(1, bufnr("$"))
        if bufexists(i) && getbufvar(i, 'cleave_original', -1) == original_bufnr
            if getbufvar(i, 'cleave_side', '') == 'left'
                let left_bufnr = i
            elseif getbufvar(i, 'cleave_side', '') == 'right'
                let right_bufnr = i
            endif
        endif
    endfor

    " Find the windows associated with the buffers
    let left_win_id = get(win_findbuf(left_bufnr), 0, -1)
    let right_win_id = get(win_findbuf(right_bufnr), 0, -1)

    " Restore the original buffer and close the windows
    if left_win_id != -1
        call win_gotoid(left_win_id)
        execute 'buffer' original_bufnr
    else
        execute 'buffer' original_bufnr
    endif

    if right_win_id != -1
        call win_gotoid(right_win_id)
        close
    endif

    " Finally, delete the temporary buffers
    if bufexists(left_bufnr)
        execute 'bdelete!' left_bufnr
    endif
    if bufexists(right_bufnr)
        execute 'bdelete!' right_bufnr
    endif
endfunction

function! cleave#sync_buffers()
    if !g:cleave_auto_sync
        return
    endif

    let current_bufnr = bufnr('%')
    let original_bufnr = getbufvar(current_bufnr, 'cleave_original', -1)
    if original_bufnr == -1
        return
    endif

    let side = getbufvar(current_bufnr, 'cleave_side', '')
    let other_side = (side == 'left') ? 'right' : 'left' 

    " Find the other buffer
    let buflist = getbufinfo({'buflisted': 1})
    let other_bufnr = -1
    for buf in buflist
        if getbufvar(buf.bufnr, 'cleave_original', -1) == original_bufnr && getbufvar(buf.bufnr, 'cleave_side', '') == other_side
            let other_bufnr = buf.bufnr
            break
        endif
    endfor

    if other_bufnr == -1
        return
    endif

    " Combine the lines from both buffers
    let left_lines = (side == 'left') ? getline(1, '$') : getbufline(other_bufnr, 1, '$')
    let right_lines = (side == 'right') ? getline(1, '$') : getbufline(other_bufnr, 1, '$')

    let combined_lines = []
    for i in range(len(left_lines))
        let right_line = (i < len(right_lines)) ? right_lines[i] : ''
        call add(combined_lines, left_lines[i] . right_line)
    endfor

    " Update the original buffer
    call setbufline(original_bufnr, 1, combined_lines)

endfunction

function! cleave#join_buffers()
    let current_bufnr = bufnr('%')
    let original_bufnr = getbufvar(current_bufnr, 'cleave_original', -1)
    let cleave_col = getbufvar(current_bufnr, 'cleave_col', -1)

    if original_bufnr == -1 || cleave_col == -1
        echoerr "Cleave: Not a cleave buffer or missing cleave column."
        return
    endif

    " Find the left and right buffers
    let left_bufnr = -1
    let right_bufnr = -1
    for i in range(1, bufnr("$"))
        if bufexists(i) && getbufvar(i, 'cleave_original', -1) == original_bufnr
            if getbufvar(i, 'cleave_side', '') == 'left'
                let left_bufnr = i
            elseif getbufvar(i, 'cleave_side', '') == 'right'
                let right_bufnr = i
            endif
        endif
    endfor

    if left_bufnr == -1 || right_bufnr == -1
        echoerr "Cleave: Could not find both left and right buffers."
        return
    endif

    " Get content from both buffers
    let left_lines = getbufline(left_bufnr, 1, '$')
    let right_lines = getbufline(right_bufnr, 1, '$')

    " Calculate cleave_column as textwidth of LEFT buffer + g:cleave_gutter + 1
    let left_textwidth = getbufvar(left_bufnr, '&textwidth', 0)
    if left_textwidth == 0
        " If textwidth is not set, try to get it from the window
        let left_winid = get(win_findbuf(left_bufnr), 0, -1)
        if left_winid != -1
            let left_textwidth = getwinvar(left_winid, '&textwidth', 80)
        else
            let left_textwidth = 80  " Default fallback
        endif
    endif
    let cleave_column = left_textwidth + g:cleave_gutter + 1

    " Combine the content
    let combined_lines = []
    let max_lines = max([len(left_lines), len(right_lines)])
    
    for i in range(max_lines)
        let left_line = (i < len(left_lines)) ? left_lines[i] : ''
        let right_line = (i < len(right_lines)) ? right_lines[i] : ''
        
        " Calculate padding needed to reach cleave_column
        let left_len = len(left_line)
        let padding_needed = cleave_column - 1 - left_len
        let padding = padding_needed > 0 ? repeat(' ', padding_needed) : ''
        
        let combined_line = left_line . padding . right_line
        call add(combined_lines, combined_line)
    endfor


    " Update the original buffer
    " Load the buffer first if it's not loaded
    if !bufloaded(original_bufnr)
        echomsg "Debug: Loading unloaded buffer"
        call bufload(original_bufnr)
    endif
    
    " First clear the buffer, then set new content
    call deletebufline(original_bufnr, 1, '$')
    call setbufline(original_bufnr, 1, combined_lines)

    " Set textwidth of joined buffer to match LEFT buffer's textwidth
    call setbufvar(original_bufnr, '&textwidth', left_textwidth)

    " Find the windows associated with the buffers
    let left_win_id = get(win_findbuf(left_bufnr), 0, -1)
    let right_win_id = get(win_findbuf(right_bufnr), 0, -1)

    " Switch left window to original buffer
    if left_win_id != -1
        call win_gotoid(left_win_id)
        execute 'buffer' original_bufnr
    endif

    " Close the right window
    if right_win_id != -1
        call win_gotoid(right_win_id)
        close
    endif

    " Delete the temporary buffers without saving
    if bufexists(left_bufnr)
        execute 'bdelete!' left_bufnr
    endif
    if bufexists(right_bufnr)
        execute 'bdelete!' right_bufnr
    endif

    " Return to the original buffer window
    if left_win_id != -1
        call win_gotoid(left_win_id)
    endif

    echomsg "Cleave: Buffers joined successfully."
endfunction

function! cleave#reflow_buffer(new_width)
    " Detect if current buffer is a cleave buffer and which side
    let current_bufnr = bufnr('%')
    let original_bufnr = getbufvar(current_bufnr, 'cleave_original', -1)
    let current_side = getbufvar(current_bufnr, 'cleave_side', '')
    let cleave_col = getbufvar(current_bufnr, 'cleave_col', -1)
    
    if original_bufnr == -1 || empty(current_side)
        echoerr "Cleave: Current buffer is not a cleave buffer (.left or .right)"
        return
    endif
    
    if a:new_width < 10
        echoerr "Cleave: Width must be at least 10 characters"
        return
    endif
    
    " Find both left and right buffers
    let left_bufnr = -1
    let right_bufnr = -1
    for i in range(1, bufnr("$"))
        if bufexists(i) && getbufvar(i, 'cleave_original', -1) == original_bufnr
            let side = getbufvar(i, 'cleave_side', '')
            if side == 'left'
                let left_bufnr = i
            elseif side == 'right'
                let right_bufnr = i
            endif
        endif
    endfor
    
    if left_bufnr == -1 || right_bufnr == -1
        echoerr "Cleave: Could not find both left and right buffers"
        return
    endif
    
    " Handle right buffer reflow with dedicated logic
    if current_side == 'right'
        call cleave#reflow_right_buffer(a:new_width, current_bufnr, left_bufnr, right_bufnr)
        return
    endif
    
    " Handle left buffer reflow with dedicated logic
    call cleave#reflow_left_buffer(a:new_width, current_bufnr, left_bufnr, right_bufnr)
endfunction

function! cleave#reflow_right_buffer(new_width, current_bufnr, left_bufnr, right_bufnr)
    " Dedicated right buffer reflow logic
    " Step 1: Note line positions of first line in each paragraph in RIGHT buffer
    let current_lines = getline(1, '$')
    let para_positions = []
    let paragraphs = []
    
    " Find paragraph start positions and extract paragraph content
    let current_para_lines = []
    let current_para_start = -1
    
    for i in range(len(current_lines))
        let line = current_lines[i]
        let trimmed_line = trim(line)
        let is_paragraph_start = v:false
        
        if i == 0 && trimmed_line != ''
            let is_paragraph_start = v:true
        elseif i > 0 && trim(current_lines[i-1]) == '' && trimmed_line != ''
            let is_paragraph_start = v:true
        endif
        
        if is_paragraph_start
            " Save previous paragraph if we have one
            if current_para_start >= 0 && !empty(current_para_lines)
                call add(para_positions, current_para_start + 1)  " Convert to 1-based
                call add(paragraphs, copy(current_para_lines))
            endif
            
            " Start new paragraph
            let current_para_lines = [trimmed_line]
            let current_para_start = i
        elseif current_para_start >= 0 && trimmed_line != ''
            " Continue current paragraph - only add non-empty lines
            call add(current_para_lines, trimmed_line)
        endif
    endfor
    
    " Save final paragraph
    if current_para_start >= 0 && !empty(current_para_lines)
        call add(para_positions, current_para_start + 1)  " Convert to 1-based
        call add(paragraphs, copy(current_para_lines))
    endif
    
    " Step 2: Reflow each paragraph individually to new width
    let reflowed_paragraphs = []
    for para_lines in paragraphs
        let reflowed_para = cleave#wrap_paragraph(para_lines, a:new_width)
        call add(reflowed_paragraphs, reflowed_para)
    endfor
    
    " Step 3: Reconstruct buffer preserving original positions when possible
    let new_buffer_lines = []
    let current_line_num = 1
    let new_para_positions = []
    
    for i in range(len(para_positions))
        let target_line = para_positions[i]
        let reflowed_para = reflowed_paragraphs[i]
        let para_length = len(reflowed_para)
        
        " Check if we can fit this paragraph at its original position
        let can_fit_at_original = v:true
        
        " Check if placing at original position would overlap with next paragraph
        if i < len(para_positions) - 1
            let next_target = para_positions[i + 1]
            let para_end_at_original = target_line + para_length - 1
            
            " Need at least one blank line between paragraphs
            if para_end_at_original >= next_target
                let can_fit_at_original = v:false
            endif
        endif
        
        " Determine actual placement position
        let actual_position = target_line
        if current_line_num > target_line || !can_fit_at_original
            " Can't fit at original position, place at current position with separation
            let actual_position = current_line_num
            
            " Ensure at least one blank line separation from previous content
            if current_line_num > 1 && len(new_buffer_lines) > 0 && new_buffer_lines[-1] != ''
                call add(new_buffer_lines, '')
                let current_line_num += 1
                let actual_position = current_line_num
            endif
        else
            " Can fit at original position, add empty lines to reach it
            while current_line_num < target_line
                call add(new_buffer_lines, '')
                let current_line_num += 1
            endwhile
        endif
        
        " Record the actual position where this paragraph starts
        call add(new_para_positions, actual_position)
        
        " Add the reflowed paragraph
        for para_line in reflowed_para
            call add(new_buffer_lines, para_line)
            let current_line_num += 1
        endfor
    endfor
    
    " Step 4: Update the right buffer
    call setline(1, new_buffer_lines)
    if line('$') > len(new_buffer_lines)
        execute (len(new_buffer_lines) + 1) . ',$delete'
    endif
    
    " Set textwidth for the reflowed buffer
    execute 'setlocal textwidth=' . a:new_width
    
    echomsg "Cleave: Reflowed right buffer to width " . a:new_width
endfunction

function! cleave#update_left_positions_after_right_reflow(left_bufnr, right_bufnr, old_para_positions, new_para_positions)
    " Update left buffer paragraph positions to match new right buffer positions after reflow
    " This ensures that corresponding paragraphs in left and right buffers stay aligned
    
    " Get the current left buffer content
    let left_lines = getbufline(a:left_bufnr, 1, '$')
    
    " Store first words from left buffer at the old paragraph positions for matching
    let para_first_words = []
    for line_num in a:old_para_positions
        if line_num <= len(left_lines)
            let line_text = left_lines[line_num - 1]  " Convert to 0-based for array access
            let first_word_match = matchstr(line_text, '\S\+')
            call add(para_first_words, first_word_match)
        else
            call add(para_first_words, '')
        endif
    endfor
    
    " Find where each paragraph's first word appears in the left buffer
    let updated_left_para_positions = []
    let last_found_line = 0
    
    for i in range(len(para_first_words))
        let target_word = para_first_words[i]
        let new_right_pos = a:new_para_positions[i]
        
        if len(target_word) > 0
            " Search for this first word in the left buffer
            let found = v:false
            for line_idx in range(last_found_line, len(left_lines))
                let line = left_lines[line_idx]
                let first_word_in_line = matchstr(line, '\S\+')
                
                if first_word_in_line == target_word
                    " Check if this is a paragraph start
                    let is_para_start = v:false
                    if line_idx == 0 && trim(line) != ''
                        let is_para_start = v:true
                    elseif line_idx > 0 && trim(left_lines[line_idx-1]) == '' && trim(line) != ''
                        let is_para_start = v:true
                    endif
                    
                    if is_para_start
                        call add(updated_left_para_positions, line_idx + 1)  " Convert to 1-based
                        let last_found_line = line_idx + 1
                        let found = v:true
                        break
                    endif
                endif
            endfor
            
            if !found
                " If we can't find the word, use the new right position as fallback
                call add(updated_left_para_positions, new_right_pos)
            endif
        else
            " No first word, use the new right position
            call add(updated_left_para_positions, new_right_pos)
        endif
    endfor
    
    " Realign left buffer paragraphs to match the new right buffer positions
    if len(updated_left_para_positions) > 0
        call cleave#restore_paragraph_alignment(a:left_bufnr, left_lines, a:new_para_positions)
    endif
endfunction

function! cleave#reflow_left_buffer(new_width, current_bufnr, left_bufnr, right_bufnr)
    " Dedicated left buffer reflow logic (original working implementation)
    " Step 1: Find paragraph positions in RIGHT buffer
    let right_lines = getbufline(a:right_bufnr, 1, '$')
    let right_para_line_numbers = []
    
    "echomsg "CleaveReflow DEBUG: Right buffer has " . len(right_lines) . " lines"
    
    for i in range(len(right_lines))
        let line = right_lines[i]
        let is_paragraph_start = v:false
        
        if i == 0 && trim(line) != ''
            " First line is a paragraph start if not empty
            let is_paragraph_start = v:true
        elseif i > 0 && trim(right_lines[i-1]) == '' && trim(line) != ''
            " Line after empty line that's not empty
            let is_paragraph_start = v:true
        endif
        
        if is_paragraph_start
            call add(right_para_line_numbers, i + 1)  " Convert to 1-based line numbers
            "echomsg "CleaveReflow DEBUG: Found paragraph start at line " . (i + 1) . ": '" . line . "'"
        endif
    endfor
    
    "echomsg "CleaveReflow DEBUG: Right buffer paragraph line numbers: " . string(right_para_line_numbers)
    
    " Step 2: Store paragraph first words for matching after reflow
    let para_first_words = []
    let left_lines = getbufline(a:left_bufnr, 1, '$')
    "echomsg "CleaveReflow DEBUG: Left buffer has " . len(left_lines) . " lines"
    for line_num in right_para_line_numbers
        if line_num <= len(left_lines)
            let line_text = left_lines[line_num - 1]  " Convert to 0-based for array access
            let first_word_match = matchstr(line_text, '\S\+')
            if len(first_word_match) > 0
                call add(para_first_words, first_word_match)
                "echomsg "CleaveReflow DEBUG: Stored first word for line " . line_num . ": '" . first_word_match . "'"
            else
                call add(para_first_words, '')
                "echomsg "CleaveReflow DEBUG: No first word found for line " . line_num
            endif
        else
            call add(para_first_words, '')
            "echomsg "CleaveReflow DEBUG: Skipped line " . line_num . " (beyond left buffer length)"
        endif
    endfor
    
    " Step 3: Reflow the text in the buffer with the cursor
    let current_lines = getline(1, '$')
    let reflowed_lines = cleave#reflow_text(current_lines, a:new_width)
    
    " Update current buffer content
    call setline(1, reflowed_lines)
    if line('$') > len(reflowed_lines)
        execute (len(reflowed_lines) + 1) . ',$delete'
    endif
    
    " Step 3.5: Find updated paragraph positions by matching first words
    let updated_para_line_numbers = []
    let current_buffer_lines = getline(1, '$')
    let last_found_line = 0  " Track last found position to ensure increasing order
    
    " For each stored first word, find where it appears in the reflowed content
    for i in range(len(para_first_words))
        let target_word = para_first_words[i]
        if len(target_word) > 0
            " Search for this first word in the reflowed content, starting after last found position
            let found = v:false
            for line_idx in range(last_found_line, len(current_buffer_lines))
                let line = current_buffer_lines[line_idx]
                let first_word_in_line = matchstr(line, '\S\+')
                
                if first_word_in_line == target_word
                    " Check if this is a paragraph start (first line or after empty line)
                    let is_para_start = v:false
                    if line_idx == 0 && trim(line) != ''
                        let is_para_start = v:true
                    elseif line_idx > 0 && trim(current_buffer_lines[line_idx-1]) == '' && trim(line) != ''
                        let is_para_start = v:true
                    endif
                    
                    if is_para_start
                        call add(updated_para_line_numbers, line_idx + 1)  " Convert to 1-based
                        let last_found_line = line_idx + 1  " Update search start for next paragraph
                        "echomsg "CleaveReflow DEBUG: Found paragraph '" . target_word . "' at line " . (line_idx + 1) . " after reflow"
                        let found = v:true
                        break  " Found this paragraph, move to next
                    endif
                endif
            endfor
            
            if !found
                echomsg "CleaveReflow WARNING: Could not find paragraph starting with '" . target_word . "' after line " . last_found_line
            endif
        endif
    endfor
    
    echomsg "CleaveReflow DEBUG: Text property positions before reflow: " . string(right_para_line_numbers)
    echomsg "CleaveReflow DEBUG: Text property positions after reflow: " . string(updated_para_line_numbers)
    
    " Check that counts match
    if len(updated_para_line_numbers) != len(right_para_line_numbers)
        echomsg "CleaveReflow WARNING: Paragraph count mismatch! Before: " . len(right_para_line_numbers) . ", After: " . len(updated_para_line_numbers)
        echomsg "CleaveReflow DEBUG: Stored first words: " . string(para_first_words)
    else
        echomsg "CleaveReflow DEBUG: Paragraph counts match: " . len(updated_para_line_numbers)
    endif
    
    " Step 4: Adjust RIGHT buffer so each first line is back on updated line numbers
    echomsg "CleaveReflow DEBUG: Calling restore_paragraph_alignment with updated line numbers: " . string(updated_para_line_numbers)
    call cleave#restore_paragraph_alignment(a:right_bufnr, right_lines, updated_para_line_numbers)
    
    " Update window sizing for left buffer reflow
    let new_cleave_col = a:new_width + 1
    call setbufvar(a:current_bufnr, 'cleave_col', new_cleave_col)
    call setbufvar(a:right_bufnr, 'cleave_col', new_cleave_col)
    
    " Resize left window
    let left_winid = get(win_findbuf(a:current_bufnr), 0, -1)
    let original_foldcolumn = left_winid != -1 ? getwinvar(left_winid, '&foldcolumn') : 0
    execute 'vertical resize ' . (a:new_width + original_foldcolumn + g:cleave_gutter)
    
    " Set textwidth for the reflowed buffer
    execute 'setlocal textwidth=' . a:new_width
    
    echomsg "Cleave: Reflowed left buffer to width " . a:new_width
endfunction

function! cleave#create_paragraph_mapping(current_para_positions, other_para_positions)
    " Create mapping between current buffer paragraphs and other buffer paragraphs
    " Returns list of [other_buffer_para_start, other_buffer_para_end] for each current paragraph
    let mapping = []
    let other_idx = 0
    
    for current_pos in a:current_para_positions
        " Find the closest paragraph in other buffer that starts at or after current_pos
        let best_other_idx = -1
        let best_distance = 999999
        
        for i in range(len(a:other_para_positions))
            let other_pos = a:other_para_positions[i]
            let distance = abs(current_pos - other_pos)
            
            " Prefer paragraphs that are close and haven't been used yet
            if distance < best_distance && i >= other_idx
                let best_distance = distance
                let best_other_idx = i
            endif
        endfor
        
        if best_other_idx >= 0 && best_distance <= 3
            " Found a corresponding paragraph
            let para_start = a:other_para_positions[best_other_idx]
            
            " Find end of this paragraph
            let para_end = -1
            if best_other_idx + 1 < len(a:other_para_positions)
                let para_end = a:other_para_positions[best_other_idx + 1] - 1
            endif
            
            call add(mapping, [para_start, para_end])
            let other_idx = best_other_idx + 1
        else
            " No corresponding paragraph found
            call add(mapping, [-1, -1])
        endif
    endfor
    
    return mapping
endfunction

function! cleave#find_paragraph_positions(lines)
    " Find line numbers where paragraphs start (0-based)
    let positions = []
    
    for i in range(len(a:lines))
        let line = a:lines[i]
        let is_paragraph_start = v:false
        
        if i == 0 && trim(line) != ''
            " First line is a paragraph start if not empty
            let is_paragraph_start = v:true
        elseif i > 0 && trim(a:lines[i-1]) == '' && trim(line) != ''
            " Line after empty line that's not empty
            let is_paragraph_start = v:true
        endif
        
        if is_paragraph_start
            call add(positions, i)
        endif
    endfor
    
    return positions
endfunction

function! cleave#reflow_text(lines, width)
    let reflowed = []
    let current_paragraph = []
    
    for line in a:lines
        let trimmed = trim(line)
        
        if empty(trimmed)
            " Empty line - end current paragraph
            if !empty(current_paragraph)
                call extend(reflowed, cleave#wrap_paragraph(current_paragraph, a:width))
                let current_paragraph = []
            endif
            call add(reflowed, '')
        else
            " Add to current paragraph
            call add(current_paragraph, trimmed)
        endif
    endfor
    
    " Handle final paragraph
    if !empty(current_paragraph)
        call extend(reflowed, cleave#wrap_paragraph(current_paragraph, a:width))
    endif
    
    return reflowed
endfunction

function! cleave#wrap_paragraph(paragraph_lines, width)
    " Join paragraph into single string
    let text = join(a:paragraph_lines, ' ')
    let words = split(text, '\s\+')
    let wrapped = []
    let current_line = ''
    
    for word in words
        let test_line = empty(current_line) ? word : current_line . ' ' . word
        
        if len(test_line) <= a:width
            let current_line = test_line
        else
            if !empty(current_line)
                call add(wrapped, current_line)
                let current_line = word
            else
                " Single word longer than width - force it
                call add(wrapped, word)
                let current_line = ''
            endif
        endif
    endfor
    
    if !empty(current_line)
        call add(wrapped, current_line)
    endif
    
    return !empty(wrapped) ? wrapped : ['']
endfunction

function! cleave#restore_paragraph_alignment(right_bufnr, original_right_lines, saved_para_line_numbers)
    " Restore right buffer so paragraph first lines are back on their saved line numbers
    "echomsg "RestoreAlignment DEBUG: Starting with " . len(a:original_right_lines) . " original lines"
    "echomsg "RestoreAlignment DEBUG: Target line numbers: " . string(a:saved_para_line_numbers)
    
    " Step 0: Clean up trailing whitespace from all lines
    let cleaned_lines = []
    for line in a:original_right_lines
        call add(cleaned_lines, substitute(line, '\s\+$', '', ''))
    endfor
    "echomsg "RestoreAlignment DEBUG: Cleaned trailing whitespace from all lines"
    
    " Step 1: Extract paragraphs into data structures with their target line numbers
    let paragraphs = []
    let para_idx = 0
    let current_para_lines = []
    let current_para_start = -1
    
    " Find paragraphs in cleaned right buffer
    for i in range(len(cleaned_lines))
        let line = cleaned_lines[i]
        let trimmed_line = trim(line)
        let is_paragraph_start = v:false
        
        if i == 0 && trimmed_line != ''
            let is_paragraph_start = v:true
        elseif i > 0 && trim(cleaned_lines[i-1]) == '' && trimmed_line != ''
            let is_paragraph_start = v:true
        endif
        
        if is_paragraph_start
            " Save previous paragraph if we have one
            if current_para_start >= 0 && !empty(current_para_lines)
                let target_line = para_idx < len(a:saved_para_line_numbers) ? a:saved_para_line_numbers[para_idx] : -1
                call add(paragraphs, {'target_line': target_line, 'content': copy(current_para_lines)})
                "echomsg "RestoreAlignment DEBUG: Saved paragraph " . para_idx . " with target line " . target_line . " and " . len(current_para_lines) . " lines"
                let para_idx += 1
            endif
            
            " Start new paragraph - only include lines with text
            let current_para_lines = [line]
            let current_para_start = i
            "echomsg "RestoreAlignment DEBUG: Started new paragraph at position " . i . ": '" . line . "'"
        elseif current_para_start >= 0 && trimmed_line != ''
            " Continue current paragraph - only add lines with text content
            call add(current_para_lines, line)
            "echomsg "RestoreAlignment DEBUG: Added to paragraph: '" . line . "'"
        endif
        " Skip empty lines - they are not included in paragraph content
    endfor
    
    " Save final paragraph
    if current_para_start >= 0 && !empty(current_para_lines)
        let target_line = para_idx < len(a:saved_para_line_numbers) ? a:saved_para_line_numbers[para_idx] : -1
        call add(paragraphs, {'target_line': target_line, 'content': copy(current_para_lines)})
        "echomsg "RestoreAlignment DEBUG: Saved final paragraph " . para_idx . " with target line " . target_line . " and " . len(current_para_lines) . " lines"
    endif
    
    "echomsg "RestoreAlignment DEBUG: Extracted " . len(paragraphs) . " paragraphs"
    
    " Step 2: Build new buffer content by placing paragraphs at target positions
    let adjusted_lines = []
    let current_line_num = 1
    
    for para in paragraphs
        if para.target_line > 0
            "echomsg "RestoreAlignment DEBUG: Processing paragraph with target line " . para.target_line
            
            " Add empty lines until we reach the target line
            while current_line_num < para.target_line
                call add(adjusted_lines, '')
                "echomsg "RestoreAlignment DEBUG: Added empty line at position " . current_line_num
                let current_line_num += 1
            endwhile
            
            " Add the paragraph content
            for content_line in para.content
                call add(adjusted_lines, content_line)
                "echomsg "RestoreAlignment DEBUG: Added paragraph line at position " . current_line_num . ": '" . content_line . "'"
                let current_line_num += 1
            endfor
        else
            "echomsg "RestoreAlignment DEBUG: Skipping paragraph with invalid target line " . para.target_line
        endif
    endfor
    
    "echomsg "RestoreAlignment DEBUG: Final adjusted_lines has " . len(adjusted_lines) . " lines"
    
    " Step 3: Update right buffer
    call setbufline(a:right_bufnr, 1, adjusted_lines)
    if getbufinfo(a:right_bufnr)[0].linecount > len(adjusted_lines)
        call deletebufline(a:right_bufnr, len(adjusted_lines) + 1, '$')
        "echomsg "RestoreAlignment DEBUG: Deleted extra lines from right buffer"
    endif
    
    "echomsg "RestoreAlignment DEBUG: Right buffer now has " . getbufinfo(a:right_bufnr)[0].linecount . " lines"
endfunction

function! cleave#realign_other_buffer(other_bufnr, other_lines, para_mapping, new_para_positions)
    " Realign other buffer paragraphs to match new paragraph positions
    let adjusted_lines = []
    let target_line = 0
    
    " Process each new paragraph position with its corresponding mapping
    for i in range(len(a:new_para_positions))
        let new_pos = a:new_para_positions[i]
        
        " Add empty lines to reach the target position
        while target_line < new_pos
            call add(adjusted_lines, '')
            let target_line += 1
        endwhile
        
        " Get the corresponding paragraph from other buffer using mapping
        if i < len(a:para_mapping)
            let [para_start, para_end] = a:para_mapping[i]
            
            if para_start >= 0
                " Determine actual end if not specified
                if para_end < 0
                    let para_end = len(a:other_lines) - 1
                    " Find last non-empty line
                    while para_end > para_start && trim(a:other_lines[para_end]) == ''
                        let para_end -= 1
                    endwhile
                endif
                
                " Copy the paragraph lines
                for line_idx in range(para_start, para_end)
                    if line_idx < len(a:other_lines)
                        call add(adjusted_lines, a:other_lines[line_idx])
                        let target_line += 1
                    endif
                endfor
            else
                " No corresponding paragraph, add empty line
                call add(adjusted_lines, '')
                let target_line += 1
            endif
        else
            " No mapping for this paragraph, add empty line
            call add(adjusted_lines, '')
            let target_line += 1
        endif
    endfor
    
    " Update other buffer
    call setbufline(a:other_bufnr, 1, adjusted_lines)
    if getbufinfo(a:other_bufnr)[0].linecount > len(adjusted_lines)
        call deletebufline(a:other_bufnr, len(adjusted_lines) + 1, '$')
    endif
endfunction

augroup cleave_sync
    autocmd!
    autocmd TextChanged,TextChangedI * call cleave#sync_buffers()
    autocmd CursorMoved * if getbufvar(bufnr('%'), 'cleave_original', -1) != -1 | set scrollbind | endif
augroup END
