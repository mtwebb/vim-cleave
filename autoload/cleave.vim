" cleave.vim - autoload script for cleave plugin

" Global variable for gutter width
if !exists('g:cleave_gutter')
    let g:cleave_gutter = 3
endif

" ============================================================================
" Paragraph Detection Helpers
" ============================================================================

" Simple paragraph start: non-empty line that is first or follows an empty line
function! s:is_para_start(lines, idx)
    if trim(a:lines[a:idx]) ==# ''
        return v:false
    endif
    return a:idx == 0 || trim(a:lines[a:idx - 1]) ==# ''
endfunction

" Paragraph start with left-buffer context: also triggers when the
" corresponding left-buffer line is empty/whitespace
function! s:is_para_start_ctx(lines, left_lines, idx)
    if trim(a:lines[a:idx]) ==# ''
        return v:false
    endif
    if a:idx == 0
        return v:true
    endif
    if trim(a:lines[a:idx - 1]) ==# ''
        return v:true
    endif
    let left_empty = (a:idx - 1 < len(a:left_lines)) ? (trim(a:left_lines[a:idx - 1]) ==# '') : v:true
    return left_empty
endfunction

" Return 1-based line numbers of paragraph starts in lines (simple detection)
function! s:para_starts(lines)
    let result = []
    for i in range(len(a:lines))
        if s:is_para_start(a:lines, i)
            call add(result, i + 1)
        endif
    endfor
    return result
endfunction

" Return 1-based line numbers of paragraph starts using left-context detection
function! s:para_starts_ctx(lines, left_lines)
    let result = []
    for i in range(len(a:lines))
        if s:is_para_start_ctx(a:lines, a:left_lines, i)
            call add(result, i + 1)
        endif
    endfor
    return result
endfunction

" Extract paragraphs from lines as a list of {start: N, content: [lines]}
" Uses simple paragraph detection (prev line empty)
function! s:extract_paragraphs(lines)
    let paragraphs = []
    let current_para = []
    let current_start = -1

    for i in range(len(a:lines))
        let trimmed = trim(a:lines[i])
        if s:is_para_start(a:lines, i)
            if current_start >= 0 && !empty(current_para)
                call add(paragraphs, {'start': current_start + 1, 'content': copy(current_para)})
            endif
            let current_para = [trimmed]
            let current_start = i
        elseif current_start >= 0 && trimmed !=# ''
            call add(current_para, trimmed)
        endif
    endfor

    if current_start >= 0 && !empty(current_para)
        call add(paragraphs, {'start': current_start + 1, 'content': copy(current_para)})
    endif
    return paragraphs
endfunction

" Extract paragraphs using left-context detection, preserving original lines
" (not trimmed). Returns list of {start: N, content: [lines]}
function! s:extract_paragraphs_ctx(lines, left_lines)
    let paragraphs = []
    let current_para = []
    let current_start = -1

    for i in range(len(a:lines))
        let trimmed = trim(a:lines[i])
        if s:is_para_start_ctx(a:lines, a:left_lines, i)
            if current_start >= 0 && !empty(current_para)
                call add(paragraphs, {'start': current_start + 1, 'content': copy(current_para)})
            endif
            let current_para = [a:lines[i]]
            let current_start = i
        elseif current_start >= 0 && trimmed !=# ''
            call add(current_para, a:lines[i])
        endif
    endfor

    if current_start >= 0 && !empty(current_para)
        call add(paragraphs, {'start': current_start + 1, 'content': copy(current_para)})
    endif
    return paragraphs
endfunction

" ============================================================================
" Buffer / Window Helpers
" ============================================================================

" Replace all lines in a buffer, removing any excess trailing lines
function! s:replace_buffer_lines(bufnr, lines)
    call setbufline(a:bufnr, 1, a:lines)
    let total = len(getbufline(a:bufnr, 1, '$'))
    if total > len(a:lines)
        call deletebufline(a:bufnr, len(a:lines) + 1, '$')
    endif
endfunction

" Shared teardown for undo_cleave and join_buffers: close windows, delete
" temp buffers, clear state
function! s:teardown_cleave(original_bufnr, left_bufnr, right_bufnr)
    let left_win_id = get(win_findbuf(a:left_bufnr), 0, -1)
    let right_win_id = get(win_findbuf(a:right_bufnr), 0, -1)

    if left_win_id != -1
        call win_gotoid(left_win_id)
        execute 'buffer' a:original_bufnr
    else
        execute 'buffer' a:original_bufnr
    endif

    if right_win_id != -1
        call win_gotoid(right_win_id)
        close
    endif

    if bufexists(a:left_bufnr)
        execute 'bdelete!' a:left_bufnr
    endif
    if bufexists(a:right_bufnr)
        execute 'bdelete!' a:right_bufnr
    endif

    if left_win_id != -1
        call win_gotoid(left_win_id)
    endif

    call s:clear_cleave_buffers()
endfunction

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
    let [original_bufnr, left_bufnr, right_bufnr] = s:get_cleave_buffers()

    if original_bufnr == -1 || left_bufnr == -1 || right_bufnr == -1
        echoerr "Cleave: Not a cleave buffer or buffers not found."
        return
    endif

    call s:teardown_cleave(original_bufnr, left_bufnr, right_bufnr)
endfunction



function! cleave#join_buffers()
    " Get buffer numbers using helper function
    let [original_bufnr, left_bufnr, right_bufnr] = s:get_cleave_buffers()

    if original_bufnr == -1 || left_bufnr == -1 || right_bufnr == -1
        echoerr "Cleave: Not a cleave buffer or buffers not found."
        return
    endif

    let cleave_col = getbufvar(left_bufnr, 'cleave_col', -1)

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
        call bufload(original_bufnr)
    endif
    
    " First clear the buffer, then set new content
    call deletebufline(original_bufnr, 1, '$')
    call setbufline(original_bufnr, 1, combined_lines)

    " Restore options from left buffer to original
    let left_textwidth = getbufvar(left_bufnr, '&textwidth', 0)
    if left_textwidth > 0
        call setbufvar(original_bufnr, '&textwidth', left_textwidth)
    endif
    let left_foldcolumn = getbufvar(left_bufnr, '&foldcolumn', 0)
    call setbufvar(original_bufnr, '&foldcolumn', left_foldcolumn)

    call s:teardown_cleave(original_bufnr, left_bufnr, right_bufnr)

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
    " Reflow right buffer to new width, preserving paragraph positions
    let current_lines = getline(1, '$')

    " Step 1: Extract paragraphs with their positions
    let extracted = s:extract_paragraphs(current_lines)
    let para_positions = map(copy(extracted), 'v:val.start')
    let paragraphs = map(copy(extracted), 'v:val.content')

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
    call s:replace_buffer_lines(bufnr('%'), new_buffer_lines)
    execute 'setlocal textwidth=' . a:new_width
endfunction

function! cleave#reflow_left_buffer(new_width, current_bufnr, left_bufnr, right_bufnr)
    " Step 1: Find paragraph positions in RIGHT buffer using left-context detection
    let right_lines = getbufline(a:right_bufnr, 1, '$')
    let left_lines = getbufline(a:left_bufnr, 1, '$')
    let right_para_line_numbers = s:para_starts_ctx(right_lines, left_lines)

    " Step 2: Store paragraph first words from LEFT buffer at corresponding positions
    let para_first_words = []
    
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
            let search_start = max([1, line_num - 2])
            let search_end = min([len(left_lines), line_num + 2])

            for search_line in range(search_start, search_end)
                if s:is_para_start(left_lines, search_line - 1)
                    let first_word = matchstr(trim(left_lines[search_line - 1]), '\S\+')
                    if !empty(first_word)
                        break
                    endif
                endif
            endfor
        endif

        call add(para_first_words, first_word)
    endfor

    " Step 3: Reflow the text in the buffer with the cursor
    let current_lines = getline(1, '$')
    let reflowed_lines = cleave#reflow_text(current_lines, a:new_width)
    call s:replace_buffer_lines(bufnr('%'), reflowed_lines)

    " Step 3.5: Find updated paragraph positions by matching first words
    let updated_para_line_numbers = []
    let current_buffer_lines = getline(1, '$')
    let last_found_line = 0

    for i in range(len(para_first_words))
        let target_word = para_first_words[i]
        if len(target_word) > 0
            let found = v:false
            for line_idx in range(last_found_line, len(current_buffer_lines))
                let first_word_in_line = matchstr(current_buffer_lines[line_idx], '\S\+')

                if first_word_in_line == target_word && s:is_para_start(current_buffer_lines, line_idx)
                    call add(updated_para_line_numbers, line_idx + 1)
                    let last_found_line = line_idx + 1
                    let found = v:true
                    break
                endif
            endfor

            if !found
                echomsg "CleaveReflow WARNING: Could not find paragraph starting with '" . target_word . "'"
            endif
        endif
    endfor

    " Step 4: Adjust RIGHT buffer so each first line is back on updated line numbers
    call cleave#restore_paragraph_alignment(a:right_bufnr, right_lines, updated_para_line_numbers)

    " Update window sizing for left buffer reflow
    let new_cleave_col = a:new_width + g:cleave_gutter + 1
    call setbufvar(a:current_bufnr, 'cleave_col', new_cleave_col)
    call setbufvar(a:right_bufnr, 'cleave_col', new_cleave_col)

    let left_winid = get(win_findbuf(a:current_bufnr), 0, -1)
    let original_foldcolumn = left_winid != -1 ? getwinvar(left_winid, '&foldcolumn') : 0
    execute 'vertical resize ' . (a:new_width + original_foldcolumn + g:cleave_gutter)
    execute 'setlocal textwidth=' . a:new_width

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
    if s:cleave_right_bufnr == -1 || !bufexists(s:cleave_right_bufnr)
        echoerr "Cleave: Right buffer not found or not valid"
        return []
    endif

    return s:para_starts(getbufline(s:cleave_right_bufnr, 1, '$'))
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
    let extracted = s:extract_paragraphs(current_lines)
    let paragraphs = map(copy(extracted), 'v:val.content')

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
    call s:replace_buffer_lines(s:cleave_right_bufnr, new_buffer_lines)
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
    " Clean up trailing whitespace from all lines
    let cleaned_lines = map(copy(a:original_right_lines), 'substitute(v:val, "\\s\\+$", "", "")')

    " Get left buffer lines for context
    let left_lines = []
    if s:validate_cleave_buffers() && s:cleave_right_bufnr == a:right_bufnr
        let left_lines = getbufline(s:cleave_left_bufnr, 1, '$')
    else
        let original_bufnr = getbufvar(a:right_bufnr, 'cleave_original', -1)
        if original_bufnr != -1
            for i in range(1, bufnr("$"))
                if bufexists(i) && getbufvar(i, 'cleave_original', -1) == original_bufnr && getbufvar(i, 'cleave_side', '') == 'left'
                    let left_lines = getbufline(i, 1, '$')
                    break
                endif
            endfor
        endif
    endif

    " Step 1: Extract paragraphs and assign target line numbers
    let extracted = s:extract_paragraphs_ctx(cleaned_lines, left_lines)
    let paragraphs = []
    for i in range(len(extracted))
        let target = i < len(a:saved_para_line_numbers) ? a:saved_para_line_numbers[i] : -1
        call add(paragraphs, {'target_line': target, 'content': extracted[i].content})
    endfor

    " Step 2: Build new buffer content by placing paragraphs at target positions
    let adjusted_lines = []
    let current_line_num = 1

    for para in paragraphs
        if para.target_line > 0
            while current_line_num < para.target_line
                call add(adjusted_lines, '')
                let current_line_num += 1
            endwhile

            for content_line in para.content
                call add(adjusted_lines, content_line)
                let current_line_num += 1
            endfor
        endif
    endfor

    " Step 3: Update right buffer
    call s:replace_buffer_lines(a:right_bufnr, adjusted_lines)
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
        call prop_type_add(prop_type, {'highlight': 'MatchParen'})
    catch /E969:/
    endtry
    
    " Clear existing text properties in left buffer
    call prop_remove({'type': prop_type, 'bufnr': left_bufnr, 'all': 1})
    
    let right_lines = getbufline(right_bufnr, 1, '$')
    let left_lines = getbufline(left_bufnr, 1, '$')
    let right_para_positions = s:para_starts_ctx(right_lines, left_lines)

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
    
endfunction
