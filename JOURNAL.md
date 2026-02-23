# Development Journal

## 2026-02-22: Unified TextChanged handler for both buffers

### Problem

The `TextChanged` autocmd only fired on the right buffer. Normal-mode
edits in the left buffer (e.g., `dd`, `u`, `p`) could delete or shift
text properties with no handler to reconcile them, leaving right-buffer
paragraphs misaligned. A secondary issue: `SetTextProperties()` silently
skipped props when right paragraphs extended beyond the left buffer's
line count, causing prop/paragraph count mismatches.

### Changes

**Unify TextChanged handler** (`2598ec7`)
- Replaced `cleave#OnRightTextChanged()` with `cleave#OnTextChanged()`
- Registered `TextChanged` autocmd on both left and right buffers
- New reconciliation logic: builds an interleaved set of text property
  lines and right paragraph start lines, walks from top to remove
  orphaned props or add missing ones until counts match, then calls
  `CleaveAlign`
- Stores `b:cleave_prop_count` on the left buffer for change detection
- Updated SPEC.md: merged left/right `TextChanged` sections into one
  unified spec

**Fix SetTextProperties left-buffer padding** (`dd38eeb`)
- `SetTextProperties()` now pads the left buffer with empty lines when
  right paragraphs extend beyond it, ensuring props can always be placed
- `OnTextChanged()` clamps target line to left buffer length when
  adding missing props for paragraphs beyond the left buffer
- Updated `doc/cleave.txt` auto-sync section for the unified handler

### Tests updated

- Updated `TestTextChangedParaDeletion` and `TestTextChangedNoChange` to
  call `cleave#OnTextChanged()` instead of `cleave#OnRightTextChanged()`
- Added `TestTextChangedLeftPropDeleted`: deletes a left-buffer paragraph,
  verifies the handler adds a new prop for the orphaned right paragraph
  and maintains all 3 right-buffer paragraphs

---

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
- Deleted `IsParaStartCtx`, `ParaStartsCtx`, `ExtractParagraphsCtx`
- All callers (`ReflowLeftBuffer`, `PlaceRightParagraphsAtLines`,
  `SyncRightParagraphs`, `SetTextProperties`) now use simple detection
- Simplified `SyncRightParagraphs` to just pad + update text properties
- Removed ~100 lines of code
- Updated SPEC.md throughout

**Add CleaveDebug command** (`21de485`, `696c479`, `08bcc39`)
- New `:CleaveDebug` command prints left text properties and right paragraph starts
- Two display modes: interleaved (default) and sequential
- Column-aligned output with right-side truncation for narrow terminals

**Auto-remove orphaned text properties** (`94eaf6d`)
- Added `TextChanged` autocmd on right buffer calling `cleave#OnRightTextChanged()`
- Stores `b:cleave_para_count` in `SetTextProperties` for change detection
- On paragraph count decrease: walks text properties, removes those without
  matching right paragraph starts, then calls `CleaveAlign`
- Updated SPEC.md with `TextChanged` behavior

### Tests added

New test file `test/test_align_and_props.vim` with 20 assertions covering:
- `CleaveSetProps`: basic property placement, zero-length props on empty left lines
- `CleaveAlign`: basic repositioning, shifted-above-anchor (the fixed bug),
  overlap slide-down, right-buffer padding
- `TextChanged`: orphaned property removal on paragraph deletion, no-op when unchanged
- `SyncLeftParagraphs`: right paragraphs reposition after left-buffer edits
- `SyncRightParagraphs`: padding and property maintenance
