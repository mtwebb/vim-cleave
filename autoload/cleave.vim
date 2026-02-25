vim9script

# cleave.vim - autoload script for cleave plugin

# Global variable for gutter width
if !exists('g:cleave_gutter')
    g:cleave_gutter = 3
endif

if !exists('g:cleave_reflow_mode')
    g:cleave_reflow_mode = 'ragged'
endif

if !exists('g:cleave_hyphenate')
    g:cleave_hyphenate = 1
endif

if !exists('g:cleave_dehyphenate')
    g:cleave_dehyphenate = 1
endif

if !exists('g:cleave_hyphen_min_length')
    g:cleave_hyphen_min_length = 8
endif

if !exists('g:cleave_justify_last_line')
    g:cleave_justify_last_line = 0
endif

if !exists('g:cleave_debug_timing')
    g:cleave_debug_timing = 0
endif

# ============================================================================
# Paragraph Detection Helpers
# ============================================================================

# Return true if line has ``` opening and closing on the same line (e.g. ```text```)
def IsInlineFence(line: string): bool
    var stripped = substitute(line, '^\s*', '', '')
    if stripped[: 2] !=# '```'
        return false
    endif
    var after = stripped[3 :]
    return after =~# '```\s*$'
enddef

# Simple paragraph start: non-empty line that is first or follows an empty line
def IsParaStart(lines: list<string>, idx: number): bool
    if trim(lines[idx]) ==# ''
        return false
    endif
    return idx == 0 || trim(lines[idx - 1]) ==# ''
enddef

# Return 1-based line numbers of paragraph starts in lines (simple detection)
def ParaStarts(lines: list<string>): list<number>
    var result = []
    for i in range(len(lines))
        if IsParaStart(lines, i)
            add(result, i + 1)
        endif
    endfor
    return result
enddef

# Extract paragraphs from lines as a list of {start: N, content: [lines]}
# Uses simple paragraph detection (prev line empty)
def ExtractParagraphs(lines: list<string>): list<dict<any>>
    var paragraphs = []
    var current_para = []
    var current_start = -1

    for i in range(len(lines))
        var trimmed = trim(lines[i])
        if IsParaStart(lines, i)
            if current_start >= 0 && !empty(current_para)
                add(paragraphs, {'start': current_start + 1, 'content': copy(current_para)})
            endif
            current_para = [lines[i]]
            current_start = i
        elseif current_start >= 0 && trimmed !=# ''
            add(current_para, lines[i])
        endif
    endfor

    if current_start >= 0 && !empty(current_para)
        add(paragraphs, {'start': current_start + 1, 'content': copy(current_para)})
    endif
    return paragraphs
enddef

def BuildParagraphPlacement(paragraphs: list<any>, target_line_numbers: list<number>): dict<any>
    var new_buffer_lines = []
    var current_line_num = 1
    var actual_positions = []

    for i in range(len(paragraphs))
        var target_line = (i < len(target_line_numbers)) ? target_line_numbers[i] : 1
        var paragraph = paragraphs[i]
        var actual_position = max([target_line, current_line_num])

        while current_line_num < actual_position
            add(new_buffer_lines, '')
            current_line_num += 1
        endwhile

        add(actual_positions, actual_position)

        for para_line in paragraph
            add(new_buffer_lines, para_line)
            current_line_num += 1
        endfor

        if i < len(paragraphs) - 1
            add(new_buffer_lines, '')
            current_line_num += 1
        endif
    endfor

    return {'lines': new_buffer_lines, 'positions': actual_positions}
enddef

# ============================================================================
# Buffer / Window Helpers
# ============================================================================

# Replace all lines in a buffer, removing any excess trailing lines
def ReplaceBufferLines(bufnr: number, lines: list<string>)
    setbufline(bufnr, 1, lines)
    var total = len(getbufline(bufnr, 1, '$'))
    if total > len(lines)
        deletebufline(bufnr, len(lines) + 1, '$')
    endif
enddef

def PadBufferLines(bufnr: number, target_len: number)
    if target_len < 1
        return
    endif

    var current_len = len(getbufline(bufnr, 1, '$'))
    if current_len >= target_len
        return
    endif

    var padding = repeat([''], target_len - current_len)
    setbufline(bufnr, current_len + 1, padding)
enddef

def EqualizeBufferLengths(left_bufnr: number, right_bufnr: number)
    if left_bufnr == -1 || right_bufnr == -1
        return
    endif

    var save_pos = getpos('.')
    var left_len = len(getbufline(left_bufnr, 1, '$'))
    var right_len = len(getbufline(right_bufnr, 1, '$'))

    if left_len < right_len
        PadBufferLines(left_bufnr, right_len)
    elseif right_len < left_len
        PadBufferLines(right_bufnr, left_len)
    endif

    setpos('.', save_pos)
enddef
# Shared teardown for undo_cleave and join_buffers: close windows, delete
# temp buffers, clear state
def TeardownCleave(original_bufnr: number, left_bufnr: number, right_bufnr: number)
    var left_win_id = get(win_findbuf(left_bufnr), 0, -1)
    var right_win_id = get(win_findbuf(right_bufnr), 0, -1)

    if left_win_id != -1
        win_gotoid(left_win_id)
        execute 'buffer' original_bufnr
    else
        execute 'buffer' original_bufnr
    endif

    if right_win_id != -1
        win_gotoid(right_win_id)
        close
    endif

    if bufexists(left_bufnr)
        execute 'bdelete!' left_bufnr
    endif
    if bufexists(right_bufnr)
        execute 'bdelete!' right_bufnr
    endif

    if left_win_id != -1
        win_gotoid(left_win_id)
    endif
enddef

# ============================================================================
# Virtual Column Utility Functions
# ============================================================================

# Convert virtual column position to byte position in a string
# Args: str - the string to analyze
#       vcol - virtual column position (1-based)
# Returns: byte position (0-based) or -1 if vcol is beyond string
export def VcolToByte(str: string, vcol: number): number
    if vcol <= 0
        return 0
    endif

    var byte_pos = 0
    var current_vcol = 1
    var char_idx = 0
    var string_char_len = strchars(str)

    while char_idx < string_char_len && current_vcol < vcol
        # Get character at current character index
        var char_str = strcharpart(str, char_idx, 1)

        # Calculate display width of this character
        if char_str == "\t"
            # Tab width depends on current column position
            var tab_width = &tabstop - ((current_vcol - 1) % &tabstop)
            current_vcol += tab_width
        else
            var char_display_width = strdisplaywidth(char_str)
            current_vcol += char_display_width
        endif

        # Move to next character
        char_idx += 1
        byte_pos = byteidx(str, char_idx)
    endwhile

    # If we've reached or exceeded the target vcol, return current byte position
    # If vcol is beyond string, return -1
    if current_vcol >= vcol
        return byte_pos
    else
        return -1
    endif
enddef

# Convert byte position to virtual column position
# Args: str - the string to analyze
#       byte_pos - byte position (0-based)
# Returns: virtual column position (1-based)
export def ByteToVcol(str: string, byte_pos: number): number
    if byte_pos <= 0
        return 1
    endif

    var string_len = len(str)
    var target_byte_pos = min([byte_pos, string_len])

    # Convert byte position to character index
    var target_char_idx = charidx(str, target_byte_pos)

    var current_vcol = 1
    var char_idx = 0

    while char_idx < target_char_idx
        # Get character at current character index
        var char_str = strcharpart(str, char_idx, 1)

        # Calculate display width of this character
        if char_str == "\t"
            # Tab width depends on current column position
            var tab_width = &tabstop - ((current_vcol - 1) % &tabstop)
            current_vcol += tab_width
        else
            var char_display_width = strdisplaywidth(char_str)
            current_vcol += char_display_width
        endif

        # Move to next character
        char_idx += 1
    endwhile

    return current_vcol
enddef

# Extract substring based on virtual column positions
# Args: str - the string to split
#       start_vcol - starting virtual column (1-based, inclusive)
#       end_vcol - ending virtual column (1-based, exclusive) or -1 for end of string
# Returns: substring based on virtual column positions
export def VirtualStrpart(str: string, start_vcol: number, ...args: list<any>): string
    var end_vcol = len(args) > 0 ? args[0] : -1

    # Handle edge cases
    var resolved_start_vcol: number
    if start_vcol <= 0
        resolved_start_vcol = 1
    else
        resolved_start_vcol = start_vcol
    endif

    # Convert virtual columns to byte positions
    var start_byte = VcolToByte(str, resolved_start_vcol)
    if start_byte == -1
        # Start position is beyond string
        return ''
    endif

    if end_vcol <= 0
        # Extract from start_vcol to end of string
        return strpart(str, start_byte)
    else
        var end_byte = VcolToByte(str, end_vcol)
        if end_byte == -1
            # End position is beyond string, extract to end
            return strpart(str, start_byte)
        else
            # Extract substring between byte positions
            var length = end_byte - start_byte
            return strpart(str, start_byte, length)
        endif
    endif
enddef

# Resolve cleave buffer triple from b:cleave dict on the given (or current) buffer
def ResolveBuffers(...args: list<any>): list<number>
    var bufnr = len(args) > 0 ? args[0] : bufnr('%')
    var info = getbufvar(bufnr, 'cleave', {})
    if empty(info)
        return [-1, -1, -1]
    endif
    var original = info.original
    var peer = info.peer
    if !bufexists(bufnr) || !bufexists(peer)
        return [-1, -1, -1]
    endif
    if info.side ==# 'left'
        return [original, bufnr, peer]
    else
        return [original, peer, bufnr]
    endif
enddef

export def SplitBuffer(bufnr: number, ...args: list<any>)
    var opts = {}
    if len(args) > 0
        for idx in range(len(args))
            var candidate = get(args, idx, null)
            if type(candidate) == v:t_dict
                opts = candidate
                break
            endif
        endfor
    endif
    if getbufvar(bufnr, '&modified') && !get(opts, 'force', 0)
        echoerr "Cleave: Buffer has unsaved changes. Please :write before cleaving."
        return
    endif

    var mode_override = get(opts, 'reflow_mode', '')
    if !empty(mode_override)
        var mode = NormalizeReflowMode(mode_override)
        if empty(mode)
            echoerr "Cleave: Invalid reflow mode"
            return
        endif
        setbufvar(bufnr, 'cleave_reflow_mode', mode)
    endif

    # Read modeline settings if g:cleave_modeline is not 'ignore'
    var modeline_settings = {}
    if cleave#modeline#Mode() !=# 'ignore'
        var parsed = cleave#modeline#Parse(bufnr)
        if parsed.line > 0
            modeline_settings = cleave#modeline#Apply(parsed.settings)
        else
            modeline_settings = cleave#modeline#Apply(
                \ cleave#modeline#Infer(bufnr))
        endif
    endif

    # 1. Determine Cleave Column
    var cleave_col = 0
    if len(args) > 0
        # Parameter is interpreted as virtual column position
        cleave_col = args[0]
    elseif !empty(modeline_settings) && get(modeline_settings, 'cc', 0) > 0
        # Use cc from modeline
        cleave_col = modeline_settings.cc
    else
        # Use virtual column position of cursor
        cleave_col = virtcol('.')
    endif

    # Apply modeline settings to buffer before splitting
    if !empty(modeline_settings)
        ApplyModelineToBuffer(bufnr, modeline_settings)
    endif

    SplitBufferAtCol(bufnr, cleave_col)
enddef

export def SplitAtColorcolumn()
    var cc = &colorcolumn
    if empty(cc)
        echoerr "Cleave: colorcolumn is not set"
        return
    endif
    var col = str2nr(split(cc, ',')[0])
    if col <= 0
        echoerr "Cleave: colorcolumn value must be a positive number"
        return
    endif
    SplitBuffer(bufnr('%'), col)
enddef

export def ToggleReflowMode()
    var current = CurrentReflowMode()
    var next_mode = current ==# 'justify' ? 'ragged' : 'justify'
    setbufvar(bufnr('%'), 'cleave_reflow_mode', next_mode)
    echomsg "Cleave: Reflow mode set to " .. next_mode
enddef

# Apply modeline settings to the buffer before cleaving
def ApplyModelineToBuffer(bufnr: number, settings: dict<any>)
    if has_key(settings, 'tw') && settings.tw > 0
        setbufvar(bufnr, '&textwidth', settings.tw)
    endif
    if has_key(settings, 'fdc')
        setbufvar(bufnr, '&foldcolumn', settings.fdc)
    endif
    if has_key(settings, 'wm') && settings.wm >= 0
        g:cleave_gutter = settings.wm
    endif
    setbufvar(bufnr, 'cleave_modeline_settings', settings)
enddef

def SplitBufferAtCol(bufnr: number, cleave_col: number)
    if cleave_col == 1
        echoerr "Cleave: Cannot split at the first column."
        return
    endif
    var saved_hidden = &hidden
    set hidden
    try
        var timing = g:cleave_debug_timing
        var t_total: any
        var t0: any
        if timing
            t_total = reltime()
        endif
        var original_bufnr = bufnr
        var original_winid = win_getid()
        var original_cursor = getcurpos()

        # 2. Content Extraction
        if timing
            t0 = reltime()
        endif
        var original_lines = getbufline(original_bufnr, 1, '$')
        var [left_lines, right_lines] = SplitContent(original_lines, cleave_col)
        if timing
            echomsg 'Cleave timing: split_content ' .. reltimestr(reltime(t0))
        endif

        # 3. Buffer Creation
        if timing
            t0 = reltime()
        endif
        var original_name = expand('%:t')
        if empty(original_name)
            original_name = 'noname'
        endif
        var original_foldcolumn = &foldcolumn
        var original_filetype = &filetype
        var [left_bufnr, right_bufnr] = CreateBuffers(left_lines, right_lines, original_name, original_foldcolumn, original_filetype)
        if timing
            echomsg 'Cleave timing: create_buffers ' .. reltimestr(reltime(t0))
        endif

        # 4. Window Management
        if timing
            t0 = reltime()
        endif
        SetupWindows(cleave_col, left_bufnr, right_bufnr, original_winid, original_cursor, original_foldcolumn)
        if timing
            echomsg 'Cleave timing: setup_windows ' .. reltimestr(reltime(t0))
        endif

        # 5. Apply modeline settings that need window/global context
        var ml_settings = getbufvar(original_bufnr, 'cleave_modeline_settings', {})
        if !empty(ml_settings)
            if has_key(ml_settings, 've') && !empty(ml_settings.ve)
                &virtualedit = ml_settings.ve
            endif
            if has_key(ml_settings, 'cc') && ml_settings.cc > 0
                var left_winid = get(win_findbuf(left_bufnr), 0, -1)
                if left_winid != -1
                    setwinvar(win_id2win(left_winid),
                        \ '&colorcolumn', string(ml_settings.cc))
                endif
            endif
        endif

        # 6. Store cleave state on each buffer
        var left_state = {'original': original_bufnr, 'side': 'left',
            \ 'peer': right_bufnr, 'col': cleave_col}
        var right_state = {'original': original_bufnr, 'side': 'right',
            \ 'peer': left_bufnr, 'col': cleave_col}
        setbufvar(left_bufnr, 'cleave', left_state)
        setbufvar(right_bufnr, 'cleave', right_state)

        # Remember last cleave column on the original buffer
        setbufvar(original_bufnr, 'cleave_col_last', cleave_col)

        # 7. Initialize text properties to show paragraph alignment
        if timing
            t0 = reltime()
        endif
        SetTextProperties()
        if timing
            echomsg 'Cleave timing: set_text_properties ' .. reltimestr(reltime(t0))
        endif

        if timing
            echomsg 'Cleave timing: TOTAL ' .. reltimestr(reltime(t_total))
        endif
    finally
        &hidden = saved_hidden
    endtry
enddef

export def RecleaveLast()
    var original_bufnr = bufnr('%')
    var last_col = getbufvar(original_bufnr, 'cleave_col_last', -1)
    if last_col == -1
        echoerr "Cleave: No stored cleave column for this buffer"
        return
    endif
    SplitBufferAtCol(original_bufnr, last_col)
enddef

export def SplitContent(lines: list<string>, cleave_col: number): list<list<string>>
    var left_lines = []
    var right_lines = []
    var byte_col = cleave_col - 1

    for line in lines
        var left_part: string
        var right_part: string
        if strdisplaywidth(line) == len(line)
            left_part = strpart(line, 0, byte_col)
            right_part = strpart(line, byte_col)
        else
            left_part = VirtualStrpart(line, 1, cleave_col)
            right_part = VirtualStrpart(line, cleave_col)
        endif
        add(left_lines, left_part)
        add(right_lines, right_part)
    endfor
    return [left_lines, right_lines]
enddef

export def CreateBuffers(left_lines: list<string>, right_lines: list<string>, original_name: string, original_foldcolumn: number, original_filetype: string = ''): list<number>
    # Create left buffer
    silent execute 'hide enew'
    silent execute 'file ' .. fnameescape(original_name .. '.left')
    var left_bufnr = bufnr('%')
    setline(1, left_lines)
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    execute 'setlocal foldcolumn=' .. original_foldcolumn
    # Set textwidth before filetype so ftplugin/left.vim sees correct &tw
    SetTexwidthToLongestLine()
    var left_ft = empty(original_filetype) ? 'left' : original_filetype .. '.left'
    execute 'setlocal filetype=' .. left_ft
    
    # Create right buffer
    silent execute 'hide enew'
    silent execute 'file ' .. fnameescape(original_name .. '.right')
    var right_bufnr = bufnr('%')
    setline(1, right_lines)
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal foldcolumn=0
    setlocal filetype=right
    # Set textwidth based on longest line in right buffer
    SetTexwidthToLongestLine()

    PadBufferLines(right_bufnr, len(left_lines))

    # Update paragraph anchors on InsertLeave in either buffer
    augroup CleaveInsertLeave
        execute 'autocmd! InsertLeave <buffer=' .. right_bufnr .. '> call cleave#SyncRightParagraphs()'
        execute 'autocmd! InsertLeave <buffer=' .. left_bufnr .. '> call cleave#SyncLeftParagraphs()'
    augroup END

    # Detect text changes in normal mode (both buffers)
    augroup CleaveTextChanged
        execute 'autocmd! TextChanged <buffer=' .. right_bufnr .. '> call cleave#OnTextChanged()'
        execute 'autocmd TextChanged <buffer=' .. left_bufnr .. '> call cleave#OnTextChanged()'
    augroup END

    return [left_bufnr, right_bufnr]
enddef

export def SetupWindows(cleave_col: number, left_bufnr: number, right_bufnr: number, original_winid: number, original_cursor: list<number>, original_foldcolumn: number)
    win_gotoid(original_winid)
    vsplit
    
    execute 'buffer' left_bufnr
    # Calculate left window width using virtual column position
    # cleave_col is now a virtual column, so this accounts for display width
    # Subtract 2 to account for the split column and add foldcolumn width
    var left_window_width = cleave_col - 2 + original_foldcolumn
    execute 'vertical resize ' .. left_window_width
    cursor(original_cursor[1], original_cursor[2])
    set scrollbind

    wincmd l
    execute 'buffer' right_bufnr
    cursor(original_cursor[1], original_cursor[2])
    set scrollbind

    wincmd h
enddef

export def UndoCleave()
    var [original_bufnr, left_bufnr, right_bufnr] = ResolveBuffers()

    if original_bufnr == -1 || left_bufnr == -1 || right_bufnr == -1
        echoerr "Cleave: Not a cleave buffer or buffers not found."
        return
    endif

    TeardownCleave(original_bufnr, left_bufnr, right_bufnr)
enddef



export def JoinBuffers()
    # Get buffer numbers using helper function
    var [original_bufnr, left_bufnr, right_bufnr] = ResolveBuffers()

    if original_bufnr == -1 || left_bufnr == -1 || right_bufnr == -1
        echoerr "Cleave: Not a cleave buffer or buffers not found."
        return
    endif

    var cleave_col = get(getbufvar(left_bufnr, 'cleave', {}), 'col', -1)

    if cleave_col == -1
        echoerr "Cleave: Missing cleave column information."
        return
    endif

    # Get content from both buffers
    var left_lines = getbufline(left_bufnr, 1, '$')
    var right_lines = getbufline(right_bufnr, 1, '$')

    var combined_lines = []
    var max_lines = max([len(left_lines), len(right_lines)])
    
    for i in range(max_lines)
        var left_line = (i < len(left_lines)) ? left_lines[i] : ''
        var right_line = (i < len(right_lines)) ? right_lines[i] : ''
        
        var combined_line: string
        if empty(right_line)
            combined_line = left_line
        else
            var left_len = strdisplaywidth(left_line)
            var padding_needed = cleave_col - 1 - left_len
            var padding = padding_needed > 0 ? repeat(' ', padding_needed) : ''
            
            combined_line = left_line .. padding .. right_line
        endif
        
        add(combined_lines, combined_line)
    endfor


    # Update the original buffer
    # Load the buffer first if it's not loaded
    if !bufloaded(original_bufnr)
        bufload(original_bufnr)
    endif
    
    # First clear the buffer, then set new content
    deletebufline(original_bufnr, 1, '$')
    setbufline(original_bufnr, 1, combined_lines)

    # Restore options from left buffer to original
    var left_textwidth = getbufvar(left_bufnr, '&textwidth', 0)
    if left_textwidth > 0
        setbufvar(original_bufnr, '&textwidth', left_textwidth)
    endif
    var left_fdc_winid = get(win_findbuf(left_bufnr), 0, -1)
    var left_foldcolumn = left_fdc_winid != -1
        \ ? getwinvar(win_id2win(left_fdc_winid), '&foldcolumn', 0)
        \ : getbufvar(left_bufnr, '&foldcolumn', 0)
    setbufvar(original_bufnr, '&foldcolumn', left_foldcolumn)

    var last_col = get(getbufvar(left_bufnr, 'cleave', {}), 'col', -1)
    if last_col != -1
        setbufvar(original_bufnr, 'cleave_col_last', last_col)
    endif

    # Collect modeline settings before teardown (buffers still exist)
    var ml_settings = getbufvar(original_bufnr, 'cleave_modeline_settings', {})
    if empty(ml_settings)
        ml_settings = {}
    endif
    ml_settings.cc = cleave_col
    ml_settings.tw = getbufvar(left_bufnr, '&textwidth', 0)
    var left_winid = get(win_findbuf(left_bufnr), 0, -1)
    ml_settings.fdc = left_winid != -1
        \ ? getwinvar(win_id2win(left_winid), '&foldcolumn', 0)
        \ : getbufvar(left_bufnr, '&foldcolumn', 0)
    ml_settings.wm = g:cleave_gutter
    var ve_val = getbufvar(right_bufnr, '&virtualedit', '')
    ml_settings.ve = !empty(ve_val) ? ve_val : 'all'

    # Write modeline text before teardown (original buffer content exists)
    cleave#modeline#Ensure(original_bufnr, ml_settings)

    TeardownCleave(original_bufnr, left_bufnr, right_bufnr)

    # Apply window-local settings after teardown (original buffer is now visible)
    var winid = get(win_findbuf(original_bufnr), 0, -1)
    if winid != -1
        if has_key(ml_settings, 'cc') && ml_settings.cc > 0
            setwinvar(win_id2win(winid),
                \ '&colorcolumn', string(ml_settings.cc))
        endif
        if has_key(ml_settings, 'fdc')
            setwinvar(win_id2win(winid),
                \ '&foldcolumn', ml_settings.fdc)
        endif
    endif
    if has_key(ml_settings, 've') && !empty(ml_settings.ve)
        &virtualedit = ml_settings.ve
    endif

    echomsg "Cleave: Buffers joined successfully."
enddef

def NormalizeReflowMode(mode: string): string
    var normalized = tolower(mode)
    if index(['ragged', 'justify'], normalized) == -1
        return ''
    endif
    return normalized
enddef

def CurrentReflowMode(): string
    var mode = getbufvar(bufnr('%'), 'cleave_reflow_mode', '')
    if empty(mode)
        mode = g:cleave_reflow_mode
    endif
    return NormalizeReflowMode(mode)
enddef

def DefaultReflowOptions(width: number): dict<any>
    var mode = NormalizeReflowMode(g:cleave_reflow_mode)
    if empty(mode)
        mode = 'ragged'
    endif
    return {
        \ 'width': width,
        \ 'mode': mode,
        \ 'hyphenate': g:cleave_hyphenate,
        \ 'dehyphenate': g:cleave_dehyphenate,
        \ 'hyphen_min_length': g:cleave_hyphen_min_length,
        \ 'justify_last_line': g:cleave_justify_last_line,
        \ }
enddef

def ResolveReflowOptions(width: number, mode_override: string): dict<any>
    var mode = CurrentReflowMode()
    if !empty(mode_override)
        var override = NormalizeReflowMode(mode_override)
        if empty(override)
            echoerr "Cleave: Invalid reflow mode"
            return {}
        endif
        mode = override
    endif
    if empty(mode)
        echoerr "Cleave: Invalid reflow mode"
        return {}
    endif
    return {
        \ 'width': width,
        \ 'mode': mode,
        \ 'hyphenate': g:cleave_hyphenate,
        \ 'dehyphenate': g:cleave_dehyphenate,
        \ 'hyphen_min_length': g:cleave_hyphen_min_length,
        \ 'justify_last_line': g:cleave_justify_last_line,
        \ }
enddef

def WithDefaultReflowOptions(options: dict<any>): dict<any>
    var width = get(options, 'width', 0)
    if type(width) == v:t_string
        if width =~# '^\d\+$'
            width = str2nr(width)
        else
            width = 0
        endif
    endif

    var defaults = DefaultReflowOptions(width)
    var merged = extend(defaults, options, 'force')

    merged.width = width > 0 ? width : defaults.width
    merged.mode = NormalizeReflowMode(get(merged, 'mode', ''))
    if empty(merged.mode)
        merged.mode = defaults.mode
    endif

    var min_length = get(merged, 'hyphen_min_length',
        \ defaults.hyphen_min_length)
    if type(min_length) != v:t_number
        min_length = defaults.hyphen_min_length
    endif
    if min_length < 2
        min_length = 2
    endif
    merged.hyphen_min_length = min_length

    merged.hyphenate = get(merged, 'hyphenate', defaults.hyphenate)
    merged.dehyphenate = get(merged, 'dehyphenate', defaults.dehyphenate)
    merged.justify_last_line = get(merged, 'justify_last_line',
        \ defaults.justify_last_line)

    return merged
enddef
export def ReflowBuffer(...args: list<any>)
    if len(args) < 1
        echoerr "Cleave: Width is required"
        return
    endif

    if args[0] !~# '^\d\+$'
        echoerr "Cleave: Width must be a number"
        return
    endif

    var new_width = str2nr(args[0])

    # Get buffer numbers using helper function
    var [original_bufnr, left_bufnr, right_bufnr] = ResolveBuffers()

    if original_bufnr == -1 || left_bufnr == -1 || right_bufnr == -1
        echoerr "Cleave: Not a cleave buffer or buffers not found."
        return
    endif

    if new_width < 10
        echoerr "Cleave: Width must be at least 10 characters"
        return
    endif

    var mode_override = len(args) > 1 ? args[1] : ''
    var options = ResolveReflowOptions(new_width, mode_override)
    if empty(options)
        return
    endif

    var current_bufnr = bufnr('%')
    var current_side = get(getbufvar(current_bufnr, 'cleave', {}), 'side', '')

    if empty(current_side)
        echoerr "Cleave: Current buffer is not a cleave buffer (.left or .right)"
        return
    endif

    # Handle right buffer reflow with dedicated logic
    if current_side == 'right'
        ReflowRightBuffer(options, current_bufnr,
            \ left_bufnr, right_bufnr)
        return
    endif

    # Handle left buffer reflow with dedicated logic
    ReflowLeftBuffer(options, current_bufnr, left_bufnr,
        \ right_bufnr)
enddef

export def ReflowRightBuffer(options: dict<any>, current_bufnr: number, left_bufnr: number,
    \ right_bufnr: number)
    # Reflow right buffer to new width, preserving paragraph positions
    var current_lines = getline(1, '$')
    var width = options.width

    # Step 1: Extract paragraphs with their positions
    var extracted = ExtractParagraphs(current_lines)
    var para_starts = mapnew(extracted, (_, v) => v.start)
    var paragraphs = mapnew(extracted, (_, v) => v.content)

    # Step 2: Reflow each paragraph individually to new width
    var reflowed_paragraphs: list<list<string>> = []
    var paragraph_index = 0
    var inside_fence = false
    var fence_pattern = '^\s*```'
    for para_lines in paragraphs
        var reflowed_para: list<string> = []
        if !inside_fence && paragraph_index < len(para_starts)
            var start_line = para_starts[paragraph_index]
            if start_line > 0 && start_line <= len(current_lines)
                var line_idx = start_line - 1
                var line_text = current_lines[line_idx]
                if line_text =~# fence_pattern && !IsInlineFence(line_text)
                    inside_fence = true
                endif
            endif
        endif

        var is_heading = len(para_lines) == 1 && para_lines[0] =~# '^\s*#'
        if inside_fence || is_heading
            reflowed_para = para_lines
        else
            reflowed_para = WrapParagraph(para_lines, options)
        endif

        add(reflowed_paragraphs, reflowed_para)
        for line_text in para_lines
            if line_text =~# fence_pattern && !IsInlineFence(line_text)
                inside_fence = !inside_fence
            endif
        endfor
        paragraph_index += 1
    endfor

    # Step 3: Reconstruct buffer preserving original positions when possible
    var new_buffer_lines: list<string> = []
    var current_line_num = 1
    var new_para_starts: list<number> = []

    for i in range(len(para_starts))
        var target_line = para_starts[i]
        var reflowed_para = reflowed_paragraphs[i]
        var actual_position = target_line
        var min_position = current_line_num

        # Maintain at least one blank line between paragraphs.
        if current_line_num > 1 && len(new_buffer_lines) > 0 && new_buffer_lines[-1] != ''
            min_position += 1
        endif

        if actual_position < min_position
            actual_position = min_position
        endif

        while current_line_num < actual_position
            add(new_buffer_lines, '')
            current_line_num += 1
        endwhile

        add(new_para_starts, actual_position)

        for para_line in reflowed_para
            add(new_buffer_lines, para_line)
            current_line_num += 1
        endfor
    endfor

    # Step 4: Update the right buffer
    ReplaceBufferLines(bufnr('%'), new_buffer_lines)
    EqualizeBufferLengths(left_bufnr, right_bufnr)
    execute 'setlocal textwidth=' .. width
enddef

def CaptureAnchors(left_lines: list<string>, para_starts: list<number>): list<string>
    var anchors: list<string> = []
    for line_num in para_starts
        var first_word = ''
        if line_num <= len(left_lines)
            first_word = matchstr(trim(left_lines[line_num - 1]), '\S\+')
        endif
        if empty(first_word)
            var search_start = max([1, line_num - 2])
            var search_end = min([len(left_lines), line_num + 2])
            for search_line in range(search_start, search_end)
                if IsParaStart(left_lines, search_line - 1)
                    first_word = matchstr(trim(left_lines[search_line - 1]), '\S\+')
                    if !empty(first_word)
                        break
                    endif
                endif
            endfor
        endif
        add(anchors, first_word)
    endfor
    return anchors
enddef

def LocateAnchorsAfterReflow(buffer_lines: list<string>, anchors: list<string>): list<number>
    var updated_para_starts: list<number> = []
    var last_found_line = 0
    var inside_fence = false
    var fence_pattern = '^\s*```'
    for i in range(len(anchors))
        var target_word = anchors[i]
        if len(target_word) > 0
            var found = false
            var line_idx = last_found_line
            while line_idx < len(buffer_lines)
                var line_text = buffer_lines[line_idx]
                if line_text =~# fence_pattern && !IsInlineFence(line_text)
                    inside_fence = !inside_fence
                    line_idx += 1
                    continue
                endif
                if inside_fence
                    line_idx += 1
                    continue
                endif
                var first_word_in_line = matchstr(line_text, '\S\+')
                if first_word_in_line == target_word
                    add(updated_para_starts, line_idx + 1)
                    last_found_line = line_idx + 1
                    found = true
                    break
                endif
                line_idx += 1
            endwhile
            if !found
                echomsg "CleaveReflow WARNING: Could not find paragraph starting with '" .. target_word .. "'"
            endif
        endif
    endfor
    return updated_para_starts
enddef

def ApplyPostReflowUi(new_width: number, current_bufnr: number, right_bufnr: number, right_lines: list<string>, updated_para_starts: list<number>)
    RestoreParagraphAlignment(right_bufnr, right_lines, updated_para_starts)

    var new_cleave_col = new_width + g:cleave_gutter + 1
    var left_info = getbufvar(current_bufnr, 'cleave', {})
    var right_info = getbufvar(right_bufnr, 'cleave', {})
    if !empty(left_info)
        left_info.col = new_cleave_col
    endif
    if !empty(right_info)
        right_info.col = new_cleave_col
    endif

    var left_winid = get(win_findbuf(current_bufnr), 0, -1)
    var original_foldcolumn = left_winid != -1 ? getwinvar(left_winid, '&foldcolumn') : 0
    execute 'vertical resize ' .. (new_width + original_foldcolumn + g:cleave_gutter)
    execute 'setlocal textwidth=' .. new_width

    SetTextProperties()
enddef

export def ReflowLeftBuffer(options: dict<any>, current_bufnr: number, left_bufnr: number,
    \ right_bufnr: number)
    var right_lines = getbufline(right_bufnr, 1, '$')
    var left_lines = getbufline(left_bufnr, 1, '$')
    var right_para_starts = ParaStarts(right_lines)

    var anchors = CaptureAnchors(left_lines, right_para_starts)

    var reflowed_lines = ReflowText(getline(1, '$'), options)
    ReplaceBufferLines(bufnr('%'), reflowed_lines)

    var updated_para_starts = LocateAnchorsAfterReflow(getline(1, '$'), anchors)

    ApplyPostReflowUi(options.width, current_bufnr,
        \ right_bufnr, right_lines, updated_para_starts)
    EqualizeBufferLengths(left_bufnr, right_bufnr)
enddef

export def ReflowText(lines: list<string>, options: dict<any>): list<string>
    var reflowed: list<string> = []
    var current_paragraph: list<string> = []
    var inside_fence = false
    var fence_pattern = '^\s*```'

    var opts = WithDefaultReflowOptions(options)
    var width = opts.width

    for line in lines
        var trimmed = trim(line)

        if line =~# fence_pattern
            if !empty(current_paragraph)
                var wrapped = WrapParagraph(current_paragraph, opts)
                extend(reflowed, wrapped)
                current_paragraph = []
            endif
            add(reflowed, line)
            if !IsInlineFence(line)
                inside_fence = !inside_fence
            endif
            continue
        endif

        if inside_fence
            add(reflowed, line)
            continue
        endif

        if line =~# '^\s*#'
            if !empty(current_paragraph)
                var wrapped = WrapParagraph(current_paragraph, opts)
                extend(reflowed, wrapped)
                current_paragraph = []
            endif
            add(reflowed, line)
            continue
        endif

        if empty(trimmed)
            # Empty line - end current paragraph
            if !empty(current_paragraph)
                var wrapped = WrapParagraph(current_paragraph, opts)
                extend(reflowed, wrapped)
                current_paragraph = []
            endif
            add(reflowed, '')
        else
            # Add to current paragraph for wrapping.
            add(current_paragraph, line)
        endif
    endfor

    # Handle final paragraph
    if !empty(current_paragraph)
        var wrapped = WrapParagraph(current_paragraph, opts)
        extend(reflowed, wrapped)
    endif

    return reflowed
enddef

def ExtractIndentAndHanging(line: string): dict<string>
    var indent = matchstr(line, '^\s*')
    var after_indent = line[len(indent) :]
    var bullet_match = matchlist(after_indent,
        \ '^\(\%([-*+]\|\d\+\.[)]\)\)\s\+')
    if empty(bullet_match)
        return {indent: indent, hanging: ''}
    endif
    var hanging = bullet_match[0]
    return {indent: indent, hanging: hanging}
enddef

def NormalizeWrappingText(lines: list<string>, dehyphenate: any): list<string>
    var normalized: list<string> = []
    var idx = 0

    while idx < len(lines)
        var line = trim(lines[idx])
        if dehyphenate && idx + 1 < len(lines)
            var next_line = trim(lines[idx + 1])
            if line =~# '\v[[:alpha:]]-$' &&
                \ next_line =~# '\v^[[:alpha:]]'
                line = substitute(line, '-$', '', '') .. next_line
                idx += 1
            endif
        endif
        add(normalized, line)
        idx += 1
    endwhile

    return normalized
enddef

def HyphenateWord(word: string, width: number, options: dict<any>): list<string>
    var max_width = width
    if max_width < 3
        return [word]
    endif

    var min_length = get(options, 'hyphen_min_length', 8)
    if strchars(word) < min_length
        return [word]
    endif

    var max_body_width = max_width - 1
    if max_body_width < 2
        return [word]
    endif

    var word_length = strchars(word)
    var width_accum = 0
    var max_index = 0
    var candidate_index = 0
    var vowels = 'aeiouy'

    for idx in range(0, word_length - 1)
        var char = strcharpart(word, idx, 1)
        width_accum += strdisplaywidth(char)
        if width_accum > max_body_width
            break
        endif
        max_index = idx + 1
        if idx > 1
            var prev_char = strcharpart(word, idx - 1, 1)
            if stridx(vowels, tolower(prev_char)) >= 0 &&
                \ stridx(vowels, tolower(char)) < 0
                candidate_index = idx
            endif
        endif
    endfor

    if max_index < 2 || max_index >= word_length - 1
        return [word]
    endif

    var split_index = candidate_index > 1 ? candidate_index : max_index
    if split_index > word_length - 2
        split_index = max_index
    endif

    var head = strcharpart(word, 0, split_index) .. '-'
    var tail = strcharpart(word, split_index)
    return [head, tail]
enddef

def JustifyLine(line: string, width: number): string
    var words = split(line, '\s\+')
    if len(words) < 2
        return line
    endif

    var base = join(words, ' ')
    var base_width = strdisplaywidth(base)
    var extra = width - base_width
    if extra <= 0
        return base
    endif

    var gaps = len(words) - 1
    var base_spaces = extra / gaps
    var remainder = extra % gaps
    var padded = ''

    for idx in range(len(words))
        padded ..= words[idx]
        if idx < gaps
            var space_count = 1 + base_spaces
            if idx < remainder
                space_count += 1
            endif
            padded ..= repeat(' ', space_count)
        endif
    endfor

    return padded
enddef

def JustifyLines(lines: list<string>, options: dict<any>, widths: any): list<string>
    var justify_last = get(options, 'justify_last_line', 0)
    var justified: list<string> = []
    var last_index = len(lines) - 1

    for idx in range(len(lines))
        var line = lines[idx]
        if idx == last_index && !justify_last
            add(justified, line)
            continue
        endif
        var target_width: number
        if type(widths) == v:t_dict
            target_width = idx == 0 ? widths.first : widths.other
        else
            target_width = widths
        endif
        add(justified, JustifyLine(line, target_width))
    endfor

    return justified
enddef

export def SetTexwidthToLongestLine(): number
    # Set textwidth option to the display width of the longest line in the current buffer
    # Ignores trailing whitespace when calculating display width
    var max_length = 0
    var line_count = line('$')

    for line_num in range(1, line_count)
        var line_text = getline(line_num)
        # Remove trailing whitespace before calculating display width
        var trimmed_line = substitute(line_text, '\s\+$', '', '')
        var line_length = strdisplaywidth(trimmed_line)
        if line_length > max_length
            max_length = line_length
        endif
    endfor

    # Set textwidth to the maximum display width found
    execute 'setlocal textwidth=' .. max_length

    return max_length
enddef

export def GetRightBufferParagraphLines(): list<number>
    var [original_bufnr, left_bufnr, right_bufnr] = ResolveBuffers()
    if right_bufnr == -1
        echoerr "Cleave: Right buffer not found or not valid"
        return []
    endif

    return ParaStarts(getbufline(right_bufnr, 1, '$'))
enddef

export def GetLeftBufferParagraphLines(): list<number>
    var [original_bufnr, left_bufnr, right_bufnr] = ResolveBuffers()
    if left_bufnr == -1
        echoerr "Cleave: Left buffer not found or not valid"
        return []
    endif

    if !has('textprop')
        echomsg "Cleave: Text properties not supported in this Vim version"
        return []
    endif

    var prop_type = 'cleave_paragraph_start'
    var para_starts = []

    var props = prop_list(1, {'bufnr': left_bufnr, 'types': [prop_type], 'end_lnum': -1})

    for prop in props
        add(para_starts, prop.lnum)
    endfor

    if empty(para_starts)
        SetTextProperties()

        props = prop_list(1, {'bufnr': left_bufnr, 'types': [prop_type], 'end_lnum': -1})
        for prop in props
            add(para_starts, prop.lnum)
        endfor
    endif

    return para_starts
enddef

export def ToggleParagraphHighlight()
    # Toggle the highlight group for cleave_paragraph_start between Normal and MatchParen
    if !has('textprop')
        echomsg "Cleave: Text properties not supported in this Vim version"
        return
    endif

    var prop_type = 'cleave_paragraph_start'

    # Check if the property type exists
    var current_highlight: dict<any>
    try
        current_highlight = prop_type_get(prop_type)
    catch
        echomsg "Cleave: Text property type '" .. prop_type .. "' not found"
        return
    endtry

    # Get current highlight group
    var current_group = get(current_highlight, 'highlight', 'Normal')

    # Toggle between Normal and MatchParen
    var new_group: string
    if current_group == 'Normal'
        new_group = 'MatchParen'
    else
        new_group = 'Normal'
    endif

    # Update the property type with new highlight
    prop_type_change(prop_type, {'highlight': new_group})

    # Force immediate visual update by temporarily moving cursor in each cleave window
    var [original_bufnr, left_bufnr, right_bufnr] = ResolveBuffers()
    var current_winid = win_getid()

    # Update left buffer windows
    if left_bufnr != -1
        for winid in win_findbuf(left_bufnr)
            var saved_winid = win_getid()
            win_gotoid(winid)
            var saved_pos = getcurpos()
            # Trigger text property refresh by briefly moving cursor
            execute "normal! \<C-L>"
            setpos('.', saved_pos)
            win_gotoid(saved_winid)
        endfor
    endif

    # Update right buffer windows
    if right_bufnr != -1
        for winid in win_findbuf(right_bufnr)
            var saved_winid = win_getid()
            win_gotoid(winid)
            var saved_pos = getcurpos()
            # Trigger text property refresh by briefly moving cursor
            execute "normal! \<C-L>"
            setpos('.', saved_pos)
            win_gotoid(saved_winid)
        endfor
    endif

    # Return to original window and force final redraw
    win_gotoid(current_winid)
    redraw!

    echomsg "Cleave: Paragraph highlight changed to " .. new_group
enddef

export def PlaceRightParagraphsAtLines(target_line_numbers: list<number>): list<number>
    # Places paragraphs from the right buffer at specified line numbers
    # If a paragraph would overlap with a previously placed paragraph,
    # slides it down to maintain one blank line separation
    #
    # Args: target_line_numbers - array of 1-based line numbers where paragraphs should be placed

    var [original_bufnr, left_bufnr, right_bufnr] = ResolveBuffers()
    if right_bufnr == -1
        echoerr "Cleave: Right buffer not found or not valid"
        return []
    endif

    if empty(target_line_numbers)
        echomsg "Cleave: No target line numbers provided"
        return []
    endif

    var current_lines = getbufline(right_bufnr, 1, '$')
    var extracted = ExtractParagraphs(current_lines)
    var paragraphs = mapnew(extracted, (_, v) => v.content)
    var paragraph_starts = mapnew(extracted, (_, v) => v.start)

    var target_lines = copy(target_line_numbers)
    if len(target_lines) < len(paragraphs)
        for idx in range(len(target_lines), len(paragraphs) - 1)
            add(target_lines, paragraph_starts[idx])
        endfor
    endif

    var placement = BuildParagraphPlacement(paragraphs, target_lines)
    ReplaceBufferLines(right_bufnr, placement.lines)
    return placement.positions
enddef

export def AlignRightToLeftParagraphs()
    var [original_bufnr, left_bufnr, right_bufnr] = ResolveBuffers()
    if original_bufnr == -1 || left_bufnr == -1 || right_bufnr == -1
        echoerr "Cleave: Not a cleave buffer or buffers not found."
        return
    endif

    var save_winid = win_getid()
    var save_cursor = getcurpos()

    # Step 1: Read text property positions from the left buffer
    var left_para_lines = GetLeftBufferParagraphLines()
    if empty(left_para_lines)
        echomsg "Cleave: No text properties found in left buffer"
        return
    endif

    # Step 2: Extract right-buffer paragraphs using simple detection.
    # Simple detection is correct here because paragraphs may have been
    # shifted away from their anchors, so positional correspondence with
    # the left buffer cannot be assumed.
    var right_lines = getbufline(right_bufnr, 1, '$')
    var extracted = ExtractParagraphs(right_lines)

    if len(left_para_lines) < len(extracted)
        echomsg "Cleave: Fewer text properties (" .. len(left_para_lines) ..
            \ ") than right-buffer paragraphs (" .. len(extracted) .. ")"
        return
    endif

    # Step 3-5: Place paragraphs at text property positions (slides down on overlap)
    var paragraphs = mapnew(extracted, (_, v) => v.content)
    var placement = BuildParagraphPlacement(paragraphs, left_para_lines)
    ReplaceBufferLines(right_bufnr, placement.lines)

    # Step 6: Pad right buffer to match left buffer
    EqualizeBufferLengths(left_bufnr, right_bufnr)

    # Step 7: Update text properties to reflect final positions
    SetTextProperties()

    # Restore cursor and syncbind
    win_gotoid(save_winid)
    setpos('.', save_cursor)
    syncbind
enddef

export def ShiftParagraph(direction: string)
    var [original_bufnr, left_bufnr, right_bufnr] = ResolveBuffers()
    if right_bufnr == -1 || left_bufnr == -1
        echoerr "Cleave: Not a cleave buffer or buffers not found."
        return
    endif

    var current_info = getbufvar(bufnr('%'), 'cleave', {})
    var current_side = get(current_info, 'side', '')
    if empty(current_info) || empty(current_side)
        echoerr "Cleave: Current buffer is not a cleave buffer (.left or .right)"
        return
    endif

    var move: number
    if direction ==# 'up'
        move = -1
    elseif direction ==# 'down'
        move = 1
    else
        echoerr "Cleave: Invalid shift direction"
        return
    endif

    var cursor_line = line('.')
    var cursor_col = col('.')
    var target_bufnr = current_side ==# 'right' ? right_bufnr : left_bufnr
    var target_lines = getbufline(target_bufnr, 1, '$')
    var total_lines = len(target_lines)

    if cursor_line < 1 || cursor_line > total_lines
        echoerr "Cleave: Cursor out of range"
        return
    endif

    var extracted = ExtractParagraphs(target_lines)
    if empty(extracted)
        echoerr "Cleave: No paragraphs found"
        return
    endif

    var para_index = -1

    for i in range(len(extracted))
        var start_line = extracted[i].start
        var para_len = len(extracted[i].content)
        if cursor_line >= start_line && cursor_line < start_line + para_len
            para_index = i
        endif
    endfor

    if para_index == -1
        for i in range(len(extracted))
            if extracted[i].start < cursor_line
                para_index = i
            endif
        endfor
    endif

    if para_index == -1
        echoerr "Cleave: Cursor is not in a paragraph"
        return
    endif

    var para_start = extracted[para_index].start
    var para_len = len(extracted[para_index].content)
    var para_end = para_start + para_len - 1

    if move == -1
        var blank_line = para_start - 1
        if blank_line < 1 || trim(target_lines[blank_line - 1]) !=# ''
            return
        endif
        if blank_line - 1 >= 1 && trim(target_lines[blank_line - 2]) !=# ''
            return
        endif
        deletebufline(target_bufnr, blank_line)
        appendbufline(target_bufnr, para_end - 1, '')
    else
        var blank_line = para_end + 1
        if blank_line > total_lines || trim(target_lines[blank_line - 1]) !=# ''
            return
        endif
        if blank_line + 1 <= total_lines && trim(target_lines[blank_line]) !=# ''
            return
        endif
        deletebufline(target_bufnr, blank_line)
        appendbufline(target_bufnr, para_start - 1, '')
    endif

    if current_side ==# 'right'
        SetTextProperties()
    endif

    var new_line = max([1, cursor_line + move])
    var new_line_text = get(getbufline(target_bufnr, new_line, new_line), 0, '')
    var new_col = min([cursor_col, len(new_line_text) + 1])
    cursor(new_line, new_col)
enddef

export def WrapParagraph(paragraph_lines: list<string>, options: dict<any>): list<string>
    var opts = WithDefaultReflowOptions(options)
    var width = opts.width
    var normalized_lines = NormalizeWrappingText(paragraph_lines,
        \ opts.dehyphenate)
    var indent_source = get(paragraph_lines, 0, '')
    var indent_info = ExtractIndentAndHanging(indent_source)
    var indent = indent_info.indent
    var hanging = indent_info.hanging
    var follow_indent = indent
    var cleaned_lines = []

    for idx in range(1, len(paragraph_lines) - 1)
        var candidate = paragraph_lines[idx]
        if !empty(trim(candidate))
            follow_indent = matchstr(candidate, '^\s*')
            break
        endif
    endfor

    for line in normalized_lines
        var trimmed = trim(line)
        if !empty(hanging) && stridx(trimmed, hanging) == 0
            trimmed = trim(trimmed[len(hanging) :])
        endif
        add(cleaned_lines, trimmed)
    endfor

    # Join paragraph into single string
    var text = join(cleaned_lines, ' ')
    var words = split(text, '\s\+')
    var wrapped_content = []
    var current_line = ''
    var prefix_first: string
    var prefix_other: string
    if empty(hanging)
        prefix_first = indent
        prefix_other = follow_indent
    else
        var hanging_pad = repeat(' ', strdisplaywidth(hanging))
        prefix_first = indent .. hanging
        prefix_other = indent .. hanging_pad
    endif
    var prefix_first_width = strdisplaywidth(prefix_first)
    var prefix_other_width = strdisplaywidth(prefix_other)
    var available_width_first = width - prefix_first_width
    var available_width_other = width - prefix_other_width

    if available_width_first < 1
        available_width_first = 1
    endif
    if available_width_other < 1
        available_width_other = 1
    endif

    var word_queue = copy(words)

    var current_width = available_width_first
    while !empty(word_queue)
        var word = remove(word_queue, 0)
        var test_line = empty(current_line) ? word : current_line .. ' ' .. word
        var line_width = strdisplaywidth(test_line)

        if line_width <= current_width
            current_line = test_line
        else
            if !empty(current_line)
                add(wrapped_content, current_line)
                current_line = ''
                insert(word_queue, word, 0)
                current_width = available_width_other
            else
                if opts.hyphenate
                    var split = HyphenateWord(word, current_width,
                        \ opts)
                    if len(split) > 1
                        add(wrapped_content, split[0])
                        insert(word_queue, split[1], 0)
                    else
                        add(wrapped_content, word)
                    endif
                else
                    add(wrapped_content, word)
                endif
                current_width = available_width_other
            endif
        endif
    endwhile

    if !empty(current_line)
        add(wrapped_content, current_line)
    endif

    if opts.mode ==# 'justify'
        var widths = {'first': available_width_first,
            \ 'other': available_width_other}
        wrapped_content = JustifyLines(wrapped_content, opts,
            \ widths)
    endif

    var wrapped = []
    for idx in range(len(wrapped_content))
        var prefix = idx == 0 ? prefix_first : prefix_other
        add(wrapped, prefix .. wrapped_content[idx])
    endfor

    return !empty(wrapped) ? wrapped : [prefix_first]
enddef

export def RestoreParagraphAlignment(right_bufnr: number, original_right_lines: list<string>, saved_para_starts: list<number>)
    var cleaned_lines = mapnew(original_right_lines, (_, v) => substitute(v, '\s\+$', '', ''))

    var extracted = ExtractParagraphs(cleaned_lines)
    var paragraphs = []
    for i in range(len(extracted))
        var target = i < len(saved_para_starts) ? saved_para_starts[i] : -1
        add(paragraphs, {'target_line': target, 'content': extracted[i].content})
    endfor

    # Step 2: Build new buffer content by placing paragraphs at target positions
    var adjusted_lines = []
    var current_line_num = 1

    for para in paragraphs
        if para.target_line > 0
            while current_line_num < para.target_line
                add(adjusted_lines, '')
                current_line_num += 1
            endwhile

            for content_line in para.content
                add(adjusted_lines, content_line)
                current_line_num += 1
            endfor
        endif
    endfor

    # Step 3: Update right buffer
    ReplaceBufferLines(right_bufnr, adjusted_lines)
enddef

export def SyncRightParagraphs()
    var [original_bufnr, left_bufnr, right_bufnr] = ResolveBuffers()
    if original_bufnr == -1 || left_bufnr == -1 || right_bufnr == -1
        return
    endif

    EqualizeBufferLengths(left_bufnr, right_bufnr)
    SetTextProperties()
enddef

export def SyncLeftParagraphs()
    var [original_bufnr, left_bufnr, right_bufnr] = ResolveBuffers()
    if original_bufnr == -1 || left_bufnr == -1 || right_bufnr == -1
        return
    endif

    var left_lines = getbufline(left_bufnr, 1, '$')
    var left_para_lines = GetLeftBufferParagraphLines()
    if empty(left_para_lines)
        SetTextProperties()
        return
    endif

    PlaceRightParagraphsAtLines(left_para_lines)

    EqualizeBufferLengths(left_bufnr, right_bufnr)
    SetTextProperties()
enddef

export def SetTextProperties()
    # Get buffer numbers using helper function
    var [original_bufnr, left_bufnr, right_bufnr] = ResolveBuffers()

    if original_bufnr == -1 || left_bufnr == -1 || right_bufnr == -1
        echoerr "Cleave: Not a cleave buffer or buffers not found."
        return
    endif

    # Check if text properties are supported
    if !has('textprop')
        echomsg "Cleave: Text properties not supported in this Vim version"
        return
    endif

    # Define text property type for paragraph markers
    var prop_type = 'cleave_paragraph_start'
    try
        prop_type_add(prop_type, {'highlight': 'MatchParen'})
    catch /E969:/
    endtry

    # Clear existing text properties in left buffer
    prop_remove({'type': prop_type, 'bufnr': left_bufnr, 'all': 1})

    var right_lines = getbufline(right_bufnr, 1, '$')
    var left_lines = getbufline(left_bufnr, 1, '$')
    var right_para_starts = ParaStarts(right_lines)

    # Pad left buffer if right paragraphs extend beyond it
    if !empty(right_para_starts)
        var max_para_line = right_para_starts[-1]
        if max_para_line > len(left_lines)
            PadBufferLines(left_bufnr, max_para_line)
            left_lines = getbufline(left_bufnr, 1, '$')
        endif
    endif

    var properties_added = 0
    for line_num in right_para_starts
        var left_line = left_lines[line_num - 1]
        if trim(left_line) != ''
            # Add text property to the first word of the line
            var match_data = matchstrpos(left_line, '\S\+')
            if match_data[1] >= 0
                var first_word = match_data[0]
                var start_col = match_data[1] + 1
                var length = match_data[2] - match_data[1]
                if !empty(first_word) && length > 0
                    prop_add(line_num, start_col, {
                        \ 'type': prop_type,
                        \ 'length': length,
                        \ 'bufnr': left_bufnr
                        \ })
                    properties_added += 1
                endif
            endif
        else
            # Line is empty, add text property to first column
            prop_add(line_num, 1, {
                \ 'type': prop_type,
                \ 'length': 0,
                \ 'bufnr': left_bufnr
                \ })
            properties_added += 1
        endif
    endfor

    # Store counts for TextChanged detection
    setbufvar(right_bufnr, 'cleave_para_count', len(right_para_starts))
    setbufvar(left_bufnr, 'cleave_prop_count', properties_added)

enddef

export def OnTextChanged()
    var [original_bufnr, left_bufnr, right_bufnr] = ResolveBuffers()
    if original_bufnr == -1 || left_bufnr == -1 || right_bufnr == -1
        return
    endif

    if !has('textprop')
        return
    endif

    var prop_type = 'cleave_paragraph_start'
    var props = prop_list(1, {'bufnr': left_bufnr, 'types': [prop_type], 'end_lnum': -1})
    var right_lines = getbufline(right_bufnr, 1, '$')
    var para_starts = ParaStarts(right_lines)

    var prop_count = len(props)
    var para_count = len(para_starts)

    # Build interleaved set of all line numbers that have a prop or para start
    var all_lines = {}
    for p in props
        all_lines[p.lnum] = 1
    endfor
    for lnum in para_starts
        all_lines[lnum] = 1
    endfor
    var sorted_lines = sort(mapnew(keys(all_lines), (_, v) => str2nr(v)), 'n')

    # Build lookup sets
    var prop_lines = {}
    for p in props
        prop_lines[p.lnum] = 1
    endfor
    var para_line_set = {}
    for lnum in para_starts
        para_line_set[lnum] = 1
    endfor

    # Walk interleaved list to reconcile
    for lnum in sorted_lines
        if prop_count == para_count
            break
        endif
        var has_prop = has_key(prop_lines, lnum)
        var has_para = has_key(para_line_set, lnum)

        if has_prop && !has_para && prop_count > para_count
            # Orphaned text property — remove it
            prop_remove({'type': prop_type, 'bufnr': left_bufnr,
                \ 'id': 0}, lnum, lnum)
            prop_count -= 1
        elseif !has_prop && has_para && prop_count < para_count
            # Right paragraph without a text property — add one
            var left_lines = getbufline(left_bufnr, 1, '$')
            var target_lnum = min([lnum, len(left_lines)])
            if target_lnum >= 1
                var left_line = left_lines[target_lnum - 1]
                if trim(left_line) != ''
                    var match_data = matchstrpos(left_line, '\S\+')
                    if match_data[1] >= 0
                        prop_add(target_lnum, match_data[1] + 1, {
                            \ 'type': prop_type,
                            \ 'length': match_data[2] - match_data[1],
                            \ 'bufnr': left_bufnr
                            \ })
                    endif
                else
                    prop_add(target_lnum, 1, {
                        \ 'type': prop_type,
                        \ 'length': 0,
                        \ 'bufnr': left_bufnr
                        \ })
                endif
            endif
            prop_count += 1
        endif
    endfor

    # Update stored counts
    setbufvar(right_bufnr, 'cleave_para_count', para_count)
    setbufvar(left_bufnr, 'cleave_prop_count', prop_count)

    # Re-align
    AlignRightToLeftParagraphs()
enddef

export def DebugParagraphs(...args: list<any>)
    var mode = len(args) > 0 ? args[0] : 'interleaved'

    var [original_bufnr, left_bufnr, right_bufnr] = ResolveBuffers()
    if original_bufnr == -1 || left_bufnr == -1 || right_bufnr == -1
        echoerr "Cleave: Not a cleave buffer or buffers not found."
        return
    endif

    var prop_type = 'cleave_paragraph_start'
    var props = has('textprop')
        \ ? prop_list(1, {'bufnr': left_bufnr, 'types': [prop_type], 'end_lnum': -1})
        \ : []
    var left_lines = getbufline(left_bufnr, 1, '$')
    var right_lines = getbufline(right_bufnr, 1, '$')
    var para_starts = ParaStarts(right_lines)

    # Build lookup dicts keyed by line number
    var prop_by_line = {}
    for p in props
        var word = p.lnum <= len(left_lines)
            \ ? matchstr(left_lines[p.lnum - 1], '\S\+') : ''
        prop_by_line[p.lnum] = printf('col %2d  len %2d  anchor: %s',
            \ p.col, p.length, empty(word) ? '(empty)' : word)
    endfor

    var para_by_line = {}
    for lnum in para_starts
        var preview = trim(right_lines[lnum - 1])
        if strchars(preview) > 50
            preview = strcharpart(preview, 0, 50) .. '...'
        endif
        para_by_line[lnum] = preview
    endfor

    if mode ==# 'sequential'
        echomsg "--- Left text properties ---"
        if empty(props)
            echomsg "  (none)"
        else
            for p in props
                echomsg printf("  line %3d  %s", p.lnum, prop_by_line[p.lnum])
            endfor
        endif
        echomsg "--- Right paragraph starts ---"
        if empty(para_starts)
            echomsg "  (none)"
        else
            for lnum in para_starts
                echomsg printf("  line %3d: %s", lnum, para_by_line[lnum])
            endfor
        endif
        return
    endif

    # Interleaved mode: merge by line number
    var all_lines = {}
    for lnum in keys(prop_by_line)
        all_lines[lnum] = 1
    endfor
    for lnum in keys(para_by_line)
        all_lines[lnum] = 1
    endfor
    var sorted_lines = sort(mapnew(keys(all_lines), (_, v) => str2nr(v)), 'n')

    var left_col_width = 40
    var header_left = '--- Left text properties ---'
    var header_right = '--- Right paragraph starts ---'
    echomsg printf('     %-' .. left_col_width .. 's  %s', header_left, header_right)

    for lnum in sorted_lines
        var left_part = has_key(prop_by_line, lnum) ? prop_by_line[lnum] : ''
        var right_part = has_key(para_by_line, lnum) ? para_by_line[lnum] : ''
        var right_avail = &columns - left_col_width - 10
        if right_avail > 3 && strchars(right_part) > right_avail
            right_part = strcharpart(right_part, 0, right_avail - 3) .. '...'
        endif
        echomsg printf('line %3d:  %-' .. left_col_width .. 's  %s',
            \ lnum, left_part, right_part)
    endfor
enddef

export def JumpToPeer()
    var info = getbufvar(bufnr('%'), 'cleave', {})
    if empty(info)
        echoerr "Cleave: Not in a cleave buffer."
        return
    endif
    var peer = info.peer
    if !bufexists(peer)
        echoerr "Cleave: Peer buffer no longer exists."
        return
    endif
    var peer_win = get(win_findbuf(peer), 0, -1)
    if peer_win == -1
        echoerr "Cleave: Peer window not found."
        return
    endif
    var target_line = line('.')
    var target_col = col('.')
    win_gotoid(peer_win)
    var last_line = line('$')
    cursor(min([target_line, last_line]), target_col)
enddef
