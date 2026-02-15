" cleave.vim - main script for cleave plugin

if exists('g:loaded_cleave')
    finish
endif
let g:loaded_cleave = 1



command! -nargs=? CleaveAtCursor call cleave#split_buffer(bufnr('%'), <f-args>)
command! -nargs=1 CleaveAtColumn call cleave#split_buffer(winbufnr(0), <args>)
command! CleaveAgain call cleave#recleave_last()
command! CleaveUndo call cleave#undo_cleave()
command! CleaveJoin call cleave#join_buffers()
command! -nargs=+ CleaveReflow call cleave#reflow_buffer(<f-args>)
command! CleaveJustifyToggle call cleave#toggle_reflow_mode()
command! CleaveSetProps call cleave#set_text_properties()
command! CleaveAlign call cleave#align_right_to_left_paragraphs()
command! CleaveToggleTextAnchorVis call cleave#toggle_paragraph_highlight()
command! CleaveShiftParagraphUp call cleave#shift_paragraph('up')
command! CleaveShiftParagraphDown call cleave#shift_paragraph('down')
