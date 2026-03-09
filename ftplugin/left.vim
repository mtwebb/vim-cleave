if !exists('g:cleave_left_width')
    let g:cleave_left_width = &tw+&wrapmargin
endif

if &l:filetype =~# '\.left$'
    let base_ft = substitute(&l:filetype, '\.left$', '', '')
    if !empty(base_ft) && &l:syntax ==# &l:filetype
        execute 'setlocal syntax=' . base_ft
    endif
endif

execute printf('syntax match Note ''\%%>%dv.\+''', g:cleave_left_width)
hi link Note Identifier

" Markdown specific niceties 
" syntax match markdownCodeFence /```/ conceal
if &l:filetype =~# '\<markdown\>'
    " Left-side fragments are often invalid markdown; suppress markdownError
    " noise so headings/lists don't render as errors after splitting.
    if hlexists('markdownError')
        syntax clear markdownError
    endif

    if hlexists('markdownH3')
        syntax clear markdownH3
        syntax region markdownH3 matchgroup=markdownH3Delimiter
            \ start=" \{,3}###\s" end="#*\s*$" keepend oneline
            \ contains=@markdownInline,markdownAutomaticLink
            \ contained concealends
    endif

    if hlexists('markdownH1')
        syntax clear markdownH1
        syntax region markdownH1 matchgroup=markdownH1Delimiter
            \ start=" \{,3}#\s" end="#*\s*$" keepend oneline
            \ contains=@markdownInline,markdownAutomaticLink
            \ contained concealends
    endif

    if hlexists('markdownH2')
        syntax clear markdownH2
        syntax region markdownH2 matchgroup=markdownH2Delimiter
            \ start=" \{,3}##\s" end="#*\s*$" keepend oneline
            \ contains=@markdownInline,markdownAutomaticLink
            \ contained concealends
    endif

    if hlexists('markdownH4')
        syntax clear markdownH4
        syntax region markdownH4 matchgroup=markdownH4Delimiter
            \ start=" \{,3}####\s" end="#*\s*$" keepend oneline
            \ contains=@markdownInline,markdownAutomaticLink
            \ contained concealends
    endif

    if hlexists('markdownH5')
        syntax clear markdownH5
        syntax region markdownH5 matchgroup=markdownH5Delimiter
            \ start=" \{,3}#####\s" end="#*\s*$" keepend oneline
            \ contains=@markdownInline,markdownAutomaticLink
            \ contained concealends
    endif

    if hlexists('markdownCodeBlock')
        syntax clear markdownCodeBlock
        syntax region markdownCodeBlock
            \ start="^\n\( \{4,}\|\t\)"
            \ end="^\ze \{,3}\S.*$" keepend
        syntax region markdownCodeBlock matchgroup=markdownCodeDelimiter
            \ start="^\s*\z(`\{3,\}\).*$"
            \ end="^\s*\z1\ze\s*$" keepend concealends
        syntax region markdownCodeBlock matchgroup=markdownCodeDelimiter
            \ start="^\s*\z(\~\{3,\}\).*$"
            \ end="^\s*\z1\ze\s*$" keepend concealends
    endif

    if hlexists('markdownBlockquote')
        syntax clear markdownBlockquote
        if hlexists('markdownBlockquoteDelimiter')
            syntax clear markdownBlockquoteDelimiter
        endif
        execute 'syntax match markdownBlockquoteDelimiter "^\s*>" conceal cchar= '
        syntax region markdownBlockquote
            \ start="^\s*>\s\?"
            \ end="$" keepend oneline
            \ contains=@markdownInline,markdownAutomaticLink,markdownBlockquoteDelimiter
    endif

    if !hlexists('markdownBlockquoteDelimiter')
        highlight default link markdownBlockquoteDelimiter Delimiter
    endif
    highlight default link markdownBlockquote Comment
endif
syntax match Modeline /^vim: .*$/
"complete hide and only display when on line in insert mode
setlocal conceallevel=2
setlocal concealcursor=n
