" Simple test for display width functionality
source autoload/cleave.vim

" Test wrap_paragraph with multi-byte characters
echo "Testing wrap_paragraph with multi-byte characters:"
let chinese_text = ['这是一个包含中文字符的段落用于测试文本换行功能']
let result = cleave#wrap_paragraph(chinese_text, 20)
for line in result
    echo "Line: " . line . " (width: " . strdisplaywidth(line) . ")"
endfor

echo ""
echo "Testing wrap_paragraph with emoji:"
let emoji_text = ['This text has emoji 🌟✨🎯 characters that are wide']
let result2 = cleave#wrap_paragraph(emoji_text, 25)
for line in result2
    echo "Line: " . line . " (width: " . strdisplaywidth(line) . ")"
endfor

echo ""
echo "Testing wrap_paragraph with mixed content:"
let mixed_text = ['Mixed: ASCII, 中文, emoji 🎯, normal text']
let result3 = cleave#wrap_paragraph(mixed_text, 20)
for line in result3
    echo "Line: " . line . " (width: " . strdisplaywidth(line) . ")"
endfor

qa!