#!/bin/bash

# Test script for cleave modeline functionality
echo "Testing vim-cleave modeline functionality..."

vim -u NONE -es -c "source test/test_modeline.vim" -c "call RunModelineTests()" -c "qa!"
result=$?

if [ $result -eq 0 ]; then
    echo "All modeline tests passed."
else
    echo "Modeline tests FAILED."
fi

echo "Test completed."
exit $result
