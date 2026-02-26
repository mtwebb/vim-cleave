# Agent Guide for vim-cleave

1) Build/lint/test
- Build: N/A (vim9script plugin)
- Lint: use vint if available: vint autoload/ plugin/ ftplugin/
- Run all tests (non-interactive): vim -u NONE -es -c "source test/test_reflow.vim" -c "call RunReflowTests()" -c "qa!"
- Run shell test: bash test/test_reflow_simple.sh
- Run a single test function: vim -u NONE -c "set rtp+=." -c "source test/test_reflow.vim" -c "call TestReflowBasic()" -c "qa!"
- Manual smoke test: vim -u NONE -c "set rtp+=." -c "source plugin/cleave.vim" -c "e test/test.txt" -c "call cursor(1,33)" -c "Cleave" -c "qa!"

2) Code style guidelines
- Language: vim9script; 4-space indent; no trailing whitespace
- File layout: commands in plugin/cleave.vim; core in autoload/cleave.vim; filetype tweaks in ftplugin/{left,right}.vim
- Naming: public funcs `export def PascalCase`; script-local `def PascalCase`; globals g:cleave_*; buffer vars via setbufvar/getbufvar
- Imports/loading: use autoload namespace cleave#...; no external deps
- Formatting: keep lines simple; prefer execute with fnameescape for filenames; avoid magic numbers
- Types: use vim9script type annotations on function params (number, string, list<any>, dict<any>)
- Errors: echoerr on invalid state/args; echomsg for info/debug; guard with bufexists(), win_findbuf()
- State: use b:cleave dict; use getbufvar('cleave', {}) for buffer state
- Text properties: type cleave_paragraph_start; check has('textprop'); use prop_type_add/prop_add/prop_remove safely
- Reflow rules: preserve paragraphs; width >= 10; left reflow updates window size and textwidth; right reflow preserves paragraph anchors
- Naming convs in ftplugins: highlight group Note; minimal options; avoid side effects outside buffer
- Tests: keep tests idempotent; clean temp files; prefer -u NONE with set rtp+=.

3) issues tracked in issues.md file. [x] indicates issue has been fixed.

4) Update JOURNAL.md with changes made during each session.
No Cursor or Copilot rules found.
