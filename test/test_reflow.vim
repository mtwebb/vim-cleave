" Test script for CleaveReflow functionality

function! TestReflowBasic()
    " Create test content
    new
    put =['This is a long line that should be wrapped when we reflow it to a smaller width.',
        \ '',
        \ 'This is another paragraph with multiple sentences. It should maintain alignment with the first paragraph after reflowing.']
    1delete
    
    " Test basic cleave
    call cursor(1, 20)
    Cleave
    
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
    
    CleaveUndo
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
    
    " Test cleave at column 25
    call cursor(1, 25)
    Cleave
    
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
    
    CleaveUndo
    bdelete!
    echo "Right buffer reflow test completed"
endfunction

function! TestReflowEdgeCases()
    " Test very narrow width
    new
    put =['This is test content for edge case testing.']
    1delete
    
    call cursor(1, 15)
    Cleave
    
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
    
    CleaveUndo
    bdelete!
    echo "Edge cases test completed"
endfunction

function! RunReflowTests()
    echo "Starting reflow tests..."
    echo "========================"
    
    call TestReflowBasic()
    echo ""
    call TestReflowRightBuffer()
    echo ""
    call TestReflowEdgeCases()
    
    echo "========================"
    echo "All reflow tests completed"
endfunction

" Run tests if called directly
if expand('%:t') == 'test_reflow.vim'
    call RunReflowTests()
    qa!
endif
