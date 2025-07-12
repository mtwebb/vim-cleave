" cleave.vim - autoload script for cleave plugin

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

    " Combine the content
    let combined_lines = []
    let max_lines = max([len(left_lines), len(right_lines)])
    
    for i in range(max_lines)
        let left_line = (i < len(left_lines)) ? left_lines[i] : ''
        let right_line = (i < len(right_lines)) ? right_lines[i] : ''
        
        " Calculate padding needed to reach cleave_col
        let left_len = len(left_line)
        let padding_needed = cleave_col - 1 - left_len
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
    
    " Find the other buffer
    let other_side = (current_side == 'left') ? 'right' : 'left'
    let other_bufnr = -1
    for i in range(1, bufnr("$"))
        if bufexists(i) && getbufvar(i, 'cleave_original', -1) == original_bufnr
            if getbufvar(i, 'cleave_side', '') == other_side
                let other_bufnr = i
                break
            endif
        endif
    endfor
    
    if other_bufnr == -1
        echoerr "Cleave: Could not find companion buffer"
        return
    endif
    
    " Get current content and mark paragraph positions
    let current_lines = getline(1, '$')
    let other_lines = getbufline(other_bufnr, 1, '$')
    
    " Mark paragraph start positions using text properties
    call cleave#mark_paragraphs(current_lines, other_lines)
    
    " Reflow current buffer to new width
    let reflowed_lines = cleave#reflow_text(current_lines, a:new_width)
    
    " Update current buffer content
    call setline(1, reflowed_lines)
    if line('$') > len(reflowed_lines)
        execute (len(reflowed_lines) + 1) . ',$delete'
    endif
    
    " Adjust other buffer to maintain paragraph alignment
    call cleave#adjust_other_buffer(other_bufnr, reflowed_lines, other_lines)
    
    " Update window sizing
    if current_side == 'left'
        let new_cleave_col = a:new_width + 1
        call setbufvar(current_bufnr, 'cleave_col', new_cleave_col)
        call setbufvar(other_bufnr, 'cleave_col', new_cleave_col)
        
        " Resize left window
        let original_foldcolumn = getbufvar(current_bufnr, 'cleave_foldcolumn', 0)
        execute 'vertical resize ' . (a:new_width + original_foldcolumn)
    endif
    
    echomsg "Cleave: Reflowed " . current_side . " buffer to width " . a:new_width
endfunction

function! cleave#mark_paragraphs(current_lines, other_lines)
    " Clear existing properties
    if has('textprop')
        try
            call prop_remove({'type': 'cleave_paragraph', 'all': v:true})
        catch
            " Property type may not exist yet
        endtry
        
        " Define property type if not exists
        try
            call prop_type_add('cleave_paragraph', {'highlight': 'none'})
        catch
            " Type already exists
        endtry
        
        " Mark paragraph starts in current buffer
        for i in range(len(a:current_lines))
            let line = a:current_lines[i]
            let is_paragraph_start = v:false
            
            if i == 0
                " First line is always a paragraph start
                let is_paragraph_start = v:true
            elseif i > 0 && trim(a:current_lines[i-1]) == '' && trim(line) != ''
                " Line after empty line that's not empty
                let is_paragraph_start = v:true
            endif
            
            if is_paragraph_start
                try
                    call prop_add(i + 1, 1, {'type': 'cleave_paragraph', 'length': 1})
                catch
                    " Ignore errors from invalid positions
                endtry
            endif
        endfor
    endif
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

function! cleave#adjust_other_buffer(other_bufnr, reflowed_lines, original_other_lines)
    " Get paragraph positions from properties
    let paragraph_positions = []
    if has('textprop')
        try
            let props = prop_list(1, {'end_lnum': line('$'), 'types': ['cleave_paragraph']})
            for prop in props
                call add(paragraph_positions, prop.lnum - 1)
            endfor
        catch
            " Fallback to simple detection
        endtry
    endif
    
    " If no properties, detect paragraphs manually
    if empty(paragraph_positions)
        for i in range(len(a:reflowed_lines))
            let line = a:reflowed_lines[i]
            if i == 0 || (i > 0 && trim(a:reflowed_lines[i-1]) == '' && trim(line) != '')
                call add(paragraph_positions, i)
            endif
        endfor
    endif
    
    " Rebuild other buffer with padding to align paragraphs
    let adjusted_lines = []
    let other_para_idx = 0
    let reflowed_para_idx = 0
    
    for i in range(len(a:reflowed_lines))
        if index(paragraph_positions, i) >= 0
            " This is a paragraph start - make sure other buffer aligns
            while other_para_idx < len(a:original_other_lines) && 
                  \ (other_para_idx >= len(adjusted_lines) || len(adjusted_lines) < i)
                call add(adjusted_lines, other_para_idx < len(a:original_other_lines) ? 
                       \ a:original_other_lines[other_para_idx] : '')
                let other_para_idx += 1
            endwhile
            let reflowed_para_idx += 1
        endif
        
        " Ensure other buffer has enough lines
        while len(adjusted_lines) <= i
            call add(adjusted_lines, other_para_idx < len(a:original_other_lines) ? 
                   \ a:original_other_lines[other_para_idx] : '')
            let other_para_idx += 1
        endwhile
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
