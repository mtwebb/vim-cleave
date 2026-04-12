vim9script

# cleave/inline.vim - inline note split/merge for cleave plugin

if !exists('g:cleave_inline_width')
    g:cleave_inline_width = 0
endif

# ============================================================================
# Inline Note Helpers
# ============================================================================

# Pattern for inline notes: ^[content]
# Matches non-nested ^[...] with any content that doesn't contain ]
const INLINE_NOTE_PATTERN = '\^\[\([^\]]*\)\]'

# Return true if the line contains at least one inline note ^[...]
def HasInlineNote(line: string): bool
    return line =~# '\^' .. '\[[^\]]*\]'
enddef

# ============================================================================
# Split / Merge
# ============================================================================

# Split a single line into [main_text, list_of_notes, list_of_anchor_words].
# Each ^[content] is removed from the main text and its inner content
# is collected in order.  The anchor word is the last whitespace-delimited
# word in the accumulated left text immediately before each note.
def ExtractInlineNotesFromLine(line: string): list<any>
    var notes: list<string> = []
    var anchors: list<string> = []
    var result = ''
    var pos = 0
    while true
        var m = matchstrpos(line, INLINE_NOTE_PATTERN, pos)
        if m[1] == -1
            result ..= strpart(line, pos)
            break
        endif
        # Append text before the match
        result ..= strpart(line, pos, m[1] - pos)
        # Capture the last word before this note as the anchor
        var preceding = substitute(result, '\s\+$', '', '')
        var anchor_word = matchstr(preceding, '\S\+$')
        add(anchors, anchor_word)
        # Extract note content (submatch group 1)
        var note_content = matchstr(strpart(line, m[1]), '\^\[\zs[^\]]*\ze\]')
        add(notes, note_content)
        pos = m[2]
    endwhile
    return [result, notes, anchors]
enddef

# Split buffer lines into left (main text) and right (notes) for inline mode.
# Returns [left_lines, right_lines, note_map] where note_map is a list of
# dicts {line: N, index: I, anchor: word} recording which source line each
# note came from and the preceding anchor word.
#
# All notes from the same source line share that left line (no blank
# padding lines inserted).  The first note goes on the same right-buffer
# line; additional notes are collected in note_map only — ReflowLeft
# repositions them at their anchor words after the left text is reflowed.
export def SplitContent(lines: list<string>): list<any>
    var left_lines: list<string> = []
    var right_lines: list<string> = []
    var note_map: list<dict<any>> = []
    var note_index = 0

    for i in range(len(lines))
        var line = lines[i]
        if !HasInlineNote(line)
            add(left_lines, line)
            add(right_lines, '')
            continue
        endif
        var [main_text, notes, anchors] = ExtractInlineNotesFromLine(line)
        # Trim trailing whitespace left behind after note removal
        add(left_lines, substitute(main_text, '\s\+$', '', ''))
        # First note on this line goes on the same right-buffer line
        if !empty(notes)
            add(right_lines, notes[0])
            add(note_map, {'line': i + 1, 'index': note_index,
                \ 'anchor': get(anchors, 0, '')})
            note_index += 1
            # Additional notes are recorded in note_map with their
            # anchors and text, but do NOT create blank left-side
            # padding lines.  ReflowLeft will position them at the
            # correct anchor word.
            for j in range(1, len(notes) - 1)
                add(note_map, {'line': i + 1, 'index': note_index,
                    \ 'anchor': get(anchors, j, ''),
                    \ 'text': notes[j]})
                note_index += 1
            endfor
        else
            add(right_lines, '')
        endif
    endfor
    return [left_lines, right_lines, note_map]
enddef

# Merge left (main text) and right (notes) back into inline note syntax.
# Consecutive non-empty right lines form a single paragraph that is joined
# into one ^[...] note attached to the first corresponding left line.
# Empty right lines separate note paragraphs.
export def MergeContent(left_lines: list<string>, right_lines: list<string>): list<string>
    var merged: list<string> = []
    var max_lines = max([len(left_lines), len(right_lines)])
    var i = 0

    while i < max_lines
        var left = (i < len(left_lines)) ? left_lines[i] : ''
        var right = (i < len(right_lines)) ? right_lines[i] : ''
        var right_trimmed = trim(right)

        if empty(right_trimmed)
            # No note on this line — pass through left text
            add(merged, left)
            i += 1
            continue
        endif

        # Collect the entire right-buffer paragraph into a single note
        var note_parts: list<string> = [right_trimmed]
        var j = i + 1
        while j < max_lines
            var next_right = (j < len(right_lines)) ? right_lines[j] : ''
            if !empty(trim(next_right))
                add(note_parts, trim(next_right))
                j += 1
            else
                break
            endif
        endwhile

        var note_body = join(note_parts, ' ')
        add(merged, left .. ' ^[' .. note_body .. ']')

        # Pass through remaining left lines that were part of this paragraph
        for k in range(i + 1, j - 1)
            var next_left = (k < len(left_lines)) ? left_lines[k] : ''
            add(merged, next_left)
        endfor

        i = j
    endwhile

    return merged
enddef

# ============================================================================
# Inline Left Reflow
# ============================================================================

# Reflow the left buffer for an inline session and reposition right-buffer
# notes so each note sits on the same line as its anchor word (the word
# that preceded the ^[...] in the original text).
export def ReflowLeft(options: dict<any>, left_bufnr: number,
    \ right_bufnr: number, note_map: list<dict<any>>)
    var right_lines = getbufline(right_bufnr, 1, '$')

    # Capture left buffer before reflow for paragraph mapping
    var left_lines_before = getline(1, '$')

    # Reflow left buffer text
    var reflowed_lines = cleave#ReflowText(left_lines_before, options)
    cleave#ReplaceBufferLines(bufnr('%'), reflowed_lines)

    # Build a map from original source line → reflowed line range.
    # Pre-reflow left lines keep the same line numbers as the original
    # source (SplitContent produces one left line per source line).
    # After reflow, a single long source line may expand into many
    # reflowed lines.  We walk both sequences in tandem: for each
    # pre-reflow paragraph (block of non-blank lines), find the
    # matching paragraph in the reflowed output.
    # Build paragraph ranges for pre-reflow text: list of [start, end]
    # (0-based inclusive indices) for each block of non-blank lines.
    var pre_paras: list<list<number>> = []
    var in_para = false
    var para_start = 0
    for li in range(len(left_lines_before))
        if !empty(trim(left_lines_before[li]))
            if !in_para
                para_start = li
                in_para = true
            endif
        else
            if in_para
                add(pre_paras, [para_start, li - 1])
                in_para = false
            endif
        endif
    endfor
    if in_para
        add(pre_paras, [para_start, len(left_lines_before) - 1])
    endif

    # Build corresponding paragraph ranges for reflowed text
    var ref_paras: list<list<number>> = []
    in_para = false
    para_start = 0
    for li in range(len(reflowed_lines))
        if !empty(trim(reflowed_lines[li]))
            if !in_para
                para_start = li
                in_para = true
            endif
        else
            if in_para
                add(ref_paras, [para_start, li - 1])
                in_para = false
            endif
        endif
    endfor
    if in_para
        add(ref_paras, [para_start, len(reflowed_lines) - 1])
    endif

    # For each note, find which pre-reflow paragraph contains its
    # source line, then search for the anchor word only within the
    # corresponding reflowed paragraph.
    var note_targets: list<number> = []
    # Track the last matched line within each paragraph to handle
    # multiple notes in the same paragraph with overlapping anchors.
    var para_search_from: dict<number> = {}
    for entry in note_map
        var anchor = get(entry, 'anchor', '')
        var src_line = entry.line - 1  # 0-based
        var target_line = -1

        # Find which pre-reflow paragraph this source line belongs to
        var para_idx = -1
        for pi in range(len(pre_paras))
            if src_line >= pre_paras[pi][0] && src_line <= pre_paras[pi][1]
                para_idx = pi
                break
            endif
        endfor

        if !empty(anchor) && para_idx >= 0 && para_idx < len(ref_paras)
            var ref_start = ref_paras[para_idx][0]
            var ref_end = ref_paras[para_idx][1]
            var search_start = get(para_search_from, string(para_idx), ref_start)
            for lnum in range(search_start, ref_end)
                if reflowed_lines[lnum] =~# '\V' .. escape(anchor, '\')
                    target_line = lnum + 1
                    para_search_from[string(para_idx)] = lnum + 1
                    break
                endif
            endfor
        endif
        add(note_targets, target_line)
    endfor

    # Build a new right buffer: place each note at its anchor target.
    # Notes that have a 'text' key in note_map carry their own text
    # (additional notes from multi-note source lines); first notes
    # are matched by order against non-empty right-buffer lines.
    var new_right: list<string> = []
    var right_cursor = 0
    for ni in range(len(note_map))
        var target = get(note_targets, ni, -1)

        # Get note text: from note_map.text if present, else next
        # non-empty right-buffer line
        var note_text = get(note_map[ni], 'text', '')
        if empty(note_text)
            while right_cursor < len(right_lines)
                if !empty(trim(right_lines[right_cursor]))
                    note_text = trim(right_lines[right_cursor])
                    right_cursor += 1
                    break
                endif
                right_cursor += 1
            endwhile
        endif

        if target < 1
            # Anchor not found — place after the last entry
            if !empty(new_right) && !empty(trim(get(new_right, -1, '')))
                add(new_right, '')
            endif
            add(new_right, note_text)
            continue
        endif

        # Pad to target line, sliding down if occupied
        while len(new_right) < target - 1
            add(new_right, '')
        endwhile
        while (target - 1) < len(new_right)
            \ && !empty(trim(new_right[target - 1]))
            target += 1
            while len(new_right) < target - 1
                add(new_right, '')
            endwhile
        endwhile
        add(new_right, note_text)
    endfor

    cleave#ReplaceBufferLines(right_bufnr, new_right)
    cleave#EqualizeBufferLengths(left_bufnr, right_bufnr)

    # Update cleave column and window sizing
    var gutter = max([1, get(g:, 'cleave_gutter', 3)])
    var new_cleave_col = options.width + gutter + 1
    var left_info = getbufvar(left_bufnr, 'cleave', {})
    var right_info = getbufvar(right_bufnr, 'cleave', {})
    if !empty(left_info)
        left_info.col = new_cleave_col
    endif
    if !empty(right_info)
        right_info.col = new_cleave_col
    endif

    var left_winid = get(win_findbuf(left_bufnr), 0, -1)
    var original_foldcolumn = left_winid != -1 ? getwinvar(left_winid, '&foldcolumn') : 0
    execute 'vertical resize ' .. (new_cleave_col - 2 + original_foldcolumn)
    execute 'setlocal textwidth=' .. options.width

    cleave#SetTextProperties()
enddef

# ============================================================================
# Buffer Split
# ============================================================================

export def SplitBuffer(bufnr: number)
    # Prevent double-cleave
    var info = getbufvar(bufnr, 'cleave', {})
    if !empty(info)
        echoerr "Cleave: Already in a cleave session. Use :CleaveUndo or :CleaveExport first."
        return
    endif
    var saved_hidden = &hidden
    set hidden
    try
        var original_bufnr = bufnr
        var original_winid = win_getid()
        var original_cursor = getcurpos()

        var original_lines = getbufline(original_bufnr, 1, '$')
        var [left_lines, right_lines, note_map] = SplitContent(original_lines)

        var original_name = expand('%:t')
        if empty(original_name)
            original_name = 'noname'
        endif
        var original_foldcolumn = &foldcolumn
        var original_filetype = &filetype

        # Compute a cleave column from the longest left line + gutter
        var max_left_width = 0
        for line in left_lines
            var w = strdisplaywidth(substitute(line, '\s\+$', '', ''))
            if w > max_left_width
                max_left_width = w
            endif
        endfor
        var gutter = max([1, get(g:, 'cleave_gutter', 3)])
        var cleave_col = max_left_width + gutter + 1

        var [left_bufnr, right_bufnr] = cleave#CreateBuffers(left_lines, right_lines, original_name, original_foldcolumn, original_filetype)

        cleave#SetupWindows(cleave_col, left_bufnr, right_bufnr, original_winid, original_cursor, original_foldcolumn)

        # Store cleave state with inline mode flag
        var left_state = {
            \ 'original': original_bufnr,
            \ 'side': 'left',
            \ 'peer': right_bufnr,
            \ 'col': cleave_col,
            \ 'source_ft': original_filetype,
            \ 'split_mode': 'inline',
            \ }
        var right_state = {
            \ 'original': original_bufnr,
            \ 'side': 'right',
            \ 'peer': left_bufnr,
            \ 'col': cleave_col,
            \ 'source_ft': original_filetype,
            \ 'split_mode': 'inline',
            \ }
        setbufvar(left_bufnr, 'cleave', left_state)
        setbufvar(right_bufnr, 'cleave', right_state)

        setbufvar(original_bufnr, 'cleave_col_last', cleave_col)

        cleave#SetTextProperties()

        # Reflow left buffer to a reasonable width so that long source
        # lines (which may have had multiple notes removed) wrap into
        # multiple lines, providing vertical space for right-buffer notes
        # to align beside the text they annotate.
        var left_reflow_width = getbufvar(original_bufnr, '&textwidth')
        if left_reflow_width < 10
            left_reflow_width = 72
        endif
        var left_winid = get(win_findbuf(left_bufnr), 0, -1)
        if left_winid != -1 && win_gotoid(left_winid)
            var left_reflow_opts = cleave#ResolveReflowOptions(left_reflow_width, '')
            if !empty(left_reflow_opts)
                ReflowLeft(left_reflow_opts, left_bufnr,
                    \ right_bufnr, note_map)
            endif
        endif

        # Reflow right buffer if g:cleave_inline_width is set
        var inline_width = get(g:, 'cleave_inline_width', 0)
        if inline_width >= 10
            var right_winid = get(win_findbuf(right_bufnr), 0, -1)
            if right_winid != -1 && win_gotoid(right_winid)
                var reflow_opts = cleave#ResolveReflowOptions(inline_width, '')
                if !empty(reflow_opts)
                    cleave#ReflowRightBuffer(reflow_opts, right_bufnr,
                        \ left_bufnr, right_bufnr)
                endif
            endif
        endif

        # Return to left window
        left_winid = get(win_findbuf(left_bufnr), 0, -1)
        if left_winid != -1
            win_gotoid(left_winid)
        endif
    finally
        &hidden = saved_hidden
    endtry
enddef

export def ExportSession()
    var [original_bufnr, left_bufnr, right_bufnr] = cleave#ResolveBuffers()

    if original_bufnr == -1 || left_bufnr == -1 || right_bufnr == -1
        echoerr "Cleave: Not a cleave buffer or buffers not found."
        return
    endif

    var left_info = getbufvar(left_bufnr, 'cleave', {})
    if get(left_info, 'split_mode', '') !=# 'inline'
        echoerr "Cleave: Not an inline import session."
        return
    endif

    var left_lines = getbufline(left_bufnr, 1, '$')
    var right_lines = getbufline(right_bufnr, 1, '$')
    var combined_lines = MergeContent(left_lines, right_lines)

    cleave#FinalizeSession(combined_lines, {
        \ 'update_modeline': false,
        \ 'message': 'Cleave: Inline notes exported.',
        \ })
enddef
