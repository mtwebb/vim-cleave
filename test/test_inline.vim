" Test script for inline note split/merge functionality
" Run with: vim -u NONE -es -c "source test/test_inline.vim" -c "call RunInlineTests()" -c "qa!"

set nocompatible
set cpo&vim
set rtp+=.
runtime plugin/cleave.vim

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
    let [left, right, nmap] = cleave#SplitInlineContent(lines)

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

    " Two notes on the same line
    let lines = ['Text ^[Note one] middle ^[Note two] end.']
    let [left, right, nmap] = cleave#SplitInlineContent(lines)

    " First note goes on line 1, second creates a continuation line
    let total += 1
    let passed += AssertEqual('Text  middle  end.', left[0], 'Multi-note: first left line has markup removed')
    let total += 1
    let passed += AssertEqual('Note one', right[0], 'Multi-note: first right line is first note')
    let total += 1
    let passed += AssertEqual('', left[1], 'Multi-note: continuation left line is empty')
    let total += 1
    let passed += AssertEqual('Note two', right[1], 'Multi-note: second right line is second note')
    let total += 1
    let passed += AssertEqual(2, len(nmap), 'Multi-note: note_map has 2 entries')

    echomsg passed . "/" . total . " passed"
    return [passed, total]
endfunction

function! TestSplitInlineNoNotes()
    echomsg "=== TestSplitInlineNoNotes ==="
    let passed = 0
    let total = 0

    " Lines without any inline notes pass through unchanged
    let lines = ['Plain text line.', 'Another plain line.']
    let [left, right, nmap] = cleave#SplitInlineContent(lines)

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
    let [left, right, nmap] = cleave#SplitInlineContent(lines)

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
    let merged = cleave#MergeInlineContent(left, right)

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
    let merged = cleave#MergeInlineContent(left, right)

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
    let merged = cleave#MergeInlineContent(left, right)

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
    let merged = cleave#MergeInlineContent(left, right)

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
    let merged = cleave#MergeInlineContent(left, right)

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

    let [left, right, nmap] = cleave#SplitInlineContent(lines)

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
    let merged = cleave#MergeInlineContent(left, right)
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
    let [left, right, nmap] = cleave#SplitInlineContent(original)
    let merged = cleave#MergeInlineContent(left, right)

    let total += 1
    let passed += AssertEqual(original, merged, 'Round-trip: end-of-line note preserved')

    " Inline note moves to end-of-line on merge (expected behavior)
    let inline = ['Some text ^[A note] more words.']
    let [left2, right2, nmap2] = cleave#SplitInlineContent(inline)
    let merged2 = cleave#MergeInlineContent(left2, right2)

    let total += 1
    let passed += AssertEqual(['Some text  more words. ^[A note]'], merged2, 'Round-trip: inline note moves to end')

    " Multiple notes on same line: split creates continuation lines which
    " merge joins into a single note (v1 limits to one note per line)
    let multi = ['Text ^[Note A] middle ^[Note B] end.']
    let [left3, right3, nmap3] = cleave#SplitInlineContent(multi)
    let merged3 = cleave#MergeInlineContent(left3, right3)

    let total += 1
    let passed += AssertEqual(['Text  middle  end. ^[Note A Note B]', ''], merged3, 'Round-trip: multiple notes joined into one')

    " Mixed document: lines without notes unchanged, notes move to end
    let mixed = [
        \ '# Heading',
        \ '',
        \ 'Paragraph one continues. ^[Margin note]',
        \ '',
        \ 'Paragraph two no notes.',
    \ ]
    let [left4, right4, nmap4] = cleave#SplitInlineContent(mixed)
    let merged4 = cleave#MergeInlineContent(left4, right4)

    let total += 1
    let passed += AssertEqual(mixed, merged4, 'Round-trip: mixed document preserved')

    echomsg passed . "/" . total . " passed"
    return [passed, total]
endfunction

" ============================================================================
" AutoCleave inline detection tests
" ============================================================================

function! TestInlineAutoDetectMarkdown()
    echomsg "=== TestInlineAutoDetectMarkdown ==="
    let passed = 0
    let total = 0

    " g:cleave_inline_mode = 'auto' (default) with markdown filetype
    let g:cleave_inline_mode = 'auto'

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

    Cleave

    " Should have split into two windows
    let total += 1
    let passed += AssertEqual(v:true, winnr('$') >= 2, 'Auto inline: split into 2+ windows')

    " Left buffer should NOT contain ^[ markup
    let left_lines = getline(1, '$')
    let has_markup = v:false
    for line in left_lines
        if line =~# '\^\['
            let has_markup = v:true
            break
        endif
    endfor
    let total += 1
    let passed += AssertEqual(v:false, has_markup, 'Auto inline: left buffer has no ^[ markup')

    " Check split_mode is 'inline'
    let info = getbufvar(bufnr('%'), 'cleave', {})
    let total += 1
    let passed += AssertEqual('inline', get(info, 'split_mode', ''), 'Auto inline: split_mode is inline')

    " Right buffer should have the note content
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
    let passed += AssertEqual(v:true, has_note, 'Auto inline: right buffer has note content')

    call cleave#UndoCleave()
    bdelete!
    call delete('/tmp/test_inline_auto.md')
    echomsg passed . "/" . total . " passed"
    return [passed, total]
endfunction

function! TestInlineModeOff()
    echomsg "=== TestInlineModeOff ==="
    let passed = 0
    let total = 0

    " With inline mode off, column-based split should be used
    let g:cleave_inline_mode = 'off'

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

    " Should still split (column mode)
    let total += 1
    let passed += AssertEqual(v:true, winnr('$') >= 2, 'Mode off: still splits')

    " split_mode should NOT be 'inline'
    let info = getbufvar(bufnr('%'), 'cleave', {})
    let total += 1
    let passed += AssertEqual(v:true, get(info, 'split_mode', 'column') !=# 'inline', 'Mode off: not inline mode')

    call cleave#UndoCleave()
    bdelete!
    let g:cleave_inline_mode = 'auto'
    call delete('/tmp/test_inline_off.md')
    echomsg passed . "/" . total . " passed"
    return [passed, total]
endfunction

" ============================================================================
" CleaveJoin auto-dispatches to inline merge
" ============================================================================

function! TestCleaveJoinInlineDispatch()
    echomsg "=== TestCleaveJoinInlineDispatch ==="
    let passed = 0
    let total = 0

    let g:cleave_inline_mode = 'auto'

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

    Cleave

    " Verify inline mode
    let info = getbufvar(bufnr('%'), 'cleave', {})
    let total += 1
    let passed += AssertEqual('inline', get(info, 'split_mode', ''), 'Join dispatch: inline mode active')

    " CleaveJoin should auto-dispatch to inline merge
    CleaveJoin

    let orig_bufnr = bufnr('/tmp/test_join_inline.md')
    if orig_bufnr > 0
        execute 'buffer' orig_bufnr
    endif
    let result_lines = getline(1, '$')
    let total += 1
    let passed += AssertEqual(original_lines, result_lines, 'Join dispatch: CleaveJoin round-trips inline content')

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

    " Plain text (no inline notes) should use column-based split
    let g:cleave_inline_mode = 'auto'

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
" CleaveJoin mode argument validation
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

    " Valid modes should not trigger the invalid-mode error
    " (they will fail with 'Not a cleave buffer' since we have no session,
    "  but that's a different error)
    let v:errmsg = ''
    try
        call cleave#JoinBuffers('inline')
    catch
    endtry
    let total += 1
    let passed += AssertEqual(v:true, v:errmsg !~# 'Invalid join mode', 'inline mode accepted')

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

    let [p, t] = TestInlineAutoDetectMarkdown()
    let total_passed += p | let total_tests += t

    let [p, t] = TestInlineModeOff()
    let total_passed += p | let total_tests += t

    let [p, t] = TestCleaveJoinInlineDispatch()
    let total_passed += p | let total_tests += t

    let [p, t] = TestColumnBehaviorPreserved()
    let total_passed += p | let total_tests += t

    let [p, t] = TestJoinModeArgValidation()
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