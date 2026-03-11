" Test JustifyLine and FindGapEnds with multibyte characters
" JustifyLine is tested indirectly via CleaveReflow <width> justify
" FindGapEnds is tested indirectly via AutoCleave on gap-based layouts

set nocompatible
set cpo&vim
set rtp+=.
runtime plugin/cleave.vim

function! AssertEqual(expected, actual, message)
    if a:expected != a:actual
        echomsg "FAIL: " . a:message
        echomsg "  Expected: '" . string(a:expected) . "'"
        echomsg "  Actual: '" . string(a:actual) . "'"
        return 0
    else
        echomsg "PASS: " . a:message
        return 1
    endif
endfunction

" ============================================================================
" JustifyLine tests (via CleaveReflow <width> justify)
" ============================================================================

function! TestJustifyCJK()
    echomsg "=== TestJustifyCJK ==="
    let passed = 0
    let total = 0

    new
    put =['中文 文本 测试 这是一段 用于测试 对齐功能的 文字内容',
        \ '',
        \ 'Second paragraph with ASCII text.']
    1delete
    setlocal nomodified

    call cursor(1, 20)
    CleaveAtCursor

    let b:cleave_reflow_mode = 'justify'
    CleaveReflow 20

    let lines = getline(1, '$')

    " Non-last lines in first paragraph should have extra spacing (justified)
    let para_lines = []
    for line in lines
        if empty(trim(line))
            break
        endif
        call add(para_lines, line)
    endfor

    let has_extra_spacing = v:false
    if len(para_lines) > 1
        for idx in range(len(para_lines) - 1)
            if para_lines[idx] =~# '\s\{2,\}\S'
                let has_extra_spacing = v:true
                break
            endif
        endfor
    endif

    let total += 1
    let passed += AssertEqual(v:true, has_extra_spacing, 'CJK justify adds spacing')

    " Verify no non-last line exceeds target width
    let all_within_width = v:true
    for idx in range(len(para_lines) - 1)
        if strdisplaywidth(para_lines[idx]) > 20
            let all_within_width = v:false
            echomsg "  Line " . (idx+1) . " exceeds width: " . strdisplaywidth(para_lines[idx])
        endif
    endfor
    let total += 1
    let passed += AssertEqual(v:true, all_within_width, 'CJK justified lines within width')

    call cleave#UndoCleave()
    bdelete!
    echomsg passed . "/" . total . " passed"
    return passed
endfunction

function! TestJustifyEmoji()
    echomsg "=== TestJustifyEmoji ==="
    let passed = 0
    let total = 0

    new
    put =['Emoji 🌟 stars ✨ sparkle 🎯 target 🔥 fire 💡 bulb 🚀 rocket extra words added to make this much longer text',
        \ '',
        \ 'Another paragraph with some words.']
    1delete
    setlocal nomodified

    call cursor(1, 20)
    CleaveAtCursor

    let b:cleave_reflow_mode = 'justify'
    CleaveReflow 30

    let lines = getline(1, '$')

    let para_lines = []
    for line in lines
        if empty(trim(line))
            break
        endif
        call add(para_lines, line)
    endfor

    let has_extra_spacing = v:false
    if len(para_lines) > 1
        for idx in range(len(para_lines) - 1)
            if para_lines[idx] =~# '\s\{2,\}\S'
                let has_extra_spacing = v:true
                break
            endif
        endfor
    endif

    let total += 1
    let passed += AssertEqual(v:true, has_extra_spacing, 'Emoji justify adds spacing')

    " Verify display widths respect the target
    let all_within_width = v:true
    for idx in range(len(para_lines) - 1)
        if strdisplaywidth(para_lines[idx]) > 30
            let all_within_width = v:false
            echomsg "  Line " . (idx+1) . " exceeds width: " . strdisplaywidth(para_lines[idx])
        endif
    endfor
    let total += 1
    let passed += AssertEqual(v:true, all_within_width, 'Emoji justified lines within width')

    call cleave#UndoCleave()
    bdelete!
    echomsg passed . "/" . total . " passed"
    return passed
endfunction

function! TestJustifyMixed()
    echomsg "=== TestJustifyMixed ==="
    let passed = 0
    let total = 0

    new
    put =['Café résumé naïve 中文 日本語 hello world testing mixed width characters',
        \ '',
        \ 'Second paragraph.']
    1delete
    setlocal nomodified

    call cursor(1, 20)
    CleaveAtCursor

    let b:cleave_reflow_mode = 'justify'
    CleaveReflow 22

    let lines = getline(1, '$')

    let para_lines = []
    for line in lines
        if empty(trim(line))
            break
        endif
        call add(para_lines, line)
    endfor

    " Last line should stay ragged (no extra spacing)
    let last_line = get(para_lines, -1, '')
    let total += 1
    let passed += AssertEqual(v:false, last_line =~# '\s\{2,\}\S',
        \ 'Mixed: last line stays ragged')

    " Non-last lines should be justified
    let has_extra_spacing = v:false
    if len(para_lines) > 1
        for idx in range(len(para_lines) - 1)
            if para_lines[idx] =~# '\s\{2,\}\S'
                let has_extra_spacing = v:true
                break
            endif
        endfor
    endif
    let total += 1
    let passed += AssertEqual(v:true, has_extra_spacing, 'Mixed justify adds spacing')

    call cleave#UndoCleave()
    bdelete!
    echomsg passed . "/" . total . " passed"
    return passed
endfunction

" ============================================================================
" FindGapEnds tests (via AutoCleave on two-column gap layouts)
" ============================================================================

function! TestGapDetectionCJK()
    echomsg "=== TestGapDetectionCJK ==="
    let passed = 0
    let total = 0

    new
    " Two-column layout with CJK on the left, gap, then right content
    " 中文 = 4 display cols each pair, gap of 4 spaces at ~col 12
    put =['第一行文本    Right side one',
        \ '第二行内容    Right side two',
        \ '第三段落字    Right side three']
    1delete
    setlocal nomodified

    Cleave

    " Should have split into two windows
    let win_count = winnr('$')
    let total += 1
    let passed += AssertEqual(v:true, win_count >= 2, 'CJK gap: split into 2+ windows')

    " Left buffer should contain the CJK text
    let left_lines = getline(1, '$')
    let has_cjk = v:false
    for line in left_lines
        if stridx(line, '第') >= 0
            let has_cjk = v:true
            break
        endif
    endfor
    let total += 1
    let passed += AssertEqual(v:true, has_cjk, 'CJK gap: left buffer has CJK')

    " Right buffer should have the ASCII content
    wincmd l
    let right_lines = getline(1, '$')
    let has_right = v:false
    for line in right_lines
        if line =~# 'Right side'
            let has_right = v:true
            break
        endif
    endfor
    let total += 1
    let passed += AssertEqual(v:true, has_right, 'CJK gap: right buffer has content')

    call cleave#UndoCleave()
    bdelete!
    echomsg passed . "/" . total . " passed"
    return passed
endfunction

function! TestGapDetectionMixedWidth()
    echomsg "=== TestGapDetectionMixedWidth ==="
    let passed = 0
    let total = 0

    new
    " Mix of ASCII, accented, and CJK with a consistent gap
    put =['Café résumé      Notes about food',
        \ 'Hello world      Notes about greeting',
        \ '日本語テスト     Notes about Japanese']
    1delete
    setlocal nomodified

    Cleave

    let win_count = winnr('$')
    let total += 1
    let passed += AssertEqual(v:true, win_count >= 2, 'Mixed gap: split into 2+ windows')

    " Right buffer should have the notes
    wincmd l
    let right_lines = getline(1, '$')
    let has_notes = v:false
    for line in right_lines
        if line =~# 'Notes about'
            let has_notes = v:true
            break
        endif
    endfor
    let total += 1
    let passed += AssertEqual(v:true, has_notes, 'Mixed gap: right buffer has notes')

    call cleave#UndoCleave()
    bdelete!
    echomsg passed . "/" . total . " passed"
    return passed
endfunction

function! TestGapDetectionEmoji()
    echomsg "=== TestGapDetectionEmoji ==="
    let passed = 0
    let total = 0

    new
    " Emoji on left side with gap to right content
    put =['🌟 Star item      Description of star',
        \ '🎯 Target item    Description of target',
        \ '🔥 Fire item      Description of fire']
    1delete
    setlocal nomodified

    Cleave

    let win_count = winnr('$')
    let total += 1
    let passed += AssertEqual(v:true, win_count >= 2, 'Emoji gap: split into 2+ windows')

    wincmd l
    let right_lines = getline(1, '$')
    let has_desc = v:false
    for line in right_lines
        if line =~# 'Description of'
            let has_desc = v:true
            break
        endif
    endfor
    let total += 1
    let passed += AssertEqual(v:true, has_desc, 'Emoji gap: right buffer has descriptions')

    call cleave#UndoCleave()
    bdelete!
    echomsg passed . "/" . total . " passed"
    return passed
endfunction

" ============================================================================
" Runner
" ============================================================================

function! RunMultibyteJustifyGapTests()
    echomsg "Starting multibyte JustifyLine & FindGapEnds tests..."
    echomsg "======================================================"
    let total_passed = 0

    let total_passed += TestJustifyCJK()
    echomsg ""
    let total_passed += TestJustifyEmoji()
    echomsg ""
    let total_passed += TestJustifyMixed()
    echomsg ""
    let total_passed += TestGapDetectionCJK()
    echomsg ""
    let total_passed += TestGapDetectionMixedWidth()
    echomsg ""
    let total_passed += TestGapDetectionEmoji()

    echomsg "======================================================"
    echomsg "Total assertions passed: " . total_passed
    echomsg "All multibyte JustifyLine & FindGapEnds tests completed"
endfunction

if expand('%:t') == 'test_multibyte_justify_gap.vim'
    call RunMultibyteJustifyGapTests()
    qa!
endif
