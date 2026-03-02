if !exists('g:cleave_left_width')
    let g:cleave_left_width = &tw+&wrapmargin
endif

execute printf('syntax match Note ''\%%>%dv.\+''', g:cleave_left_width)
hi link Note Identifier

" Markdown specific niceties 
syntax match markdownCodeFence /```/ conceal
syntax match markdownHeadingDelimiter "^#\{1,6}\s" conceal

"complete hide and only display when on line in insert mode
setlocal conceallevel=2
setlocal concealcursor=n
