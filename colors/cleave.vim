" tuftish.vim -- Vim color scheme.
" Author:      Ben Weinstein-Raun (b@w-r.me)
" Webpage:     http://www.example.com
" Description: A theme reminiscent of the Tufte Jekyll theme

hi clear

if exists("syntax_on")
  syntax reset
endif

let colors_name = "cleave"
set background=light
set termguicolors


"let bg          = "#f5f3ee"
"let bg_section  = "#e8e5de"
"let heading     = "#1a1a18"
"let text        = "#2e2e2b"
"let text_muted  = "#8a8880"
"let accent_blue = "#4a7fa5"
"let fill        = "#1e1e1c"
"let border      = "#b5b2aa"

" Theme Colors
let bg_lightest = "#faf9f6"
let bg_main     = "#f0eee7"
let bg_section  = "#e8e5de"
let text_header = "#2c2b26"
let text_main   = "#5d5b4f"
let text_muted  = "#7b796a"
let accent_blue = "#4592cc"
let accent_red  = "#a05050"


let debug_red   = "#ff0000"
" Text Styles (link Core styles to these


" UI styles: put the non buffer styles here. 


execute "hi Normal     guibg=". bg_main . " guifg=" . text_main  . " cterm=NONE"
execute "hi FoldColumn guibg=". bg_main . " guifg=" . text_muted . " cterm=NONE"
execute "hi VertSplit  guibg=". bg_main . " guifg=" . bg_main .    " cterm=NONE"

"vim-cleave specific 
execute "hi Note       guibg=". bg_main . " guifg=" . text_muted . " cterm=italic cterm=italic"
execute "hi CleaveAnchor guibg=".bg_main." guifg=".debug_red . " cterm=NONE"
execute "hi Conceal guibg=".bg_main." guifg=".debug_red." cterm=NONE"
execute "hi StatusLine guibg=".bg_lightest." guifg=".accent_blue." cterm=bold,reverse" 
execute "hi StatusLineNC guibg=".bg_main." guifg=".text_muted." cterm=NONE"

execute "hi Modeline guifg=". accent_blue . " cterm=italic"  
execute "hi ColorColumn guibg=".bg_lightest. " guifg=".text_main

" Headings (H1-H5)
execute "hi markdownH1 guibg=".bg_main." guifg=".accent_blue." cterm=bold"
execute "hi markdownH2 guibg=".bg_main." guifg=".text_header." cterm=bold"
execute "hi markdownH3 guibg=".bg_main." guifg=".text_muted." cterm=bold"
execute "hi markdownH4 guibg=".bg_main." guifg=".text_header." cterm=underline"
execute "hi markdownH5 guibg=".bg_main." guifg=".text_header." cterm=NONE"

" Heading delimiters (#, ##, ###, ####, #####)
execute "hi markdownHeadingDelimiter guibg=".bg_main." guifg=".debug_red." cterm=NONE"
execute "hi markdownH1Delimiter guibg=".bg_main." guifg=".debug_red." cterm=NONE"
execute "hi markdownH2Delimiter guibg=".bg_main." guifg=".debug_red." cterm=NONE"
execute "hi markdownH3Delimiter guibg=".bg_main." guifg=".debug_red." cterm=NONE"
execute "hi markdownH4Delimiter guibg=".bg_main." guifg=".debug_red." cterm=NONE"
execute "hi markdownH5Delimiter guibg=".bg_main." guifg=".debug_red." cterm=NONE"

" List marker (kept from your example)
execute "hi markdownListMarker guibg=".bg_main." guifg=".text_main." cterm=bold"

" Code block delimiter (``` / ~~~ fences use markdownCodeDelimiter)
execute "hi markdownCodeDelimiter guibg=".bg_main." guifg=".debug_red." cterm=NONE"

execute "hi markdownBlockquote guibg=".bg_main." guifg=".text_main." cterm=italic"
execute "hi markdownBlockquoteDelimiter guibg=".bg_main." guifg=".debug_red." cterm=NONE" 

" Inline styles
execute "hi markdownBold guibg=".bg_main." guifg=".text_header." cterm=bold"
execute "hi markdownBoldDelimiter guibg=".bg_main." guifg=".debug_red." cterm=NONE"
execute "hi markdownItalic guibg=".bg_main." guifg=".text_main." cterm=italic"
execute "hi markdownItalicDelimiter guibg=".bg_main." guifg=".debug_red." cterm=NONE"
execute "hi markdownBoldItalic guibg=".bg_main." guifg=".text_header." cterm=bold,italic"
execute "hi markdownBoldItalicDelimiter guibg=".bg_main." guifg=".debug_red." cterm=NONE"
execute "hi markdownCode guibg=".bg_lightest." guifg=".text_muted." cterm=NONE"
execute "hi markdownStrike guibg=".bg_main." guifg=".text_muted." cterm=strikethrough"
execute "hi markdownStrikeDelimiter guibg=".bg_main." guifg=".debug_red." cterm=NONE"

" Links and URLs
execute "hi markdownLinkText guibg=".bg_main." guifg=".accent_blue." cterm=underline"
execute "hi markdownLinkTextDelimiter guibg=".bg_main." guifg=".debug_red." cterm=NONE"
execute "hi markdownLinkDelimiter guibg=".bg_main." guifg=".debug_red." cterm=NONE"
execute "hi markdownUrl guibg=".bg_main." guifg=".text_muted." cterm=underline"
execute "hi markdownUrlDelimiter guibg=".bg_main." guifg=".debug_red." cterm=NONE"
execute "hi markdownUrlTitle guibg=".bg_main." guifg=".text_main." cterm=italic"
execute "hi markdownUrlTitleDelimiter guibg=".bg_main." guifg=".debug_red." cterm=NONE"
execute "hi markdownIdDeclaration guibg=".bg_main." guifg=".accent_blue." cterm=NONE"
execute "hi markdownId guibg=".bg_main." guifg=".accent_blue." cterm=NONE"
execute "hi markdownIdDelimiter guibg=".bg_main." guifg=".debug_red." cterm=NONE"

" Rules and misc
execute "hi markdownRule guibg=".bg_main." guifg=".text_muted." cterm=NONE"
execute "hi markdownOrderedListMarker guibg=".bg_main." guifg=".text_main." cterm=bold"
execute "hi markdownFootnote guibg=".bg_main." guifg=".accent_blue." cterm=NONE"
execute "hi markdownFootnoteDefinition guibg=".bg_main." guifg=".text_muted." cterm=italic"

execute "hi Statement guibg=".bg_main." guifg=".text_muted." cterm=italic"

" Terminal ANSI palette (controls rg/bat colors in fzf terminal buffer)
let g:terminal_ansi_colors = [
    \ text_header,
    \ accent_red,
    \ '#6a8a50',
    \ '#8a7a40',
    \ accent_blue,
    \ text_main,
    \ text_main,
    \ bg_lightest,
    \ text_muted,
    \ accent_red,
    \ '#6a8a50',
    \ '#8a7a40',
    \ accent_blue,
    \ text_main,
    \ text_main,
    \ bg_lightest,
    \ ]

" fzf color integration
execute "hi FzfNormal guibg=".bg_section." guifg=".text_muted." cterm=NONE"
execute "hi FzfMatch guibg=".bg_section." guifg=".accent_red." cterm=NONE"
let g:fzf_colors =
\ { 'fg':      ['fg', 'FzfNormal'],
  \ 'bg':      ['bg', 'FzfNormal'],
  \ 'hl':      ['fg', 'FzfMatch'],
  \ 'fg+':     ['fg', 'markdownH2'],
  \ 'bg+':     ['bg', 'ColorColumn'],
  \ 'hl+':     ['fg', 'FzfMatch'],
  \ 'info':    ['fg', 'Note'],
  \ 'border':  ['fg', 'VertSplit'],
  \ 'prompt':  ['fg', 'markdownH1'],
  \ 'pointer': ['fg', 'markdownH1'],
  \ 'marker':  ['fg', 'markdownLinkText'],
  \ 'spinner': ['fg', 'Note'],
  \ 'header':  ['fg', 'Note'] }

" Notational Velocity integration
let g:nv_use_short_pathnames = 0
autocmd User NVEnter set laststatus=0
autocmd User NVLeave set laststatus=2
execute "autocmd User NVEnter hi StatusLine guibg=".bg_section." guifg=".text_muted
execute "autocmd User NVLeave hi StatusLine guibg=".bg_lightest." guifg=".accent_blue." cterm=bold,reverse"

"hi NonText guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi Comment guibg=#fdfbf4 guifg=#81b7f2 gui=NONE
"hi Constant guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi Error guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi Identifier guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi Ignore guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi PreProc guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi Special guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi Statement guibg=#fdfbf4 guifg=#cb1a00 gui=NONE
"hi Number guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi Todo guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi Type guibg=#fdfbf4 guifg=#333333 gui=bold
"hi Underlined guibg=#fdfbf4 guifg=#333333 gui=NONE
""hi StatusLine guibg=#fdfbf4 guifg=#c0c0c0 gui=italic
""hi StatusLineNC guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi TabLine guibg=#fdfbf4 guifg=#c0c0c0 gui=bold
"hi TabLineFill guibg=#fdfbf4 guifg=#c0c0c0 gui=bold
"hi TabLineSel guibg=#fdfbf4 guifg=#cb1a00 gui=bold
"hi Title guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi CursorLine guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi LineNr guibg=#fdfbf4 guifg=#c0c0c0 gui=italic
"hi CursorLineNr guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi helpLeadBlank guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi helpNormal guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi Visual guibg=#728baf guifg=#fdfbf4 gui=NONE
"hi VisualNOS guibg=#728baf guifg=#fdfbf4 gui=NONE
"hi Pmenu guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi PmenuSbar guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi PmenuSel guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi PmenuThumb guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi Folded guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi WildMenu guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi SpecialKey guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi DiffAdd guibg=#fdfbf4 guifg=#008f11 gui=NONE
"hi DiffChange guibg=#fdfbf4 guifg=#218cff gui=NONE
"hi DiffDelete guibg=#fdfbf4 guifg=#ab1500 gui=NONE
"hi DiffText guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi IncSearch guibg=#81b7f2 guifg=#333333 gui=NONE
"hi Search guibg=#728baf guifg=#ffffff gui=NONE
"hi Directory guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi MatchParen guibg=#fdfbf4 guifg=#1dca4e gui=NONE
"hi SpellBad guibg=#fdfbf4 guifg=#333333 gui=undercurl guisp=#cb1a00
"hi SpellCap guibg=#fdfbf4 guifg=#333333 gui=undercurl guisp=#21a2fd
"hi SpellLocal guibg=#fdfbf4 guifg=#333333 gui=undercurl guisp=#e62c55
"hi SpellRare guibg=#fdfbf4 guifg=#333333 gui=undercurl guisp=#81b7f2
"hi ColorColumn guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi signColumn guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi ErrorMsg guibg=#fdfbf4 guifg=#df9a1f gui=NONE
"hi ModeMsg guibg=#fdfbf4 guifg=#c0c0c0 gui=NONE
"hi MoreMsg guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi Question guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi WarningMsg guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi Cursor guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi CursorColumn guibg=#fdfbf4 guifg=#333333 gui=NONE
"
""mwebb additions for annotate-vim
"hi String guibg=#fdfbf4 guifg=#333333 gui=NONE
"hi StringItalic guibg=#fdfbf4 guifg=#333333 gui=NONE cterm=italic
"hi StringBold guibg=#fdfbf4 guifg=#333333 gui=NONE cterm=bold
"
"" hi link Note ModeMsg
"hi link FootnoteEditable String
"hi link FootnoteMarker ModeMsg
"hi link FootnoteDelimiter ModeMsg
"hi link NoteEditable Statement
"hi Heading1 gui=underline,bold
"hi Heading2 gui=bold
"hi Heading3 gui=underline
"hi link Quote StringItalic
"hi link Highlight StringBold
""hi link Modeline ModeMsg
""hi link Conceal MarkdownDelimiter
"hi ColorColumn guibg=#ffcc99 guifg=#333333 gui=NONE
"hi link SideNote Normal
"hi link EmbeddedSideNote ModeMsg
""syntax match Modeline /\v\c^\s*(#|\/\/|\/\*)?\s*vim:\s*set\s+.*:$/
