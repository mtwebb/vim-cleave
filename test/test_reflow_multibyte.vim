" Test script for CleaveReflow functionality with multi-byte characters

function! TestReflowMultibyteCharacters()
    " Create test content with various character types
    new
    put =['This line has 中文字符 (Chinese characters) and should wrap correctly.',
        \ '',
        \ 'Another line with 日本語 (Japanese) and emoji 🌟✨ characters for testing display width calculations.']
    1delete
    
    " Test basic cleave
    call cursor(1, 20)
    Cleave
    
    " Test reflow left buffer with multi-byte content
    CleaveReflow 25
    
    " Check that left buffer was reflowed correctly
    let left_lines = getline(1, '$')
    echo "Left buffer after reflow (multi-byte):"
    for i in range(len(left_lines))
        let line = left_lines[i]
        echo (i+1) . ": " . line . " (display width: " . strdisplaywidth(line) . ")"
        
        " Verify no line exceeds the target width (except for single words that can't be broken)
        if strdisplaywidth(line) > 25 && match(line, ' ') != -1
            echo "ERROR: Line " . (i+1) . " exceeds width 25: " . strdisplaywidth(line)
        endif
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
    echo "Multi-byte reflow test completed"
endfunction

function! TestReflowTabCharacters()
    " Create test content with tab characters
    new
    " Use literal tabs in the content
    put =['This line has	tab characters	that should be handled correctly during reflow.',
        \ '',
        \ 'Another	line with	multiple tabs	for testing.']
    1delete
    
    " Test basic cleave
    call cursor(1, 15)
    Cleave
    
    " Test reflow left buffer with tab content
    CleaveReflow 20
    
    " Check that left buffer was reflowed correctly
    let left_lines = getline(1, '$')
    echo "Left buffer after reflow (with tabs):"
    for i in range(len(left_lines))
        let line = left_lines[i]
        echo (i+1) . ": " . substitute(line, '\t', '<TAB>', 'g') . " (display width: " . strdisplaywidth(line) . ")"
        
        " Verify no line exceeds the target width (except for single words that can't be broken)
        if strdisplaywidth(line) > 20 && match(line, ' ') != -1
            echo "ERROR: Line " . (i+1) . " exceeds width 20: " . strdisplaywidth(line)
        endif
    endfor
    
    CleaveUndo
    bdelete!
    echo "Tab character reflow test completed"
endfunction

function! TestReflowMixedContent()
    " Create test content with mixed character types
    new
    put =['Mixed content: ASCII, 中文, 日本語, emoji 🎯, tabs	and spaces.',
        \ '',
        \ 'Testing wrap_paragraph with various character widths: 한국어 Korean text with symbols ★☆.']
    1delete
    
    " Test basic cleave
    call cursor(1, 25)
    Cleave
    
    " Test reflow left buffer with mixed content
    CleaveReflow 30
    
    " Check that left buffer was reflowed correctly
    let left_lines = getline(1, '$')
    echo "Left buffer after reflow (mixed content):"
    for i in range(len(left_lines))
        let line = left_lines[i]
        echo (i+1) . ": " . line . " (display width: " . strdisplaywidth(line) . ")"
        
        " Verify no line exceeds the target width (except for single words that can't be broken)
        if strdisplaywidth(line) > 30 && match(line, ' ') != -1
            echo "ERROR: Line " . (i+1) . " exceeds width 30: " . strdisplaywidth(line)
        endif
    endfor
    
    CleaveUndo
    bdelete!
    echo "Mixed content reflow test completed"
endfunction

function! TestWrapParagraphDirectly()
    " Test the wrap_paragraph function directly with multi-byte content
    echo "Testing wrap_paragraph function directly:"
    
    " Test with Chinese characters
    let chinese_para = ['这是一个包含中文字符的段落，用于测试文本换行功能是否正确处理多字节字符。']
    let wrapped_chinese = cleave#wrap_paragraph(chinese_para, 20)
    echo "Chinese paragraph wrapped to width 20:"
    for i in range(len(wrapped_chinese))
        let line = wrapped_chinese[i]
        echo "  " . (i+1) . ": " . line . " (display width: " . strdisplaywidth(line) . ")"
    endfor
    
    " Test with emoji
    let emoji_para = ['This paragraph contains emoji 🌟✨🎯 and should wrap correctly based on display width.']
    let wrapped_emoji = cleave#wrap_paragraph(emoji_para, 25)
    echo "Emoji paragraph wrapped to width 25:"
    for i in range(len(wrapped_emoji))
        let line = wrapped_emoji[i]
        echo "  " . (i+1) . ": " . line . " (display width: " . strdisplaywidth(line) . ")"
    endfor
    
    echo "Direct wrap_paragraph test completed"
endfunction

function! RunMultibyteReflowTests()
    echo "Starting multi-byte reflow tests..."
    echo "===================================="
    
    call TestReflowMultibyteCharacters()
    echo ""
    call TestReflowTabCharacters()
    echo ""
    call TestReflowMixedContent()
    echo ""
    call TestWrapParagraphDirectly()
    
    echo "===================================="
    echo "All multi-byte reflow tests completed"
endfunction

" Run tests if called directly
if expand('%:t') == 'test_reflow_multibyte.vim'
    call RunMultibyteReflowTests()
    qa!
endif