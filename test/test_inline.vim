" Test script for inline note split/merge functionality
" Run with: vim -u NONE -es -c "source test/test_inline.vim" -c "call RunInlineTests()" -c "qa!"

set nocompatible
set cpo&vim
set rtp+=.
runtime plugin/cleave.vim
runtime plugin/cleave_inline.vim

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

" ============================================================================
" SplitInlineContent tests
" ============================================================================

function! TestSplitInlineBasic()
    echomsg "=== TestSplitInlineBasic ==="
    let passed = 0
    let total = 0

    " Single note on a single line
    let lines = ['Hello world ^[This is a note] and more text.']
    let [left, right, nmap] = cleave#inline#SplitContent(lines)

    let total += 1
    let passed += AssertEqual(['Hello world  and more text.'], left, 'Basic split: left removes ^[...]')
    let total += 1
    let passed += AssertEqual(['This is a note'], right, 'Basic split: right has note content')
    let total += 1
    let passed += AssertEqual(1, len(nmap), 'Basic split: note_map has 1 entry')

    echomsg passed . "/" . total . " passed"
    return [passed, total]
endfunction

function! TestSplitInlineMultipleNotes()
    echomsg "=== TestSplitInlineMultipleNotes ==="
    let passed = 0
    let total = 0

    " Two notes on the same line — no blank padding lines inserted
    let lines = ['Text ^[Note one] middle ^[Note two] end.']
    let [left, right, nmap] = cleave#inline#SplitContent(lines)

    let total += 1
    let passed += AssertEqual(1, len(left), 'Multi-note: only one left line (no padding)')
    let total += 1
    let passed += AssertEqual('Text  middle  end.', left[0], 'Multi-note: left line has markup removed')
    let total += 1
    let passed += AssertEqual(1, len(right), 'Multi-note: only one right line')
    let total += 1
    let passed += AssertEqual('Note one', right[0], 'Multi-note: first right line is first note')
    let total += 1
    let passed += AssertEqual(2, len(nmap), 'Multi-note: note_map has 2 entries')
    let total += 1
    let passed += AssertEqual('Note two', get(nmap[1], 'text', ''), 'Multi-note: second note text in note_map')

    echomsg passed . "/" . total . " passed"
    return [passed, total]
endfunction

function! TestSplitInlineNoNotes()
    echomsg "=== TestSplitInlineNoNotes ==="
    let passed = 0
    let total = 0

    " Lines without any inline notes pass through unchanged
    let lines = ['Plain text line.', 'Another plain line.']
    let [left, right, nmap] = cleave#inline#SplitContent(lines)

    let total += 1
    let passed += AssertEqual(lines, left, 'No notes: left unchanged')
    let total += 1
    let passed += AssertEqual(['', ''], right, 'No notes: right is empty strings')
    let total += 1
    let passed += AssertEqual(0, len(nmap), 'No notes: note_map is empty')

    echomsg passed . "/" . total . " passed"
    return [passed, total]
endfunction

function! TestSplitInlineMixedLines()
    echomsg "=== TestSplitInlineMixedLines ==="
    let passed = 0
    let total = 0

    " Mix of lines with and without notes
    let lines = [
        \ 'First paragraph text.',
        \ '',
        \ 'Second paragraph ^[A margin note] continues here.',
        \ 'Third line no note.',
    \ ]
    let [left, right, nmap] = cleave#inline#SplitContent(lines)

    let total += 1
    let passed += AssertEqual('First paragraph text.', left[0], 'Mixed: line 1 unchanged')
    let total += 1
    let passed += AssertEqual('', right[0], 'Mixed: line 1 right empty')
    let total += 1
    let passed += AssertEqual('', left[1], 'Mixed: line 2 (blank) unchanged')
    let total += 1
    let passed += AssertEqual('Second paragraph  continues here.', left[2], 'Mixed: line 3 note removed (trailing space trimmed)')
    let total += 1
    let passed += AssertEqual('A margin note', right[2], 'Mixed: line 3 right has note')
    let total += 1
    let passed += AssertEqual('Third line no note.', left[3], 'Mixed: line 4 unchanged')
    let total += 1
    let passed += AssertEqual('', right[3], 'Mixed: line 4 right empty')

    echomsg passed . "/" . total . " passed"
    return [passed, total]
endfunction

" ============================================================================
" MergeInlineContent tests
" ============================================================================

function! TestMergeInlineBasic()
    echomsg "=== TestMergeInlineBasic ==="
    let passed = 0
    let total = 0

    let left = ['Hello world  and more text.']
    let right = ['This is a note']
    let merged = cleave#inline#MergeContent(left, right)

    let total += 1
    let passed += AssertEqual(['Hello world  and more text. ^[This is a note]'], merged, 'Basic merge: note re-inserted')

    echomsg passed . "/" . total . " passed"
    return [passed, total]
endfunction

function! TestMergeInlineMultiLineNote()
    echomsg "=== TestMergeInlineMultiLineNote ==="
    let passed = 0
    let total = 0

    " Multi-line right paragraph merges into a single ^[...] note
    let left = ['Main text here.', 'More left text.']
    let right = ['First part of note', 'second part of note']
    let merged = cleave#inline#MergeContent(left, right)

    let total += 1
    let passed += AssertEqual(2, len(merged), 'Multi-line note: output has 2 lines')
    let total += 1
    let passed += AssertEqual('Main text here. ^[First part of note second part of note]', merged[0], 'Multi-line note: paragraph joined into one note')
    let total += 1
    let passed += AssertEqual('More left text.', merged[1], 'Multi-line note: second left line passed through')

    echomsg passed . "/" . total . " passed"
    return [passed, total]
endfunction

function! TestMergeInlineNoNotes()
    echomsg "=== TestMergeInlineNoNotes ==="
    let passed = 0
    let total = 0

    let left = ['Plain text.', 'More text.']
    let right = ['', '']
    let merged = cleave#inline#MergeContent(left, right)

    let total += 1
    let passed += AssertEqual(left, merged, 'No-notes merge: left passed through')

    echomsg passed . "/" . total . " passed"
    return [passed, total]
endfunction

function! TestMergeInlineMixed()
    echomsg "=== TestMergeInlineMixed ==="
    let passed = 0
    let total = 0

    let left = ['Line one.', '', 'Line three.', 'Line four.']
    let right = ['', '', 'A note', '']
    let merged = cleave#inline#MergeContent(left, right)

    let total += 1
    let passed += AssertEqual('Line one.', merged[0], 'Mixed merge: line 1 no note')
    let total += 1
    let passed += AssertEqual('', merged[1], 'Mixed merge: line 2 blank')
    let total += 1
    let passed += AssertEqual('Line three. ^[A note]', merged[2], 'Mixed merge: line 3 note merged')
    let total += 1
    let passed += AssertEqual('Line four.', merged[3], 'Mixed merge: line 4 no note')

    echomsg passed . "/" . total . " passed"
    return [passed, total]
endfunction

" ============================================================================
" Multi-line right paragraph merges into single note
" ============================================================================

function! TestMergeInlineReflowedParagraph()
    echomsg "=== TestMergeInlineReflowedParagraph ==="
    let passed = 0
    let total = 0

    " Simulates a reflowed right buffer: 5-line paragraph on the right,
    " 8 lines on the left (left paragraph is longer than right paragraph)
    let left = [
        \ 'In metus vulputate eu scelerisque felis imperdiet proin fermentum',
        \ 'leo. At lectus urna duis convallis convallis tellus id. Turpis',
        \ 'egestas maecenas pharetra convallis posuere morbi. Nunc mattis',
        \ 'enim ut tellus elementum sagittis vitae et. Eu consequat ac felis',
        \ 'donec et. Libero nunc consequat interdum varius sit amet mattis',
        \ 'vulputate. Ultricies integer quis auctor elit sed vulputate mi',
        \ 'sit amet. In dictum non consectetur a erat nam at. A diam',
        \ 'maecenas sed enim ut sem. Pellentesque elit eget gravida cum.',
    \ ]
    let right = [
        \ 'Ultricies integer quis auctor elit sed',
        \ 'vulputate mi sit amet. In dictum non',
        \ 'consectetur a erat nam at. A diam maecenas',
        \ 'sed enim ut sem.  Pellentesque elit eget',
        \ 'gravida cum.',
        \ '',
        \ '',
        \ '',
    \ ]
    let merged = cleave#inline#MergeContent(left, right)

    " Should produce 8 lines: first line has the whole note, rest are plain
    let total += 1
    let passed += AssertEqual(8, len(merged), 'Reflowed para: output has 8 lines')

    let expected_note = 'Ultricies integer quis auctor elit sed vulputate mi sit amet. In dictum non consectetur a erat nam at. A diam maecenas sed enim ut sem.  Pellentesque elit eget gravida cum.'
    let total += 1
    let passed += AssertEqual(left[0] .. ' ^[' .. expected_note .. ']', merged[0], 'Reflowed para: note joined on first line')

    " Remaining lines are plain left text
    for idx in range(1, 7)
        let total += 1
        let passed += AssertEqual(left[idx], merged[idx], 'Reflowed para: line ' .. (idx + 1) .. ' is plain left')
    endfor

    echomsg passed . "/" . total . " passed"
    return [passed, total]
endfunction

" ============================================================================
" Multiple inline notes across document (one per line) regression test
" ============================================================================

function! TestMultipleInlineNotesAcrossDocument()
    echomsg "=== TestMultipleInlineNotesAcrossDocument ==="
    let passed = 0
    let total = 0

    " Document with several inline notes on separate lines, interspersed
    " with plain lines, blank lines, and headings.
    let lines = [
        \ '# Introduction',
        \ '',
        \ 'First paragraph about the topic. ^[Background reference]',
        \ 'Continuation of first paragraph.',
        \ '',
        \ 'Second paragraph starts here. ^[See also chapter 3]',
        \ '',
        \ '## Details',
        \ '',
        \ 'Detail line with no note.',
        \ 'Another detail. ^[This contradicts prior work]',
        \ '',
        \ 'Final thought. ^[Conclusion note]',
    \ ]

    let [left, right, nmap] = cleave#inline#SplitContent(lines)

    " Exactly 4 notes extracted
    let total += 1
    let passed += AssertEqual(4, len(nmap), 'Multi-doc: 4 notes extracted')

    " Left lines have no ^[ markup anywhere
    let has_markup = v:false
    for l in left
        if l =~# '\^\['
            let has_markup = v:true
            break
        endif
    endfor
    let total += 1
    let passed += AssertEqual(v:false, has_markup, 'Multi-doc: left has no ^[ markup')

    " Right lines have note content at the correct positions
    let total += 1
    let passed += AssertEqual('Background reference', right[2], 'Multi-doc: right line 3 has first note')
    let total += 1
    let passed += AssertEqual('See also chapter 3', right[5], 'Multi-doc: right line 6 has second note')
    let total += 1
    let passed += AssertEqual('This contradicts prior work', right[10], 'Multi-doc: right line 11 has third note')
    let total += 1
    let passed += AssertEqual('Conclusion note', right[12], 'Multi-doc: right line 13 has fourth note')

    " Non-note right lines are empty
    let total += 1
    let passed += AssertEqual('', right[0], 'Multi-doc: heading right empty')
    let total += 1
    let passed += AssertEqual('', right[3], 'Multi-doc: continuation right empty')
    let total += 1
    let passed += AssertEqual('', right[7], 'Multi-doc: subheading right empty')
    let total += 1
    let passed += AssertEqual('', right[9], 'Multi-doc: plain detail right empty')

    " Left lines preserve non-note content
    let total += 1
    let passed += AssertEqual('# Introduction', left[0], 'Multi-doc: heading preserved')
    let total += 1
    let passed += AssertEqual('Continuation of first paragraph.', left[3], 'Multi-doc: continuation preserved')
    let total += 1
    let passed += AssertEqual('## Details', left[7], 'Multi-doc: subheading preserved')
    let total += 1
    let passed += AssertEqual('Detail line with no note.', left[9], 'Multi-doc: plain line preserved')

    " Line count matches (one note per line, no continuation lines needed)
    let total += 1
    let passed += AssertEqual(len(lines), len(left), 'Multi-doc: left line count matches input')
    let total += 1
    let passed += AssertEqual(len(lines), len(right), 'Multi-doc: right line count matches input')

    " Round-trip merge should reproduce original
    let merged = cleave#inline#MergeContent(left, right)
    let total += 1
    let passed += AssertEqual(lines, merged, 'Multi-doc: round-trip preserves original')

    echomsg passed . "/" . total . " passed"
    return [passed, total]
endfunction

" ============================================================================
" Round-trip tests
" ============================================================================

function! TestSplitMergeRoundTrip()
    echomsg "=== TestSplitMergeRoundTrip ==="
    let passed = 0
    let total = 0

    " Notes at end of line round-trip perfectly
    let original = ['Some text more words. ^[A note]']
    let [left, right, nmap] = cleave#inline#SplitContent(original)
    let merged = cleave#inline#MergeContent(left, right)

    let total += 1
    let passed += AssertEqual(original, merged, 'Round-trip: end-of-line note preserved')

    " Inline note moves to end-of-line on merge (expected behavior)
    let inline = ['Some text ^[A note] more words.']
    let [left2, right2, nmap2] = cleave#inline#SplitContent(inline)
    let merged2 = cleave#inline#MergeContent(left2, right2)

    let total += 1
    let passed += AssertEqual(['Some text  more words. ^[A note]'], merged2, 'Round-trip: inline note moves to end')

    " Multiple notes on same line: no padding lines; only first note is in
    " right buffer, additional notes stored in note_map.text
    let multi = ['Text ^[Note A] middle ^[Note B] end.']
    let [left3, right3, nmap3] = cleave#inline#SplitContent(multi)
    let merged3 = cleave#inline#MergeContent(left3, right3)

    let total += 1
    let passed += AssertEqual(['Text  middle  end. ^[Note A]'], merged3, 'Round-trip: first note merges back')

    " Mixed document: lines without notes unchanged, notes move to end
    let mixed = [
        \ '# Heading',
        \ '',
        \ 'Paragraph one continues. ^[Margin note]',
        \ '',
        \ 'Paragraph two no notes.',
    \ ]
    let [left4, right4, nmap4] = cleave#inline#SplitContent(mixed)
    let merged4 = cleave#inline#MergeContent(left4, right4)

    let total += 1
    let passed += AssertEqual(mixed, merged4, 'Round-trip: mixed document preserved')

    echomsg passed . "/" . total . " passed"
    return [passed, total]
endfunction

" ============================================================================
" Explicit inline import/export command tests
" ============================================================================

function! TestCleaveImportCommand()
    echomsg "=== TestCleaveImportCommand ==="
    let passed = 0
    let total = 0

    new
    setlocal filetype=markdown
    call setline(1, [
        \ '# Title',
        \ '',
        \ 'Some text ^[A note] here.',
        \ '',
        \ 'More text.'
    \ ])
    setlocal nomodified
    write! /tmp/test_inline_auto.md
    edit! /tmp/test_inline_auto.md
    setlocal filetype=markdown

    CleaveImport

    let total += 1
    let passed += AssertEqual(v:true, winnr('$') >= 2, 'Import: split into 2+ windows')

    let left_lines = getline(1, '$')
    let has_markup = v:false
    for line in left_lines
        if line =~# '\^\['
            let has_markup = v:true
            break
        endif
    endfor
    let total += 1
    let passed += AssertEqual(v:false, has_markup, 'Import: left buffer has no ^[ markup')

    let info = getbufvar(bufnr('%'), 'cleave', {})
    let total += 1
    let passed += AssertEqual('inline', get(info, 'split_mode', ''), 'Import: split_mode is inline')

    wincmd l
    let right_lines = getline(1, '$')
    let has_note = v:false
    for line in right_lines
        if line =~# 'A note'
            let has_note = v:true
            break
        endif
    endfor
    let total += 1
    let passed += AssertEqual(v:true, has_note, 'Import: right buffer has note content')

    call cleave#UndoCleave()
    bdelete!
    call delete('/tmp/test_inline_auto.md')
    echomsg passed . "/" . total . " passed"
    return [passed, total]
endfunction

function! TestCleaveDoesNotAutoImport()
    echomsg "=== TestCleaveDoesNotAutoImport ==="
    let passed = 0
    let total = 0

    new
    setlocal filetype=markdown
    call setline(1, [
        \ 'Text ^[A note] here.',
        \ 'More text ^[Another] end.'
    \ ])
    setlocal nomodified
    write! /tmp/test_inline_off.md
    edit! /tmp/test_inline_off.md
    setlocal filetype=markdown

    Cleave

    let total += 1
    let passed += AssertEqual(v:true, winnr('$') >= 2, 'Cleave: still splits')

    let info = getbufvar(bufnr('%'), 'cleave', {})
    let total += 1
    let passed += AssertEqual(v:true, get(info, 'split_mode', 'column') !=# 'inline', 'Cleave: not inline mode')

    let left_lines = getline(1, '$')
    let total += 1
    let passed += AssertEqual(v:true, join(left_lines, "\n") =~# '\^\[', 'Cleave: markup remains in column split')

    call cleave#UndoCleave()
    bdelete!
    call delete('/tmp/test_inline_off.md')
    echomsg passed . "/" . total . " passed"
    return [passed, total]
endfunction

" ============================================================================
" CleaveExport merges inline import sessions
" ============================================================================

function! TestCleaveExportInlineSession()
    echomsg "=== TestCleaveExportInlineSession ==="
    let passed = 0
    let total = 0

    new
    setlocal filetype=markdown
    " End-of-line notes for exact round-trip
    let original_lines = [
        \ 'Alpha paragraph text. ^[Side A]',
        \ '',
        \ 'Beta paragraph end. ^[Side B]'
    \ ]
    call setline(1, original_lines)
    setlocal nomodified
    write! /tmp/test_join_inline.md
    edit! /tmp/test_join_inline.md
    setlocal filetype=markdown

    CleaveImport

    let info = getbufvar(bufnr('%'), 'cleave', {})
    let total += 1
    let passed += AssertEqual('inline', get(info, 'split_mode', ''), 'Export: inline mode active')

    CleaveExport

    let orig_bufnr = bufnr('/tmp/test_join_inline.md')
    if orig_bufnr > 0
        execute 'buffer' orig_bufnr
    endif
    let result_lines = getline(1, '$')
    let total += 1
    let passed += AssertEqual(original_lines, result_lines, 'Export: CleaveExport round-trips inline content')

    bdelete!
    call delete('/tmp/test_join_inline.md')
    echomsg passed . "/" . total . " passed"
    return [passed, total]
endfunction

" ============================================================================
" Column-based behavior preserved
" ============================================================================

function! TestColumnBehaviorPreserved()
    echomsg "=== TestColumnBehaviorPreserved ==="
    let passed = 0
    let total = 0

    new
    call setline(1, [
        \ 'Left column text      Right column text',
        \ 'More left text        More right text'
    \ ])
    setlocal nomodified
    write! /tmp/test_column_preserved.txt
    edit! /tmp/test_column_preserved.txt

    Cleave

    let info = getbufvar(bufnr('%'), 'cleave', {})
    let total += 1
    let passed += AssertEqual(v:true, get(info, 'split_mode', 'column') !=# 'inline', 'Column preserved: not inline mode')

    call cleave#UndoCleave()
    bdelete!
    call delete('/tmp/test_column_preserved.txt')
    echomsg passed . "/" . total . " passed"
    return [passed, total]
endfunction

" ============================================================================
" Join/export command validation
" ============================================================================

function! TestJoinModeArgValidation()
    echomsg "=== TestJoinModeArgValidation ==="
    let passed = 0
    let total = 0

    " Invalid mode should throw an error
    let caught_invalid = v:false
    try
        call cleave#JoinBuffers('bogus')
    catch /Invalid join mode/
        let caught_invalid = v:true
    endtry
    let total += 1
    let passed += AssertEqual(v:true, caught_invalid, 'Invalid mode rejected')

    " The core join path should reject inline-specific modes.
    let caught_inline_mode = v:false
    try
        call cleave#JoinBuffers('inline')
    catch /Invalid join mode/
        let caught_inline_mode = v:true
    catch
    endtry
    let total += 1
    let passed += AssertEqual(v:true, caught_inline_mode, 'inline mode rejected by core join')

    let v:errmsg = ''
    try
        call cleave#JoinBuffers('column')
    catch
    endtry
    let total += 1
    let passed += AssertEqual(v:true, v:errmsg !~# 'Invalid join mode', 'column mode accepted')

    " No argument should also not trigger invalid-mode error
    let v:errmsg = ''
    try
        call cleave#JoinBuffers()
    catch
    endtry
    let total += 1
    let passed += AssertEqual(v:true, v:errmsg !~# 'Invalid join mode', 'no-arg mode accepted')

    new
    setlocal filetype=markdown
    call setline(1, ['Alpha text. ^[Side note]'])
    setlocal nomodified
    write! /tmp/test_inline_join_guard.md
    edit! /tmp/test_inline_join_guard.md
    setlocal filetype=markdown

    CleaveImport

    let caught_export_guard = v:false
    try
        call cleave#JoinBuffers()
    catch /format-specific export command/
        let caught_export_guard = v:true
    catch
    endtry
    let total += 1
    let passed += AssertEqual(v:true, caught_export_guard, 'inline session rejected by core join')

    call cleave#UndoCleave()
    bdelete!
    call delete('/tmp/test_inline_join_guard.md')

    echomsg passed . "/" . total . " passed"
    return [passed, total]
endfunction

" ============================================================================
" Left buffer reflow after inline split
" ============================================================================

function! TestInlineLeftReflow()
    echomsg "=== TestInlineLeftReflow ==="
    let passed = 0
    let total = 0

    " Build a long source line (>100 chars) with two notes
    let long_line = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. ^[First note] Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris. ^[Second note]'

    new
    setlocal filetype=markdown
    setlocal textwidth=60
    call setline(1, [long_line])
    setlocal nomodified
    write! /tmp/test_inline_reflow.md
    edit! /tmp/test_inline_reflow.md
    setlocal filetype=markdown
    setlocal textwidth=60

    CleaveImport

    " Verify inline mode
    let info = getbufvar(bufnr('%'), 'cleave', {})
    let total += 1
    let passed += AssertEqual('inline', get(info, 'split_mode', ''), 'Left reflow: inline mode active')

    " Left buffer should have multiple lines (reflowed from one long line)
    let left_lines = getline(1, '$')
    let non_empty = filter(copy(left_lines), 'v:val !~# "^\\s*$"')
    let total += 1
    let passed += AssertEqual(v:true, len(non_empty) > 1, 'Left reflow: long line was wrapped (' . len(non_empty) . ' non-empty lines)')

    " No left line should exceed the reflow width (60) by much
    let max_left_width = 0
    for line in left_lines
        let w = strdisplaywidth(substitute(line, '\s\+$', '', ''))
        if w > max_left_width
            let max_left_width = w
        endif
    endfor
    let total += 1
    let passed += AssertEqual(v:true, max_left_width <= 65, 'Left reflow: lines within width limit (' . max_left_width . ')')

    " Right buffer should have notes
    wincmd l
    let right_lines = getline(1, '$')
    let has_first = v:false
    let has_second = v:false
    for line in right_lines
        if line =~# 'First note'
            let has_first = v:true
        endif
        if line =~# 'Second note'
            let has_second = v:true
        endif
    endfor
    let total += 1
    let passed += AssertEqual(v:true, has_first, 'Left reflow: right has first note')
    let total += 1
    let passed += AssertEqual(v:true, has_second, 'Left reflow: right has second note')

    wincmd h
    CleaveExport

    let orig_bufnr = bufnr('/tmp/test_inline_reflow.md')
    if orig_bufnr > 0
        execute 'buffer' orig_bufnr
    endif
    let result_lines = getline(1, '$')
    " Merged content should contain both notes
    let merged_text = join(result_lines, "\n")
    let total += 1
    let passed += AssertEqual(v:true, merged_text =~# 'First note', 'Left reflow: merged has first note')
    let total += 1
    let passed += AssertEqual(v:true, merged_text =~# 'Second note', 'Left reflow: merged has second note')

    bdelete!
    call delete('/tmp/test_inline_reflow.md')
    echomsg passed . "/" . total . " passed"
    return [passed, total]
endfunction

" ============================================================================
" Anchor word positioning: note appears on line containing its preceding word
" ============================================================================

function! TestInlineAnchorWordAlignment()
    echomsg "=== TestInlineAnchorWordAlignment ==="
    let passed = 0
    let total = 0

    " Two notes with distinctive anchor words.  At tw=40 the text wraps so
    " "aliqua." and "laboris." end up on different lines.
    let long_line = 'Lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. ^[Note about aliqua] Ut enim ad minim veniam quis nostrud exercitation ullamco laboris. ^[Note about laboris]'

    new
    setlocal filetype=markdown
    setlocal textwidth=40
    call setline(1, [long_line])
    setlocal nomodified
    write! /tmp/test_anchor_align.md
    edit! /tmp/test_anchor_align.md
    setlocal filetype=markdown
    setlocal textwidth=40

    CleaveImport

    let info = getbufvar(bufnr('%'), 'cleave', {})
    let total += 1
    let passed += AssertEqual('inline', get(info, 'split_mode', ''), 'Anchor: inline mode')

    let left_lines = getline(1, '$')

    " Find which left line contains "aliqua."
    let aliqua_line = -1
    for lnum in range(len(left_lines))
        if left_lines[lnum] =~# 'aliqua\.'
            let aliqua_line = lnum + 1
            break
        endif
    endfor
    let total += 1
    let passed += AssertEqual(v:true, aliqua_line > 0, 'Anchor: found aliqua. in left buffer')

    " Find which left line contains "laboris."
    let laboris_line = -1
    for lnum in range(len(left_lines))
        if left_lines[lnum] =~# 'laboris\.'
            let laboris_line = lnum + 1
            break
        endif
    endfor
    let total += 1
    let passed += AssertEqual(v:true, laboris_line > 0, 'Anchor: found laboris. in left buffer')

    " Right buffer: first note should be on the same line as "aliqua."
    wincmd l
    let right_lines = getline(1, '$')

    if aliqua_line > 0 && aliqua_line <= len(right_lines)
        let total += 1
        let passed += AssertEqual(v:true, right_lines[aliqua_line - 1] =~# 'Note about aliqua', 'Anchor: first note on aliqua line (' . aliqua_line . ')')
    else
        let total += 1
        let passed += AssertEqual(v:true, v:false, 'Anchor: aliqua line out of range')
    endif

    if laboris_line > 0 && laboris_line <= len(right_lines)
        let total += 1
        let passed += AssertEqual(v:true, right_lines[laboris_line - 1] =~# 'Note about laboris', 'Anchor: second note on laboris line (' . laboris_line . ')')
    else
        let total += 1
        let passed += AssertEqual(v:true, v:false, 'Anchor: laboris line out of range')
    endif

    " The two notes should be on different lines
    let total += 1
    let passed += AssertEqual(v:true, aliqua_line != laboris_line, 'Anchor: notes on different lines')

    call cleave#UndoCleave()
    bdelete!
    call delete('/tmp/test_anchor_align.md')
    echomsg passed . "/" . total . " passed"
    return [passed, total]
endfunction

" ============================================================================
" CleaveImport with lorem_ipsum_inline.md (multi-paragraph, multi-note)
" ============================================================================

function! TestImportLoremIpsumInline()
    echomsg "=== TestImportLoremIpsumInline ==="
    let passed = 0
    let total = 0

    edit test/lorem_ipsum_inline.md
    setlocal filetype=markdown

    CleaveImport

    let info = getbufvar(bufnr('%'), 'cleave', {})
    let total += 1
    let passed += AssertEqual('inline', get(info, 'split_mode', ''), 'LoremImport: inline mode')

    " Left buffer should be reflowed — no line exceeds tw (79)
    let left_lines = getline(1, '$')
    let max_w = 0
    for line in left_lines
        let w = strdisplaywidth(line)
        if w > max_w
            let max_w = w
        endif
    endfor
    let total += 1
    let passed += AssertEqual(v:true, max_w <= 85, 'LoremImport: left lines reflowed within width (' . max_w . ')')

    " Left buffer should have more lines than original (84) due to reflow
    let total += 1
    let passed += AssertEqual(v:true, len(left_lines) > 84, 'LoremImport: left buffer expanded by reflow (' . len(left_lines) . ')')

    " Right buffer should have 6 notes (4 lines have notes; 2 have 2 each)
    wincmd l
    let right_lines = getline(1, '$')
    let note_count = 0
    for line in right_lines
        if !empty(trim(line))
            let note_count += 1
        endif
    endfor
    let total += 1
    let passed += AssertEqual(6, note_count, 'LoremImport: 6 notes in right buffer')

    " Each note should be on a line where the left buffer contains
    " the corresponding anchor word
    wincmd h
    let left_lines = getline(1, '$')
    wincmd l
    let right_lines = getline(1, '$')

    " Build anchor→note pairs from the original file
    let expected_anchors = ['proin', 'fermentum', 'proin', 'ornare', 'malesuada', 'rutrum']
    let anchor_idx = 0
    for i in range(len(right_lines))
        if !empty(trim(right_lines[i]))
            if anchor_idx < len(expected_anchors)
                let anchor = expected_anchors[anchor_idx]
                let left_line = i < len(left_lines) ? left_lines[i] : ''
                let total += 1
                let passed += AssertEqual(v:true, left_line =~# '\V' . escape(anchor, '\'), 'LoremImport: note ' . (anchor_idx + 1) . ' aligned with "' . anchor . '" (line ' . (i + 1) . ')')
                let anchor_idx += 1
            endif
        endif
    endfor

    " Notes from different original paragraphs should NOT be adjacent
    " (there should be paragraph gaps between them)
    let note_lines = []
    for i in range(len(right_lines))
        if !empty(trim(right_lines[i]))
            call add(note_lines, i + 1)
        endif
    endfor
    " First two notes are from different paragraphs (lines 3 and 6)
    let total += 1
    let passed += AssertEqual(v:true, note_lines[1] - note_lines[0] > 2, 'LoremImport: notes 1-2 have paragraph gap')
    " Notes 2 and 3 are from different paragraphs (lines 6 and 11)
    let total += 1
    let passed += AssertEqual(v:true, note_lines[2] - note_lines[1] > 2, 'LoremImport: notes 2-3 have paragraph gap')

    wincmd h
    CleaveExport

    echomsg passed . "/" . total . " passed"
    return [passed, total]
endfunction

" ============================================================================
" Runner
" ============================================================================

function! RunInlineTests()
    echomsg "Running inline note tests..."
    echomsg "================================="
    let total_passed = 0
    let total_tests = 0

    let [p, t] = TestSplitInlineBasic()
    let total_passed += p | let total_tests += t

    let [p, t] = TestSplitInlineMultipleNotes()
    let total_passed += p | let total_tests += t

    let [p, t] = TestSplitInlineNoNotes()
    let total_passed += p | let total_tests += t

    let [p, t] = TestSplitInlineMixedLines()
    let total_passed += p | let total_tests += t

    let [p, t] = TestMergeInlineBasic()
    let total_passed += p | let total_tests += t

    let [p, t] = TestMergeInlineMultiLineNote()
    let total_passed += p | let total_tests += t

    let [p, t] = TestMergeInlineNoNotes()
    let total_passed += p | let total_tests += t

    let [p, t] = TestMergeInlineMixed()
    let total_passed += p | let total_tests += t

    let [p, t] = TestMergeInlineReflowedParagraph()
    let total_passed += p | let total_tests += t

    let [p, t] = TestMultipleInlineNotesAcrossDocument()
    let total_passed += p | let total_tests += t

    let [p, t] = TestSplitMergeRoundTrip()
    let total_passed += p | let total_tests += t

    let [p, t] = TestCleaveImportCommand()
    let total_passed += p | let total_tests += t

    let [p, t] = TestCleaveDoesNotAutoImport()
    let total_passed += p | let total_tests += t

    let [p, t] = TestCleaveExportInlineSession()
    let total_passed += p | let total_tests += t

    let [p, t] = TestColumnBehaviorPreserved()
    let total_passed += p | let total_tests += t

    let [p, t] = TestJoinModeArgValidation()
    let total_passed += p | let total_tests += t

    let [p, t] = TestInlineLeftReflow()
    let total_passed += p | let total_tests += t

    let [p, t] = TestInlineAnchorWordAlignment()
    let total_passed += p | let total_tests += t

    let [p, t] = TestImportLoremIpsumInline()
    let total_passed += p | let total_tests += t

    echomsg "================================="
    echomsg "INLINE TEST RESULTS:"
    echomsg "Total: " . total_passed . "/" . total_tests . " tests passed"

    if total_passed == total_tests
        echomsg "ALL INLINE TESTS PASSED!"
    else
        echomsg (total_tests - total_passed) . " TESTS FAILED!"
    endif

    return total_passed == total_tests ? 0 : 1
endfunction

if expand('%:t') == 'test_inline.vim'
    call RunInlineTests()
    qa!
endif
