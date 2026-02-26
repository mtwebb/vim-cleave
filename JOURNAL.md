# Development Journal

## 2026-02-25: Simplify unnecessarily complicated logic

### Changes

**Simplify `ToggleParagraphHighlight` redraw** (`autoload/cleave.vim`)
- Removed per-window cursor-moving hack (`\<C-L>` in each window + window
  hopping) used to refresh text property highlights after `prop_type_change()`
- Replaced with a single `redraw!` — achieves the same visual result with
  ~30 fewer lines

**Simplify `TeardownCleave`** (`autoload/cleave.vim`)
- Both `if`/`else` branches contained identical `execute 'buffer' original_bufnr`;
  moved it after the conditional
- Removed redundant final `win_gotoid(left_win_id)` — already navigated there
  at the top of the function

**Delegate `RestoreParagraphAlignment` to `BuildParagraphPlacement`**
(`autoload/cleave.vim`)
- The function manually reimplemented paragraph placement logic (blank-line
  padding, line-by-line buffer construction) that `BuildParagraphPlacement`
  already provides
- Replaced ~25 lines with a 2-line delegation to `BuildParagraphPlacement`

**Simplify `WithDefaultReflowOptions`** (`autoload/cleave.vim`)
- Removed `extend(defaults, options, 'force')` call that was immediately
  overwritten by individual field assignments, making it a no-op
- Now builds and returns the options dict directly

### Validation

- `bash test/test_reflow_simple.sh`
- `vim -u NONE -es -c "source test/test_reflow.vim" -c "call RunReflowTests()" -c "qa!"`

All commands above passed.

## 2026-02-24: Added fuzz suites for split/join, paragraph ops, and modelines

### Problem

`CleaveReflow` had property-based fuzzing, but other stateful commands with
complex invariants (`Split/Join`, paragraph shifting/alignment, and modeline
flow) still relied mostly on deterministic unit/integration tests.

### Changes

**New split/join fuzz suite**
- Added `test/fuzz/split_join_fuzz.vim`
- Added runner `test/test_split_join_fuzz.sh`
- Invariants:
  - split output consistency
  - `CleaveUndo` restores original buffer text
  - `CleaveJoin` round-trip preserves content
  - repeated `CleaveAgain` + `CleaveJoin` does not drift

**New paragraph operations fuzz suite**
- Added `test/fuzz/paragraph_ops_fuzz.vim`
- Added runner `test/test_paragraph_ops_fuzz.sh`
- Invariants under random `ShiftParagraph`/`Align` sequences:
  - paragraph signatures remain unchanged on left and right
  - left anchors and right paragraph starts stay in sync
  - `CleaveUndo` restores original content

**New modeline fuzz suite**
- Added `test/fuzz/modeline_fuzz.vim`
- Added runner `test/test_modeline_fuzz.sh`
- Invariants:
  - BuildString/Parse consistency for cleave settings
  - non-cleave modeline options are preserved
  - split honors modeline-driven cleave column/gutter
  - join in update mode keeps modeline parseable and stable

**Documentation updates**
- Expanded `README.md` testing section with the three new fuzz commands.

### Validation

- `test/test_split_join_fuzz.sh --seed 1111 --iterations 200`
- `test/test_paragraph_ops_fuzz.sh --seed 2222 --iterations 200`
- `test/test_modeline_fuzz.sh --seed 3333 --iterations 200`
- `test/test_reflow_fuzz.sh --seed 4444 --iterations 100`
- `vim -u NONE -es -c "source test/test_reflow.vim" -c "call RunReflowTests()" -c "qa!"`

All commands above passed.

## 2026-02-24: Reduced fuzz regression + right reflow separator fix

### Problem

After adding the fuzz harness, long-seed runs produced reproducible
`reason=paragraph` failures in right-buffer reflow. A minimized case showed
that reflow could consume the blank separator between adjacent paragraphs,
merging signatures even though paragraph boundaries should remain stable.

### Changes

**Reduced and promoted a failing fuzz case**
- Reduced seed `424242` / iter `97` into:
  - `test/fixtures/regressions/reflow_paragraph_signature_seed424242_iter97_reduced.txt`
  - `test/fixtures/regressions/reflow_paragraph_signature_seed424242_iter97_reduced.meta`
- Regression fixture is automatically exercised by
  `TestReflowRegressionFixtures()` in `test/test_reflow.vim`

**Fixed right-buffer paragraph placement in reflow** (`autoload/cleave.vim`)
- Updated `ReflowRightBuffer()` placement logic to enforce a minimum of one
  blank line between consecutive paragraphs when rebuilding the right buffer
- Replaced lookahead fit heuristics with a simpler placement rule:
  `actual_position = max(target_line, minimum_non_overlapping_position)`
  where minimum position includes one blank separator after prior paragraph

### Validation

- `test/test_reflow_fuzz.sh --replay test/fixtures/regressions/reflow_paragraph_signature_seed424242_iter97_reduced.txt --meta test/fixtures/regressions/reflow_paragraph_signature_seed424242_iter97_reduced.meta`
- `vim -u NONE -es -c "source test/test_reflow.vim" -c "call RunReflowTests()" -c "qa!"`
- `test/test_reflow_fuzz.sh --seed 424242 --iterations 500`

All commands above passed after the fix.

Note: a separate long campaign (`seed=424242`, `iterations=10000`) still
finds additional failures (`reason=width`, iter `4785`) to investigate next.

## 2026-02-24: Executable reflow spec and fuzzing workflow

### Problem

Reflow behavior had growing complexity (paragraph placement, justification,
anchors, join/recleave paths), but tests were mostly hand-written examples.
That made edge-case regressions expensive to detect and hard to reproduce.

### Changes

**Plan and documentation updates**
- Added a new robustness plan item in `vim_cleave_plan.md`:
  "Add executable spec + fuzzing loop for reflow"
- Added a `## Testing` section to `README.md` covering:
  - baseline reflow test command
  - deterministic fuzz runs
  - replaying saved failures
  - minimizing failures into regression fixtures

**Property-based fuzz harness** (`test/fuzz/reflow_fuzz.vim`)
- Added deterministic RNG + generated two-column test cases
- Added replay mode from saved case files (`.txt`) and metadata (`.meta`)
- Added invariant checks across split/reflow/join/recleave flow:
  - idempotence (`reflow` twice is stable)
  - paragraph signature preservation
  - width compliance (with guards for known display-width edge cases)
  - anchor parity between right paragraph starts and left text properties
  - join output matches expected merge math
- Added failure artifact capture with seed/iteration context

**Fuzz runner script** (`test/test_reflow_fuzz.sh`)
- Added CLI options: `--seed`, `--iterations`, `--replay`, `--meta`
- Added deterministic run output and replay instructions on failure

**Failure reducer** (`test/fuzz/reduce_reflow_failure.sh`)
- Added line-deletion delta reducer to minimize reproducing fuzz failures
- Added replay-based validation inside reducer loop
- Added `--help` handling and metadata output for reduced fixtures

**Fixture structure and ignore rules**
- Added `test/fixtures/failures/.gitkeep`
- Added `test/fixtures/regressions/.gitkeep`
- Updated `.gitignore` to ignore generated failure artifacts:
  - `test/fixtures/failures/*.txt`
  - `test/fixtures/failures/*.meta`

**Regression test integration** (`test/test_reflow.vim`)
- Added `TestReflowRegressionFixtures()`
- Added replay helper that runs `RunReflowFuzz()` per fixture under
  `test/fixtures/regressions/*.txt`
- Hooked regression fixture replay into `RunReflowTests()`

### Validation

- `vim -u NONE -es -c "source test/test_reflow.vim" -c "call RunReflowTests()" -c "qa!"`
- `bash test/test_reflow_simple.sh`
- `test/test_reflow_fuzz.sh --seed 123 --iterations 200`

All commands above passed during implementation.

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
