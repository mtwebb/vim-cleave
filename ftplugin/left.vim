if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

if !exists('g:cleave_left_width')
    let g:cleave_left_width = &tw+&wrapmargin
endif

execute printf('syntax match Note ''\%%>%dv.\+''', g:cleave_left_width)
hi link Note Identifier
