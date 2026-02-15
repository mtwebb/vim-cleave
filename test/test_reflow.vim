" Test script for CleaveReflow functionality

set nocompatible
set cpo&vim
set rtp+=.
runtime plugin/cleave.vim

function! AssertEqual(expected, actual, message)
    if a:expected != a:actual
        echomsg "FAIL: " . a:message
        echomsg "  Expected: '" . a:expected . "'"
        echomsg "  Actual: '" . a:actual . "'"
        return 0
    else
        echomsg "PASS: " . a:message
        return 1
    endif
endfunction

function! TestReflowBasic()
    " Create test content
    new
    put =['This is a long line that should be wrapped when we reflow it to a smaller width.',
        \ '',
        \ 'This is another paragraph with multiple sentences. It should maintain alignment with the first paragraph after reflowing.']
    1delete
    setlocal nomodified
    
    " Test basic cleave
    call cursor(1, 20)
    CleaveAtCursor
    
    " Test reflow left buffer
    CleaveReflow 15
    
    " Check that left buffer was reflowed
    let left_lines = getline(1, '$')
    echo "Left buffer after reflow:"
    for i in range(len(left_lines))
        echo (i+1) . ": " . left_lines[i]
    endfor
    
    " Switch to right buffer and check alignment
    wincmd l
    let right_lines = getline(1, '$')
    echo "Right buffer after reflow:"
    for i in range(len(right_lines))
        echo (i+1) . ": " . right_lines[i]
    endfor
    
    call cleave#undo_cleave()
    bdelete!
    echo "Basic reflow test completed"
endfunction

function! TestReflowRightBuffer()
    " Create test content
    new
    put =['Short left side text here.',
        \ '',
        \ 'More left text.']
    1delete
    setlocal nomodified
    
    " Test cleave at column 25
    call cursor(1, 25)
    CleaveAtCursor
    
    " Move to right buffer and add content
    wincmd l
    call setline(1, ['This is a very long right side text that needs to be reflowed to a smaller width for better readability.',
                   \ '',
                   \ 'This is another paragraph on the right side that should maintain proper alignment.'])
    
    " Test reflow right buffer
    CleaveReflow 20
    
    " Check results
    let right_lines = getline(1, '$')
    echo "Right buffer after reflow:"
    for i in range(len(right_lines))
        echo (i+1) . ": " . right_lines[i]
    endfor
    
    call cleave#undo_cleave()
    bdelete!
    echo "Right buffer reflow test completed"
endfunction

function! TestReflowEdgeCases()
    " Test very narrow width
    new
    put =['This is test content for edge case testing.']
    1delete
    setlocal nomodified
    
    call cursor(1, 15)
    CleaveAtCursor
    
    " Try very narrow width (should be rejected)
    try
        CleaveReflow 5
        echo "ERROR: Should have rejected width 5"
    catch
        echo "Correctly rejected narrow width"
    endtry
    
    " Try minimum width
    CleaveReflow 10
    echo "Minimum width test passed"
    
    call cleave#undo_cleave()
    bdelete!
    echo "Edge cases test completed"
endfunction

function! TestReflowFencedBlocks()
    new
    let before_line = 'Paragraph before the fence should wrap to a ' .
        \ 'smaller width for testing.'
    let code_line = 'let example_code = "' .
        \ 'This line should not be wrapped even if it is long"'
    let after_line = 'Paragraph after fence should wrap as well.'
    let another_line = 'let another_line = "Keep as-is"'
    put =[before_line,
        \ '',
        \ '```',
        \ code_line,
        \ another_line,
        \ '```',
        \ '',
        \ after_line]
    1delete
    setlocal nomodified

    call cursor(1, 20)
    CleaveAtCursor
    CleaveReflow 20

    let lines = getline(1, '$')
    let fence_start = index(lines, '```')
    let fence_end = index(lines, '```', fence_start + 1)
    call AssertEqual(3, fence_start + 1, 'Fence start line preserved')
    call AssertEqual(6, fence_end + 1, 'Fence end line preserved')
    call AssertEqual(code_line, lines[fence_start + 1], 'Fence content preserved')
    call AssertEqual(another_line, lines[fence_start + 2], 'Fence content preserved')

    call cleave#undo_cleave()
    bdelete!
    echo "Fenced reflow test completed"
endfunction

function! TestRecleaveLast()
    new
    put =['One line of text for cleave.',
        \ 'Second line of text for cleave.']
    1delete
    setlocal nomodified

    call cursor(1, 15)
    CleaveAtCursor
    CleaveUndo
    file recleave_test.txt

    CleaveAgain
    let right_bufnr = bufnr('%')
    let info = getbufvar(right_bufnr, 'cleave', {})
    call AssertEqual(15, get(info, 'col', -1), 'Recleave uses last column')

    CleaveJoin
    call deletebufline(bufnr('%'), 1, '$')
    call setline(1, ['New content', 'Second line'])
    setlocal modified
    CleaveAgain
    CleaveJoin
    let recleave_lines = getline(1, '$')
    call AssertEqual('New content', get(recleave_lines, 0, ''), 'Recleave keeps unsaved buffer content')
    call AssertEqual('Second line', get(recleave_lines, 1, ''), 'Recleave keeps unsaved buffer content')

    bdelete!
    echomsg "Recleave test completed"
endfunction

function! TestShiftRightParagraph()
    if !has('textprop')
        echomsg "Skipping shift paragraph test: text properties unavailable"
        return
    endif

    new
    put =['Left column text.',
        \ '',
        \ 'Second left paragraph.',
        \ '']
    1delete
    setlocal nomodified

    call cursor(1, 20)
    CleaveAtCursor

    wincmd l
    call setline(1, ['First right paragraph line one.',
        \ 'First right paragraph line two.',
        \ '',
        \ 'Second right paragraph starts here.',
        \ 'Second right paragraph line two.'])

    call cleave#set_text_properties()

    call cursor(4, 5)
    call cleave#shift_paragraph('up')

    let right_lines = getline(1, '$')
    let shifted_index = index(right_lines, 'Second right paragraph starts here.')
    let expected_start = 4
    call AssertEqual(expected_start, shifted_index + 1, 'Shift paragraph up blocked')

    wincmd h
    let left_props = prop_list(1, {'bufnr': bufnr('%'), 'types': ['cleave_paragraph_start'], 'end_lnum': -1})
    let prop_lines = map(copy(left_props), 'v:val.lnum')
    call AssertEqual(4, prop_lines[1], 'Anchor moved with paragraph')

    wincmd l
    call cursor(3, 5)
    call cleave#shift_paragraph('down')

    let right_lines_after = getline(1, '$')
    let shifted_index_down = index(right_lines_after, 'Second right paragraph starts here.')
    call AssertEqual(4, shifted_index_down + 1, 'Shift paragraph down')

    wincmd h
    call cursor(3, 1)
    call cleave#shift_paragraph('up')
    let left_props_after = prop_list(1, {'bufnr': bufnr('%'), 'types': ['cleave_paragraph_start'], 'end_lnum': -1})
    let prop_lines_after = map(copy(left_props_after), 'v:val.lnum')
    call AssertEqual(4, prop_lines_after[1], 'Left buffer shift respected anchors')

    wincmd l
    call cursor(2, 1)
    call cleave#shift_paragraph('up')
    let right_lines_shift = getline(1, '$')
    let shifted_first = index(right_lines_shift, 'First right paragraph line one.')
    call AssertEqual(1, shifted_first + 1, 'Shift respects left anchor spacing')

    wincmd h
    call setline(1, ['Left column text.',
        \ '',
        \ 'Second left paragraph.',
        \ ''])
    setlocal nomodified
    call cleave#set_text_properties()

    wincmd l
    let right_before = getline(1, '$')
    let right_positions_before = []
    for i in range(len(right_before))
        if !empty(right_before[i]) && (i == 0 || empty(right_before[i - 1]))
            call add(right_positions_before, i + 1)
        endif
    endfor

    wincmd l
    call cursor(4, 1)
    call cleave#shift_paragraph('up')
    let right_lines_blank = getline(1, '$')
    let blank_index = index(right_lines_blank, '')
    call AssertEqual(3, blank_index + 1, 'Shift does not insert blank lines')

    let right_positions_after = []
    for i in range(len(right_lines_blank))
        if !empty(right_lines_blank[i]) && (i == 0 || empty(right_lines_blank[i - 1]))
            call add(right_positions_after, i + 1)
        endif
    endfor
    call AssertEqual(string(right_positions_before), string(right_positions_after), 'Right positions unchanged when shifting left')

    call cursor(1, 1)
    let right_positions_before_down = copy(right_positions_after)
    call cleave#shift_paragraph('down')
    let right_lines_after_down = getline(1, '$')
    let right_positions_after_down = []
    for i in range(len(right_lines_after_down))
        if !empty(right_lines_after_down[i]) && (i == 0 || empty(right_lines_after_down[i - 1]))
            call add(right_positions_after_down, i + 1)
        endif
    endfor
    call AssertEqual(string(right_positions_before_down), string(right_positions_after_down), 'Right positions unchanged when shift blocked')

    call cleave#undo_cleave()
    bdelete!
    echomsg "Shift paragraph test completed"
endfunction

function! RunReflowTests()
    echo "Starting reflow tests..."
    echo "========================"
    
    call TestReflowBasic()
    echo ""
    call TestReflowRightBuffer()
    echo ""
    call TestReflowEdgeCases()
    echo ""
    call TestReflowFencedBlocks()
    echo ""
    call TestShiftRightParagraph()
    echo ""
    call TestRecleaveLast()

    echo "========================"
    echo "All reflow tests completed"
endfunction

" Run tests if called directly
if expand('%:t') == 'test_reflow.vim'
    call RunReflowTests()
    qa!
endif
