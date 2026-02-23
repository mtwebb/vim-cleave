# Vim9script Conversion Log

## Overview

Converted the vim-cleave plugin from legacy Vimscript to Vim9script on the
`vim9script` branch (branched from `dev`). All three source files were
converted. Tests pass and interactive usage works.

## Files Converted

### 1. `plugin/cleave.vim` (converted prior to this session)
- Added `vim9script` header
- `let g:loaded_cleave = 1` → `g:loaded_cleave = 1`
- All command definitions updated to reference PascalCase autoload functions
  (e.g. `cleave#split_buffer` → `cleave#SplitBuffer`)

### 2. `autoload/cleave/modeline.vim` (converted prior to this session)
- Added `vim9script` header, removed cpo save/restore boilerplate
- Script-local `s:cleave_keys` → `var cleave_keys`
- All public functions converted to `export def` with PascalCase names:
  `cleave#modeline#mode()` → `Mode()`, `parse()` → `Parse()`,
  `apply()` → `Apply()`, `infer()` → `Infer()`, `ensure()` → `Ensure()`,
  `build_string()` → `BuildString()`
- Script-local helpers converted to `def` with PascalCase names

### 3. `autoload/cleave.vim` (~1989 lines, converted in this session)
- Added `vim9script` header, removed cpo save/restore boilerplate
- 30 public functions converted to `export def` with PascalCase names
- 15 script-local helpers converted to `def` with PascalCase names
- Full function name mapping listed below

### 4. `test/test_reflow.vim` (updated in this session)
- Updated all `cleave#snake_case()` calls to `cleave#PascalCase()`:
  - `cleave#undo_cleave` → `cleave#UndoCleave`
  - `cleave#set_text_properties` → `cleave#SetTextProperties`
  - `cleave#shift_paragraph` → `cleave#ShiftParagraph`
- Test file itself remains legacy Vimscript (tests are standalone)

## Conversion Rules Applied

| Legacy Vimscript | Vim9script |
|---|---|
| `function! cleave#name()` | `export def Name()` |
| `function! s:name()` | `def Name()` |
| `endfunction` | `enddef` |
| `let var = val` (first) | `var x = val` |
| `let var = val` (reassign) | `x = val` |
| `let &option = val` | `&option = val` |
| `call func()` | `func()` |
| `a:param` | `param` |
| `" comment` | `# comment` |
| `v:true` / `v:false` | `true` / `false` |
| `v:null` | `null` |
| String concat `.` | `..` |
| String append `.=` | `..=` |
| `a:0` (vararg count) | `len(args)` |
| `a:1`, `a:2` | `args[0]`, `args[1]` |
| `function! f(x, ...)` | `def F(x: type, ...args: list<any>)` |
| `map(copy(l), 'v:val.x')` | `mapnew(l, (_, v) => v.x)` |
| `type(x) == type({})` | `type(x) == v:t_dict` |
| `type(x) == type('')` | `type(x) == v:t_string` |
| `type(x) == type(0)` | `type(x) == v:t_number` |
| `if c \| cmd \| endif` | Split to 3 lines |
| `list[:2]` | `list[: 2]` (spaces required) |
| `list[3:]` | `list[3 :]` (spaces required) |

Items that stayed unchanged: `execute`, `setlocal`, `set`, `wincmd`, `vsplit`,
`close`, `syncbind`, `redraw!`, `try/catch/finally/endtry`, `g:` globals,
`&option` references, all builtin functions, dictionary literals, `\` line
continuation.

## Exported Function Name Mapping

| Legacy (`cleave#`) | Vim9script (`export def`) |
|---|---|
| `split_buffer` | `SplitBuffer` |
| `split_at_colorcolumn` | `SplitAtColorcolumn` |
| `toggle_reflow_mode` | `ToggleReflowMode` |
| `vcol_to_byte` | `VcolToByte` |
| `byte_to_vcol` | `ByteToVcol` |
| `virtual_strpart` | `VirtualStrpart` |
| `split_content` | `SplitContent` |
| `create_buffers` | `CreateBuffers` |
| `setup_windows` | `SetupWindows` |
| `recleave_last` | `RecleaveLast` |
| `undo_cleave` | `UndoCleave` |
| `join_buffers` | `JoinBuffers` |
| `reflow_buffer` | `ReflowBuffer` |
| `reflow_right_buffer` | `ReflowRightBuffer` |
| `reflow_left_buffer` | `ReflowLeftBuffer` |
| `reflow_text` | `ReflowText` |
| `wrap_paragraph` | `WrapParagraph` |
| `set_textwidth_to_longest_line` | `SetTexwidthToLongestLine` |
| `get_right_buffer_paragraph_lines` | `GetRightBufferParagraphLines` |
| `get_left_buffer_paragraph_lines` | `GetLeftBufferParagraphLines` |
| `toggle_paragraph_highlight` | `ToggleParagraphHighlight` |
| `place_right_paragraphs_at_lines` | `PlaceRightParagraphsAtLines` |
| `align_right_to_left_paragraphs` | `AlignRightToLeftParagraphs` |
| `shift_paragraph` | `ShiftParagraph` |
| `restore_paragraph_alignment` | `RestoreParagraphAlignment` |
| `sync_right_paragraphs` | `SyncRightParagraphs` |
| `sync_left_paragraphs` | `SyncLeftParagraphs` |
| `set_text_properties` | `SetTextProperties` |
| `on_text_changed` | `OnTextChanged` |
| `debug_paragraphs` | `DebugParagraphs` |

## Script-Local Function Name Mapping

| Legacy (`s:`) | Vim9script (`def`) |
|---|---|
| `is_inline_fence` | `IsInlineFence` |
| `is_para_start` | `IsParaStart` |
| `para_starts` | `ParaStarts` |
| `extract_paragraphs` | `ExtractParagraphs` |
| `build_paragraph_placement` | `BuildParagraphPlacement` |
| `replace_buffer_lines` | `ReplaceBufferLines` |
| `pad_buffer_lines` | `PadBufferLines` |
| `equalize_buffer_lengths` | `EqualizeBufferLengths` |
| `teardown_cleave` | `TeardownCleave` |
| `resolve_buffers` | `ResolveBuffers` |
| `apply_modeline_to_buffer` | `ApplyModelineToBuffer` |
| `split_buffer_at_col` | `SplitBufferAtCol` |
| `normalize_reflow_mode` | `NormalizeReflowMode` |
| `current_reflow_mode` | `CurrentReflowMode` |
| `default_reflow_options` | `DefaultReflowOptions` |
| `resolve_reflow_options` | `ResolveReflowOptions` |
| `with_default_reflow_options` | `WithDefaultReflowOptions` |
| `capture_paragraph_anchors` | `CaptureAnchors` |
| `locate_anchors_after_reflow` | `LocateAnchorsAfterReflow` |
| `apply_post_reflow_ui` | `ApplyPostReflowUi` |
| `extract_indent_and_hanging` | `ExtractIndentAndHanging` |
| `normalize_wrapping_text` | `NormalizeWrappingText` |
| `hyphenate_word` | `HyphenateWord` |
| `justify_line` | `JustifyLine` |
| `justify_lines` | `JustifyLines` |

## Issues Found During Conversion

1. **Slice syntax spacing** — `stripped[:2]` and `stripped[3:]` caused
   `E1004: White space required before and after ':'`. Fixed to
   `stripped[: 2]` and `stripped[3 :]`.

2. **Duplicate functions from parallel conversion** — Two sub-agents
   independently converted `RecleaveLast` and `SetTexwidthToLongestLine`,
   producing duplicate definitions. Resolved by removing the extras.

3. **Timing instrumentation dropped** — `SplitBufferAtCol` had
   `if timing | let t0 = reltime() | endif` patterns throughout. The
   single-line `if` conversion step removed them entirely. Restored with
   proper multi-line `if`/`endif` blocks and `var t_total: any` / `var t0: any`
   declarations at function scope (vim9script block-scopes `var` declarations).

4. **Byte-level fast path dropped** — `SplitContent` had an optimization
   checking `strdisplaywidth(line) == len(line)` to use `strpart()` for
   ASCII-only lines. The conversion simplified it to always use
   `VirtualStrpart()`. Restored the original optimization.

5. **Missing global** — `g:cleave_debug_timing` declaration was omitted
   from the globals section. Added back.

## Verification

- `defcompile` passes cleanly on Vim 9.1
- `test/test_reflow.vim` — all tests pass
- `test/test_reflow_simple.sh` — passes
- Manual test: `CleaveAtColumn 91` + `CleaveReflow 65` on lorem_ipsum.md works
