" cleave.vim - main script for cleave plugin

if exists('g:loaded_cleave')
    finish
endif
let g:loaded_cleave = 1

if !exists('g:cleave_auto_sync')
    let g:cleave_auto_sync = v:false
endif

command! -nargs=? Cleave call cleave#split_buffer(<f-args>)
command! -nargs=1 CleaveAt call cleave#split_buffer(<args>)
command! CleaveUndo call cleave#undo_cleave()
