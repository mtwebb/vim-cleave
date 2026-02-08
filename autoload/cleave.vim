" cleave.vim - autoload script for cleave plugin

" Global variable for gutter width
if !exists('g:cleave_gutter')
    let g:cleave_gutter = 3
endif

" ============================================================================
" Virtual Column Utility Functions
" ============================================================================

" Convert virtual column position to byte position in a string
" Args: string - the string to analyze
"       vcol - virtual column position (1-based)
" Returns: byte position (0-based) or -1 if vcol is beyond string
function! cleave#vcol_to_byte(string, vcol)
    if a:vcol <= 0
        return 0
    endif
    
    let byte_pos = 0
    let current_vcol = 1
    let char_idx = 0
    let string_char_len = strchars(a:string)
    
    while char_idx < string_char_len && current_vcol < a:vcol
        " Get character at current character index
        let char_str = strcharpart(a:string, char_idx, 1)
        
        " Calculate display width of this character
        if char_str == "\t"
            " Tab width depends on current column position
            let tab_width = &tabstop - ((current_vcol - 1) % &tabstop)
            let current_vcol += tab_width
        else
            let char_display_width = strdisplaywidth(char_str)
            let current_vcol += char_display_width
        endif
        
        " Move to next character
        let char_idx += 1
        let byte_pos = byteidx(a:string, char_idx)
    endwhile
    
    " If we've reached or exceeded the target vcol, return current byte position
    " If vcol is beyond string, return -1
    if current_vcol >= a:vcol
        return byte_pos
    else
        return -1
    endif
endfunction

" Convert byte position to virtual column position
" Args: string - the string to analyze
"       byte_pos - byte position (0-based)
" Returns: virtual column position (1-based)
function! cleave#byte_to_vcol(string, byte_pos)
    if a:byte_pos <= 0
        return 1
    endif
    
    let string_len = len(a:string)
    let target_byte_pos = min([a:byte_pos, string_len])
    
    " Convert byte position to character index
    let target_char_idx = charidx(a:string, target_byte_pos)
    
    let current_vcol = 1
    let char_idx = 0
    
    while char_idx < target_char_idx
        " Get character at current character index
        let char_str = strcharpart(a:string, char_idx, 1)
        
        " Calculate display width of this character
        if char_str == "\t"
            " Tab width depends on current column position
            let tab_width = &tabstop - ((current_vcol - 1) % &tabstop)
            let current_vcol += tab_width
        else
            let char_display_width = strdisplaywidth(char_str)
            let current_vcol += char_display_width
        endif
        
        " Move to next character
        let char_idx += 1
    endwhile
    
    return current_vcol
endfunction

" Extract substring based on virtual column positions
" Args: string - the string to split
"       start_vcol - starting virtual column (1-based, inclusive)
"       end_vcol - ending virtual column (1-based, exclusive) or -1 for end of string
" Returns: substring based on virtual column positions
function! cleave#virtual_strpart(string, start_vcol, ...)
    let end_vcol = a:0 > 0 ? a:1 : -1
    
    " Handle edge cases
    if a:start_vcol <= 0
        let start_vcol = 1
    else
        let start_vcol = a:start_vcol
    endif
    
    " Convert virtual columns to byte positions
    let start_byte = cleave#vcol_to_byte(a:string, start_vcol)
    if start_byte == -1
        " Start position is beyond string
        return ''
    endif
    
    if end_vcol <= 0
        " Extract from start_vcol to end of string
        return strpart(a:string, start_byte)
    else
        let end_byte = cleave#vcol_to_byte(a:string, end_vcol)
        if end_byte == -1
            " End position is beyond string, extract to end
            return strpart(a:string, start_byte)
        else
            " Extract substring between byte positions
            let length = end_byte - start_byte
            return strpart(a:string, start_byte, length)
        endif
    endif
endfunction

" Script-local variables to store buffer numbers
let s:cleave_original_bufnr = -1
let s:cleave_left_bufnr = -1
let s:cleave_right_bufnr = -1

" Helper function to validate if stored buffer numbers are still valid
function! s:validate_cleave_buffers()
    return s:cleave_original_bufnr != -1 && 
         \ s:cleave_left_bufnr != -1 && 
         \ s:cleave_right_bufnr != -1 &&
         \ bufexists(s:cleave_original_bufnr) &&
         \ bufexists(s:cleave_left_bufnr) &&
         \ bufexists(s:cleave_right_bufnr)
endfunction

" Helper function to get cleave buffer numbers with validation and fallback
function! s:get_cleave_buffers()
    " First try to use script-local variables if they're valid
    if s:validate_cleave_buffers()
        return [s:cleave_original_bufnr, s:cleave_left_bufnr, s:cleave_right_bufnr]
    endif
    
    " Fallback: search through buffers using the old method
    let current_bufnr = bufnr('%')
    let original_bufnr = getbufvar(current_bufnr, 'cleave_original', -1)
    
    if original_bufnr == -1
        return [-1, -1, -1]
    endif
    
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
    
    " Update script variables if we found valid buffers
    if original_bufnr != -1 && left_bufnr != -1 && right_bufnr != -1
        let s:cleave_original_bufnr = original_bufnr
        let s:cleave_left_bufnr = left_bufnr
        let s:cleave_right_bufnr = right_bufnr
    endif
    
    return [original_bufnr, left_bufnr, right_bufnr]
endfunction

" Helper function to clear script-local variables
function! s:clear_cleave_buffers()
    let s:cleave_original_bufnr = -1
    let s:cleave_left_bufnr = -1
    let s:cleave_right_bufnr = -1
endfunction

function! cleave#split_buffer(bufnr, ...)
    if getbufvar(a:bufnr, '&modified')
        echoerr "Cleave: Buffer has unsaved changes. Please :write before cleaving."
        return
    endif
    " 1. Determine Cleave Column
    let cleave_col = 0
    if a:0 > 0
        " Parameter is interpreted as virtual column position
        let cleave_col = a:1
    else
        " Use virtual column position of cursor
        let cleave_col = virtcol('.')
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

    " 5. Set script-local variables to store buffer numbers
    let s:cleave_original_bufnr = original_bufnr
    let s:cleave_left_bufnr = left_bufnr
    let s:cleave_right_bufnr = right_bufnr

    " 6. Set buffer variables for potential undo
    call setbufvar(left_bufnr, 'cleave_original', original_bufnr)
    call setbufvar(left_bufnr, 'cleave_side', 'left')
    call setbufvar(left_bufnr, 'cleave_col', cleave_col)
    call setbufvar(right_bufnr, 'cleave_original', original_bufnr)
    call setbufvar(right_bufnr, 'cleave_side', 'right')
    call setbufvar(right_bufnr, 'cleave_col', cleave_col)

    " 6. Initialize text properties to show paragraph alignment
    call cleave#set_text_properties()

endfunction

function! cleave#split_content(lines, cleave_col)
    let left_lines = []
    let right_lines = []
    let split_col = a:cleave_col

    for line in a:lines
        " Use virtual column splitting instead of byte-based splitting
        let left_part = cleave#virtual_strpart(line, 1, split_col)
        let right_part = cleave#virtual_strpart(line, split_col)
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
    " Set textwidth based on longest line in left buffer
    call cleave#set_textwidth_to_longest_line()
    
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
    " Set textwidth based on longest line in right buffer
    call cleave#set_textwidth_to_longest_line()

    return [left_bufnr, right_bufnr]
endfunction

function! cleave#setup_windows(cleave_col, left_bufnr, right_bufnr, original_winid, original_cursor, original_foldcolumn)
    call win_gotoid(a:original_winid)
    vsplit
    
    execute 'buffer' a:left_bufnr
    " Calculate left window width using virtual column position
    " cleave_col is now a virtual column, so this accounts for display width
    " Subtract 2 to account for the split column and add foldcolumn width
    let left_window_width = a:cleave_col - 2 + a:original_foldcolumn
    execute 'vertical resize ' . left_window_width
    call cursor(a:original_cursor[1], a:original_cursor[2])
    set scrollbind

    wincmd l
    execute 'buffer' a:right_bufnr
    call cursor(a:original_cursor[1], a:original_cursor[2])
    set scrollbind

    wincmd h
endfunction

function! cleave#undo_cleave()
    " Get buffer numbers using helper function
    let [original_bufnr, left_bufnr, right_bufnr] = s:get_cleave_buffers()

    if original_bufnr == -1 || left_bufnr == -1 || right_bufnr == -1
        echoerr "Cleave: Not a cleave buffer or buffers not found."
        return
    endif

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

    " Clear script-local variables since cleave is undone
    call s:clear_cleave_buffers()
endfunction



function! cleave#join_buffers()
    " Get buffer numbers using helper function
    let [original_bufnr, left_bufnr, right_bufnr] = s:get_cleave_buffers()

    if original_bufnr == -1 || left_bufnr == -1 || right_bufnr == -1
        echoerr "Cleave: Not a cleave buffer or buffers not found."
        return
    endif

    " Get cleave column from buffer variables (still needed for joining logic)
    "XXX why current? should get from left.
    "cleave col is missing gutter offset
    let current_bufnr = bufnr('%')
    let cleave_col = getbufvar(current_bufnr, 'cleave_col', -1)

    if cleave_col == -1
        echoerr "Cleave: Missing cleave column information."
        return
    endif

    " Get content from both buffers
    let left_lines = getbufline(left_bufnr, 1, '$')
    let right_lines = getbufline(right_bufnr, 1, '$')

    " Use the original cleave_col value for consistent virtual column alignment
    " This ensures that the right content starts at the same virtual column position
    " where the original split occurred, accounting for display width properly
    let cleave_column = cleave_col

    " Combine the content
    let combined_lines = []
    let max_lines = max([len(left_lines), len(right_lines)])
    
    for i in range(max_lines)
        let left_line = (i < len(left_lines)) ? left_lines[i] : ''
        let right_line = (i < len(right_lines)) ? right_lines[i] : ''
        
        " Only add padding if there's content in the right part
        " This prevents adding unnecessary spaces to lines that were originally shorter than cleave_column
        if empty(right_line)
            " No right content, just use the left line as-is
            let combined_line = left_line
        else
            " Calculate padding needed to reach cleave_column
            let left_len = strdisplaywidth(left_line)
            let padding_needed = cleave_column - 1 - left_len
            let padding = padding_needed > 0 ? repeat(' ', padding_needed) : ''
            
            let combined_line = left_line . padding . right_line
        endif
        
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
    let left_textwidth = getbufvar(left_bufnr, '&textwidth', 0)
    if left_textwidth > 0
        call setbufvar(original_bufnr, '&textwidth', left_textwidth)
    endif
    
    " Set foldcolumn of joined buffer to match LEFT buffer's foldcolumn
    let left_foldcolumn = getbufvar(left_bufnr, '&foldcolumn', 0)
    call setbufvar(original_bufnr, '&foldcolumn', left_foldcolumn)

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

    " Clear script-local variables since buffers are joined
    call s:clear_cleave_buffers()

    echomsg "Cleave: Buffers joined successfully."
endfunction

function! cleave#reflow_buffer(new_width)
    " Get buffer numbers using helper function
    let [original_bufnr, left_bufnr, right_bufnr] = s:get_cleave_buffers()
    
    if original_bufnr == -1 || left_bufnr == -1 || right_bufnr == -1
        echoerr "Cleave: Not a cleave buffer or buffers not found."
        return
    endif
    
    if a:new_width < 10
        echoerr "Cleave: Width must be at least 10 characters"
        return
    endif
    
    " Detect which side the current buffer is
    let current_bufnr = bufnr('%')
    let current_side = getbufvar(current_bufnr, 'cleave_side', '')
    
    if empty(current_side)
        echoerr "Cleave: Current buffer is not a cleave buffer (.left or .right)"
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
    " Dedicated right buffer reflow logic. Assumed called in right buffer
    " Reflows the content to new width attempting to keep existing paragraph
    " Assumed right paragraphs are in correct position prior to reflowing
    " Start locations. Does not not reference 
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
        elseif i > 0 && trimmed_line != ''
            " Check if this is a paragraph start - previous line must be empty
            let prev_right_empty = trim(current_lines[i-1]) == ''
            
            if prev_right_empty
                let is_paragraph_start = v:true
            endif
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

function! cleave#reflow_left_buffer(new_width, current_bufnr, left_bufnr, right_bufnr)
    " Dedicated left buffer reflow logic (updated to handle current right buffer state)
    " Step 1: Find paragraph positions in RIGHT buffer (current state)
    let right_lines = getbufline(a:right_bufnr, 1, '$')
    let left_lines = getbufline(a:left_bufnr, 1, '$')
    let right_para_line_numbers = []
    
    "echomsg "CleaveReflow DEBUG: Right buffer has " . len(right_lines) . " lines"
    
    for i in range(len(right_lines))
        let line = right_lines[i]
        let is_paragraph_start = v:false
        
        if i == 0 && trim(line) != ''
            " First line is a paragraph start if not empty
            let is_paragraph_start = v:true
        elseif i > 0 && trim(line) != ''
            " Check if this can be a paragraph start based on left buffer context
            " Allow paragraph start if previous right line is empty OR corresponding left line is empty/whitespace
            let prev_right_empty = trim(right_lines[i-1]) == ''
            let left_line_empty = (i-1 < len(left_lines)) ? (trim(left_lines[i-1]) == '') : v:true
            
            if prev_right_empty || left_line_empty
                let is_paragraph_start = v:true
            endif
        endif
        
        if is_paragraph_start
            call add(right_para_line_numbers, i + 1)  " Convert to 1-based line numbers
            "echomsg "CleaveReflow DEBUG: Found paragraph start at line " . (i + 1) . ": '" . line . "'"
        endif
    endfor
    
    "echomsg "CleaveReflow DEBUG: Right buffer paragraph line numbers: " . string(right_para_line_numbers)
    
    " Step 2: Store paragraph first words from LEFT buffer at corresponding positions
    " This handles cases where new paragraphs may have been added to the right buffer
    let para_first_words = []
    let left_lines = getbufline(a:left_bufnr, 1, '$')
    "echomsg "CleaveReflow DEBUG: Left buffer has " . len(left_lines) . " lines"
    
    " For each paragraph position in the right buffer, try to find corresponding content in left buffer
    for line_num in right_para_line_numbers
        let first_word = ''
        
        " Check if there's content at this line in the left buffer
        if line_num <= len(left_lines)
            let line_text = left_lines[line_num - 1]  " Convert to 0-based for array access
            let first_word_match = matchstr(trim(line_text), '\S\+')
            if len(first_word_match) > 0
                let first_word = first_word_match
                "echomsg "CleaveReflow DEBUG: Found first word at line " . line_num . ": '" . first_word . "'"
            endif
        endif
        
        " If no content at exact line, search nearby lines for paragraph content
        if empty(first_word)
            " Search within a small range around the target line
            let search_start = max([1, line_num - 2])
            let search_end = min([len(left_lines), line_num + 2])
            
            for search_line in range(search_start, search_end)
                let line_text = left_lines[search_line - 1]
                let trimmed_text = trim(line_text)
                
                " Check if this could be a paragraph start
                let is_para_start = v:false
                if search_line == 1 && !empty(trimmed_text)
                    let is_para_start = v:true
                elseif search_line > 1 && empty(trim(left_lines[search_line - 2])) && !empty(trimmed_text)
                    let is_para_start = v:true
                endif
                
                if is_para_start
                    let first_word = matchstr(trimmed_text, '\S\+')
                    if !empty(first_word)
                        "echomsg "CleaveReflow DEBUG: Found nearby first word at line " . search_line . ": '" . first_word . "'"
                        break
                    endif
                endif
            endfor
        endif
        
        call add(para_first_words, first_word)
        if empty(first_word)
            "echomsg "CleaveReflow DEBUG: No first word found for right buffer line " . line_num
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
    " XXX this needs gutter width added
    let new_cleave_col = a:new_width + g:cleave_gutter + 1
    call setbufvar(a:current_bufnr, 'cleave_col', new_cleave_col)
    call setbufvar(a:right_bufnr, 'cleave_col', new_cleave_col)
    
    " Resize left window
    let left_winid = get(win_findbuf(a:current_bufnr), 0, -1)
    let original_foldcolumn = left_winid != -1 ? getwinvar(left_winid, '&foldcolumn') : 0
    execute 'vertical resize ' . (a:new_width + original_foldcolumn + g:cleave_gutter)
    
    " Set textwidth for the reflowed buffer
    execute 'setlocal textwidth=' . a:new_width
    
    echomsg "Cleave: Reflowed left buffer to width " . a:new_width
    call cleave#set_text_properties()
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

function! cleave#set_textwidth_to_longest_line()
    " Set textwidth option to the display width of the longest line in the current buffer
    " Ignores trailing whitespace when calculating display width
    let max_length = 0
    let line_count = line('$')
    
    for line_num in range(1, line_count)
        let line_text = getline(line_num)
        " Remove trailing whitespace before calculating display width
        let trimmed_line = substitute(line_text, '\s\+$', '', '')
        let line_length = strdisplaywidth(trimmed_line)
        if line_length > max_length
            let max_length = line_length
        endif
    endfor
    
    " Set textwidth to the maximum display width found
    execute 'setlocal textwidth=' . max_length
    
    return max_length
endfunction

function! cleave#get_right_buffer_paragraph_lines()
    " Returns array of line numbers (1-based) where paragraphs start in the right buffer
    " Uses script-local variable to identify the right buffer
    if s:cleave_right_bufnr == -1 || !bufexists(s:cleave_right_bufnr)
        echoerr "Cleave: Right buffer not found or not valid"
        return []
    endif
    
    let current_lines = getbufline(s:cleave_right_bufnr, 1, '$')
    let para_line_numbers = []
    
    for i in range(len(current_lines))
        let line = current_lines[i]
        let trimmed_line = trim(line)
        let is_paragraph_start = v:false
        
        if i == 0 && trimmed_line != ''
            let is_paragraph_start = v:true
        elseif i > 0 && trimmed_line != ''
            " Check if this is a paragraph start - previous line must be empty
            let prev_right_empty = trim(current_lines[i-1]) == ''
            
            if prev_right_empty
                let is_paragraph_start = v:true
            endif
        endif
        
        if is_paragraph_start
            call add(para_line_numbers, i + 1)  " Convert to 1-based line numbers
        endif
    endfor
    
    return para_line_numbers
endfunction

function! cleave#get_left_buffer_paragraph_lines()
    " Returns array of line numbers (1-based) that have cleave_paragraph_start text property in left buffer
    " Uses script-local variable to identify the left buffer
    " If no text properties exist, creates them by calling cleave#set_text_properties()
    
    if s:cleave_left_bufnr == -1 || !bufexists(s:cleave_left_bufnr)
        echoerr "Cleave: Left buffer not found or not valid"
        return []
    endif
    
    " Check if text properties are supported
    if !has('textprop')
        echomsg "Cleave: Text properties not supported in this Vim version"
        return []
    endif
    
    let prop_type = 'cleave_paragraph_start'
    let para_line_numbers = []
    
    " Get all text properties of the specified type from the left buffer
    let props = prop_list(1, {'bufnr': s:cleave_left_bufnr, 'types': [prop_type], 'end_lnum': -1})
    
    " Extract line numbers from properties
    for prop in props
        call add(para_line_numbers, prop.lnum)
    endfor
    
    " If no properties found, create them
    if empty(para_line_numbers)
        echomsg "Cleave: No text properties found, creating them..."
        call cleave#set_text_properties()
        
        " Try again to get the properties
        let props = prop_list(1, {'bufnr': s:cleave_left_bufnr, 'types': [prop_type], 'end_lnum': -1})
        for prop in props
            call add(para_line_numbers, prop.lnum)
        endfor
    endif
    
    return para_line_numbers
endfunction

function! cleave#toggle_paragraph_highlight()
    " Toggle the highlight group for cleave_paragraph_start between Normal and MatchParen
    if !has('textprop')
        echomsg "Cleave: Text properties not supported in this Vim version"
        return
    endif
    
    let prop_type = 'cleave_paragraph_start'
    
    " Check if the property type exists
    try
        let current_highlight = prop_type_get(prop_type)
    catch
        echomsg "Cleave: Text property type '" . prop_type . "' not found"
        return
    endtry
    
    " Get current highlight group
    let current_group = get(current_highlight, 'highlight', 'Normal')
    
    " Toggle between Normal and MatchParen
    if current_group == 'Normal'
        let new_group = 'MatchParen'
    else
        let new_group = 'Normal'
    endif
    
    " Update the property type with new highlight
    call prop_type_change(prop_type, {'highlight': new_group})
    
    " Force immediate visual update by temporarily moving cursor in each cleave window
    let [original_bufnr, left_bufnr, right_bufnr] = s:get_cleave_buffers()
    let current_winid = win_getid()
    
    " Update left buffer windows
    if left_bufnr != -1
        for winid in win_findbuf(left_bufnr)
            let saved_winid = win_getid()
            call win_gotoid(winid)
            let saved_pos = getcurpos()
            " Trigger text property refresh by briefly moving cursor
            execute "normal! \<C-L>"
            call setpos('.', saved_pos)
            call win_gotoid(saved_winid)
        endfor
    endif
    
    " Update right buffer windows  
    if right_bufnr != -1
        for winid in win_findbuf(right_bufnr)
            let saved_winid = win_getid()
            call win_gotoid(winid)
            let saved_pos = getcurpos()
            " Trigger text property refresh by briefly moving cursor
            execute "normal! \<C-L>"
            call setpos('.', saved_pos)
            call win_gotoid(saved_winid)
        endfor
    endif
    
    " Return to original window and force final redraw
    call win_gotoid(current_winid)
    redraw!
    
    echomsg "Cleave: Paragraph highlight changed to " . new_group
endfunction

function! cleave#place_right_paragraphs_at_lines(target_line_numbers)
    " Places paragraphs from the right buffer at specified line numbers
    " If a paragraph would overlap with a previously placed paragraph, 
    " slides it down to maintain one blank line separation
    " 
    " Args: target_line_numbers - array of 1-based line numbers where paragraphs should be placed
    
    if s:cleave_right_bufnr == -1 || !bufexists(s:cleave_right_bufnr)
        echoerr "Cleave: Right buffer not found or not valid"
        return
    endif
    
    if empty(a:target_line_numbers)
        echomsg "Cleave: No target line numbers provided"
        return
    endif
    
    " Step 1: Extract current paragraphs from right buffer
    let current_lines = getbufline(s:cleave_right_bufnr, 1, '$')
    let paragraphs = []
    let current_para_lines = []
    
    for i in range(len(current_lines))
        let line = current_lines[i]
        let trimmed_line = trim(line)
        let is_paragraph_start = v:false
        
        if i == 0 && trimmed_line != ''
            let is_paragraph_start = v:true
        elseif i > 0 && trimmed_line != ''
            " Check if this is a paragraph start - previous line must be empty
            let prev_right_empty = trim(current_lines[i-1]) == ''
            
            if prev_right_empty
                let is_paragraph_start = v:true
            endif
        endif
        
        if is_paragraph_start
            " Save previous paragraph if we have one
            if !empty(current_para_lines)
                call add(paragraphs, copy(current_para_lines))
            endif
            
            " Start new paragraph
            let current_para_lines = [trimmed_line]
        elseif !empty(current_para_lines) && trimmed_line != ''
            " Continue current paragraph - only add non-empty lines
            call add(current_para_lines, trimmed_line)
        endif
    endfor
    
    " Save final paragraph
    if !empty(current_para_lines)
        call add(paragraphs, copy(current_para_lines))
    endif
    
    " Step 2: Place paragraphs at target positions with conflict resolution
    let new_buffer_lines = []
    let current_line_num = 1
    let actual_positions = []
    
    for i in range(len(paragraphs))
        " Get target line for this paragraph (use 1 if array is shorter)
        let target_line = (i < len(a:target_line_numbers)) ? a:target_line_numbers[i] : 1
        let paragraph = paragraphs[i]
        let para_length = len(paragraph)
        
        " Determine actual placement position
        let actual_position = max([target_line, current_line_num])
        
        " Add empty lines to reach the actual position
        while current_line_num < actual_position
            call add(new_buffer_lines, '')
            let current_line_num += 1
        endwhile
        
        " Record where this paragraph actually starts
        call add(actual_positions, actual_position)
        
        " Add the paragraph lines
        for para_line in paragraph
            call add(new_buffer_lines, para_line)
            let current_line_num += 1
        endfor
        
        " Ensure at least one blank line after paragraph (except for last paragraph)
        if i < len(paragraphs) - 1
            call add(new_buffer_lines, '')
            let current_line_num += 1
        endif
    endfor
    
    " Step 3: Update the right buffer
    call setbufline(s:cleave_right_bufnr, 1, new_buffer_lines)
    
    " Remove any extra lines beyond our new content
    let total_lines = len(getbufline(s:cleave_right_bufnr, 1, '$'))
    if total_lines > len(new_buffer_lines)
        call deletebufline(s:cleave_right_bufnr, len(new_buffer_lines) + 1, total_lines)
    endif
    
    echomsg "Cleave: Placed " . len(paragraphs) . " paragraphs at target positions"
    return actual_positions
endfunction

function! cleave#align_right_to_left_paragraphs()
    " Aligns right buffer paragraphs to match left buffer paragraph positions
    " Gets paragraph line numbers from left buffer text properties and places
    " right buffer paragraphs at those positions
    
    let left_para_lines = cleave#get_left_buffer_paragraph_lines()
    if empty(left_para_lines)
        echomsg "Cleave: No paragraph positions found in left buffer"
        return
    endif
    
    let actual_positions = cleave#place_right_paragraphs_at_lines(left_para_lines)
    echomsg "Cleave: Aligned right buffer paragraphs at lines: " . string(actual_positions)
endfunction

function! cleave#wrap_paragraph(paragraph_lines, width)
    " Join paragraph into single string
    let text = join(a:paragraph_lines, ' ')
    let words = split(text, '\s\+')
    let wrapped = []
    let current_line = ''
    
    for word in words
        let test_line = empty(current_line) ? word : current_line . ' ' . word
        
        " Use display width instead of byte length for proper multi-byte character handling
        if strdisplaywidth(test_line) <= a:width
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
    
    " Get corresponding left buffer lines for context using script variables
    let left_lines = []
    let left_bufnr = -1
    
    " Try to use script-local variables first
    if s:validate_cleave_buffers() && s:cleave_right_bufnr == a:right_bufnr
        let left_bufnr = s:cleave_left_bufnr
        let left_lines = getbufline(left_bufnr, 1, '$')
    else
        " Fallback: Find the left buffer that corresponds to this right buffer
        let original_bufnr = getbufvar(a:right_bufnr, 'cleave_original', -1)
        if original_bufnr != -1
            for i in range(1, bufnr("$"))
                if bufexists(i) && getbufvar(i, 'cleave_original', -1) == original_bufnr && getbufvar(i, 'cleave_side', '') == 'left'
                    let left_bufnr = i
                    let left_lines = getbufline(i, 1, '$')
                    break
                endif
            endfor
        endif
    endif
    
    " Step 1: Extract paragraphs into data structures with their target line numbers
    let paragraphs = []
    let para_idx = 0
    let current_para_lines = []
    let current_para_start = -1
    
    " Find paragraphs in cleaned right buffer using improved logic
    for i in range(len(cleaned_lines))
        let line = cleaned_lines[i]
        let trimmed_line = trim(line)
        let is_paragraph_start = v:false
        
        if i == 0 && trimmed_line != ''
            let is_paragraph_start = v:true
        elseif i > 0 && trimmed_line != ''
            " Check if this can be a paragraph start based on left buffer context
            " Allow paragraph start if previous right line is empty OR corresponding left line is empty/whitespace
            let prev_right_empty = trim(cleaned_lines[i-1]) == ''
            let left_line_empty = (i-1 < len(left_lines)) ? (trim(left_lines[i-1]) == '') : v:true
            
            if prev_right_empty || left_line_empty
                let is_paragraph_start = v:true
            endif
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

function! cleave#set_text_properties()
    " Get buffer numbers using helper function
    let [original_bufnr, left_bufnr, right_bufnr] = s:get_cleave_buffers()
    
    if original_bufnr == -1 || left_bufnr == -1 || right_bufnr == -1
        echoerr "Cleave: Not a cleave buffer or buffers not found."
        return
    endif
    
    " Check if text properties are supported
    if !has('textprop')
        echomsg "Cleave: Text properties not supported in this Vim version"
        return
    endif
    
    " Define text property type for paragraph markers
    let prop_type = 'cleave_paragraph_start'
    try
        "TODO: indicate the word note is anchored to
        "underline perhaps? 
        call prop_type_add(prop_type, {'highlight': 'MatchParen'})
        "call prop_type_add(prop_type, {})
    catch /E969:/
        " Property type already exists, that's fine
    endtry
    
    " Clear existing text properties in left buffer
    call prop_remove({'type': prop_type, 'bufnr': left_bufnr, 'all': 1})
    
    " Get content from both buffers
    let right_lines = getbufline(right_bufnr, 1, '$')
    let left_lines = getbufline(left_bufnr, 1, '$')
    
    " Find paragraph start positions in right buffer
    let right_para_positions = []
    for i in range(len(right_lines))
        let line = right_lines[i]
        let is_paragraph_start = v:false
        
        if i == 0 && trim(line) != ''
            " First line is a paragraph start if not empty
            let is_paragraph_start = v:true
        elseif i > 0 && trim(line) != ''
            " Check if this can be a paragraph start based on left buffer context
            let prev_right_empty = trim(right_lines[i-1]) == ''
            let left_line_empty = (i-1 < len(left_lines)) ? (trim(left_lines[i-1]) == '') : v:true
            
            if prev_right_empty || left_line_empty
                let is_paragraph_start = v:true
            endif
        endif
        
        if is_paragraph_start
            call add(right_para_positions, i + 1)  " Convert to 1-based line numbers
        endif
    endfor
    
    " Add text properties to corresponding lines in left buffer
    let properties_added = 0
    for line_num in right_para_positions
        if line_num <= len(left_lines)
            let left_line = left_lines[line_num - 1]  " Convert to 0-based for array access
            if trim(left_line) != ''
                " Add text property to the first word of the line
                " Extract the first word and calculate its proper character length
                let first_word = matchstr(trim(left_line), '\S\+')
                if !empty(first_word)
                    " Calculate the character length (not byte length) of the first word
                    let first_word_char_len = strchars(first_word)
                    call prop_add(line_num, 1, {
                        \ 'type': prop_type,
                        \ 'length': first_word_char_len,
                        \ 'bufnr': left_bufnr
                        \ })
                    let properties_added += 1
                endif
            else
                " Line is empty, add text property to first column
                call prop_add(line_num, 1, {
                    \ 'type': prop_type,
                    \ 'length': 0,
                    \ 'bufnr': left_bufnr
                    \ })
                let properties_added += 1
            endif
        endif
    endfor
    
    echomsg "Cleave: Refreshed " . properties_added . " text properties in left buffer"
endfunction
