vim9script

# cleave_inline.vim - inline note import/export commands for cleave plugin

if exists('g:loaded_cleave_inline')
    finish
endif
g:loaded_cleave_inline = 1

command! CleaveImport call cleave#inline#SplitBuffer(bufnr('%'))
command! CleaveExport call cleave#inline#ExportSession()
