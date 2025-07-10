if exists('g:loaded_cleave')
  finish
endif
let g:loaded_cleave = 1

command! -nargs=0 Cleave call cleave#Cleave()
