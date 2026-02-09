#!/bin/bash

# Simple test script for CleaveReflow functionality
echo "Testing vim-cleave reflow functionality..."

# Create a temporary test file
cat > /tmp/test_content.txt << 'EOF'
This is a very long line that should be wrapped when we reflow it to a smaller width for better readability and formatting.

This is another paragraph with multiple sentences that should maintain alignment. It contains several words that will need to be wrapped properly.

Short paragraph.
EOF

# Test the reflow functionality
cat > /tmp/test_reflow.vim << 'VIMEOF'
set rtp+=.
edit /tmp/test_content.txt
call cursor(1, 25)
Cleave
CleaveReflow 20
echo "Left buffer content:"
for i in range(1, line("$")) | echo i . ": " . getline(i) | endfor
wincmd l
echo "Right buffer content:"
for i in range(1, line("$")) | echo i . ": " . getline(i) | endfor
CleaveUndo
echo "Reflow test completed successfully!"
qa!
VIMEOF

vim -u NONE -es -S /tmp/test_reflow.vim

# Clean up
rm -f /tmp/test_content.txt

echo "Test completed."
