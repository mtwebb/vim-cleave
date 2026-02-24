# vim-cleave
<p align="center">
  <img src="doc/screenshot.webp" alt="Example session" width="800">
</p>
Vim-cleave is a plugin that splits a buffer's content vertically at a specified column, creating separate left and right buffers while maintaining spatial positioning. It was developed as a way to bring the wonder of margin notes to plain text files. 

## Features

- **Buffer Splitting**: Split any buffer vertically at a specified column or use cursor position
- **Text Reflow**: Reflow text in either buffer while maintaining paragraph alignment, so can change the layout of of each column based on the screen real estate you have. 
- **Spatial Preservation**: Maintains cursor position and scroll synchronization.  Even when split, acts like a single document. 
- **Paragraph Alignment**: Intelligently preserves paragraph boundaries during reflow so if you change the main text the margin notes will stay aligned with the content they were added next to. 

Quick demo:
<a href="https://asciinema.org/a/IIWD2CA3ZwNII12hTd5U3v7u1" target="_blank"><img src="https://asciinema.org/a/IIWD2CA3ZwNII12hTd5U3v7u1.svg" /></a>

## Installation

### Manual Installation

```bash
mkdir -p ~/.vim/pack/plugins/start
cd ~/.vim/pack/plugins/start
git clone https://github.com/mtwebb/vim-cleave.git
```

### vim-plug

```vim
Plug 'mtwebb/vim-cleave'
```

### Vundle

```vim
Plugin 'mtwebb/vim-cleave'
```

## Usage

### Basic Workflow

1. Open a file with content you want to split
2. Position cursor at desired split column
3. Run `:CleaveAtCursor` to create left and right buffers
4. Edit either buffer independently
5. Use `:CleaveReflow <width>` to reflow text while preserving alignment
6. Use `:CleaveJoin` to merge back to original format
7. Use `:CleaveUndo` to restore original buffer

### Commands

#### `:CleaveAtCursor`
Splits the current buffer at the cursor position. Creates two new buffers:
- Left buffer: content from start of each line to cursor column
- Right buffer: content from cursor column to end of each line

#### `:CleaveAtColumn <column>`
Splits the current buffer at the specified column number.

**Example:**
```vim
:CleaveAtColumn 80
```

#### `:CleaveAtColorColumn`
Splits the current buffer at the first `colorcolumn` value. Requires `colorcolumn` to be set.

**Example:**
```vim
:set colorcolumn=80
:CleaveAtColorColumn
```

#### `:CleaveUndo`
Restores the original buffer and closes the cleaved windows. This discards any changes made to the split buffers.

#### `:CleaveJoin`
Merges the left and right buffers back into the original buffer, maintaining proper alignment and spacing between the content. Changes are preserved.

#### `:CleaveReflow <width> [mode]`
Reflows the text in the current buffer (left or right) to the specified width.
Optional mode values: `ragged` (default) or `justify`.

**Key features:**
- Automatically detects which cleaved buffer has focus
- Preserves paragraph alignment between buffers
- Maintains correspondence between left and right content
- Updates window sizing when reflowing the left buffer
- Minimum width: 10 characters

**Example:**
```vim
:CleaveReflow 60
:CleaveReflow 60 justify
```

#### `:CleaveJustifyToggle`
Toggles the active buffer's reflow mode between `ragged` and `justify`.

#### `:CleaveAlign`
Repositions right-buffer paragraphs to match left-buffer text property anchors. Useful when paragraph alignment has been disrupted.

**Key features:**
- Reads text property positions from the left buffer
- Validates property count matches paragraph count
- Extracts right-buffer paragraphs using simple detection
- Slides overlapping paragraphs down with blank separators
- Pads right buffer, updates text properties, restores cursor, calls `syncbind`

**Example:**
```vim
:CleaveAlign
```

#### `:CleaveAgain`
Re-cleaves the current buffer at the most recently used cleave column. The
column is stored when `:CleaveAtCursor` or `:CleaveAtColumn` is used, and the
command works even if the current buffer has unsaved changes.

**Example:**
```vim
:CleaveAgain
```

#### `:CleaveShiftParagraphUp` / `:CleaveShiftParagraphDown`
Moves the current paragraph up or down by one line in the active buffer and updates the left-side anchor markers. Movement stops if it would remove the single blank line between paragraphs.

#### `:CleaveSetProps`
Creates or updates text properties that mark paragraph start positions in the left buffer. Called automatically by other commands; manual use is rarely needed.

#### `:CleaveToggleTextAnchorVis`
Toggles the visual highlighting of paragraph anchor text properties between visible and invisible states. Useful for debugging paragraph alignment.

#### `:CleaveJump`
Jumps the cursor to the same line in the peer buffer (left → right or right → left). Useful for quickly switching context between main text and margin notes without losing your place.

#### `:CleaveDebug [mode]`
Prints left-buffer text properties and right-buffer paragraph starts for debugging. Output via `:messages`.

- `:CleaveDebug` — interleaved side-by-side view (default)
- `:CleaveDebug sequential` — two separate lists

### Options

#### `g:cleave_gutter`
Sets the number of spaces between the left and right content when joining buffers. This affects the spacing calculation during `:CleaveJoin` operations.

**Default:** `3`

**Example:**
```vim
g:cleave_gutter = 5
```

#### `g:cleave_reflow_mode`
Default reflow mode for `:CleaveReflow` (`ragged` or `justify`).

**Default:** `ragged`

```vim
g:cleave_reflow_mode = 'justify'
```

#### `g:cleave_hyphenate`
Enable heuristic hyphenation for words longer than the target width.

**Default:** `1`

#### `g:cleave_dehyphenate`
Join end-of-line hyphenations before wrapping.

**Default:** `1`

#### `g:cleave_hyphen_min_length`
Minimum word length eligible for hyphenation.

**Default:** `8`

#### `g:cleave_justify_last_line`
Justify the final line of each paragraph when enabled.

**Default:** `0`

#### `g:cleave_modeline`
Controls how vim-cleave interacts with modelines in files. Modelines allow cleave settings to be embedded directly in a file for repeatable sessions.

**Values:**
- `read` — Read modeline on cleave start but never write it back (default)
- `update` — Read modeline on cleave start AND write it back on `:CleaveJoin`
- `ignore` — Skip modeline processing entirely

**Default:** `read`

**Example:**
```vim
g:cleave_modeline = 'update'
```

### Keybinding Suggestions

Fast paragraph shifting with Meta (Alt) keys:

```vim
nnoremap <M-k> :CleaveShiftParagraphUp<CR>
nnoremap <M-j> :CleaveShiftParagraphDown<CR>
```

If your terminal does not pass Meta, these bracket mappings are easy to repeat:

```vim
nnoremap [p :CleaveShiftParagraphUp<CR>
nnoremap ]p :CleaveShiftParagraphDown<CR>
```

Jump to the same line in the other buffer with Tab:

```vim
nnoremap <Tab> :CleaveJump<CR>
```

## Use Cases

- **Documentation Editing**: Split documentation with comments/annotations
- **Code Review**: Compare code side-by-side with notes
- **Diff Editing**: Work with unified diff files
- **Formatted Text**: Edit text with specific column layouts
- **Data Files**: Work with fixed-width data formats

## Requirements

- Vim 9.0 or higher (vim9script)
- Text properties support (for advanced paragraph alignment features)

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

This project is licensed under the MIT License.
