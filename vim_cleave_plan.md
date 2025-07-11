# Vim-Cleave Plugin Development Plan

## Overview
Vim-Cleave is a plugin that splits buffer content vertically at the cursor position, creating separate left and right buffers while maintaining spatial positioning.

## Core Functionality

### 1. Buffer Splitting Logic
- **Cursor Position Capture**: Store current cursor column position as `cleavecolumn`
- **Content Extraction**: 
  - Left buffer: Characters 0 to `cleavecolumn-1` from each line
  - Right buffer: Characters `cleavecolumn` to end of line from each line
- **Buffer Naming**: Original filename with `.left` and `.right` suffixes

### 2. Window Management
- **Split Configuration**: Create vertical split with left buffer on left, right buffer on right
- **Window Sizing**: Left window width = `cleavecolumn-1` to maintain spatial alignment
- **Cursor Positioning**: Place cursor at same line in both buffers

## Implementation Structure

### Plugin File Organization
```
vim-cleave/
├── plugin/
│   └── cleave.vim          # Main plugin entry point
├── autoload/
│   └── cleave.vim          # Core functionality
├── doc/
│   └── cleave.txt          # Documentation
└── README.md
```

### Core Functions (autoload/cleave.vim)

#### `cleave#split_buffer()`
- Main entry point function
- Validates current buffer state
- Calls helper functions in sequence
- Handles error cases

#### `cleave#get_buffer_content()`
- Extracts all lines from current buffer
- Returns array of lines for processing

#### `cleave#split_content(lines, cleave_col)`
- Takes line array and cleave column position
- Returns two arrays: left_lines and right_lines
- Handles edge cases (empty lines, short lines)

#### `cleave#create_buffers(left_lines, right_lines, original_name)`
- Creates two new buffers with appropriate names
- Populates buffers with split content
- Sets buffer properties (filetype, etc.)

#### `cleave#setup_windows(cleave_col)`
- Creates vertical split layout
- Sizes left window to `cleave_col-1`
- Loads appropriate buffers in each window
- Positions cursors correctly

### Command Interface (plugin/cleave.vim)

#### Commands
- `:Cleave` - Execute split at cursor position
- `:CleaveAt <column>` - Execute split at specific column
- `:CleaveUndo` - Restore original buffer (if possible)

#### Key Mappings (optional)
- `<leader>cs` - Split buffer at cursor
- `<leader>cu` - Undo cleave operation

## Technical Implementation Details

### Buffer Content Processing
```vim
function! cleave#split_content(lines, cleave_col)
    let left_lines = []
    let right_lines = []
    
    for line in a:lines
        let line_len = len(line)
        
        if line_len <= a:cleave_col
            " Handle short lines
            call add(left_lines, line)
            call add(right_lines, '')
        else
            " Split line at cleave column
            let left_part = line[:a:cleave_col-1]
            let right_part = line[a:cleave_col:]
            call add(left_lines, left_part)
            call add(right_lines, right_part)
        endif
    endfor
    
    return [left_lines, right_lines]
endfunction
```

### Window Management
```vim
function! cleave#setup_windows(cleave_col)
    " Create vertical split
    execute 'vsplit'
    
    " Size left window
    execute 'vertical resize ' . (a:cleave_col - 1)
    
    " Load buffers in appropriate windows
    execute 'buffer ' . g:cleave_left_buffer
    wincmd l
    execute 'buffer ' . g:cleave_right_buffer
    wincmd h
endfunction
```

### Error Handling
- Check if buffer is modifiable
- Validate cursor position
- Handle empty buffers
- Manage buffer creation failures
- Provide meaningful error messages

## Configuration Options

### Global Variables
- `g:cleave_auto_resize` - Automatically resize windows on cleave
- `g:cleave_preserve_original` - Keep original buffer open in tab
- `g:cleave_default_mappings` - Enable default key mappings

### Buffer-local Variables
- `b:cleave_column` - Store cleave column for buffer
- `b:cleave_original` - Reference to original buffer
- `b:cleave_side` - Track if buffer is 'left' or 'right'

## Advanced Features

### Undo Functionality
- Track original buffer state
- Provide command to restore original content
- Handle multiple cleave operations

### Synchronization
- Option to keep left/right buffers synchronized
- Update corresponding buffer when one is modified
- Handle cursor movement synchronization

### Multiple Cleave Support
- Allow multiple cleave operations on same buffer
- Manage nested splits
- Track cleave history

## Testing Strategy

### Unit Tests
- Test content splitting logic with various inputs
- Verify buffer creation and naming
- Test window sizing calculations

### Integration Tests
- Test full cleave workflow
- Verify cursor positioning
- Test undo functionality

### Edge Case Testing
- Empty buffers
- Single character lines
- Very wide/narrow windows
- Binary files

## Documentation Requirements

### User Documentation
- Installation instructions
- Usage examples
- Configuration options
- Troubleshooting guide

### Developer Documentation
- Function API reference
- Extension points
- Contributing guidelines

## Installation Methods

### Manual Installation
```bash
mkdir -p ~/.vim/pack/plugins/start
cd ~/.vim/pack/plugins/start
git clone https://github.com/user/vim-cleave.git
```

### Plugin Manager Support
- Pathogen compatibility
- Vundle configuration
- vim-plug integration

## Development Phases

### Phase 1: Core Functionality
- Basic buffer splitting
- Simple window management
- Essential commands

### Phase 2: Enhancement
- Error handling
- Configuration options
- Undo functionality

### Phase 3: Advanced Features
- Buffer synchronization
- Multiple cleave support
- Performance optimization

### Phase 4: Polish
- Comprehensive testing
- Documentation completion
- Community feedback integration

## Performance Considerations

### Large Files
- Efficient line processing
- Memory usage optimization
- Progress indication for large operations

### Buffer Management
- Proper cleanup of temporary buffers
- Memory leak prevention
- Efficient redraw handling

## Compatibility

### Vim Versions
- Minimum Vim 7.4 support
- Neovim compatibility
- Test across versions

### Operating Systems
- Cross-platform path handling
- Platform-specific optimizations
- Shell integration considerations