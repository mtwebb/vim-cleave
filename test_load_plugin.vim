" Test script to load Cleave plugin for development testing
" Usage: vim -S test_load_plugin.vim

" Add current directory to runtime path
let s:plugin_dir = expand('<sfile>:p:h')
execute 'set runtimepath+=' . s:plugin_dir

" Load the plugin files
runtime plugin/cleave.vim

" Verify plugin is loaded
if exists(':Cleave')
    echo "✅ Cleave plugin loaded successfully!"
    echo "Available commands:"
    echo "  :Cleave - Split buffer at cursor position"
    echo "  :CleaveReflow [width] - Reflow left buffer to specified width"
    echo "  :CleaveUndo - Undo cleave operation"
    echo ""
    
    " Load a test file for immediate testing
    echo "Loading test file with multi-byte content..."
    edit test/multibyte_mixed.txt
    echo "✅ Test file loaded. Try :Cleave to test the plugin!"
else
    echo "❌ Failed to load Cleave plugin"
    echo "Make sure you're running this from the plugin root directory"
endif

" Set up useful testing environment
set number
set ruler
set showcmd
set laststatus=2

" Show current directory
echo "Current directory: " . getcwd()
echo "Plugin directory: " . s:plugin_dir