" Test script for CleaveAlign, CleaveSetProps, sync functions,
" and TextChanged paragraph deletion detection.

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

" Helper: get text property line numbers from the left buffer
function! s:get_prop_lines(left_bufnr)
    if !has('textprop')
        return []
    endif
    let props = prop_list(1, {'bufnr': a:left_bufnr,
        \ 'types': ['cleave_paragraph_start'], 'end_lnum': -1})
    return map(copy(props), 'v:val.lnum')
endfunction

" Helper: get 1-based line numbers of paragraph starts (simple detection)
function! s:get_para_starts(bufnr)
    let lines = getbufline(a:bufnr, 1, '$')
    let starts = []
    for i in range(len(lines))
        if trim(lines[i]) !=# ''
            if i == 0 || trim(lines[i - 1]) ==# ''
                call add(starts, i + 1)
            endif
        endif
    endfor
    return starts
endfunction

" ============================================================================
" CleaveSetProps tests
" ============================================================================

function! TestSetPropsBasic()
    if !has('textprop')
        echomsg "SKIP: TestSetPropsBasic (no textprop)"
        return
    endif

    new
    put =['Left paragraph one.',
        \ '',
        \ 'Left paragraph two.',
        \ '',
        \ 'Left paragraph three.']
    1delete
    setlocal nomodified

    call cursor(1, 20)
    CleaveAtCursor

    " Put right paragraphs at lines 1, 3, 5
    wincmd l
    call setline(1, ['Right note one.',
        \ '',
        \ 'Right note two.',
        \ '',
        \ 'Right note three.'])

    wincmd h
    CleaveSetProps

    let left_bufnr = bufnr('%')
    let prop_lines = s:get_prop_lines(left_bufnr)

    call AssertEqual(3, len(prop_lines), 'SetProps creates 3 properties')
    call AssertEqual(1, prop_lines[0], 'SetProps prop 1 at line 1')
    call AssertEqual(3, prop_lines[1], 'SetProps prop 2 at line 3')
    call AssertEqual(5, prop_lines[2], 'SetProps prop 3 at line 5')

    call cleave#undo_cleave()
    bdelete!
    echomsg "TestSetPropsBasic completed"
endfunction

function! TestSetPropsEmptyLeftLine()
    if !has('textprop')
        echomsg "SKIP: TestSetPropsEmptyLeftLine (no textprop)"
        return
    endif

    new
    put =['Left paragraph one.',
        \ '',
        \ '',
        \ '',
        \ 'Left paragraph two.']
    1delete
    setlocal nomodified

    call cursor(1, 20)
    CleaveAtCursor

    " Put a right paragraph at line 3 (empty left line)
    wincmd l
    call setline(1, ['Right note one.',
        \ '',
        \ 'Right on blank left.',
        \ '',
        \ 'Right note two.'])

    wincmd h
    CleaveSetProps

    let left_bufnr = bufnr('%')
    let props = prop_list(1, {'bufnr': left_bufnr,
        \ 'types': ['cleave_paragraph_start'], 'end_lnum': -1})

    call AssertEqual(3, len(props), 'SetProps empty left: 3 properties')
    " The property on the empty line should be zero-length
    let empty_prop = props[1]
    call AssertEqual(3, empty_prop.lnum, 'SetProps empty left: prop at line 3')
    call AssertEqual(0, empty_prop.length, 'SetProps empty left: zero-length prop')

    call cleave#undo_cleave()
    bdelete!
    echomsg "TestSetPropsEmptyLeftLine completed"
endfunction

" ============================================================================
" CleaveAlign tests
" ============================================================================

function! TestAlignBasic()
    if !has('textprop')
        echomsg "SKIP: TestAlignBasic (no textprop)"
        return
    endif

    new
    put =['Left paragraph one.',
        \ '',
        \ 'Left paragraph two.',
        \ '',
        \ 'Left paragraph three.']
    1delete
    setlocal nomodified

    call cursor(1, 20)
    CleaveAtCursor

    " Set right content aligned
    wincmd l
    call setline(1, ['Right A.',
        \ '',
        \ 'Right B.',
        \ '',
        \ 'Right C.'])

    wincmd h
    CleaveSetProps

    " Now shift right paragraphs out of position: B moved up next to A
    wincmd l
    call setline(1, ['Right A.',
        \ 'Right B.',
        \ '',
        \ 'Right C.',
        \ ''])

    wincmd h
    CleaveAlign

    " After align, right paragraphs should be repositioned.
    " "Right A.\nRight B." is one 2-line paragraph (no blank between).
    " So we have 2 paragraphs, not 3, and only 2 props are needed.
    " Para 1 (2 lines) at prop line 1, para 2 at prop line 3 or later.
    wincmd l
    let right_starts = s:get_para_starts(bufnr('%'))

    call AssertEqual(2, len(right_starts), 'Align basic: 2 paragraphs found')
    call AssertEqual(1, right_starts[0], 'Align basic: para 1 at line 1')
    call AssertEqual(v:true, right_starts[1] >= 3,
        \ 'Align basic: para 2 at or after line 3')

    call cleave#undo_cleave()
    bdelete!
    echomsg "TestAlignBasic completed"
endfunction

function! TestAlignShiftedAboveAnchor()
    if !has('textprop')
        echomsg "SKIP: TestAlignShiftedAboveAnchor (no textprop)"
        return
    endif

    new
    put =['',
        \ '',
        \ '',
        \ '',
        \ 'Left paragraph starts here.',
        \ 'Left paragraph line two.',
        \ '',
        \ 'Second left paragraph.']
    1delete
    setlocal nomodified

    call cursor(1, 30)
    CleaveAtCursor

    " Place right paragraph at line 5 (aligned) then set props
    wincmd l
    call setline(1, ['',
        \ '',
        \ '',
        \ '',
        \ 'Right note.',
        \ '',
        \ '',
        \ 'Second right note.'])

    wincmd h
    CleaveSetProps
    let prop_lines_before = s:get_prop_lines(bufnr('%'))

    " Now simulate shifting right paragraph ABOVE its anchor (line 2)
    wincmd l
    call setline(1, ['',
        \ 'Right note.',
        \ '',
        \ '',
        \ '',
        \ '',
        \ '',
        \ 'Second right note.'])

    " Run CleaveAlign — should NOT split "Right note." paragraph
    wincmd h
    CleaveAlign

    wincmd l
    let right_lines = getline(1, '$')
    " "Right note." should be a single paragraph, not split
    let right_starts = s:get_para_starts(bufnr('%'))
    call AssertEqual(2, len(right_starts),
        \ 'Align shifted: still 2 paragraphs (no false split)')

    call cleave#undo_cleave()
    bdelete!
    echomsg "TestAlignShiftedAboveAnchor completed"
endfunction

function! TestAlignOverlap()
    if !has('textprop')
        echomsg "SKIP: TestAlignOverlap (no textprop)"
        return
    endif

    new
    put =['Left line one.',
        \ 'Left line two.',
        \ 'Left line three.',
        \ '',
        \ 'Left paragraph two.']
    1delete
    setlocal nomodified

    call cursor(1, 20)
    CleaveAtCursor

    " Right: two paragraphs, first is 3 lines long
    wincmd l
    call setline(1, ['Right A line one.',
        \ 'Right A line two.',
        \ 'Right A line three.',
        \ '',
        \ 'Right B.'])

    wincmd h
    CleaveSetProps

    " Props should be at lines 1 and 5. But if we place a 3-line para at
    " line 1 and try to place para 2 at line 2 (which would overlap),
    " it should slide down.
    " Manually set props at lines 1 and 2 to force overlap
    let prop_type = 'cleave_paragraph_start'
    call prop_remove({'type': prop_type, 'bufnr': bufnr('%'), 'all': 1})
    call prop_add(1, 1, {'type': prop_type, 'length': 4, 'bufnr': bufnr('%')})
    call prop_add(2, 1, {'type': prop_type, 'length': 4, 'bufnr': bufnr('%')})

    CleaveAlign

    wincmd l
    let right_starts = s:get_para_starts(bufnr('%'))
    " Para 1 at line 1, para 2 should be slid down (after 3 lines + blank)
    call AssertEqual(1, right_starts[0], 'Align overlap: para 1 at line 1')
    call AssertEqual(v:true, right_starts[1] >= 5,
        \ 'Align overlap: para 2 slid past overlap')

    call cleave#undo_cleave()
    bdelete!
    echomsg "TestAlignOverlap completed"
endfunction

function! TestAlignPadding()
    if !has('textprop')
        echomsg "SKIP: TestAlignPadding (no textprop)"
        return
    endif

    new
    put =['Left line one.',
        \ '',
        \ 'Left line three.',
        \ '',
        \ 'Left line five.',
        \ '',
        \ 'Left line seven.',
        \ '',
        \ 'Left line nine.',
        \ '',
        \ 'Left line eleven.']
    1delete
    setlocal nomodified

    call cursor(1, 20)
    CleaveAtCursor

    wincmd l
    call setline(1, ['Right note.'])

    wincmd h
    CleaveSetProps
    CleaveAlign

    wincmd l
    let right_line_count = line('$')
    wincmd h
    let left_line_count = line('$')

    call AssertEqual(v:true, right_line_count >= left_line_count,
        \ 'Align padding: right >= left line count')

    call cleave#undo_cleave()
    bdelete!
    echomsg "TestAlignPadding completed"
endfunction

" ============================================================================
" TextChanged / on_right_text_changed tests
" ============================================================================

function! TestTextChangedParaDeletion()
    if !has('textprop')
        echomsg "SKIP: TestTextChangedParaDeletion (no textprop)"
        return
    endif

    new
    put =['Left paragraph one.',
        \ '',
        \ 'Left paragraph two.',
        \ '',
        \ 'Left paragraph three.']
    1delete
    setlocal nomodified

    call cursor(1, 20)
    CleaveAtCursor

    wincmd l
    call setline(1, ['Right A.',
        \ '',
        \ 'Right B.',
        \ '',
        \ 'Right C.'])
    let right_bufnr = bufnr('%')

    wincmd h
    CleaveSetProps

    let prop_lines_before = s:get_prop_lines(bufnr('%'))
    call AssertEqual(3, len(prop_lines_before),
        \ 'TextChanged: 3 props before deletion')

    " Delete the middle paragraph from right buffer
    wincmd l
    " Remove lines 2-3 (blank + "Right B.")
    call deletebufline(right_bufnr, 2, 3)

    " Simulate TextChanged by calling the handler directly
    call cleave#on_text_changed()

    wincmd h
    let prop_lines_after = s:get_prop_lines(bufnr('%'))
    call AssertEqual(2, len(prop_lines_after),
        \ 'TextChanged: 2 props after deletion')

    call cleave#undo_cleave()
    bdelete!
    echomsg "TestTextChangedParaDeletion completed"
endfunction

function! TestTextChangedNoChange()
    if !has('textprop')
        echomsg "SKIP: TestTextChangedNoChange (no textprop)"
        return
    endif

    new
    put =['Left paragraph one.',
        \ '',
        \ 'Left paragraph two.']
    1delete
    setlocal nomodified

    call cursor(1, 20)
    CleaveAtCursor

    wincmd l
    call setline(1, ['Right A.',
        \ '',
        \ 'Right B.'])

    wincmd h
    CleaveSetProps
    let prop_lines_before = s:get_prop_lines(bufnr('%'))

    " Call handler without deleting anything
    wincmd l
    call cleave#on_text_changed()

    wincmd h
    let prop_lines_after = s:get_prop_lines(bufnr('%'))
    call AssertEqual(prop_lines_before, prop_lines_after,
        \ 'TextChanged no change: props unchanged')

    call cleave#undo_cleave()
    bdelete!
    echomsg "TestTextChangedNoChange completed"
endfunction

" ============================================================================
" TextChanged left buffer tests
" ============================================================================

function! TestTextChangedLeftPropDeleted()
    if !has('textprop')
        echomsg "SKIP: TestTextChangedLeftPropDeleted (no textprop)"
        return
    endif

    new
    put =['Left paragraph one.',
        \ '',
        \ 'Left paragraph two.',
        \ '',
        \ 'Left paragraph three.']
    1delete
    setlocal nomodified

    call cursor(1, 20)
    CleaveAtCursor

    let left_bufnr = bufnr('%')
    wincmd l
    let right_bufnr = bufnr('%')
    call setline(1, ['Right A.',
        \ '',
        \ 'Right B.',
        \ '',
        \ 'Right C.'])

    wincmd h
    CleaveSetProps

    let prop_lines_before = s:get_prop_lines(left_bufnr)
    call AssertEqual(3, len(prop_lines_before),
        \ 'TextChangedLeft: 3 props before deletion')

    " Delete the middle paragraph from left buffer (lines 2-3: blank + "Left paragraph two.")
    " This removes the text property on line 3
    call deletebufline(left_bufnr, 2, 3)

    " Simulate TextChanged by calling the handler directly
    call cleave#on_text_changed()

    let prop_lines_after = s:get_prop_lines(left_bufnr)
    call AssertEqual(3, len(prop_lines_after),
        \ 'TextChangedLeft: 3 props after deletion (new prop added for orphaned para)')

    " Right buffer should still have 3 paragraphs
    let right_para_starts = s:get_para_starts(right_bufnr)
    call AssertEqual(3, len(right_para_starts),
        \ 'TextChangedLeft: right buffer still has 3 paragraphs')

    call cleave#undo_cleave()
    bdelete!
    echomsg "TestTextChangedLeftPropDeleted completed"
endfunction

" ============================================================================
" sync_left_paragraphs tests
" ============================================================================

function! TestSyncLeftParagraphs()
    if !has('textprop')
        echomsg "SKIP: TestSyncLeftParagraphs (no textprop)"
        return
    endif

    new
    put =['Left paragraph one.',
        \ '',
        \ 'Left paragraph two.',
        \ '',
        \ 'Left paragraph three.']
    1delete
    setlocal nomodified

    call cursor(1, 20)
    CleaveAtCursor

    wincmd l
    call setline(1, ['Right A.',
        \ '',
        \ 'Right B.',
        \ '',
        \ 'Right C.'])

    wincmd h
    CleaveSetProps

    " Now add lines to the left buffer, shifting paragraph 2 down
    wincmd h
    call append(1, ['Added left line.', 'Another added line.'])

    " Call sync_left to reposition right paragraphs
    call cleave#sync_left_paragraphs()

    wincmd l
    let right_starts = s:get_para_starts(bufnr('%'))

    " Right paragraphs should have moved to match updated text properties
    " Props were at 1, 3, 5 originally; after adding 2 lines after line 1,
    " the text properties on lines 3 and 5 shift to 5 and 7
    wincmd h
    let updated_props = s:get_prop_lines(bufnr('%'))

    wincmd l
    let right_starts_final = s:get_para_starts(bufnr('%'))

    " Right paragraph positions should match the updated property lines
    for i in range(min([len(updated_props), len(right_starts_final)]))
        call AssertEqual(v:true, right_starts_final[i] >= updated_props[i],
            \ 'SyncLeft: para ' . (i+1) . ' at or after prop line')
    endfor

    call cleave#undo_cleave()
    bdelete!
    echomsg "TestSyncLeftParagraphs completed"
endfunction

" ============================================================================
" sync_right_paragraphs tests
" ============================================================================

function! TestSyncRightParagraphs()
    if !has('textprop')
        echomsg "SKIP: TestSyncRightParagraphs (no textprop)"
        return
    endif

    new
    put =['Left paragraph one.',
        \ '',
        \ 'Left paragraph two.']
    1delete
    setlocal nomodified

    call cursor(1, 20)
    CleaveAtCursor

    wincmd l
    call setline(1, ['Right A.',
        \ '',
        \ 'Right B.'])

    wincmd h
    CleaveSetProps
    let left_bufnr = bufnr('%')

    " Add extra lines to left buffer to test padding
    call append(line('$'), ['', 'Extra left line.', '', 'More left.'])

    wincmd l
    let right_bufnr = bufnr('%')
    call cleave#sync_right_paragraphs()

    let right_line_count = len(getbufline(right_bufnr, 1, '$'))
    let left_line_count = len(getbufline(left_bufnr, 1, '$'))

    call AssertEqual(v:true, right_line_count >= left_line_count,
        \ 'SyncRight: right padded to left length')

    " Text properties should still exist
    wincmd h
    let props = s:get_prop_lines(bufnr('%'))
    call AssertEqual(v:true, len(props) >= 2,
        \ 'SyncRight: text properties maintained')

    call cleave#undo_cleave()
    bdelete!
    echomsg "TestSyncRightParagraphs completed"
endfunction

" ============================================================================
" Test runner
" ============================================================================

function! RunAlignAndPropsTests()
    echomsg "Starting align and props tests..."
    echomsg "=================================="

    call TestSetPropsBasic()
    call TestSetPropsEmptyLeftLine()
    call TestAlignBasic()
    call TestAlignShiftedAboveAnchor()
    call TestAlignOverlap()
    call TestAlignPadding()
    call TestTextChangedParaDeletion()
    call TestTextChangedNoChange()
    call TestTextChangedLeftPropDeleted()
    call TestSyncLeftParagraphs()
    call TestSyncRightParagraphs()

    echomsg "=================================="
    echomsg "All align and props tests completed"
endfunction

if expand('%:t') == 'test_align_and_props.vim'
    call RunAlignAndPropsTests()
    qa!
endif
