#!/bin/bash

# Test script for CleaveReflow functionality with multi-byte characters

echo "Starting multi-byte reflow tests..."
echo "===================================="

# Test 1: Multi-byte character reflow
echo "Test 1: Multi-byte character reflow"
vim -c "
new |
put =['This line has 中文字符 (Chinese characters) and should wrap correctly.', '', 'Another line with 日本語 (Japanese) and emoji 🌟✨ characters for testing display width calculations.'] |
1delete |
call cursor(1, 20) |
Cleave |
CleaveReflow 25 |
let left_lines = getline(1, '\$') |
echo 'Left buffer after reflow (multi-byte):' |
for i in range(len(left_lines)) |
  let line = left_lines[i] |
  echo (i+1) . ': ' . line . ' (display width: ' . strdisplaywidth(line) . ')' |
  if strdisplaywidth(line) > 25 && match(line, ' ') != -1 |
    echo 'ERROR: Line ' . (i+1) . ' exceeds width 25: ' . strdisplaywidth(line) |
  endif |
endfor |
CleaveUndo |
bdelete! |
echo 'Multi-byte reflow test completed' |
qa!
"

echo ""

# Test 2: Tab character reflow  
echo "Test 2: Tab character reflow"
vim -c "
new |
put =['This line has\ttab characters\tthat should be handled correctly during reflow.', '', 'Another\tline with\tmultiple tabs\tfor testing.'] |
1delete |
call cursor(1, 15) |
Cleave |
CleaveReflow 20 |
let left_lines = getline(1, '\$') |
echo 'Left buffer after reflow (with tabs):' |
for i in range(len(left_lines)) |
  let line = left_lines[i] |
  echo (i+1) . ': ' . substitute(line, '\t', '<TAB>', 'g') . ' (display width: ' . strdisplaywidth(line) . ')' |
  if strdisplaywidth(line) > 20 && match(line, ' ') != -1 |
    echo 'ERROR: Line ' . (i+1) . ' exceeds width 20: ' . strdisplaywidth(line) |
  endif |
endfor |
CleaveUndo |
bdelete! |
echo 'Tab character reflow test completed' |
qa!
"

echo ""

# Test 3: Direct wrap_paragraph function test
echo "Test 3: Direct wrap_paragraph function test"
vim -c "
echo 'Testing wrap_paragraph function directly:' |
let chinese_para = ['这是一个包含中文字符的段落，用于测试文本换行功能是否正确处理多字节字符。'] |
let wrapped_chinese = cleave#wrap_paragraph(chinese_para, 20) |
echo 'Chinese paragraph wrapped to width 20:' |
for i in range(len(wrapped_chinese)) |
  let line = wrapped_chinese[i] |
  echo '  ' . (i+1) . ': ' . line . ' (display width: ' . strdisplaywidth(line) . ')' |
endfor |
let emoji_para = ['This paragraph contains emoji 🌟✨🎯 and should wrap correctly based on display width.'] |
let wrapped_emoji = cleave#wrap_paragraph(emoji_para, 25) |
echo 'Emoji paragraph wrapped to width 25:' |
for i in range(len(wrapped_emoji)) |
  let line = wrapped_emoji[i] |
  echo '  ' . (i+1) . ': ' . line . ' (display width: ' . strdisplaywidth(line) . ')' |
endfor |
echo 'Direct wrap_paragraph test completed' |
qa!
"

echo ""
echo "===================================="
echo "All multi-byte reflow tests completed"