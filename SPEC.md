# vim-cleave Behavior Specification

## Core Concepts

### Buffers

- **Original buffer**: The file the user was editing before cleaving. Hidden while cleave is active.
- **Left buffer** (`{name}.left`): Contains text from column 1 to the cleave column. This is the "main content" buffer. Retains the original file's syntax highlighting. Has `buftype=nofile`.
- **Right buffer** (`{name}.right`): Contains text from the cleave column onward. This is the "margin notes" buffer. Has `filetype=right` (gray appearance via `ftplugin/right.vim`). Has `buftype=nofile`.

### Paragraphs

A **paragraph** is a contiguous block of non-empty lines.

- **Simple detection**: A paragraph starts at a non-empty line that is either line 1 or follows an empty line. Used for all paragraph detection in both buffers.

### Text Anchors (Text Properties)

Text properties of type `cleave_paragraph_start` are placed in the **left buffer** to mark where each right-buffer paragraph is anchored. The anchor is on the first word of the left-buffer line that corresponds to the right-buffer paragraph's start line. These are visual indicators and are also used by `CleaveAlign` to determine target positions.

### Scrollbind

Both windows are `scrollbind`-ed so they scroll as a single document. Scrollbind must be preserved across all operations and restored via `syncbind` after any operation that modifies buffer content or switches windows.

### Invariants (must hold after every command)

1. Both windows have `scrollbind` set.
2. Right buffer has at least as many lines as the left buffer (padded with empty lines).
3. Cursor position and window are restored to where the user was before the command (unless the command's purpose is to move the cursor, e.g., `CleaveShiftParagraph*`).
4. `syncbind` is called after any content modification to re-synchronize scroll positions.
5. Text properties are updated to reflect current paragraph positions after any command that changes paragraph positions.

---

## Commands

### CleaveAtCursor / CleaveAtColumn / CleaveAtColorColumn

**Purpose**: Split the original buffer into left and right buffers at a column.

**Preconditions**: Original buffer must be saved (no unsaved changes).

**Behavior**:
1. Read modeline settings from the original buffer (if `g:cleave_modeline != 'ignore'`).
2. Determine cleave column from argument, cursor position, or colorcolumn.
3. Split each line of the original buffer at the cleave column into left and right parts.
4. Create left buffer: set `buftype=nofile`, copy `foldcolumn` from original, set `textwidth` to longest line.
5. Create right buffer: set `buftype=nofile`, `filetype=right`, `foldcolumn=0`, set `textwidth` to longest line.
6. Equalize buffer lengths (pad shorter buffer).
7. Register `InsertLeave` autocmds for both buffers.
8. Register `BufWinEnter` autocmds to re-enforce `scrollbind`.
9. Create vertical split: left buffer on left, right buffer on right.
10. Set `scrollbind` on both windows.
11. Set initial text properties.
12. Store cleave state (`b:cleave`) on each buffer linking to original, peer, side, and column.
13. Store `b:cleave_col_last` on original buffer for `CleaveAgain`.

**Left buffer effects**: Created and displayed in left window.
**Right buffer effects**: Created and displayed in right window.
**Cursor**: Positioned at the original cursor position in the left window. Focus is on the left window.

---

### CleaveAgain

**Purpose**: Re-cleave the current buffer at the previously used cleave column.

**Preconditions**: `b:cleave_col_last` must exist on the current buffer (set by a prior cleave).

**Behavior**: Calls the same split logic as `CleaveAtColumn` using the stored column.

**Effects**: Same as `CleaveAtCursor`.

---

### CleaveUndo

**Purpose**: Discard all changes and restore the original buffer.

**Behavior**:
1. Clear `CleaveScrollBind` autocmds.
2. Switch left window to show the original buffer, unset `scrollbind`.
3. Close the right window.
4. Delete both temporary buffers.
5. Focus the original buffer.

**Left buffer effects**: Deleted.
**Right buffer effects**: Deleted.
**Original buffer**: Restored unchanged.

---

### CleaveJoin

**Purpose**: Merge left and right buffers back into the original buffer, preserving edits.

**Behavior**:
1. For each line, combine: `left_line + padding + right_line` where padding fills to the cleave column.
2. Replace original buffer content with combined lines (with undo history).
3. Restore `textwidth` and `foldcolumn` from left buffer to original.
4. Write modeline if `g:cleave_modeline == 'update'`.
5. Tear down: clear autocmds, close right window, delete temp buffers.
6. Apply window-local settings (colorcolumn, foldcolumn, virtualedit) to original.

**Left buffer effects**: Deleted.
**Right buffer effects**: Deleted.
**Original buffer**: Updated with merged content.
**Cursor**: In the original buffer window.

---

### CleaveReflow \<width\> [mode]

**Purpose**: Reflow text in the current buffer to a new width, preserving paragraph alignment between buffers.

**Preconditions**: Must be in a cleave buffer. Width >= 10.

#### When run from the LEFT buffer:

**Behavior**:
1. Detect right-buffer paragraph starts (simple detection).
2. Capture anchor words: for each right-buffer paragraph start position, find the first word of the corresponding left-buffer line. These anchor words identify which left-buffer paragraph each right-buffer paragraph is associated with.
3. Reflow left buffer text to new width (wrap paragraphs, preserve headings and fenced code blocks).
4. Replace left buffer content.
5. Locate anchors in the reflowed left buffer: search for each anchor word to find where it moved.
6. Reposition right-buffer paragraphs to the new anchor positions (via `restore_paragraph_alignment`).
7. Update cleave column: `new_width + g:cleave_gutter + 1`.
8. Resize left window to new width.
9. Set left buffer `textwidth`.
10. Equalize buffer lengths.
11. Update text properties.

**Left buffer effects**: Content reflowed to new width. Window resized.
**Right buffer effects**: Paragraphs repositioned to stay aligned with their left-buffer anchors. Content is NOT reflowed.
**Cursor**: Restored to pre-reflow position. `syncbind` called.

#### When run from the RIGHT buffer:

**Behavior**:
1. Extract paragraphs with their current positions (simple detection — right buffer is the active buffer).
2. Reflow each paragraph to new width (preserve headings and fenced code blocks).
3. Reconstruct buffer: place each reflowed paragraph at its original start position if it fits; if it would overlap the next paragraph, slide it down with a blank separator.
4. Replace right buffer content.
5. Equalize buffer lengths.
6. Set right buffer `textwidth`.

**Left buffer effects**: NONE. No changes to left buffer content, window size, text properties, or anchors.
**Right buffer effects**: Paragraphs reflowed to new width in-place.
**Cursor**: Restored to pre-reflow position. `syncbind` called.

---

### CleaveAlign

**Purpose**: Reposition right-buffer paragraphs to align with left-buffer anchor positions.

**Behavior**:
1. Read text property positions from the left buffer (`cleave_paragraph_start` props).
2. If no properties exist, or there are fewer properties than paragraphs in right buffer, exit with message detailing issue.  
3. Extract right-buffer paragraphs using simple detection.
4. Place each paragraph at the corresponding text property line number.
5. If a paragraph would overlap a previous one, slide it down.
6. Equalize buffer lengths.
7. Update text properties to reflect final paragraph positions in the case where paragraphs were shifted.

**Left buffer effects**: Text properties updated.
**Right buffer effects**: Paragraphs repositioned to match left-buffer anchor lines.
**Cursor**: Restored to pre-command position. `syncbind` called.

---

### CleaveShiftParagraphUp / CleaveShiftParagraphDown

**Purpose**: Move the paragraph under the cursor up or down by one line.

**Preconditions**: Must be on a paragraph. The adjacent line in the shift direction must be blank. The line beyond that must also be blank or absent (to prevent merging paragraphs).

**Behavior**:
1. Find the paragraph containing the cursor.
2. For shift up: delete the blank line above the paragraph, append a blank line after it.
3. For shift down: delete the blank line below the paragraph, insert a blank line before it.
4. If in right buffer: update text properties to reflect the new intentional position.
5. Move cursor by one line in the shift direction.

**Left buffer effects**: If run from left buffer, the paragraph moves. Text properties are NOT updated.
**Right buffer effects**: If run from right buffer, the paragraph moves and text properties are updated to the new position.
**Cursor**: Moves with the paragraph (cursor line ± 1).

---

### CleaveSetProps

**Purpose**: Create/update text properties marking right-buffer paragraph anchors in the left buffer.

**Behavior**:
1. Detect right-buffer paragraph starts (simple detection).
2. Clear all existing `cleave_paragraph_start` properties from the left buffer.
3. For each paragraph start line: if the corresponding left-buffer line has text, add a text property on its first word. If the left-buffer line is empty, add a zero-length property.

**Left buffer effects**: Text properties updated.
**Right buffer effects**: NONE.
**Cursor**: Unchanged.

---

### CleaveToggleTextAnchorVis

**Purpose**: Toggle highlight of text anchor properties between visible (`MatchParen`) and invisible (`Normal`).

**Behavior**: Changes the highlight group of the `cleave_paragraph_start` property type.

**Left buffer effects**: Visual change only.
**Right buffer effects**: NONE.

---

### CleaveJustifyToggle

**Purpose**: Toggle the buffer's reflow mode between `ragged` and `justify`.

**Behavior**: Sets `b:cleave_reflow_mode` on the current buffer. Does NOT reflow — just changes the mode for the next `CleaveReflow`.

**Effects**: None beyond setting the variable.

---

### CleaveJump

**Purpose**: Jump to the same line in the peer buffer.

**Preconditions**: Must be in a cleave buffer with a visible peer window.

**Behavior**:
1. Read `b:cleave` from the current buffer to find the peer buffer.
2. Find the peer buffer's window.
3. Move cursor to the peer window at the same line number (clamped to peer buffer length).

**Left buffer effects**: NONE.
**Right buffer effects**: NONE.
**Cursor**: Moves to the peer window at the same line.

---

### CleaveDebug

**Purpose**: Print left-buffer text properties and right-buffer paragraph starts for debugging.

**Behavior**:
1. List all `cleave_paragraph_start` text properties from the left buffer: line number, column, length, and anchor word.
2. List all right-buffer paragraph starts (simple detection): line number and a preview of the first line (truncated to 50 chars).

**Effects**: None. Output via `echomsg` (viewable with `:messages`).

two display options: sequential or interleaved.
example sequential:
--- Left text properties ---
  line   3  col  1  len  6  anchor: Sapien
  line  12  col  1  len  9  anchor: imperdiet
  line  33  col  1  len  4  anchor: diam
  line  42  col  6  len  6  anchor: Sapien
  line 121  col  1  len  6  anchor: Tempus
--- Right paragraph starts ---
  line   3: In metus vulputate eu scelerisque felis
  line  12: Ultricies integer quis auctor elit sed
  line  34: Add a new note
  line  43: In fermentum posuere urna nec tincidunt.
  line 122: Turpis egestas pretium.

Same Example Interleaved:
     --- Left text properties ---                   --- Right paragraph starts ---
line   3:  col  1  len  6  anchor: Sapien      In metus vulputate eu scelerisque felis
line  12:  col  1  len  9  anchor: imperdiet   Ultricies integer quis auctor elit sed
line  33:  col  1  len  4  anchor: diam
line  34:                                      Add a new note
line  42:  col  6  len  6  anchor: Sapien
line  43:                                      In fermentum posuere urna nec tincidunt.
line 121:  col  1  len  6  anchor: Tempus
line 122:                                      Turpis egestas pretium.

For interleave. truncate right buffer line if it does not fit (use elipsis to indicate)
---

## Autocmd Behaviors

### InsertLeave on RIGHT buffer → `cleave#SyncRightParagraphs()`

**Purpose**: Update padding and text properties after the user edits the right buffer.

**Behavior**:
1. Equalize buffer lengths.
2. Update text properties.

**Cursor**: Restored. `syncbind` called.

### InsertLeave on LEFT buffer → `cleave#SyncLeftParagraphs()`

**Purpose**: Reposition right-buffer paragraphs to stay aligned after the user edits the left buffer.

**Behavior**:
1. Read text property positions from the left buffer.
2. Place right-buffer paragraphs at those positions.
3. Equalize buffer lengths.
4. Update text properties.

**Cursor**: Restored. `syncbind` called.

### TextChanged on LEFT or RIGHT buffer → `cleave#OnTextChanged()`

**Purpose**: Reconcile text properties in the left buffer with right-buffer paragraphs after any normal-mode edit in either buffer (e.g., `dd`, `u`, `p`), then re-align.

**Behavior**:
1. Get current text property positions from the left buffer and current right-buffer paragraph starts (simple detection).
2. Build an interleaved set of lines that have a text property, a right paragraph start, or both.
3. Walk the interleaved list from the top:
   a. If line has both a text property and a right paragraph start: leave text property.
   b. If line has a text property but NO right paragraph start, AND text property count > right paragraph count: REMOVE that text property and decrement text property count.
   c. If line has NO text property but a right paragraph start, AND text property count < right paragraph count: ADD a text property on that line and increment text property count.
   d. Once text property count matches right paragraph count, stop.
4. Call CleaveAlign.
5. Update stored counts (`b:cleave_para_count`, `b:cleave_prop_count`).


### BufWinEnter on either buffer

**Purpose**: Re-enforce `scrollbind` in case it was lost.

**Behavior**: `setlocal scrollbind`.

---

## Internal Helper Contracts

### `ReplaceBufferLines(bufnr, lines)`

Replaces all buffer content. Removes excess trailing lines.

### `EqualizeBufferLengths(left_bufnr, right_bufnr)`

Compares the line counts of both buffers and pads the shorter one with blank lines so they are the same length. Saves and restores cursor position.

### `BuildParagraphPlacement(paragraphs, target_line_numbers)`

Places paragraphs at target line numbers. If a paragraph's target is before the current position (would overlap), it is placed at the current position instead. A blank separator is added between paragraphs.

### `CaptureAnchors(left_lines, para_starts)`

For each paragraph start position, finds the first word of the corresponding left-buffer line to use as an anchor. Falls back to searching nearby lines if the exact line is empty.

### `LocateAnchorsAfterReflow(buffer_lines, anchors)`

Searches the (reflowed) buffer for each anchor word to find where it moved. Searches forward from the last found position. Skips fenced code blocks. Used only after left-buffer reflow.

---

## Configuration

| Variable | Default | Description |
|---|---|---|
| `g:cleave_gutter` | `3` | Spaces between left/right content in joined buffer |
| `g:cleave_reflow_mode` | `'ragged'` | Default reflow mode (`ragged` or `justify`) |
| `g:cleave_hyphenate` | `1` | Enable hyphenation for long words during reflow |
| `g:cleave_dehyphenate` | `1` | Rejoin hyphenated words before reflow |
| `g:cleave_hyphen_min_length` | `8` | Minimum word length for hyphenation |
| `g:cleave_justify_last_line` | `0` | Justify the last line of justified paragraphs |
| `g:cleave_modeline` | `'read'` | Modeline mode: `read`, `update`, or `ignore` |
| `g:cleave_debug_timing` | `0` | When enabled, logs `reltime` measurements for each step of `CleaveAtCursor`/`CleaveAtColumn` via `echomsg` (viewable with `:messages`) |
