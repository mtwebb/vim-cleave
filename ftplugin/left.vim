if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

if !exists('g:cleaveleftwidth')
    let g:cleaveleftwidth = &tw+&wrapmargin
endif

execute printf('syntax match Note ''\%%>%dv.\+''', g:cleaveleftwidth)
hi link Note Identifier
