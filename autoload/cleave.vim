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

    echomsg "original_bufnr: " . original_bufnr
    echomsg "original_winid: " . original_winid
    echomsg "last_line_in_original_buf: " . line('$', original_bufnr)

    " 2. Content Extraction
    let original_lines = getbufline(original_bufnr, 1, line('$', original_bufnr))
    echomsg "original_lines: " . string(original_lines)
    echomsg "cleave_col: " . cleave_col
    let [left_lines, right_lines] = cleave#split_content(original_lines, cleave_col)

    " 3. Buffer Creation
    let original_name = expand('%:t')
    if empty(original_name)
        let original_name = 'noname'
    endif
    let [left_bufnr, right_bufnr] = cleave#create_buffers(left_lines, right_lines, original_name)

    " 4. Window Management
    call cleave#setup_windows(cleave_col, left_bufnr, right_bufnr, original_winid, original_cursor)

    " 5. Set buffer variables for potential undo
    call setbufvar(left_bufnr, 'cleave_original', original_bufnr)
    call setbufvar(left_bufnr, 'cleave_side', 'left')
    call setbufvar(right_bufnr, 'cleave_original', original_bufnr)
    call setbufvar(right_bufnr, 'cleave_side', 'right')

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
    echomsg "left_lines: " . string(left_lines)
    echomsg "right_lines: " . string(right_lines)
    return [left_lines, right_lines]
endfunction

function! cleave#create_buffers(left_lines, right_lines, original_name)
    " Create left buffer
    execute 'enew'
    let left_bufnr = bufnr(a:original_name . '.left', 1)
    call setbufline(left_bufnr, 1, a:left_lines)
    call setbufline(left_bufnr, 1, a:left_lines)
    call setbufvar(left_bufnr, '&buftype', 'nofile')
    call setbufvar(left_bufnr, '&bufhidden', 'hide')
    call setbufvar(left_bufnr, '&swapfile', 0)
    
    " Create right buffer
    execute 'enew'
    let right_bufnr = bufnr(a:original_name . '.right', 1)
    call setbufline(right_bufnr, 1, a:right_lines)
    call setbufvar(right_bufnr, '&buftype', 'nofile')
    call setbufvar(right_bufnr, '&bufhidden', 'hide')
    call setbufvar(right_bufnr, '&swapfile', 0)

    return [left_bufnr, right_bufnr]
endfunction

function! cleave#setup_windows(cleave_col, left_bufnr, right_bufnr, original_winid, original_cursor)
    call win_gotoid(a:original_winid)
    vsplit
    
    execute 'buffer' a:left_bufnr
    execute 'vertical resize ' . (a:cleave_col - 1)
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

augroup cleave_sync
    autocmd!
    autocmd TextChanged,TextChangedI * call cleave#sync_buffers()
    autocmd CursorMoved * if getbufvar(bufnr('%'), 'cleave_original', -1) != -1 | set scrollbind | endif
augroup END
