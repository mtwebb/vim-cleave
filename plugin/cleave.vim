vim9script

# cleave.vim - main script for cleave plugin

if exists('g:loaded_cleave')
    finish
endif
g:loaded_cleave = 1

command! -nargs=? CleaveAtCursor call cleave#SplitBuffer(bufnr('%'), <f-args>)
command! -nargs=1 CleaveAtColumn call cleave#SplitBuffer(winbufnr(0), <args>)
command! CleaveAtColorColumn call cleave#SplitAtColorcolumn()
command! CleaveAgain call cleave#RecleaveLast()
command! CleaveUndo call cleave#UndoCleave()
command! CleaveJoin call cleave#JoinBuffers()
command! -nargs=+ CleaveReflow call cleave#ReflowBuffer(<f-args>)
command! CleaveJustifyToggle call cleave#ToggleReflowMode()
command! CleaveSetProps call cleave#SetTextProperties()
command! CleaveAlign call cleave#AlignRightToLeftParagraphs()
command! CleaveToggleTextAnchorVis call cleave#ToggleParagraphHighlight()
command! CleaveShiftParagraphUp call cleave#ShiftParagraph('up')
command! CleaveShiftParagraphDown call cleave#ShiftParagraph('down')
command! -nargs=? CleaveDebug call cleave#DebugParagraphs(<f-args>)
