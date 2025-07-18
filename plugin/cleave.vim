" cleave.vim - main script for cleave plugin

if exists('g:loaded_cleave')
    finish
endif
let g:loaded_cleave = 1



command! -nargs=? CleaveAtCursor call cleave#split_buffer(bufnr('%'), <f-args>)
command! -nargs=1 CleaveAtColumn call cleave#split_buffer(winbufnr(0), <args>)
command! CleaveUndo call cleave#undo_cleave()
command! CleaveJoin call cleave#join_buffers()
command! -nargs=1 CleaveReflow call cleave#reflow_buffer(<args>)
command! CleaveSetProps call cleave#set_text_properties()
