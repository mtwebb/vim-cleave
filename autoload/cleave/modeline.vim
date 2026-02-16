" cleave/modeline.vim - modeline parsing and management for cleave plugin

let s:save_cpo = &cpo
set cpo&vim

if !exists('g:cleave_modeline')
    let g:cleave_modeline = 'read'
endif

" Cleave-relevant option names (abbreviated forms)
let s:cleave_keys = ['cc', 'tw', 'fdc', 'wm', 've']

" ============================================================================
" Public API
" ============================================================================

" Return the current g:cleave_modeline value (default 'read')
function! cleave#modeline#mode() abort
    return get(g:, 'cleave_modeline', 'read')
endfunction

" Scan buffer for a vim: modeline and extract cleave-relevant settings.
" Returns {'line': line_number_or_0, 'settings': {...}, 'other': '...'}
function! cleave#modeline#parse(bufnr) abort
    if !bufexists(a:bufnr)
        echoerr 'Cleave: buffer ' . a:bufnr . ' does not exist'
        return {'line': 0, 'settings': {}, 'other': ''}
    endif

    let total = getbufinfo(a:bufnr)[0].linecount
    let ranges = s:modeline_ranges(total)

    for lnum in ranges
        let text = getbufline(a:bufnr, lnum)[0]
        let parsed = s:parse_modeline_text(text)
        if !empty(parsed)
            return {'line': lnum, 'settings': parsed.settings, 'other': parsed.other}
        endif
    endfor

    return {'line': 0, 'settings': {}, 'other': ''}
endfunction

" Validate a settings dict and return clamped/safe values.
" Returns {'cc': num, 'tw': num, 'fdc': num, 'wm': num, 've': str}
function! cleave#modeline#apply(settings) abort
    let result = {}
    let result.cc  = s:clamp(get(a:settings, 'cc', 0), 10, 999)
    let result.tw  = s:clamp(get(a:settings, 'tw', 0), 10, 999)
    let result.fdc = s:clamp(get(a:settings, 'fdc', 0), 0, 12)
    let result.wm  = s:clamp(get(a:settings, 'wm', 0), 0, 99)
    let result.ve  = s:validate_ve(get(a:settings, 've', 'all'))
    return result
endfunction

" Infer cleave settings from buffer state when no modeline is present.
function! cleave#modeline#infer(bufnr) abort
    if !bufexists(a:bufnr)
        echoerr 'Cleave: buffer ' . a:bufnr . ' does not exist'
        return {}
    endif

    let settings = {}

    " ve: default 'all'
    let settings.ve = 'all'

    " tw: prefer existing textwidth, else infer from average line length
    let buf_tw = getbufvar(a:bufnr, '&textwidth')
    if buf_tw > 0
        let settings.tw = buf_tw
    else
        let settings.tw = s:infer_textwidth(a:bufnr)
    endif

    " wm: prefer wrapmargin, else default to g:cleave_gutter or 3
    let buf_wm = getbufvar(a:bufnr, '&wrapmargin')
    if buf_wm > 0
        let settings.wm = buf_wm
    else
        let settings.wm = get(g:, 'cleave_gutter', 3)
    endif

    " fdc: prefer foldcolumn, else infer from indent variance
    let buf_fdc = getbufvar(a:bufnr, '&foldcolumn')
    if buf_fdc > 0
        let settings.fdc = buf_fdc
    else
        let settings.fdc = s:infer_foldcolumn(a:bufnr)
    endif

    " cc: prefer colorcolumn, else tw + wm if tw is set, else 79/80
    let buf_cc = getbufvar(a:bufnr, '&colorcolumn')
    if buf_cc !=# '' && buf_cc =~# '^\d\+$'
        let settings.cc = str2nr(buf_cc)
    elseif settings.tw > 0
        let settings.cc = settings.tw + settings.wm
    else
        let settings.cc = 80
    endif

    return settings
endfunction

" Insert or update a modeline in the buffer.
" Only writes if g:cleave_modeline is 'update'.
function! cleave#modeline#ensure(bufnr, settings) abort
    if !bufexists(a:bufnr)
        echoerr 'Cleave: buffer ' . a:bufnr . ' does not exist'
        return
    endif

    if cleave#modeline#mode() !=# 'update'
        return
    endif

    if !getbufvar(a:bufnr, '&modifiable')
        return
    endif

    let parsed = cleave#modeline#parse(a:bufnr)
    let modeline_str = cleave#modeline#build_string(a:settings, parsed.other)

    if parsed.line > 0
        call setbufline(a:bufnr, parsed.line, modeline_str)
    else
        let total = getbufinfo(a:bufnr)[0].linecount
        call appendbufline(a:bufnr, total, modeline_str)
    endif

    " Apply settings to the buffer's vim options
    call s:apply_settings_to_buffer(a:bufnr, a:settings)
endfunction

" Apply modeline settings to buffer/window vim options
function! s:apply_settings_to_buffer(bufnr, settings) abort
    if has_key(a:settings, 'tw') && a:settings.tw > 0
        call setbufvar(a:bufnr, '&textwidth', a:settings.tw)
    endif
    if has_key(a:settings, 'wm') && a:settings.wm >= 0
        let g:cleave_gutter = a:settings.wm
    endif
    " colorcolumn and foldcolumn are window-local; virtualedit is global
    let winid = get(win_findbuf(a:bufnr), 0, -1)
    if winid != -1
        if has_key(a:settings, 'fdc')
            call setwinvar(win_id2win(winid), '&foldcolumn', a:settings.fdc)
        endif
        if has_key(a:settings, 'cc') && a:settings.cc > 0
            call setwinvar(win_id2win(winid), '&colorcolumn',
                \ string(a:settings.cc))
        endif
    endif
    if has_key(a:settings, 've') && !empty(a:settings.ve)
        let &virtualedit = a:settings.ve
    endif
endfunction

" Build a modeline string from settings dict and any other non-cleave options.
" Format: vim: cc=91 tw=79 ve=all fdc=5 wm=3 [other options]
function! cleave#modeline#build_string(settings, other_opts) abort
    let parts = []
    for key in s:cleave_keys
        if has_key(a:settings, key)
            call add(parts, key . '=' . a:settings[key])
        endif
    endfor
    let result = 'vim: ' . join(parts, ' ')
    if a:other_opts !=# ''
        let result .= ' ' . a:other_opts
    endif
    return result
endfunction

" ============================================================================
" Script-local helpers
" ============================================================================

" Return line numbers to scan for modelines (first 5 and last 5)
function! s:modeline_ranges(total) abort
    let lines = []
    let head = min([5, a:total])
    for i in range(1, head)
        call add(lines, i)
    endfor
    let tail_start = max([head + 1, a:total - 4])
    for i in range(tail_start, a:total)
        call add(lines, i)
    endfor
    return lines
endfunction

" Parse a single line of text for a vim: modeline.
" Returns {} if not a modeline, or {'settings': {...}, 'other': '...'} if found.
function! s:parse_modeline_text(text) abort
    " Match vim: at start or after whitespace/comment chars
    " Handle both 'vim: set opt1=val1 opt2=val2 :' and 'vim: opt1=val1 opt2=val2'
    let pat = '\v^.*<vim:\s*(set\s+)?(.*)'
    let m = matchlist(a:text, pat)
    if empty(m)
        return {}
    endif

    let opts_str = m[2]
    " Strip trailing ':' from 'vim: set ... :' format
    let opts_str = substitute(opts_str, '\s*:\s*$', '', '')

    let settings = {}
    let other_parts = []

    for token in split(opts_str)
        let kv = matchlist(token, '^\([a-zA-Z]\+\)=\(.*\)$')
        if !empty(kv)
            let key = kv[1]
            let val = kv[2]
            if index(s:cleave_keys, key) >= 0
                if key ==# 've'
                    let settings[key] = val
                else
                    let settings[key] = str2nr(val)
                endif
            else
                call add(other_parts, token)
            endif
        else
            " bare option (e.g., 'noai')
            call add(other_parts, token)
        endif
    endfor

    return {'settings': settings, 'other': join(other_parts, ' ')}
endfunction

" Clamp a numeric value to [lo, hi]
function! s:clamp(val, lo, hi) abort
    let n = type(a:val) == v:t_string ? str2nr(a:val) : a:val
    return max([a:lo, min([a:hi, n])])
endfunction

" Validate virtualedit value
function! s:validate_ve(val) abort
    let valid = ['all', 'block', 'insert', 'onemore', 'none', '']
    if index(valid, a:val) >= 0
        return a:val
    endif
    return 'all'
endfunction

" Infer textwidth from average non-empty line length in buffer (cap at 79)
function! s:infer_textwidth(bufnr) abort
    let lines = getbufline(a:bufnr, 1, '$')
    let total_len = 0
    let line_count = 0
    for line in lines
        if line !=# ''
            let total_len += len(line)
            let line_count += 1
        endif
    endfor
    if line_count == 0
        return 79
    endif
    let avg = total_len / line_count
    return min([avg, 79])
endfunction

" Infer foldcolumn from leading-indent variance (default 0)
function! s:infer_foldcolumn(bufnr) abort
    let lines = getbufline(a:bufnr, 1, '$')
    let indents = []
    for line in lines
        if line !=# ''
            let leading = len(matchstr(line, '^\s*'))
            call add(indents, leading)
        endif
    endfor
    if len(indents) < 2
        return 0
    endif
    " If there is significant indent variance, suggest a small foldcolumn
    let min_indent = min(indents)
    let max_indent = max(indents)
    if max_indent - min_indent > 4
        return min([max_indent, 4])
    endif
    return 0
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
