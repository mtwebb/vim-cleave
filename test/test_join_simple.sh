#!/bin/bash

# Simple test script for join_buffers functionality
echo "Testing cleave#join_buffers() with multi-byte characters..."

# Create a temporary test file
cat > /tmp/cleave_test.txt << 'EOF'
Hello 世界 test
Test 测试 line
ASCII only line
日本語テスト content
Mixed: αβγ and 123
EOF

echo "Test file content:"
cat /tmp/cleave_test.txt
echo ""

# Test the join functionality by creating a vim script
cat > /tmp/test_join.vim << 'EOF'
" Load the test file
edit /tmp/cleave_test.txt

" Show original content
echo "Original content:"
for i in range(1, line('$'))
    let line = getline(i)
    echo printf("Line %d: '%s' (display width: %d)", i, line, strdisplaywidth(line))
endfor

" Split at virtual column 12
call cleave#split_buffer(bufnr('%'), 12)

" Show split results
echo "\nAfter split:"
let left_lines = getbufline(bufnr('%'), 1, '$')
echo "Left buffer:"
for i in range(len(left_lines))
    echo printf("  Line %d: '%s' (width: %d)", i+1, left_lines[i], strdisplaywidth(left_lines[i]))
endfor

wincmd l
let right_lines = getbufline(bufnr('%'), 1, '$')
echo "Right buffer:"
for i in range(len(right_lines))
    echo printf("  Line %d: '%s' (width: %d)", i+1, right_lines[i], strdisplaywidth(right_lines[i]))
endfor

" Join back
call cleave#join_buffers()

echo "\nAfter join:"
let joined_lines = getline(1, '$')
for i in range(len(joined_lines))
    let line = joined_lines[i-1]
    echo printf("Line %d: '%s' (width: %d)", i, line, strdisplaywidth(line))
    
    " Check where right content starts
    let vcol = 1
    let char_pos = 0
    let found_right_start = 0
    let in_padding = 0
    
    while char_pos < len(line) && !found_right_start
        let char = strpart(line, char_pos, 1)
        if char == ' ' && !in_padding
            let in_padding = 1
        elseif char != ' ' && in_padding
            echo printf("  Right content starts at virtual column %d", vcol)
            let found_right_start = 1
            break
        elseif char != ' '
            let in_padding = 0
        endif
        
        if char == "\t"
            let tab_width = &tabstop - ((vcol - 1) % &tabstop)
            let vcol += tab_width
        else
            let vcol += strdisplaywidth(char)
        endif
        let char_pos += len(char)
    endwhile
endfor

echo "\nTest completed successfully!"
quit!
EOF

echo "Running vim test..."
vim -n -c "source /tmp/test_join.vim" 2>&1

# Clean up
rm -f /tmp/cleave_test.txt /tmp/test_join.vim

echo "Test completed."