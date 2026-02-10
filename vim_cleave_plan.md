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

### Paragraph Shifting

The plugin provides paragraph shifting to adjust alignment between the left
and right buffers. There are two behaviors:

1. `cleave#shift_paragraph(direction)`
   - When invoked from the right buffer, it shifts only the active right
     paragraph up or down by one line. Other right paragraphs retain their
     original start positions. After the move, `cleave#set_text_properties()`
     is called to refresh left-side anchor markers based on the right buffer.
   - When invoked from the left buffer, it shifts only the active left
     paragraph up or down by one line. Right paragraphs remain in place unless
     the left shift pushes later left paragraphs down, in which case the right
     buffer is re-aligned to the new left positions to keep both sides in sync.
   - Cursor behavior:
     - Right buffer: cursor stays on the same relative line within the moved
       paragraph.
     - Left buffer: cursor stays on the same relative line within the moved
       paragraph.

   Step-by-step (right buffer):
   - Extract right paragraphs with `s:extract_paragraphs()`.
   - Identify the paragraph that contains the cursor.
   - Shift that paragraph's target start line by `+1` (down) or `-1` (up).
   - Rebuild the right buffer with `cleave#place_right_paragraphs_at_lines()`.
   - Refresh left anchor properties via `cleave#set_text_properties()`.

   Step-by-step (left buffer):
   - Collect left anchor lines from `cleave#get_left_buffer_paragraph_lines()`.
   - Identify the left paragraph for the cursor using anchor position.
   - Shift that left paragraph's target start line by `+1` or `-1`.
   - Rebuild the left buffer using `s:build_paragraph_placement()`.
   - If shifting down causes later left paragraphs to move (actual positions
     differ from targets), rebuild the right buffer using those new positions
     to keep alignment.
   - Refresh left anchor properties via `cleave#set_text_properties()`.

Paragraph shifting relies on these helpers:
- `s:extract_paragraphs()` and `s:extract_paragraphs_ctx()`
- `s:build_paragraph_placement()` for collision-safe placement
- `cleave#place_right_paragraphs_at_lines()` for right-side reconstruction

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

## Robustness & Dependability Plan

Ordered list of improvements. Each step is self-contained and testable before moving to the next.

### 1. Remove debug output
Remove all leftover `echomsg` debug calls that leak into user message history:
- `"Debug: Loading unloaded buffer"` in `join_buffers` (line ~406)
- `"Cleave: Refreshed N text properties"` in `set_text_properties` (line ~1350)
- `"Cleave: No text properties found, creating them..."` in `get_left_buffer_paragraph_lines` (line ~902)
- Commented-out `echomsg` blocks in `reflow_left_buffer` (lines ~624-702)
Keep only `echoerr` for real errors and the success message in `join_buffers`.

### 2. Validate `g:cleave_gutter` on use
At the top of `split_buffer`, clamp `g:cleave_gutter` to a safe range. A zero or negative gutter will produce wrong window widths and padding. Add:
```vim
let gutter = max([0, g:cleave_gutter])
```
Use the validated value throughout instead of reading the global directly in downstream functions.

### 3. Unset `scrollbind` on cleanup
`setup_windows` sets `scrollbind` on both left and right windows, but neither `undo_cleave` nor `join_buffers` unsets it. After joining/undoing, the original buffer window retains `scrollbind`, which silently breaks normal scrolling if other splits exist. Add `setlocal noscrollbind` before switching back to the original buffer in both cleanup paths.

### 4. Clean up text properties on undo/join
`set_text_properties` creates a global prop type `cleave_paragraph_start` and adds props to the left buffer. Neither `undo_cleave` nor `join_buffers` removes the prop type. After cleanup the type lingers, and a second cleave hits the `E969` catch silently. Fix:
- Call `prop_remove({'type': ..., 'bufnr': left_bufnr, 'all': 1})` before deleting buffers
- Call `prop_type_delete('cleave_paragraph_start')` after buffer deletion (guarded with `has('textprop')`)

### 5. Guard all text property paths with `has('textprop')`
`split_buffer` unconditionally calls `set_text_properties()` at line ~243. If Vim lacks `textprop` support, `set_text_properties` returns early but `split_buffer` doesn't know. Guard the call:
```vim
if has('textprop')
    call cleave#set_text_properties()
endif
```
Similarly guard the call in `reflow_left_buffer`.

### 6. Handle `win_gotoid` failures
`setup_windows`, `undo_cleave`, and `join_buffers` all call `win_gotoid` without checking its return value. If the window was closed externally, the function returns 0 and subsequent commands operate on the wrong window. Wrap each call:
```vim
if !win_gotoid(win_id)
    echoerr "Cleave: Expected window no longer exists."
    return
endif
```

### 7. Add `BufWipeout` autocommand to clear stale state
If a user manually closes (`:bwipeout`) a left or right buffer, `s:cleave_*` variables still point to dead buffers. Every subsequent command will hit the fallback scan in `s:get_cleave_buffers`. Add an autocommand in `split_buffer` after buffer creation:
```vim
augroup CleaveCleanup
    autocmd!
    execute 'autocmd BufWipeout <buffer=' . left_bufnr . '> call s:clear_cleave_buffers()'
    execute 'autocmd BufWipeout <buffer=' . right_bufnr . '> call s:clear_cleave_buffers()'
augroup END
```

### 8. Prevent double-cleave
Nothing stops a user from running `:Cleave` while already in a cleaved buffer, which creates nested cleave state and corrupts `s:cleave_*` variables. At the top of `split_buffer`, check:
```vim
if s:validate_cleave_buffers()
    echoerr "Cleave: Already in a cleave session. Use :CleaveUndo or :CleaveJoin first."
    return
endif
```

### 9. Use `undojoin` for buffer writes
`join_buffers` calls `deletebufline` then `setbufline` on the original buffer, creating two undo entries for one logical operation. Prefix with `undojoin` so the user can undo the join in a single step:
```vim
undojoin | call deletebufline(original_bufnr, 1, '$')
undojoin | call setbufline(original_bufnr, 1, combined_lines)
```

### 10. Sync buffer options from original to temp buffers
`create_buffers` sets `buftype=nofile` but doesn't propagate `tabstop`, `expandtab`, `shiftwidth`, or `wrap` from the original. This causes reflow and display width calculations to use wrong values (especially `tabstop` which affects virtual column math). After buffer creation, sync:
```vim
for opt in ['tabstop', 'shiftwidth', 'expandtab']
    call setbufvar(left_bufnr, '&' . opt, getbufvar(original_bufnr, '&' . opt))
    call setbufvar(right_bufnr, '&' . opt, getbufvar(original_bufnr, '&' . opt))
endfor
```

## Possible Improvements

### Robustness
- Validate `g:cleave_gutter` type and range (reject 0/negative values)
- Guard all text property callers with `has('textprop')`, not just some
- Handle `win_gotoid` failures instead of ignoring return value
- Add `BufWipeout` autocommand to clear `s:cleave_*` state when buffers are killed manually
- Unset `scrollbind` on left/right windows during `CleaveUndo` and `join_buffers` cleanup
- Namespace `prop_type_add` names and clean up prop types on undo

### Code Quality
- Remove remaining debug `echomsg` calls (e.g., "Debug: Loading unloaded buffer" in join_buffers, reflow debug logs)
- Replace `s:get_cleave_buffers` buffer scan with direct lookups from stored `s:cleave_*` bufnrs
- Use `undojoin` before `setbufline`/`deletebufline` sequences to avoid spamming undo history
- Set filetype consistently on both left and right buffers in `create_buffers`
- Sync relevant options (`wrap`, `list`, `tabstop`, `expandtab`) from original buffer to temp buffers

### Reflow
- Preserve intentional leading whitespace/indent during reflow instead of trimming
- Improve paragraph detection to handle list items, code blocks, and indented content
- Make `restore_paragraph_alignment` less dependent on left-context heuristics

### Multibyte (partially addressed in `multibyte_support` branch)
- `split_content` now uses virtual column splitting — verify edge cases with combining characters and zero-width joiners
- Verify window resize formula (`cleave_col - 2 + foldcolumn`) is correct across different multibyte content widths
- Consider performance of `vcol_to_byte` / `virtual_strpart` on very long lines (current implementation is O(n) per call)

### Testing
- Integrate multibyte test suites into the main test runner (`test/test_reflow.vim` or `test/test_reflow_simple.sh`)
- Add integration tests that exercise the full cleave/edit/join round-trip with multibyte content
- Add regression tests for `set_textwidth_to_longest_line` off-by-one (issue: ignores last line)

### debug line
vim -c "set rtp+=." -c "source plugin/cleave.vim" -c "e test/lorem_ipsum.md" -c "colo tuftish" -c "CleaveAtColumn 91" -c "CleaveReflow 65"

