# Vim-Cleave Agent Guidelines

## Test Commands
- Run plugin test: `./test.sh`
- Manual test: `vim -u NONE -c 'set rtp+=.' -c 'source plugin/cleave.vim' -c 'e test.txt' -c 'call cursor(1, 33)' -c 'Cleave'`
- Clean test artifacts: `rm -f *.swp *.swo`

## Architecture
- **plugin/cleave.vim**: Main entry point, defines commands and plugin guard
- **autoload/cleave.vim**: Core functionality with functions for splitting, buffer management, and undo
- **doc/cleave.txt**: Plugin documentation
- Plugin follows standard Vim plugin structure with autoload pattern for lazy loading

## Commands
- `:Cleave` - Split buffer at cursor position
- `:CleaveAt <column>` - Split buffer at specified column
- `:CleaveUndo` - Restore original buffer and close cleaved windows

## Code Style
- **VimScript**: 4-space indentation, function names use `namespace#function_name` pattern
- **Variables**: Use `g:` prefix for global options (e.g., `g:cleave_auto_sync`)
- **Error handling**: Use `echoerr` for user-facing errors, `echomsg` for debugging
- **Buffer management**: Use `setbufvar()` and `getbufvar()` for buffer-local variables
- **Naming**: Temporary buffers use `.left` and `.right` suffixes
