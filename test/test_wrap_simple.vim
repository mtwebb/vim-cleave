" Simple test for wrap_paragraph function
echo "Testing wrap_paragraph function:"

" Test with ASCII
let ascii_result = cleave#wrap_paragraph(['This is a long line that should be wrapped'], 10)
echo "ASCII test (width 10):"
for line in ascii_result
    echo "  '" . line . "' (width: " . strdisplaywidth(line) . ")"
endfor

" Test with multi-byte characters
let mb_result = cleave#wrap_paragraph(['This has 中文 characters that are wide'], 15)
echo "Multi-byte test (width 15):"
for line in mb_result
    echo "  '" . line . "' (width: " . strdisplaywidth(line) . ")"
endfor

echo "Test completed"