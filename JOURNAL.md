# Development Journal

## 2026-02-21: CleaveAlign refactor and text property maintenance

### Problem

CleaveAlign was using context-aware paragraph detection, which assumes
right-buffer line N corresponds to left-buffer line N. When a right
paragraph was shifted above its left-buffer anchor, context-aware
detection falsely split the paragraph at left-buffer paragraph
boundaries, inserting blank lines mid-paragraph.

A secondary issue: deleting a right-buffer paragraph left orphaned text
properties on the left buffer with no way to clean them up, since
`InsertLeave` doesn't fire for normal-mode deletions like `dd`.

### Changes

**Refactor CleaveAlign** (`a7520f5`)
- Switched from context-aware to simple paragraph detection
- Added validation: exit with message if text property count < paragraph count
- Added right-buffer padding, text property update, cursor restore, and `syncbind`

**Remove context-aware detection entirely** (`a0c29d7`)
- Deleted `s:is_para_start_ctx`, `s:para_starts_ctx`, `s:extract_paragraphs_ctx`
- All callers (`reflow_left_buffer`, `place_right_paragraphs_at_lines`,
  `sync_right_paragraphs`, `set_text_properties`) now use simple detection
- Simplified `sync_right_paragraphs` to just pad + update text properties
- Removed ~100 lines of code
- Updated SPEC.md throughout

**Add CleaveDebug command** (`21de485`, `696c479`, `08bcc39`)
- New `:CleaveDebug` command prints left text properties and right paragraph starts
- Two display modes: interleaved (default) and sequential
- Column-aligned output with right-side truncation for narrow terminals

**Auto-remove orphaned text properties** (`94eaf6d`)
- Added `TextChanged` autocmd on right buffer calling `cleave#on_right_text_changed()`
- Stores `b:cleave_para_count` in `set_text_properties` for change detection
- On paragraph count decrease: walks text properties, removes those without
  matching right paragraph starts, then calls `CleaveAlign`
- Updated SPEC.md with `TextChanged` behavior

### Tests added

New test file `test/test_align_and_props.vim` with 20 assertions covering:
- `CleaveSetProps`: basic property placement, zero-length props on empty left lines
- `CleaveAlign`: basic repositioning, shifted-above-anchor (the fixed bug),
  overlap slide-down, right-buffer padding
- `TextChanged`: orphaned property removal on paragraph deletion, no-op when unchanged
- `sync_left_paragraphs`: right paragraphs reposition after left-buffer edits
- `sync_right_paragraphs`: padding and property maintenance
